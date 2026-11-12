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
    private var saveFailureItem: NSMenuItem?
    private var settingsWindowController: SettingsWindowController?
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
        let panel = PanelController(contentView: rootView, size: settings.panelSize)
        panel.onSizeChange = { [weak self] size in
            guard let self else { return }
            self.settings.panelSize = PanelSize(size)
            self.scheduleSave()
        }
        panel.onShow = { [weak rootView] in
            rootView?.refresh()
        }
        panel.focusSearchHandler = { [weak rootView] in
            rootView?.focusSearchField()
        }
        panelController = panel

        let monitor = HoverMonitor(panelController: panel)
        monitor.start()
        hoverMonitor = monitor

        rootView.setInteractionHandler { [weak self] active in
            self?.panelController?.setInteractionActive(active)
            if active {
                self?.hoverMonitor?.beginInteraction()
            } else {
                self?.hoverMonitor?.endInteraction()
            }
        }

        let hotkey = HotkeyCenter { [weak self] in
            self?.hoverMonitor?.hotkeyPressed()
        }
        hotkeyCenter = hotkey
        if !hotkey.register(settings.hotkey) {
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
            saveFailureItem?.isHidden = true
        } catch {
            NSLog("文件抽屉：保存状态失败：\(error)")
            saveFailureItem?.isHidden = false
        }
    }

    private func presentHotkeyFailure() {
        NSApp.activate()

        let alert = NSAlert()
        alert.messageText = "全局快捷键注册失败"
        alert.informativeText = """
        当前快捷键（\(settings.hotkey.displayName)）可能已被其他应用占用。
        请在「设置」中更换或禁用快捷键。
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "知道了")
        alert.runModal()
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

        let hiddenFiles = NSMenuItem(
            title: "显示隐藏文件",
            action: #selector(toggleHiddenFiles),
            keyEquivalent: ""
        )
        hiddenFiles.target = self
        hiddenFiles.state = settings.showsHiddenFiles ? .on : .off
        menu.addItem(hiddenFiles)
        hiddenFilesMenuItem = hiddenFiles

        let settingsItem = NSMenuItem(
            title: "设置…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let saveFailure = NSMenuItem(
            title: "状态未保存 — 点此重试",
            action: #selector(retrySave),
            keyEquivalent: ""
        )
        saveFailure.target = self
        saveFailure.isHidden = true
        menu.addItem(saveFailure)
        saveFailureItem = saveFailure

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
        updateShowsHiddenFiles(!settings.showsHiddenFiles)
    }

    private func updateShowsHiddenFiles(_ value: Bool) {
        settings.showsHiddenFiles = value
        hiddenFilesMenuItem?.state = value ? .on : .off
        rootView?.setShowsHiddenFiles(value)
        scheduleSave()
    }

    @objc private func openSettings() {
        let controller: SettingsWindowController

        if let existing = settingsWindowController {
            existing.refresh(settings: settings, launchAtLogin: LaunchAtLogin.isEnabled)
            controller = existing
        } else {
            let created = SettingsWindowController(
                settings: settings,
                stateFileURL: store.fileURL
            )
            created.onHotkeyChange = { [weak self] spec in
                self?.updateHotkey(spec) ?? false
            }
            created.onShowsHiddenFilesChange = { [weak self] value in
                self?.updateShowsHiddenFiles(value)
            }
            created.onLaunchAtLoginChange = { [weak self] enabled in
                self?.updateLaunchAtLogin(enabled) ?? false
            }
            created.onResetPanelSize = { [weak self] in
                self?.resetPanelSize()
            }
            created.onRecordingChange = { [weak self] recording in
                guard let self else { return }
                if recording {
                    self.hotkeyCenter?.unregister()
                } else {
                    _ = self.hotkeyCenter?.register(self.settings.hotkey)
                }
            }
            settingsWindowController = created
            controller = created
        }

        NSApp.activate()
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    private func updateHotkey(_ spec: HotkeySpec) -> Bool {
        guard let hotkeyCenter else { return false }

        let previous = settings.hotkey
        guard hotkeyCenter.register(spec) else {
            _ = hotkeyCenter.register(previous)
            return false
        }

        settings.hotkey = spec
        scheduleSave()
        return true
    }

    private func updateLaunchAtLogin(_ enabled: Bool) -> Bool {
        do {
            try LaunchAtLogin.set(enabled)
            return true
        } catch {
            let alert = NSAlert()
            alert.messageText = "无法更改登录启动"
            alert.informativeText = "\(error.localizedDescription)\n请稍后再试。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "知道了")
            alert.runModal()
            return false
        }
    }

    private func resetPanelSize() {
        settings.panelSize = .default
        panelController?.applySize(.default)
        scheduleSave()
    }

    @objc private func retrySave() {
        saveNow()
    }

    @objc private func togglePanel() {
        panelController?.toggle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
