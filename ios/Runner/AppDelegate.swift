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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NativeTabBar") {
      registrar.register(
        NativeTabBarFactory(messenger: registrar.messenger()),
        withId: "prato_em_dia/native_tab_bar"
      )
    }
  }
}

/// Native UIKit tab bar. Built with the iOS 26 SDK it renders as Liquid Glass.
final class NativeTabBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    NativeTabBarView(viewId: viewId, arguments: args, messenger: messenger)
  }
}

final class NativeTabBarView: NSObject, FlutterPlatformView, UITabBarDelegate {
  private let tabBar = UITabBar()
  private let channel: FlutterMethodChannel

  init(viewId: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "prato_em_dia/native_tab_bar/\(viewId)",
      binaryMessenger: messenger
    )
    super.init()
    let params = arguments as? [String: Any] ?? [:]
    let entries = params["items"] as? [[String: String]] ?? []
    tabBar.items = entries.enumerated().map { index, entry in
      UITabBarItem(
        title: entry["title"],
        image: UIImage(systemName: entry["symbol"] ?? "circle"),
        tag: index
      )
    }
    let selected = params["selected"] as? Int ?? 0
    if let items = tabBar.items, items.indices.contains(selected) {
      tabBar.selectedItem = items[selected]
    }
    if let color = params["tint"] as? Int {
      tabBar.tintColor = UIColor(
        red: CGFloat((color >> 16) & 0xFF) / 255,
        green: CGFloat((color >> 8) & 0xFF) / 255,
        blue: CGFloat(color & 0xFF) / 255,
        alpha: 1
      )
    }
    tabBar.delegate = self
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "select", let index = call.arguments as? Int else {
        result(FlutterMethodNotImplemented)
        return
      }
      if let items = self?.tabBar.items, items.indices.contains(index) {
        self?.tabBar.selectedItem = items[index]
      }
      result(nil)
    }
  }

  func view() -> UIView { tabBar }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    channel.invokeMethod("selected", arguments: item.tag)
  }
}
