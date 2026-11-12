import CoreGraphics

/// 面板尺寸。用户设定的「期望尺寸」会持久化；屏幕放不下时只在显示时夹取，
/// 不覆盖期望值，回到大屏仍恢复原尺寸。
public struct PanelSize: Codable, Equatable, Sendable {
    public var width: CGFloat
    public var height: CGFloat

    public static let `default` = PanelSize(width: 720, height: 440)

    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }

    public init(_ size: CGSize) {
        self.init(width: size.width, height: size.height)
    }

    public var cgSize: CGSize {
        CGSize(width: width, height: height)
    }
}
