import Flutter
import UIKit

/// Bridge between the KeevyShare extension and Flutter (`app.keevy/share` channel).
/// The extension writes shared items into the App Group inbox; the app imports them.
/// The app writes the boards list there so the extension can offer a board picker.
public class KeevySharePlugin: NSObject, FlutterPlugin {
  static let appGroup = "group.app.keevy.keevy"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "app.keevy/share", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(KeevySharePlugin(), channel: channel)
  }

  private var container: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: KeevySharePlugin.appGroup)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "takePending":
      result(takeInbox())
    case "syncBoards":
      if let args = call.arguments as? [String: Any], let boards = args["boards"] {
        writeBoards(boards)
      }
      result(nil)
    case "finishShare":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func takeInbox() -> [[String: Any]] {
    guard let container = container else { return [] }
    let inbox = container.appendingPathComponent("inbox.json")
    var items: [[String: Any]] = []
    let coordinator = NSFileCoordinator()
    var error: NSError?
    coordinator.coordinate(writingItemAt: inbox, options: .forDeleting, error: &error) { url in
      if let data = try? Data(contentsOf: url),
         let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
        items = parsed
      }
      try? FileManager.default.removeItem(at: url)
    }
    cleanOldFiles(in: container.appendingPathComponent("inbox", isDirectory: true))
    return items
  }

  private func writeBoards(_ boards: Any) {
    guard let container = container,
          JSONSerialization.isValidJSONObject(boards),
          let data = try? JSONSerialization.data(withJSONObject: boards) else { return }
    try? data.write(to: container.appendingPathComponent("boards.json"), options: .atomic)
  }

  /// Images imported more than a week ago are no longer needed.
  private func cleanOldFiles(in dir: URL) {
    let limit = Date().addingTimeInterval(-7 * 24 * 3600)
    guard let files = try? FileManager.default.contentsOfDirectory(
      at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
    for file in files {
      let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
      if let date = date, date < limit { try? FileManager.default.removeItem(at: file) }
    }
  }
}
