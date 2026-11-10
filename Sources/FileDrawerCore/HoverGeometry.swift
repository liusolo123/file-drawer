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

    /// 判断指针是否在热区内。
    ///
    /// `CGRect.contains` 不包含 maxY 边界，而指针贴到屏幕最顶边时
    /// `NSEvent.mouseLocation.y` 恰好等于屏幕顶边，会被误判为「不在热区」。
    /// 这里把四条边都视为命中。
    public static func contains(_ point: CGPoint, in zone: CGRect) -> Bool {
        point.x >= zone.minX && point.x <= zone.maxX
            && point.y >= zone.minY && point.y <= zone.maxY
    }
}
