import Foundation

/// 抽屉面板的可见状态。
public enum PanelState: Equatable, Sendable {
    /// 完全收起。
    case hidden
    /// 鼠标已进入顶部热区，等待满 `hoverDelay`。
    case hoverArmed(deadline: TimeInterval)
    /// 正在显示。
    case visible
    /// 鼠标已离开面板，等待满 `hideDelay`。
    case hidePending(deadline: TimeInterval)
    /// 拖放、预览或菜单进行中，暂停自动收起。
    case interactionHold
}

public enum PanelEvent: Equatable, Sendable {
    case hoverBegan
    case hoverEnded
    case pointerEnteredPanel
    case pointerExitedPanel
    case timeAdvanced(TimeInterval)
    case interactionBegan
    case interactionEnded
    /// 焦点进入面板（用户点击或快捷键唤出）。
    case focusEntered
    /// 点击面板外部或按 Esc。
    case dismiss
    /// 全局快捷键。
    case hotkeyPressed
}

public enum PanelAction: Equatable, Sendable {
    /// 展开面板。`stealFocus` 为 false 时不抢键盘焦点。
    case show(stealFocus: Bool)
    /// 收起面板，并按需把焦点交还展开前的前台应用。
    case hide(returnFocus: Bool)
    /// 把焦点放进搜索框。
    case focusSearchField
}

/// 纯状态机：不持有定时器，时间由调用方注入。
///
/// 转移规则见 `.scratch/file-drawer-v1/spec.md` 的「面板状态机」一节。
public struct PanelStateMachine: Sendable {
    public private(set) var state: PanelState

    private let hoverDelay: TimeInterval
    private let hideDelay: TimeInterval

    private var pointerInside = false
    private var interactionCount = 0
    private var hadFocus = false

    public init(hoverDelay: TimeInterval = 0.25, hideDelay: TimeInterval = 0.5) {
        self.state = .hidden
        self.hoverDelay = hoverDelay
        self.hideDelay = hideDelay
    }

    public var isVisible: Bool {
        switch state {
        case .hidden:
            return false
        case .hoverArmed, .visible, .hidePending, .interactionHold:
            return true
        }
    }

    public mutating func handle(
        _ event: PanelEvent,
        at now: TimeInterval
    ) -> [PanelAction] {
        switch event {
        case .hoverBegan:
            guard case .hidden = state else { return [] }
            state = .hoverArmed(deadline: now + hoverDelay)
            return []

        case .hoverEnded:
            if case .hoverArmed = state {
                state = .hidden
            }
            return []

        case .pointerEnteredPanel:
            pointerInside = true
            if case .hidePending = state {
                state = .visible
            }
            return []

        case .pointerExitedPanel:
            pointerInside = false
            if case .visible = state {
                state = .hidePending(deadline: now + hideDelay)
            }
            return []

        case .timeAdvanced(let time):
            return advance(to: time)

        case .interactionBegan:
            interactionCount += 1
            if interactionCount == 1, isShowing {
                state = .interactionHold
            }
            return []

        case .interactionEnded:
            guard interactionCount > 0 else { return [] }
            interactionCount -= 1

            guard interactionCount == 0, case .interactionHold = state else {
                return []
            }

            if pointerInside {
                state = .visible
            } else {
                state = .hidePending(deadline: now + hideDelay)
            }
            return []

        case .focusEntered:
            hadFocus = true
            return []

        case .dismiss:
            guard !isHidden else { return [] }
            return hide(returnFocus: hadFocus)

        case .hotkeyPressed:
            switch state {
            case .hidden, .hoverArmed:
                state = .visible
                hadFocus = true
                return [.show(stealFocus: true), .focusSearchField]
            case .visible, .hidePending:
                return hide(returnFocus: hadFocus)
            case .interactionHold:
                return []
            }
        }
    }

    private var isHidden: Bool {
        if case .hidden = state { return true }
        return false
    }

    private var isShowing: Bool {
        switch state {
        case .visible, .hidePending:
            return true
        case .hidden, .hoverArmed, .interactionHold:
            return false
        }
    }

    private mutating func advance(to time: TimeInterval) -> [PanelAction] {
        switch state {
        case .hoverArmed(let deadline) where time >= deadline:
            state = .visible
            return [.show(stealFocus: false)]

        case .hidePending(let deadline) where time >= deadline && interactionCount == 0:
            return hide(returnFocus: hadFocus)

        default:
            return []
        }
    }

    private mutating func hide(returnFocus: Bool) -> [PanelAction] {
        state = .hidden
        pointerInside = false
        hadFocus = false
        interactionCount = 0
        return [.hide(returnFocus: returnFocus)]
    }
}
