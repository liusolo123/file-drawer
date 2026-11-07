import AppKit
import FileDrawerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panelController: PanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController = PanelController()
        installStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "tray.full",
            accessibilityDescription: AppMetadata.displayName
        )
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        let open = NSMenuItem(
            title: "打开抽屉",
            action: #selector(togglePanel),
            keyEquivalent: ""
        )
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: "退出\(AppMetadata.displayName)",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    @objc private func togglePanel() {
        panelController?.toggle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
