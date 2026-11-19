import SwiftUI
import UIKit
import UniformTypeIdentifiers

// "Enregistrer dans Keevy" — native share sheet shown over Instagram, TikTok, Safari…
// It never leaves the source app: items go into the App Group inbox and are imported
// by Keevy the next time it comes to the foreground.

private let appGroup = "group.app.keevy.keevy"

private func L(_ fr: String, _ en: String) -> String {
  (Locale.preferredLanguages.first ?? "fr").hasPrefix("en") ? en : fr
}

private extension Color {
  static let keevyPrimary = Color(red: 0x1A / 255, green: 0x1A / 255, blue: 0x2E / 255)
  static let keevyBackground = Color(red: 0xF7 / 255, green: 0xF4 / 255, blue: 0xF1 / 255)

  init(hex: String?) {
    let cleaned = (hex ?? "#B07860").replacingOccurrences(of: "#", with: "")
    let value = UInt64(cleaned, radix: 16) ?? 0xB07860
    self.init(
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255
    )
  }
}

struct SharedBoard: Decodable, Identifiable, Hashable {
  struct BoardSection: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
  }

  let id: String
  let name: String
  let emoji: String?
  let color: String?
  let mode: String?
  let sections: [BoardSection]?
}

/// Thread-safe collector for item-provider callbacks.
final class Accumulator: @unchecked Sendable {
  private let lock = NSLock()
  private var _texts: [String] = []
  private var _images: [String] = []

  var texts: [String] { lock.lock(); defer { lock.unlock() }; return _texts }
  var images: [String] { lock.lock(); defer { lock.unlock() }; return _images }

  func add(text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    lock.lock(); defer { lock.unlock() }
    if !_texts.contains(trimmed) { _texts.append(trimmed) }
  }

  func add(image path: String) {
    lock.lock(); defer { lock.unlock() }
    _images.append(path)
  }
}

final class ShareModel: ObservableObject {
  enum Kind: String { case inspiration, vendor }

  @Published var loading = true
  @Published var text: String?
  @Published var imagePaths: [String] = []
  @Published var boards: [SharedBoard] = []
  @Published var kind: Kind = .inspiration
  @Published var boardId: String?
  @Published var sectionId: String?
  @Published var note = ""

