import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "iptv.playback/control",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "restorePlaybackAudio" {
        self.restorePlaybackAudio(result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Cast kapanınca medya ses oturumunu yeniden açar. setActive(false) çağrılmaz;
  /// o çağrı VLC görüntüsünü de kesiyordu.
  private func restorePlaybackAudio(result: @escaping FlutterResult) {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback, mode: .moviePlayback)
      try session.setActive(true)
      result(nil)
    } catch {
      result(
        FlutterError(
          code: "audio",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }
}
