import AppKit
import FileDrawerCore

/// 抽屉面板：无边框、可成为键盘窗口，但不成为主窗口。
@MainActor
final class DrawerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Esc 通过响应链到达这里。
    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}

/// 管理唯一的抽屉面板：定位、显示、收起。
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let panel: DrawerPanel

    /// 打开系统模态界面（如添加文件夹面板）时暂停「失焦即收起」。
    var suppressesAutoHide = false

    init(contentView: NSView) {
        panel = DrawerPanel(
            contentRect: CGRect(x: 0, y: 0, width: 720, height: 440),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        configurePanel(contentView: contentView)
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let screen = targetScreen() else { return }

        panel.setFrame(
            PanelPlacement.topCenter(panelSize: panel.frame.size, in: screen.visibleFrame),
            display: true
        )
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func hide() {
        panel.orderOut(nil)
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

        let material = NSVisualEffectView()
        material.material = .popover
        material.blendingMode = .behindWindow
        material.state = .active
        material.wantsLayer = true
        material.layer?.cornerRadius = 12
        material.layer?.masksToBounds = true

        contentView.translatesAutoresizingMaskIntoConstraints = false
        material.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: material.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: material.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: material.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: material.bottomAnchor)
        ])

        panel.contentView = material
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !suppressesAutoHide else { return }
        hide()
    }
}
