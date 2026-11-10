import CoreGraphics

/// 悬停热区的几何计算。
///
/// 热区覆盖目标屏幕顶部菜单栏的整条高度、水平居中。
/// 取整条菜单栏而不是最顶部几条像素，是因为用户通常把鼠标停在菜单栏
/// 视觉中间；过窄的带子会让唤出时灵时不灵。
public enum HoverGeometry {
    public static func hotZone(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        width: CGFloat,
        minimumHeight: CGFloat = 12
    ) -> CGRect {
        let menuBarHeight = max(minimumHeight, screenFrame.maxY - visibleFrame.maxY)
        let clampedWidth = min(max(width, 0), screenFrame.width)

        return CGRect(
            x: screenFrame.midX - clampedWidth / 2,
            y: screenFrame.maxY - menuBarHeight,
            width: clampedWidth,
            height: menuBarHeight
        )
    }
}
