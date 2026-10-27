import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Tells Flutter when an app-menu item it owns is chosen. The menu stays
  /// native (MainMenu.xib); only the choices it cannot act on alone cross over.
  private var appMenuChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    appMenuChannel = FlutterMethodChannel(
      name: "pickstock/app_menu",
      binaryMessenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()

    // The menu bar is installed from the same nib as this window, after it:
    // wait a turn of the run loop for it to be there.
    DispatchQueue.main.async { [weak self] in self?.connectSettingsItem() }
  }

  /// Points the app menu's Settings… item (⌘,) at Flutter. The template ships
  /// it wired to nothing, which leaves it permanently greyed out.
  private func connectSettingsItem() {
    let appMenu = NSApp.mainMenu?.items.first?.submenu
    guard let item = appMenu?.items.first(where: { $0.keyEquivalent == "," }) else {
      return
    }
    item.target = self
    item.action = #selector(openSettings(_:))
  }

  @objc private func openSettings(_ sender: Any?) {
    appMenuChannel?.invokeMethod("openSettings", arguments: nil)
  }
}
