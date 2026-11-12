import Foundation

/// 「常用文件夹」当前是否可访问。
public enum FolderStatus: String, Codable, Sendable {
    case available
    case missing
    case permissionDenied
    case volumeUnavailable

    /// 面向用户的原因说明。
    public var localizedDescription: String {
        switch self {
        case .available:
            return "可用"
        case .missing:
            return "文件夹不存在或已被移动"
        case .permissionDenied:
            return "没有访问该文件夹的权限"
        case .volumeUnavailable:
            return "所在磁盘或卷未连接"
        }
    }

    /// 用户接下来可以做什么。
    public var recoverySuggestion: String {
        switch self {
        case .available:
            return ""
        case .missing:
            return "重新选择这个入口指向的文件夹，或移除入口。"
        case .permissionDenied:
            return "在系统设置中恢复访问权限后点「重试」，或重新选择文件夹。"
        case .volumeUnavailable:
            return "重新连接磁盘后点「重试」，或移除入口。"
        }
    }
}

/// 用户加入文件抽屉的一个真实文件夹。
public struct CommonFolder: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var displayName: String
    /// 安全作用域书签，用于在重启后重新获得访问权。
    public var bookmark: Data
    /// 派生状态，加载时会按实际文件系统重新计算。
    public var status: FolderStatus
    /// 相对于该文件夹根目录的「浏览位置」，空数组表示根目录本身。
    public var browsingPath: [String]
    /// 每个「常用文件夹」独立记住的排序规则。
    public var sortRule: SortRule

    public init(
        id: UUID = UUID(),
        displayName: String,
        bookmark: Data,
        status: FolderStatus = .available,
        browsingPath: [String] = [],
        sortRule: SortRule = .default
    ) {
        self.id = id
        self.displayName = displayName
        self.bookmark = bookmark
        self.status = status
        self.browsingPath = browsingPath
        self.sortRule = sortRule
    }

    public var isAvailable: Bool { status == .available }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case bookmark
        case status
        case browsingPath
        case sortRule
    }

    /// 早期状态文件没有 `browsingPath` / `sortRule`，按默认值处理。
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        bookmark = try container.decode(Data.self, forKey: .bookmark)
        status = try container.decodeIfPresent(FolderStatus.self, forKey: .status) ?? .available
        browsingPath = try container.decodeIfPresent([String].self, forKey: .browsingPath) ?? []
        sortRule = try container.decodeIfPresent(SortRule.self, forKey: .sortRule) ?? .default
    }
}
