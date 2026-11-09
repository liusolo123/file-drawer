import Foundation

/// 目录中的一个项目。
public struct DirectoryEntry: Equatable, Identifiable, Sendable {
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let isPackage: Bool
    public let modifiedAt: Date?

    public var id: String { url.path }

    /// 可以在抽屉内进入的容器：真实文件夹，且不是包。
    public var isBrowsable: Bool { isDirectory && !isPackage }

    public init(
        url: URL,
        name: String,
        isDirectory: Bool,
        isPackage: Bool,
        modifiedAt: Date?
    ) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.isPackage = isPackage
        self.modifiedAt = modifiedAt
    }
}

/// 列出目录内容并应用排序规则。
///
/// 第一版排序固定为：文件夹在前、文件在后；组内按修改时间降序。
/// 排序切换在后续票据里加入。
public struct DirectoryBrowser: Sendable {
    private let access: any FolderAccess

    public init(access: any FolderAccess = LocalFolderAccess()) {
        self.access = access
    }

    public func contents(of url: URL) throws -> [DirectoryEntry] {
        try access.contents(of: url).sorted(by: Self.defaultOrder)
    }

    static func defaultOrder(_ lhs: DirectoryEntry, _ rhs: DirectoryEntry) -> Bool {
        if lhs.isBrowsable != rhs.isBrowsable {
            return lhs.isBrowsable
        }

        let lhsDate = lhs.modifiedAt ?? .distantPast
        let rhsDate = rhs.modifiedAt ?? .distantPast
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }

        let comparison = lhs.name.localizedStandardCompare(rhs.name)
        if comparison != .orderedSame {
            return comparison == .orderedAscending
        }

        return lhs.url.path < rhs.url.path
    }
}
