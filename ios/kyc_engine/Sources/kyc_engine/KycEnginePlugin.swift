import Flutter
import UIKit

public class KycEnginePlugin: NSObject, FlutterPlugin {
  private var recorders: [Int: LivenessVideoRecorder] = [:]
  private var nextId = 0
  private let lock = NSLock()
  private let writer = DispatchQueue(label: "kyc_engine.video.writer")

  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let channel = FlutterMethodChannel(
      name: "kyc_engine/video",
      binaryMessenger: messenger,
      codec: FlutterStandardMethodCodec.sharedInstance(),
      taskQueue: messenger.makeBackgroundTaskQueue?()
    )
    registrar.addMethodCallDelegate(KycEnginePlugin(), channel: channel)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    lock.lock()
    let all = Array(recorders.values)
    recorders.removeAll()
    lock.unlock()
    all.forEach { $0.release() }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "start":
      start(args, result)
    case "frame":
      frame(args, result)
    case "finish":
      finish(args, result)
    case "release":
      if let id = args["id"] as? Int {
        recorder(id, remove: true)?.release()
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func recorder(_ id: Int, remove: Bool = false) -> LivenessVideoRecorder? {
    lock.lock()
    defer { lock.unlock() }
    return remove ? recorders.removeValue(forKey: id) : recorders[id]
  }

  private func start(_ args: [String: Any], _ result: @escaping FlutterResult) {
    guard args["format"] as? String == "bgra",
      let width = args["width"] as? Int,
      let height = args["height"] as? Int,
      let rotation = args["rotation"] as? Int,
      let fps = args["fps"] as? Int,
      let bitrate = args["bitrate"] as? Int,
      let maxDurationUs = (args["maxDurationUs"] as? NSNumber)?.int64Value
    else {
      return result(FlutterError(code: "invalid_arguments", message: "iOS recording expects BGRA frames", details: nil))
    }
    do {
      let recorder = try LivenessVideoRecorder(
        width: width,
        height: height,
        rotation: rotation,
        fps: fps,
        bitrate: bitrate,
        maxDurationUs: maxDurationUs
      )
      lock.lock()
      let id = nextId
      nextId += 1
      recorders[id] = recorder
      lock.unlock()
      result(id)
    } catch {
      result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func frame(_ args: [String: Any], _ result: @escaping FlutterResult) {
    guard let id = args["id"] as? Int, let recorder = recorder(id),
      let bytes = args["bytes"] as? FlutterStandardTypedData,
      let bytesPerRow = args["bytesPerRow"] as? Int,
      let timestampUs = (args["timestampUs"] as? NSNumber)?.int64Value
    else {
      return result(FlutterError(code: "unknown_recorder", message: "No recorder for this id", details: nil))
    }
    recorder.encode(bytes.data, bytesPerRow: bytesPerRow, timestampUs: timestampUs) { error in
      DispatchQueue.main.async {
        result(error.map { FlutterError(code: "frame_failed", message: $0.localizedDescription, details: nil) })
      }
    }
  }

  private func finish(_ args: [String: Any], _ result: @escaping FlutterResult) {
    guard let id = args["id"] as? Int, let recorder = recorder(id), let path = args["path"] as? String else {
      return result(FlutterError(code: "unknown_recorder", message: "No recorder for this id", details: nil))
    }
    writer.async {
      let outcome = Result { try recorder.finish(path: path) }
      DispatchQueue.main.async {
        switch outcome {
        case .success(let written):
          result(written)
        case .failure(let error):
          result(FlutterError(code: "finish_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }
}
