import Testing
import CoreGraphics
@testable import FileDrawerCore

@Suite("悬停热区")
struct HoverGeometryTests {
    @Test("热区覆盖菜单栏整条高度并水平居中")
    func coversWholeMenuBar() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let visible = CGRect(x: 0, y: 0, width: 1512, height: 950)

        let zone = HoverGeometry.hotZone(
            screenFrame: screen,
            visibleFrame: visible,
            width: 320
        )

        #expect(zone.width == 320)
        #expect(zone.height == 32)
        #expect(zone.midX == screen.midX)
        #expect(zone.maxY == screen.maxY)
        #expect(zone.minY == visible.maxY)
    }

    @Test("菜单栏自动隐藏时保留最小高度")
    func keepsMinimumHeightWhenMenuBarHidden() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

        let zone = HoverGeometry.hotZone(
            screenFrame: screen,
            visibleFrame: screen,
            width: 320
        )

        #expect(zone.height == 12)
        #expect(zone.maxY == screen.maxY)
    }

    @Test("窄屏时热区收窄到屏幕宽度")
    func clampsWidthToScreen() {
        let screen = CGRect(x: 0, y: 0, width: 240, height: 400)
        let visible = CGRect(x: 0, y: 0, width: 240, height: 375)

        let zone = HoverGeometry.hotZone(
            screenFrame: screen,
            visibleFrame: visible,
            width: 320
        )

        #expect(zone.width == 240)
        #expect(zone.minX == 0)
    }

    @Test("以给定屏幕为基准，副屏原点不为零时同样居中")
    func centersOnSecondaryScreen() {
        let screen = CGRect(x: 1512, y: 0, width: 1920, height: 1080)
        let visible = CGRect(x: 1512, y: 0, width: 1920, height: 1055)

        let zone = HoverGeometry.hotZone(
            screenFrame: screen,
            visibleFrame: visible,
            width: 320
        )

        #expect(zone.midX == CGFloat(1512 + 960))
        #expect(zone.height == 25)
    }
}
