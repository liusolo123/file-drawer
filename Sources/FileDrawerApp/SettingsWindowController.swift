import AppKit
import FileDrawerCore
import ServiceManagement

/// 系统登录项状态。默认关闭。
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

/// 设置窗口内容视图：录入快捷键时直接接收按键。
final class SettingsContentView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true { return }
        super.keyDown(with: event)
    }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onHotkeyChange: ((HotkeySpec) -> Bool)?
    var onShowsHiddenFilesChange: ((Bool) -> Void)?
    var onLaunchAtLoginChange: ((Bool) -> Bool)?
    var onResetPanelSize: (() -> Void)?
    /// 录入期间临时注销全局热键，避免按键先触发抽屉。
    var onRecordingChange: ((Bool) -> Void)?

    private let stateFileURL: URL
    private let hotkeyLabel = NSTextField(labelWithString: "")
    private let hotkeyButton = NSButton()
    private let hotkeyEnabled = NSButton()
    private let hiddenFiles = NSButton()
    private let launchAtLogin = NSButton()
    private let statusLabel = NSTextField(wrappingLabelWithString: "")

    private var currentHotkey = HotkeySpec.default
    private var recording = false

    init(settings: DrawerSettings, stateFileURL: URL) {
        self.stateFileURL = stateFileURL

        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 460, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "文件抽屉设置"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
        build(settings: settings)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refresh(settings: DrawerSettings, launchAtLogin isEnabled: Bool) {
        currentHotkey = settings.hotkey
        hotkeyLabel.stringValue = settings.hotkey.displayName
        hotkeyEnabled.state = settings.hotkey.enabled ? .on : .off
        hiddenFiles.state = settings.showsHiddenFiles ? .on : .off
        launchAtLogin.state = isEnabled ? .on : .off
    }

    private func build(settings: DrawerSettings) {
        guard let window else { return }

        let content = SettingsContentView()
        content.onKeyDown = { [weak self] event in
            self?.handleKey(event) ?? false
        }
        window.contentView = content

        let title = NSTextField(labelWithString: "文件抽屉设置")
        title.font = .systemFont(ofSize: 16, weight: .semibold)

        hotkeyLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        hotkeyLabel.stringValue = settings.hotkey.displayName

        hotkeyButton.title = "录入"
        hotkeyButton.bezelStyle = .rounded
        hotkeyButton.target = self
        hotkeyButton.action = #selector(recordTapped)

        hotkeyEnabled.setButtonType(.switch)
        hotkeyEnabled.title = "启用全局快捷键"
        hotkeyEnabled.target = self
        hotkeyEnabled.action = #selector(hotkeyEnabledChanged)

        let hotkeyRow = NSStackView(views: [
            fieldLabel("全局快捷键"),
            hotkeyLabel,
            hotkeyButton,
            hotkeyEnabled
        ])
        hotkeyRow.orientation = .horizontal
        hotkeyRow.spacing = 10

        hiddenFiles.setButtonType(.switch)
        hiddenFiles.title = "显示隐藏文件"
        hiddenFiles.target = self
        hiddenFiles.action = #selector(hiddenFilesChanged)

        launchAtLogin.setButtonType(.switch)
        launchAtLogin.title = "登录时启动"
        launchAtLogin.target = self
        launchAtLogin.action = #selector(launchAtLoginChanged)

        let resetButton = NSButton(
            title: "重置面板尺寸",
            target: self,
            action: #selector(resetSizeTapped)
        )
        resetButton.bezelStyle = .rounded

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = "状态文件：\(stateFileURL.path)"

        let stack = NSStackView(views: [
            title,
            hotkeyRow,
            hiddenFiles,
            launchAtLogin,
            resetButton,
            statusLabel
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(
                lessThanOrEqualTo: content.trailingAnchor,
                constant: -20
            ),
            stack.bottomAnchor.constraint(
                lessThanOrEqualTo: content.bottomAnchor,
                constant: -20
            ),
            statusLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 420)
        ])

        refresh(settings: settings, launchAtLogin: LaunchAtLogin.isEnabled)
    }

    private func fieldLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.textColor = .secondaryLabelColor
        return label
    }

    // MARK: - 动作

    @objc private func recordTapped() {
        recording = true
        onRecordingChange?(true)
        hotkeyLabel.stringValue = "请按下新的快捷键…（避开系统保留组合）"
        window?.makeFirstResponder(window?.contentView)
    }

    private func stopRecording() {
        guard recording else { return }
        recording = false
        onRecordingChange?(false)
    }

    @objc private func hotkeyEnabledChanged() {
        var spec = currentHotkey
        spec.enabled = hotkeyEnabled.state == .on

        if onHotkeyChange?(spec) == true {
            currentHotkey = spec
            hotkeyLabel.stringValue = spec.displayName
        } else {
            hotkeyEnabled.state = spec.enabled ? .off : .on
        }
    }

    @objc private func hiddenFilesChanged() {
        onShowsHiddenFilesChange?(hiddenFiles.state == .on)
    }

    @objc private func launchAtLoginChanged() {
        let desired = launchAtLogin.state == .on
        if onLaunchAtLoginChange?(desired) != true {
            launchAtLogin.state = desired ? .off : .on
        }
    }

    @objc private func resetSizeTapped() {
        onResetPanelSize?()
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard recording else { return false }

        if event.keyCode == 53 { // Esc 取消
            stopRecording()
            hotkeyLabel.stringValue = currentHotkey.displayName
            return true
        }

        var modifiers: HotkeyModifiers = []
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }

        let keyCode = UInt32(event.keyCode)
        let spec = HotkeySpec(
            enabled: true,
            keyCode: keyCode,
            keyLabel: HotkeySpec.keyLabel(for: keyCode),
            modifiers: modifiers
        )

        guard spec.hasPrimaryModifier else {
            hotkeyLabel.stringValue = "请至少使用 ⌃ ⌥ ⌘ 之一"
            return true
        }

        if onHotkeyChange?(spec) == true {
            currentHotkey = spec
            stopRecording()
            hotkeyLabel.stringValue = spec.displayName
            hotkeyEnabled.state = .on
        } else {
            stopRecording()
            hotkeyLabel.stringValue = currentHotkey.displayName
            presentConflictAlert()
        }

        return true
    }

    private func presentConflictAlert() {
        NSApp.activate()

        let alert = NSAlert()
        alert.messageText = "快捷键注册失败"
        alert.informativeText = "这个组合可能被系统或其他应用占用（例如 ⌘Space、⌘Tab），请换一个。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        // 录入时窗口失焦，说明组合被系统截走（如 ⌘Space 触发 Spotlight）。
        guard recording, !NSApp.isActive else { return }

        stopRecording()
        hotkeyLabel.stringValue = currentHotkey.displayName
        presentConflictAlert()
    }

    func windowWillClose(_ notification: Notification) {
        stopRecording()
    }
}