  private var container: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
  }

  var selectedBoard: SharedBoard? { boards.first { $0.id == boardId } }
  var hasImages: Bool { !imagePaths.isEmpty }
  var canBeVendor: Bool { text != nil && !hasImages }

  /// Profiles (instagram.com/<handle>, tiktok.com/@handle), emails and phones look like vendors.
  var looksLikeVendor: Bool {
    guard let t = text?.lowercased() else { return false }
    if t.contains("@") && !t.contains("http") { return true }
    if let url = URL(string: t.trimmingCharacters(in: .whitespacesAndNewlines)), let host = url.host {
      let parts = url.pathComponents.filter { $0 != "/" }
      if host.contains("instagram.com") {
        let reserved: Set<String> = ["p", "reel", "reels", "tv", "stories", "explore"]
        return parts.count == 1 && !reserved.contains(parts[0])
      }
      if host.contains("tiktok.com") { return parts.count == 1 && parts[0].hasPrefix("@") }
    }
    return false
  }

  func loadBoards() {
    guard let url = container?.appendingPathComponent("boards.json"),
          let data = try? Data(contentsOf: url),
          let decoded = try? JSONDecoder().decode([SharedBoard].self, from: data) else { return }
    boards = decoded
  }

  func load(from context: NSExtensionContext?) {
    loadBoards()
    let items = (context?.inputItems as? [NSExtensionItem]) ?? []
    let providers = items.flatMap { $0.attachments ?? [] }
    let acc = Accumulator()
    let folder = container
    let group = DispatchGroup()

    for provider in providers {
      if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
        group.enter()
        provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
          var data: Data?
          if let url = item as? URL { data = try? Data(contentsOf: url) }
          else if let image = item as? UIImage { data = image.jpegData(compressionQuality: 0.85) }
          else if let raw = item as? Data { data = raw }
          if let data = data, let path = ShareModel.saveImage(data, container: folder) { acc.add(image: path) }
          group.leave()
        }
      } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
        group.enter()
        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
          if let url = item as? URL, !url.isFileURL { acc.add(text: url.absoluteString) }
          else if let string = item as? String { acc.add(text: string) }
          group.leave()
        }
      } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
        group.enter()
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
          if let string = item as? String { acc.add(text: string) }
          group.leave()
        }
      }
    }

    group.notify(queue: .main) { [weak self] in
      guard let self = self else { return }
      let texts = acc.texts
      self.text = texts.isEmpty ? nil : texts.joined(separator: "\n")
      self.imagePaths = acc.images
      self.kind = self.looksLikeVendor ? .vendor : .inspiration
      self.loading = false
    }
  }

  /// Normalises to JPEG (HEIC → JPEG), max 2400 px, into the App Group inbox folder.
  static func saveImage(_ data: Data, container: URL?) -> String? {
    guard let container = container, let image = UIImage(data: data) else { return nil }
    let dir = container.appendingPathComponent("inbox", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let maxSide: CGFloat = 2400
    let size = image.size
    let scale = min(1, maxSide / max(size.width, size.height))
    var output = image
    if scale < 1 {
      let target = CGSize(width: size.width * scale, height: size.height * scale)
      output = UIGraphicsImageRenderer(size: target).image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
    }
    guard let jpeg = output.jpegData(compressionQuality: 0.85) else { return nil }
    let file = dir.appendingPathComponent("\(UUID().uuidString).jpg")
    do {
      try jpeg.write(to: file, options: .atomic)
      return file.path
    } catch {
      return nil
    }
  }

  /// Appends the items to inbox.json (read and cleared by the app).
  func persist() {
    guard let container = container else { return }
    var newItems: [[String: Any]] = []
    func base(_ type: String, _ value: String) -> [String: Any] {
      var item: [String: Any] = ["type": type, "value": value, "kind": kind.rawValue,
                                 "createdAt": ISO8601DateFormatter().string(from: Date())]
      if let boardId = boardId { item["boardId"] = boardId }
      if let sectionId = sectionId, kind == .inspiration { item["sectionId"] = sectionId }
      let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmedNote.isEmpty { item["note"] = trimmedNote }
      return item
    }
    for path in imagePaths {
      var item = base("image", path)
      item["mimeType"] = "image/jpeg"
      item["kind"] = Kind.inspiration.rawValue
      newItems.append(item)
    }
    if let text = text { newItems.append(base("text", text)) }
    guard !newItems.isEmpty else { return }

    let inbox = container.appendingPathComponent("inbox.json")
    let coordinator = NSFileCoordinator()
    var error: NSError?
    coordinator.coordinate(writingItemAt: inbox, options: .forMerging, error: &error) { url in
      var existing: [[String: Any]] = []
      if let data = try? Data(contentsOf: url),
         let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
        existing = parsed
      }
      existing.append(contentsOf: newItems)
      if let data = try? JSONSerialization.data(withJSONObject: existing) {
        try? data.write(to: url, options: .atomic)
      }
    }
  }
}

struct ShareView: View {
  @ObservedObject var model: ShareModel
  let onCancel: () -> Void
  let onSave: () -> Void

