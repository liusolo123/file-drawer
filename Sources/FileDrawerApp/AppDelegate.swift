import AppKit
import FileDrawerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panelController: PanelController?
    private var hoverMonitor: HoverMonitor?
    private var library: FolderLibrary?
    private let store: StateStore
    private var saveWorkItem: DispatchWorkItem?

    override init() {
        store = StateStore(directory: AppPaths.stateDirectory)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let library = FolderLibrary(state: loadState())
        library.onChange = { [weak self] in self?.scheduleSave() }

        let rootView = DrawerRootView(library: library)
        rootView.onModalStateChange = { [weak self] active in
            self?.panelController?.setModalActive(active)
        }

        self.library = library
        let panel = PanelController(contentView: rootView)
        panelController = panel

        let monitor = HoverMonitor(panelController: panel)
        monitor.start()
        hoverMonitor = monitor

        installStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveWorkItem?.cancel()
        saveNow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func loadState() -> DrawerState {
        do {
            return try store.load()
        } catch {
            NSLog("文件抽屉：读取状态失败，按空状态启动：\(error)")
            return .empty
        }
    }

    /// 500 毫秒合并写入，避免拖动排序时频繁落盘。
    private func scheduleSave() {
        saveWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.saveNow()
        }
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func saveNow() {
        guard let library else { return }
        do {
            try store.save(library.state)
        } catch {
            NSLog("文件抽屉：保存状态失败：\(error)")
        }
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
