import Foundation

/// 「常用文件夹」当前是否可访问。
public enum FolderStatus: String, Codable, Sendable {
    case available
    case missing
    case permissionDenied
    case volumeUnavailable

    /// 面向用户的原因说明。完整的三段式错误呈现留到失效处理那张票。
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

    public init(
        id: UUID = UUID(),
        displayName: String,
        bookmark: Data,
        status: FolderStatus = .available,
        browsingPath: [String] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.bookmark = bookmark
        self.status = status
        self.browsingPath = browsingPath
    }

    public var isAvailable: Bool { status == .available }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case bookmark
        case status
        case browsingPath
    }

    /// 早期状态文件没有 `browsingPath`，按根目录处理。
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        bookmark = try container.decode(Data.self, forKey: .bookmark)
        status = try container.decodeIfPresent(FolderStatus.self, forKey: .status) ?? .available
        browsingPath = try container.decodeIfPresent([String].self, forKey: .browsingPath) ?? []
    }
}