  var body: some View {
    NavigationView {
      Group {
        if model.loading {
          ProgressView()
        } else {
          Form {
            Section {
              preview
            }
            if model.canBeVendor {
              Section {
                Picker("", selection: $model.kind) {
                  Text(L("Une inspiration", "An idea")).tag(ShareModel.Kind.inspiration)
                  Text(L("Un prestataire", "A vendor")).tag(ShareModel.Kind.vendor)
                }
                .pickerStyle(.segmented)
              }
            }
            Section(header: Text(L("Choisis un board", "Pick a board"))) {
              if model.boards.isEmpty {
                Text(L("Ouvre Keevy et connecte-toi pour retrouver tes boards ici. Tu peux aussi l’enregistrer pour plus tard.",
                       "Open Keevy and sign in to see your boards here. You can also save it for later."))
                  .font(.footnote)
                  .foregroundColor(.secondary)
              }
              ForEach(model.boards) { board in
                Button {
                  model.boardId = model.boardId == board.id ? nil : board.id
                  model.sectionId = nil
                } label: {
                  HStack {
                    Text(board.emoji ?? "✨")
                      .frame(width: 32, height: 32)
                      .background(Color(hex: board.color).opacity(0.18))
                      .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text(board.name).foregroundColor(.primary)
                    Spacer()
                    if model.boardId == board.id {
                      Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    }
                  }
                }
              }
            }
            if model.kind == .inspiration, let sections = model.selectedBoard?.sections, !sections.isEmpty {
              Section(header: Text(L("Section", "Section"))) {
                ScrollView(.horizontal, showsIndicators: false) {
                  HStack {
                    chip(L("Sans section", "No section"), selected: model.sectionId == nil) { model.sectionId = nil }
                    ForEach(sections) { section in
                      chip(section.name, selected: model.sectionId == section.id) { model.sectionId = section.id }
                    }
                  }
                  .padding(.vertical, 4)
                }
              }
            }
            Section {
              TextField(L("Ajouter une note (optionnel)", "Add a note (optional)"), text: $model.note)
            }
          }
        }
      }
      .navigationTitle(L("Enregistrer dans Keevy", "Save to Keevy"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L("Annuler", "Cancel"), action: onCancel)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(model.boardId == nil ? L("Plus tard", "Later") : L("Enregistrer", "Save"), action: onSave)
            .font(.body.weight(.semibold))
            .disabled(model.loading || (model.text == nil && model.imagePaths.isEmpty))
        }
      }
    }
    .navigationViewStyle(.stack)
    .tint(.keevyPrimary)
  }

  @ViewBuilder private var preview: some View {
    if let first = model.imagePaths.first, let image = UIImage(contentsOfFile: first) {
      HStack(spacing: 12) {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(width: 64, height: 64)
          .clipShape(RoundedRectangle(cornerRadius: 10))
        Text(model.imagePaths.count > 1 ? L("\(model.imagePaths.count) photos", "\(model.imagePaths.count) photos") : L("1 photo", "1 photo"))
          .font(.headline)
      }
    } else if let text = model.text {
      VStack(alignment: .leading, spacing: 4) {
        if let url = URL(string: text.components(separatedBy: .whitespacesAndNewlines).first(where: { $0.hasPrefix("http") }) ?? ""),
           let host = url.host {
          Text(host.replacingOccurrences(of: "www.", with: "")).font(.headline)
        }
        Text(text).font(.footnote).foregroundColor(.secondary).lineLimit(3)
      }
    } else {
      Text(L("Rien à enregistrer", "Nothing to save")).foregroundColor(.secondary)
    }
  }

  private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(label)
        .font(.footnote.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(selected ? Color.keevyPrimary : Color.keevyBackground)
        .foregroundColor(selected ? .white : .primary)
        .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }
}

class ShareViewController: UIViewController {
  private let model = ShareModel()

  override func viewDidLoad() {
    super.viewDidLoad()
    let root = ShareView(
      model: model,
      onCancel: { [weak self] in
        self?.extensionContext?.cancelRequest(withError: NSError(domain: "app.keevy.share", code: 0))
      },
      onSave: { [weak self] in
        self?.model.persist()
        self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
      }
    )
    let host = UIHostingController(rootView: root)
    addChild(host)
    host.view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(host.view)
    NSLayoutConstraint.activate([
      host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      host.view.topAnchor.constraint(equalTo: view.topAnchor),
      host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    host.didMove(toParent: self)
    model.load(from: extensionContext)
  }
}
