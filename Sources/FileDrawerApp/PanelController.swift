import AppKit
import FileDrawerCore

/// 抽屉面板：无边框、可成为键盘窗口，但不成为主窗口。
@MainActor
final class DrawerPanel: NSPanel {
    /// Esc 收起时要交还焦点，交给控制器处理。
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Esc 通过响应链到达这里。
    override func cancelOperation(_ sender: Any?) {
        if let onCancel {
            onCancel()
        } else {
            orderOut(nil)
        }
    }
}

/// 管理唯一的抽屉面板：定位、显示、收起与焦点交还。
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let panel: DrawerPanel
    private var previousApplication: NSRunningApplication?
    private var hadFocus = false

    /// 打开系统模态界面（如添加文件夹面板）时暂停「失焦即收起」。
    private(set) var suppressesAutoHide = false

    var isVisible: Bool { panel.isVisible }
    var panelFrame: CGRect { panel.frame }

    /// 由外层注入：把键盘焦点放进搜索框。
    var focusSearchHandler: (() -> Void)?

    init(contentView: NSView) {
        panel = DrawerPanel(
            contentRect: CGRect(x: 0, y: 0, width: 720, height: 440),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        configurePanel(contentView: contentView)
        panel.onCancel = { [weak self] in
            self?.hide(returnFocus: true)
        }
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    /// 从菜单栏打开：展开并激活应用、取得键盘焦点。
    func show() {
        present(activating: true)
    }

    /// 悬停打开：只把面板前置，不激活应用、不抢键盘焦点。
    func showWithoutFocus() {
        present(activating: false)
    }

    /// 把焦点放进搜索框。延后一拍，确保窗口已经成为键盘窗口。
    func focusSearchField() {
        DispatchQueue.main.async { [weak self] in
            self?.focusSearchHandler?()
        }
    }

    func hide(returnFocus: Bool? = nil) {
        let shouldReturnFocus = returnFocus ?? hadFocus
        hadFocus = false
        panel.orderOut(nil)

        guard shouldReturnFocus,
              let previousApplication,
              !previousApplication.isTerminated,
              previousApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return
        }

        previousApplication.activate()
    }

    /// 预览或右键菜单期间暂停「失焦即收起」。
    func setInteractionActive(_ active: Bool) {
        suppressesAutoHide = active
    }

    /// 模态界面期间把抽屉降到普通窗口层级并压后，避免遮挡系统面板。
    func setModalActive(_ active: Bool) {        if active {
            suppressesAutoHide = true
            panel.level = .normal
            panel.orderBack(nil)
        } else {
            suppressesAutoHide = false
            panel.level = .floating
            panel.orderFront(nil)
        }
    }

    private func present(activating: Bool) {
        guard let screen = targetScreen() else { return }

        if !panel.isVisible {
            previousApplication = NSWorkspace.shared.frontmostApplication
        }

        panel.setFrame(
            PanelPlacement.topCenter(panelSize: panel.frame.size, in: screen.visibleFrame),
            display: true
        )

        if activating {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate()
        } else {
            panel.orderFrontRegardless()
        }
    }

    private func targetScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func configurePanel(contentView: NSView) {
        panel.delegate = self
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        // 毛玻璃背板不一定遵守自身 layer 的圆角，外层需要一个裁剪容器。
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 14
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = NSColor.separatorColor
            .withAlphaComponent(0.5)
            .cgColor

        let material = NSVisualEffectView()
        material.material = .popover
        material.blendingMode = .behindWindow
        material.state = .active
        material.wantsLayer = true
        material.layer?.cornerRadius = 14
        material.layer?.cornerCurve = .continuous
        material.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(material)
        NSLayoutConstraint.activate([
            material.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            material.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            material.topAnchor.constraint(equalTo: container.topAnchor),
            material.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        contentView.translatesAutoresizingMaskIntoConstraints = false
        material.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: material.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: material.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: material.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: material.bottomAnchor)
        ])

        panel.contentView = container
    }

    func windowDidBecomeKey(_ notification: Notification) {
        hadFocus = true
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !suppressesAutoHide else { return }
        // 用户点击了其他应用：焦点应留在那个应用，不夺回。
        hide(returnFocus: false)
    }
}
