import Foundation

/// 一条搜索结果：命中的项目，加上它相对于「常用文件夹」根目录的父目录路径。
public struct SearchMatch: Equatable, Identifiable, Sendable {
    public let entry: DirectoryEntry
    /// 根目录下的项目为空数组；更深层为从根到父目录的路径分量。
    public let relativePath: [String]

    public var id: String { entry.url.path }

    public init(entry: DirectoryEntry, relativePath: [String]) {
        self.entry = entry
        self.relativePath = relativePath
    }
}

/// 可跨线程读取的取消标记。
public final class SearchCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    public init() {}

    public func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}

/// 在「搜索范围」内按名称递归查找。
///
/// 边界与列表一致：不进入包目录、不沿符号链接或替身越界、隐藏文件按开关处理、
/// 只匹配名称而不匹配文件内容。
public struct SearchEngine: Sendable {
    private let access: any FolderAccess

    public init(access: any FolderAccess = LocalFolderAccess()) {
        self.access = access
    }

    public func search(
        query: String,
        in root: URL,
        sortRule: SortRule = .default,
        showHiddenFiles: Bool = false,
        isCancelled: @escaping @Sendable () -> Bool = { false }
    ) throws -> [SearchMatch] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }

        var matches: [SearchMatch] = []
        var stack: [(url: URL, path: [String])] = [(root, [])]

        while let current = stack.popLast() {
            if isCancelled() { return [] }

            // 单个目录读取失败不应中断整次搜索。
            let entries = (try? access.contents(
                of: current.url,
                includingHidden: showHiddenFiles
            )) ?? []

            for entry in entries {
                if matchesName(entry.name, term: term) {
                    matches.append(SearchMatch(entry: entry, relativePath: current.path))
                }

                // isBrowsable 已排除包目录、符号链接与替身。
                if entry.isBrowsable {
                    stack.append((entry.url, current.path + [entry.name]))
                }
            }
        }

        let entryOrder = DirectoryBrowser.order(by: sortRule)
        return matches.sorted { entryOrder($0.entry, $1.entry) }
    }

    private func matchesName(_ name: String, term: String) -> Bool {
        name.range(
            of: term,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) != nil
    }
}
