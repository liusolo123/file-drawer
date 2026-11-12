import Testing
import CoreGraphics
@testable import FileDrawerCore

@Suite("面板定位")
struct PanelPlacementTests {
    @Test("面板水平居中且贴住可见区域顶部")
    func centersHorizontallyAndAnchorsToTop() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = PanelPlacement.topCenter(
            panelSize: CGSize(width: 640, height: 420),
            in: screen
        )

        #expect(frame.origin.x == 400)
        #expect(frame.origin.y == 480)
        #expect(frame.width == 640)
        #expect(frame.height == 420)
    }

    @Test("面板大于屏幕时被夹取到可见区域内")
    func clampsOversizedPanel() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = PanelPlacement.topCenter(
            panelSize: CGSize(width: 2000, height: 1200),
            in: screen
        )

        #expect(frame == screen)
    }

    @Test("以给定屏幕的可见区域为准，而不是主屏")
    func respectsGivenVisibleFrame() {
        let secondary = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let frame = PanelPlacement.topCenter(
            panelSize: CGSize(width: 600, height: 400),
            in: secondary,
            topInset: 10
        )

        #expect(frame.origin.x == CGFloat(2100))
        #expect(frame.origin.y == CGFloat(670))
    }

    @Test("应用标识与 Info.plist 约定一致")
    func metadataMatchesBundleConvention() {
        #expect(AppMetadata.displayName == "文件抽屉")
        #expect(AppMetadata.bundleIdentifier == "com.liusolo.filedrawer")
    }

    @Test("尺寸过大时夹取到可见区域")
    func clampsOversizedPanelSize() {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)

        let size = PanelPlacement.clampedSize(
            CGSize(width: 2000, height: 1200),
            in: visible
        )

        #expect(size == CGSize(width: 1440, height: 900))
    }

    @Test("尺寸过小时抬到最小尺寸")
    func raisesUndersizedPanelSize() {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)

        let size = PanelPlacement.clampedSize(
            CGSize(width: 200, height: 100),
            in: visible
        )

        #expect(size == CGSize(width: 480, height: 320))
    }

    @Test("小屏上最小尺寸不会超过屏幕")
    func minimumNeverExceedsScreen() {
        let visible = CGRect(x: 0, y: 0, width: 400, height: 300)

        let size = PanelPlacement.clampedSize(
            CGSize(width: 480, height: 320),
            in: visible
        )

        #expect(size == CGSize(width: 400, height: 300))
    }
}
