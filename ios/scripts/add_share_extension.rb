# Adds the "KeevyShare" share extension target to ios/Runner.xcodeproj and wires
# the App Group entitlements. Idempotent: does nothing if the target exists.
#
#   gem install xcodeproj
#   ruby ios/scripts/add_share_extension.rb
#
# (CI runs it automatically, see .github/workflows/ci.yml → bootstrap.)
require 'xcodeproj'

PROJECT = File.expand_path('../Runner.xcodeproj', __dir__)
EXT_NAME = 'KeevyShare'
EXT_BUNDLE_ID = 'app.keevy.keevy.share'
DEPLOYMENT_TARGET = '15.0'

project = Xcodeproj::Project.open(PROJECT)
if project.targets.any? { |t| t.name == EXT_NAME }
  puts "#{EXT_NAME} already present"
  exit 0
end

app = project.targets.find { |t| t.name == 'Runner' } or abort('Runner target not found')

# ── Runner: share bridge + App Group entitlements ──────────────────────────
runner_group = project.main_group['Runner'] or abort('Runner group not found')
plugin_ref = runner_group.files.find { |f| f.path.to_s.end_with?('KeevySharePlugin.swift') } || runner_group.new_reference('KeevySharePlugin.swift')
app.add_file_references([plugin_ref]) unless app.source_build_phase.files_references.include?(plugin_ref)
runner_group.new_reference('Runner.entitlements') unless runner_group.files.any? { |f| f.path.to_s.end_with?('Runner.entitlements') }
app.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

# ── Extension target ───────────────────────────────────────────────────────
ext = project.new_target(:app_extension, EXT_NAME, :ios, DEPLOYMENT_TARGET)

group = project.main_group.new_group(EXT_NAME, EXT_NAME)
swift_ref = group.new_reference('ShareViewController.swift')
group.new_reference('Info.plist')
group.new_reference("#{EXT_NAME}.entitlements")
ext.add_file_references([swift_ref])

# Version numbers come from Flutter (FLUTTER_BUILD_NAME / FLUTTER_BUILD_NUMBER).
flutter_group = project.main_group['Flutter'] or abort('Flutter group not found')
generated = flutter_group.files.find { |f| f.display_name == 'Generated.xcconfig' || f.path.to_s.end_with?('Generated.xcconfig') } ||
            flutter_group.new_reference('Generated.xcconfig')

ext.build_configurations.each do |config|
  config.base_configuration_reference = generated
  s = config.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = EXT_BUNDLE_ID
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = "#{EXT_NAME}/Info.plist"
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['CODE_SIGN_ENTITLEMENTS'] = "#{EXT_NAME}/#{EXT_NAME}.entitlements"
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
  s['SKIP_INSTALL'] = 'YES'
  s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  s['ENABLE_BITCODE'] = 'NO'
end

# ── Embed the extension in the app ─────────────────────────────────────────
embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
build_file = embed.add_file_reference(ext.product_reference, true)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
app.add_dependency(ext)

# Xcode 15+ "cycle inside Runner" fix: embed extensions before the Thin Binary script.
phases = app.build_phases
thin = phases.find { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
if thin
  phases.delete(embed)
  phases.insert(phases.index(thin), embed)
end

project.save
puts "#{EXT_NAME} target added"
