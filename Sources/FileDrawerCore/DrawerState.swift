import Foundation

/// 需要持久化的全部抽屉状态。
public struct DrawerState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    /// 顺序即侧栏顺序。
    public var folders: [CommonFolder]

    public init(
        schemaVersion: Int = DrawerState.currentSchemaVersion,
        folders: [CommonFolder] = []
    ) {
        self.schemaVersion = schemaVersion
        self.folders = folders
    }

    public static let empty = DrawerState()
}
