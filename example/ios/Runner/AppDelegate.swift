import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, AVAudioPlayerDelegate {
  private var audioPlayer: AVAudioPlayer?
  private var audioCompleted = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "audify_example/audio_player",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handleAudioCall(call, result: result)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleAudioCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "load":
      guard
        let args = call.arguments as? [String: Any],
        let asset = args["asset"] as? String
      else {
        result(FlutterError(code: "invalid_argument", message: "Missing asset path", details: nil))
        return
      }
      do {
        try loadAsset(asset)
        result(nil)
      } catch {
        result(FlutterError(code: "load_failed", message: error.localizedDescription, details: nil))
      }
    case "play":
      audioCompleted = false
      audioPlayer?.play()
      result(nil)
    case "pause":
      audioPlayer?.pause()
      result(nil)
    case "stop":
      audioPlayer?.pause()
      audioPlayer?.currentTime = 0
      audioCompleted = false
      result(nil)
    case "seek":
      let args = call.arguments as? [String: Any]
      let positionMs = args?["positionMs"] as? Int ?? 0
      audioPlayer?.currentTime = TimeInterval(positionMs) / 1000.0
      audioCompleted = false
      result(nil)
    case "getState":
      result(currentState())
    case "release":
      audioPlayer?.stop()
      audioPlayer = nil
      audioCompleted = false
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func loadAsset(_ asset: String) throws {
    let assetKey = FlutterDartProject.lookupKey(forAsset: asset)
    guard let path = Bundle.main.path(forResource: assetKey, ofType: nil) else {
      throw NSError(domain: "AudifyExample", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "Asset not found: \(asset)"
      ])
    }

    audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
    audioPlayer?.delegate = self
    audioPlayer?.prepareToPlay()
    audioCompleted = false
  }

  private func currentState() -> [String: Any] {
    guard let player = audioPlayer else {
      return [
        "isPlaying": false,
        "isCompleted": false,
        "durationMs": 0,
        "positionMs": 0
      ]
    }

    return [
      "isPlaying": player.isPlaying,
      "isCompleted": audioCompleted,
      "durationMs": Int(player.duration * 1000),
      "positionMs": audioCompleted ? 0 : Int(player.currentTime * 1000)
    ]
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    audioCompleted = true
    player.currentTime = 0
  }
}
