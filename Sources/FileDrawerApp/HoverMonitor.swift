import AppKit
import FileDrawerCore

/// 轮询鼠标位置，把「顶部热区悬停」与「指针是否在面板内」翻译成状态机事件。
///
/// 不使用全局鼠标监听，避免触发辅助功能权限；也不创建覆盖菜单栏的窗口，
/// 因此不会拦截用户点击。
@MainActor
final class HoverMonitor: NSObject {
    private let panelController: PanelController
    private var machine = PanelStateMachine()
    private var timer: Timer?

    private var lastInHotZone = false
    private var lastInsidePanel = false

    private let tickInterval: TimeInterval = 0.05
    private let hotZoneWidth: CGFloat = 320

    init(panelController: PanelController) {
        self.panelController = panelController
        super.init()
    }

    func start() {
        guard timer == nil else { return }

        let timer = Timer(
            timeInterval: tickInterval,
            target: self,
            selector: #selector(tickSelector),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// 拖放、预览、菜单开始时调用，暂停自动收起。
    func beginInteraction() {
        apply(machine.handle(.interactionBegan, at: now))
    }

    /// 对应的结束调用，恢复收起规则。
    func endInteraction() {
        apply(machine.handle(.interactionEnded, at: now))
    }

    /// 全局快捷键按下。
    func hotkeyPressed() {
        apply(machine.handle(.hotkeyPressed, at: now))
    }

    private var now: TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    private var hotZone: CGRect {
        guard let screen = activeScreen else { return .zero }
        return HoverGeometry.hotZone(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            width: hotZoneWidth
        )
    }

    /// 鼠标所在屏幕，而不是「有键盘焦点的屏幕」。
    private var activeScreen: NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
    }

    @objc private func tickSelector() {
        tick()
    }

    private func tick() {
        let timestamp = now
        let mouse = NSEvent.mouseLocation
        let zone = hotZone

        let inHotZone = HoverGeometry.contains(mouse, in: zone)
        if inHotZone != lastInHotZone {
            lastInHotZone = inHotZone
            apply(machine.handle(inHotZone ? .hoverBegan : .hoverEnded, at: timestamp))
        }

        let insidePanel = panelController.isVisible
            && (panelController.panelFrame.contains(mouse)
                || HoverGeometry.contains(mouse, in: zone))
        if insidePanel != lastInsidePanel {
            lastInsidePanel = insidePanel
            apply(
                machine.handle(
                    insidePanel ? .pointerEnteredPanel : .pointerExitedPanel,
                    at: timestamp
                )
            )
        }

        apply(machine.handle(.timeAdvanced(timestamp), at: timestamp))
    }

    private func apply(_ actions: [PanelAction]) {
        for action in actions {
            switch action {
            case .show(let stealFocus):
                if stealFocus {
                    panelController.show()
                } else {
                    panelController.showWithoutFocus()
                }
            case .hide(let returnFocus):
                panelController.hide(returnFocus: returnFocus)
            case .focusSearchField:
                panelController.focusSearchField()
            }
        }
    }
}
