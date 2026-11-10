import AppKit
import FileDrawerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panelController: PanelController?
    private var hoverMonitor: HoverMonitor?
    private var hotkeyCenter: HotkeyCenter?
    private var library: FolderLibrary?
    private var rootView: DrawerRootView?
    private var hiddenFilesMenuItem: NSMenuItem?
    private var settings: DrawerSettings = .default
    private let store: StateStore
    private var saveWorkItem: DispatchWorkItem?

    override init() {
        store = StateStore(directory: AppPaths.stateDirectory)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let initialState = loadState()
        settings = initialState.settings

        let library = FolderLibrary(state: initialState)
        library.onChange = { [weak self] in self?.scheduleSave() }

        let rootView = DrawerRootView(library: library)
        rootView.onModalStateChange = { [weak self] active in
            self?.panelController?.setModalActive(active)
        }
        rootView.setShowsHiddenFiles(settings.showsHiddenFiles)

        self.library = library
        self.rootView = rootView
        let panel = PanelController(contentView: rootView)
        panel.focusSearchHandler = { [weak rootView] in
            rootView?.focusSearchField()
        }
        panelController = panel

        let monitor = HoverMonitor(panelController: panel)
        monitor.start()
        hoverMonitor = monitor

        let hotkey = HotkeyCenter { [weak self] in
            self?.hoverMonitor?.hotkeyPressed()
        }
        hotkeyCenter = hotkey
        if !hotkey.registerDefault() {
            presentHotkeyFailure()
        }

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

        var state = library.state
        state.settings = settings

        do {
            try store.save(state)
        } catch {
            NSLog("文件抽屉：保存状态失败：\(error)")
        }
    }

    private func presentHotkeyFailure() {
        NSApp.activate()

        let alert = NSAlert()
        alert.messageText = "全局快捷键注册失败"
        alert.informativeText = """
        Control + Option + F 可能已被其他应用占用。
        请退出占用该快捷键的应用后重新启动文件抽屉；快捷键自定义将在后续版本提供。
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }

    private func installStatusItem() {        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
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

        let hiddenFiles = NSMenuItem(
            title: "显示隐藏文件",
            action: #selector(toggleHiddenFiles),
            keyEquivalent: ""
        )
        hiddenFiles.target = self
        hiddenFiles.state = settings.showsHiddenFiles ? .on : .off
        menu.addItem(hiddenFiles)
        hiddenFilesMenuItem = hiddenFiles

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

    @objc private func toggleHiddenFiles() {
        settings.showsHiddenFiles.toggle()
        hiddenFilesMenuItem?.state = settings.showsHiddenFiles ? .on : .off
        rootView?.setShowsHiddenFiles(settings.showsHiddenFiles)
        scheduleSave()
    }

    @objc private func togglePanel() {
        panelController?.toggle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
