import CoreGraphics

/// 面板在屏幕上的几何定位。
///
/// 只做纯计算，不依赖 AppKit，因此可以无头测试。
public enum PanelPlacement {
    /// 把面板放在给定可见区域的顶部中央。
    ///
    /// - Parameters:
    ///   - panelSize: 面板期望的尺寸。
    ///   - visibleFrame: 目标屏幕的可见区域（已排除菜单栏、Dock 与刘海占位）。
    ///   - topInset: 面板顶部与可见区域顶部之间保留的间距。
    /// - Returns: 夹取到可见区域内的面板 frame。
    public static func topCenter(
        panelSize: CGSize,
        in visibleFrame: CGRect,
        topInset: CGFloat = 0
    ) -> CGRect {
        let width = min(max(panelSize.width, 0), visibleFrame.width)
        let height = min(max(panelSize.height, 0), visibleFrame.height)

        let x = visibleFrame.minX + (visibleFrame.width - width) / 2
        let y = visibleFrame.maxY - topInset - height

        return CGRect(
            x: x.rounded(),
            y: y.rounded(),
            width: width.rounded(),
            height: height.rounded()
        )
    }
}
