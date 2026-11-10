import Foundation

/// 全局设置。
public struct DrawerSettings: Codable, Equatable, Sendable {
    /// 是否在列表与搜索中显示隐藏文件。默认关闭。
    public var showsHiddenFiles: Bool

    public init(showsHiddenFiles: Bool = false) {
        self.showsHiddenFiles = showsHiddenFiles
    }

    public static let `default` = DrawerSettings()
}

/// 需要持久化的全部抽屉状态。
public struct DrawerState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    /// 顺序即侧栏顺序。
    public var folders: [CommonFolder]
    public var settings: DrawerSettings

    public init(
        schemaVersion: Int = DrawerState.currentSchemaVersion,
        folders: [CommonFolder] = [],
        settings: DrawerSettings = .default
    ) {
        self.schemaVersion = schemaVersion
        self.folders = folders
        self.settings = settings
    }

    public static let empty = DrawerState()

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case folders
        case settings
    }

    /// 早期状态文件没有 `settings`，按默认值处理。
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        folders = try container.decode([CommonFolder].self, forKey: .folders)
        settings = try container.decodeIfPresent(DrawerSettings.self, forKey: .settings)
            ?? .default
    }
}
