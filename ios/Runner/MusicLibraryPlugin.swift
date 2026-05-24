import Flutter
import UIKit
import MediaPlayer
import AVFoundation

/// Bridges Flutter ↔ the iOS Music library so the Area Configuration screen
/// can offer "Pick from Apple Music" alongside the existing Files picker.
///
/// Flow:
///   1. `pick` opens `MPMediaPickerController` and resolves with the user's
///      chosen items once they tap Done (or with an empty list on cancel).
///   2. Each non-DRM item is exported to
///      `<Documents>/MusicLibrary/<persistentID>.m4a` via
///      `AVAssetExportSession`. The on-disk filename is stable per track so
///      a re-pick is idempotent and the existing audio engine treats the
///      path like any other MP3.
///   3. The result map contains `tracks` (successfully exported file paths
///      with metadata) and `skipped` (DRM-locked tracks reported back so
///      the UI can show a snackbar).
///
/// DRM caveat: tracks from an Apple Music subscription have a nil asset
/// URL — they can't be exported. We surface those in `skipped` rather than
/// silently dropping them.
public class MusicLibraryPlugin: NSObject, FlutterPlugin, MPMediaPickerControllerDelegate {
  private var pendingResult: FlutterResult?
  private weak var presented: MPMediaPickerController?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "ancient_anguish_client/music_library",
      binaryMessenger: registrar.messenger()
    )
    let instance = MusicLibraryPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pick":
      if pendingResult != nil {
        result(FlutterError(
          code: "already_picking",
          message: "A music library picker is already presented",
          details: nil
        ))
        return
      }
      pendingResult = result
      DispatchQueue.main.async { self.presentPicker() }

    case "isAvailable":
      // Always true on iOS; the platform check lives in Dart but we keep
      // this around for symmetry.
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func presentPicker() {
    let picker = MPMediaPickerController(mediaTypes: .music)
    picker.delegate = self
    picker.allowsPickingMultipleItems = true
    picker.showsCloudItems = false  // exporting cloud items is unreliable
    picker.prompt = "Pick tracks to add to this area"

    guard let topVC = topViewController() else {
      finish(error: "no_view_controller", message: "Could not present picker")
      return
    }
    presented = picker
    topVC.present(picker, animated: true)
  }

  // MARK: MPMediaPickerControllerDelegate

  public func mediaPicker(
    _ mediaPicker: MPMediaPickerController,
    didPickMediaItems mediaItemCollection: MPMediaItemCollection
  ) {
    mediaPicker.dismiss(animated: true) { [weak self] in
      self?.export(items: mediaItemCollection.items)
    }
  }

  public func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
    mediaPicker.dismiss(animated: true) { [weak self] in
      self?.finish(tracks: [], skipped: [])
    }
  }

  // MARK: Export

  private func export(items: [MPMediaItem]) {
    guard !items.isEmpty else {
      finish(tracks: [], skipped: [])
      return
    }

    let destDir = musicLibraryDir()
    do {
      try FileManager.default.createDirectory(
        at: destDir, withIntermediateDirectories: true)
    } catch {
      finish(error: "io_error", message: "Could not create export dir: \(error)")
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      var tracks: [[String: Any]] = []
      var skipped: [[String: Any]] = []
      let group = DispatchGroup()

      for item in items {
        let title = item.title ?? "Unknown"
        let artist = item.artist ?? ""
        let persistentID = String(item.persistentID)
        let destURL = destDir.appendingPathComponent("\(persistentID).m4a")

        // Idempotency: if we already exported this track, reuse it.
        if FileManager.default.fileExists(atPath: destURL.path) {
          tracks.append([
            "path": destURL.path,
            "title": title,
            "artist": artist,
            "persistentId": persistentID,
          ])
          continue
        }

        guard let assetURL = item.assetURL else {
          // DRM-protected (Apple Music subscription) — can't export.
          skipped.append([
            "title": title,
            "artist": artist,
            "reason": "drm_protected",
          ])
          continue
        }

        let asset = AVURLAsset(url: assetURL)
        guard let session = AVAssetExportSession(
          asset: asset, presetName: AVAssetExportPresetAppleM4A
        ) else {
          skipped.append([
            "title": title,
            "artist": artist,
            "reason": "export_session_unavailable",
          ])
          continue
        }
        session.outputURL = destURL
        session.outputFileType = .m4a
        session.shouldOptimizeForNetworkUse = false

        group.enter()
        session.exportAsynchronously {
          defer { group.leave() }
          if session.status == .completed {
            tracks.append([
              "path": destURL.path,
              "title": title,
              "artist": artist,
              "persistentId": persistentID,
            ])
          } else {
            skipped.append([
              "title": title,
              "artist": artist,
              "reason": "export_failed",
            ])
          }
        }
      }

      group.wait()
      DispatchQueue.main.async { [weak self] in
        self?.finish(tracks: tracks, skipped: skipped)
      }
    }
  }

  // MARK: Helpers

  private func musicLibraryDir() -> URL {
    let docs = FileManager.default.urls(
      for: .documentDirectory, in: .userDomainMask).first!
    return docs.appendingPathComponent("MusicLibrary", isDirectory: true)
  }

  private func finish(tracks: [[String: Any]], skipped: [[String: Any]]) {
    let result = pendingResult
    pendingResult = nil
    presented = nil
    result?(["tracks": tracks, "skipped": skipped])
  }

  private func finish(error code: String, message: String) {
    let result = pendingResult
    pendingResult = nil
    presented = nil
    result?(FlutterError(code: code, message: message, details: nil))
  }

  private func topViewController() -> UIViewController? {
    var topController = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first(where: { $0.isKeyWindow })?
      .rootViewController
    while let presented = topController?.presentedViewController {
      topController = presented
    }
    return topController
  }
}
