import AppKit
import InputMethodKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var inputServer: IMKServer?
    var preview: PreviewController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = Runtime.shared
        if CommandLine.arguments.contains("--preview") {
            preview = PreviewController(); preview?.show()
        } else {
            guard let connection = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String,
                  let identifier = Bundle.main.bundleIdentifier else {
                Runtime.shared.preferences.showError("请从构建的 EnKeyBoard.app 启动输入法。")
                NSApp.terminate(nil); return
            }
            inputServer = IMKServer(name: connection, bundleIdentifier: identifier)
        }
        if let error = Runtime.shared.startupError { Runtime.shared.preferences.showError(error) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        CommandLine.arguments.contains("--preview")
    }
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    let appDelegate = AppDelegate()
    application.delegate = appDelegate
    withExtendedLifetime(appDelegate) { application.run() }
}
