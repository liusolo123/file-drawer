import Foundation

/// 目录中的一个项目。
public struct DirectoryEntry: Equatable, Identifiable, Sendable {
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let isPackage: Bool
    public let isSymbolicLink: Bool
    /// 位于 iCloud，但内容尚未下载到本地。
    public let isCloudOnly: Bool
    public let modifiedAt: Date?

    public var id: String { url.path }

    /// 可以在抽屉内进入的容器：真实文件夹，不是包，也不是符号链接或替身。
    public var isBrowsable: Bool {
        isDirectory && !isPackage && !isSymbolicLink
    }

    public init(
        url: URL,
        name: String,
        isDirectory: Bool,
        isPackage: Bool,
        isSymbolicLink: Bool = false,
        isCloudOnly: Bool = false,
        modifiedAt: Date?
    ) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.isPackage = isPackage
        self.isSymbolicLink = isSymbolicLink
        self.isCloudOnly = isCloudOnly
        self.modifiedAt = modifiedAt
    }
}

/// 列出目录内容并应用排序规则。
public struct DirectoryBrowser: Sendable {
    private let access: any FolderAccess

    public init(access: any FolderAccess = LocalFolderAccess()) {
        self.access = access
    }

    public func contents(
        of url: URL,
        sortRule: SortRule = .default,
        showHiddenFiles: Bool = false
    ) throws -> [DirectoryEntry] {
        try access
            .contents(of: url, includingHidden: showHiddenFiles)
            .sorted(by: Self.order(by: sortRule))
    }

    static func order(by rule: SortRule) -> (DirectoryEntry, DirectoryEntry) -> Bool {
        { lhs, rhs in
            if lhs.isBrowsable != rhs.isBrowsable {
                return lhs.isBrowsable
            }

            let comparison = compare(lhs, rhs, by: rule.key)
            if comparison != .orderedSame {
                return rule.ascending
                    ? comparison == .orderedAscending
                    : comparison == .orderedDescending
            }

            // 稳定兜底：名称升序，再按路径。
            let nameComparison = lhs.name.localizedStandardCompare(rhs.name)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }
            return lhs.url.path < rhs.url.path
        }
    }

    private static func compare(
        _ lhs: DirectoryEntry,
        _ rhs: DirectoryEntry,
        by key: SortRule.Key
    ) -> ComparisonResult {
        switch key {
        case .name:
            return lhs.name.localizedStandardCompare(rhs.name)
        case .modified:
            let lhsDate = lhs.modifiedAt ?? .distantPast
            let rhsDate = rhs.modifiedAt ?? .distantPast
            if lhsDate == rhsDate { return .orderedSame }
            return lhsDate < rhsDate ? .orderedAscending : .orderedDescending
        }
    }
}
