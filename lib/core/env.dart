/// Build-time configuration, injected with `--dart-define-from-file=dart_defines.json`.
/// Never hard-code keys in the repository.
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Legacy anon key or new publishable key (sb_publishable_…). Both are safe on the client.
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const revenueCatAppleKey = String.fromEnvironment('REVENUECAT_APPLE_KEY');
  static const revenueCatGoogleKey = String.fromEnvironment('REVENUECAT_GOOGLE_KEY');

  /// Public web app (PWA) URL, used to build share links: `<webBaseUrl>/s/<token>`.
  static const webBaseUrl = String.fromEnvironment('WEB_BASE_URL', defaultValue: 'https://keevy.app');

  /// RevenueCat entitlement identifier that unlocks Premium.
  static const premiumEntitlement = String.fromEnvironment('REVENUECAT_ENTITLEMENT', defaultValue: 'premium');

  static const appVersion = '1.0.0';

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
