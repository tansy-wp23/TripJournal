import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let mapsKey = dartDefine(named: "GOOGLE_MAPS_IOS_KEY")?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !mapsKey.isEmpty
    {
      GMSServices.provideAPIKey(mapsKey)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// Flutter exposes build-time Dart defines to Xcode as a comma-separated
  /// list of Base64-encoded `name=value` strings. Info.plist carries that
  /// build setting as a placeholder; no rendering key is stored in Git.
  private func dartDefine(named name: String) -> String? {
    guard
      let encodedDefines = Bundle.main.object(
        forInfoDictionaryKey: "TripJournalDartDefines"
      ) as? String
    else {
      return nil
    }

    for encodedDefinition in encodedDefines.split(separator: ",") {
      guard
        let data = Data(base64Encoded: String(encodedDefinition)),
        let definition = String(data: data, encoding: .utf8)
      else {
        continue
      }
      let pair = definition.split(
        separator: "=",
        maxSplits: 1,
        omittingEmptySubsequences: false
      )
      if pair.count == 2, pair[0] == name {
        return String(pair[1])
      }
    }
    return nil
  }
}
