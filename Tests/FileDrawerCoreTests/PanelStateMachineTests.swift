import Testing
@testable import FileDrawerCore

@Suite("面板状态机")
struct PanelStateMachineTests {
    private func visibleMachine() -> PanelStateMachine {
        var machine = PanelStateMachine()
        _ = machine.handle(.hoverBegan, at: 0)
        _ = machine.handle(.timeAdvanced(0.25), at: 0.25)
        return machine
    }

    @Test("悬停不足 250 毫秒不展开")
    func doesNotShowBeforeHoverDelay() {
        var machine = PanelStateMachine()
        _ = machine.handle(.hoverBegan, at: 0)

        #expect(machine.handle(.timeAdvanced(0.249), at: 0.249).isEmpty)
        _ = machine.handle(.hoverEnded, at: 0.249)
        #expect(machine.handle(.timeAdvanced(1.0), at: 1.0).isEmpty)
        #expect(machine.state == .hidden)
    }

    @Test("悬停满 250 毫秒展开且不抢焦点")
    func showsWithoutStealingFocus() {
        var machine = PanelStateMachine()
        _ = machine.handle(.hoverBegan, at: 0)

        let actions = machine.handle(.timeAdvanced(0.25), at: 0.25)

        #expect(actions == [.show(stealFocus: false)])
        #expect(machine.state == .visible)
    }

    @Test("重复的悬停开始不会重置计时")
    func repeatedHoverBeganKeepsDeadline() {
        var machine = PanelStateMachine()
        _ = machine.handle(.hoverBegan, at: 0)
        _ = machine.handle(.hoverBegan, at: 0.2)

        #expect(machine.handle(.timeAdvanced(0.25), at: 0.25) == [.show(stealFocus: false)])
    }

    @Test("离开面板 500 毫秒后收起")
    func hidesAfterHideDelay() {
        var machine = visibleMachine()
        _ = machine.handle(.pointerEnteredPanel, at: 0.26)
        _ = machine.handle(.pointerExitedPanel, at: 0.3)

        #expect(machine.handle(.timeAdvanced(0.799), at: 0.799).isEmpty)
        #expect(machine.handle(.timeAdvanced(0.8), at: 0.8) == [.hide(returnFocus: false)])
        #expect(machine.state == .hidden)
    }

    @Test("等待收起期间移回面板会取消收起")
    func reenteringPanelCancelsHide() {
        var machine = visibleMachine()
        _ = machine.handle(.pointerEnteredPanel, at: 0.26)
        _ = machine.handle(.pointerExitedPanel, at: 0.3)
        _ = machine.handle(.pointerEnteredPanel, at: 0.4)

        #expect(machine.handle(.timeAdvanced(5.0), at: 5.0).isEmpty)
        #expect(machine.state == .visible)
    }

    @Test("拖放或预览进行中不自动收起")
    func interactionHoldPausesAutoHide() {
        var machine = visibleMachine()
        _ = machine.handle(.pointerEnteredPanel, at: 0.26)
        _ = machine.handle(.pointerExitedPanel, at: 0.3)
        _ = machine.handle(.interactionBegan, at: 0.4)

        #expect(machine.handle(.timeAdvanced(10.0), at: 10.0).isEmpty)
        #expect(machine.state == .interactionHold)
    }

    @Test("交互结束后指针在外面则重新计时收起")
    func interactionEndRestartsHideTimer() {
        var machine = visibleMachine()
        _ = machine.handle(.pointerEnteredPanel, at: 0.26)
        _ = machine.handle(.pointerExitedPanel, at: 0.3)
        _ = machine.handle(.interactionBegan, at: 0.4)
        _ = machine.handle(.interactionEnded, at: 1.0)

        #expect(machine.handle(.timeAdvanced(1.499), at: 1.499).isEmpty)
        #expect(machine.handle(.timeAdvanced(1.5), at: 1.5) == [.hide(returnFocus: false)])
    }

    @Test("交互结束后指针在面板内则保持显示")
    func interactionEndInsidePanelKeepsVisible() {
        var machine = visibleMachine()
        _ = machine.handle(.pointerEnteredPanel, at: 0.26)
        _ = machine.handle(.interactionBegan, at: 0.3)
        _ = machine.handle(.interactionEnded, at: 1.0)

        #expect(machine.state == .visible)
        #expect(machine.handle(.timeAdvanced(10.0), at: 10.0).isEmpty)
    }

    @Test("嵌套交互要等最后一个结束")
    func nestedInteractionsRequireAllToEnd() {
        var machine = visibleMachine()
        _ = machine.handle(.pointerEnteredPanel, at: 0.26)
        _ = machine.handle(.pointerExitedPanel, at: 0.3)
        _ = machine.handle(.interactionBegan, at: 0.4)
        _ = machine.handle(.interactionBegan, at: 0.5)
        _ = machine.handle(.interactionEnded, at: 0.6)

        #expect(machine.state == .interactionHold)

        _ = machine.handle(.interactionEnded, at: 0.7)
        #expect(machine.state == .hidePending(deadline: 1.2))
    }

    @Test("点击外部收起时，焦点在面板内才交还焦点")
    func dismissReturnsFocusOnlyWhenPanelHadFocus() {
        var machine = visibleMachine()
        _ = machine.handle(.focusEntered, at: 0.3)

        #expect(machine.handle(.dismiss, at: 0.4) == [.hide(returnFocus: true)])

        var neverFocused = visibleMachine()
        #expect(neverFocused.handle(.dismiss, at: 0.4) == [.hide(returnFocus: false)])
    }

    @Test("隐藏状态下忽略指针与时间事件")
    func ignoresEventsWhileHidden() {
        var machine = PanelStateMachine()

        #expect(machine.handle(.pointerEnteredPanel, at: 0).isEmpty)
        #expect(machine.handle(.pointerExitedPanel, at: 0.1).isEmpty)
        #expect(machine.handle(.timeAdvanced(1.0), at: 1.0).isEmpty)
        #expect(machine.state == .hidden)
    }

    @Test("隐藏时按快捷键展开并聚焦搜索框")
    func hotkeyShowsAndFocusesSearchField() {
        var machine = PanelStateMachine()

        let actions = machine.handle(.hotkeyPressed, at: 0)

        #expect(actions == [.show(stealFocus: true), .focusSearchField])
        #expect(machine.state == .visible)
    }

    @Test("可见时再按快捷键收起并交还焦点")
    func hotkeyHidesAndReturnsFocus() {
        var machine = PanelStateMachine()
        _ = machine.handle(.hotkeyPressed, at: 0)

        #expect(machine.handle(.hotkeyPressed, at: 1.0) == [.hide(returnFocus: true)])
        #expect(machine.state == .hidden)
    }

    @Test("悬停展开且从未获得焦点时，快捷键收起不夺焦点")
    func hotkeyHideDoesNotReturnFocusWhenNeverFocused() {
        var machine = visibleMachine()

        #expect(machine.handle(.hotkeyPressed, at: 1.0) == [.hide(returnFocus: false)])
    }

    @Test("交互保持期间忽略快捷键")
    func hotkeyIsIgnoredDuringInteractionHold() {
        var machine = visibleMachine()
        _ = machine.handle(.pointerEnteredPanel, at: 0.26)
        _ = machine.handle(.interactionBegan, at: 0.3)

        #expect(machine.handle(.hotkeyPressed, at: 0.4).isEmpty)
        #expect(machine.state == .interactionHold)
    }
}
