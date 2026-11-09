import Foundation

public struct ResolvedFolder: Equatable, Sendable {
    public let url: URL
    public let isStale: Bool

    public init(url: URL, isStale: Bool) {
        self.url = url
        self.isStale = isStale
    }
}

/// 核心库访问文件系统的唯一入口。
///
/// 生产实现是 `FileManager` 的薄包装；测试实现可以构造真实环境难以复现的
/// 失效、权限与云端场景。
public protocol FolderAccess: Sendable {
    func makeBookmark(for url: URL) throws -> Data
    func resolveBookmark(_ data: Data) throws -> ResolvedFolder
    func displayName(for url: URL) -> String
    func status(of url: URL) -> FolderStatus
    func contents(of url: URL) throws -> [DirectoryEntry]
}

public struct LocalFolderAccess: FolderAccess {
    public init() {}

    public func makeBookmark(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            // 非沙盒环境或某些网络卷不支持安全作用域书签，退化为普通书签。
            return try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
    }

    public func resolveBookmark(_ data: Data) throws -> ResolvedFolder {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return ResolvedFolder(url: url, isStale: isStale)
        } catch {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return ResolvedFolder(url: url, isStale: isStale)
        }
    }

    public func displayName(for url: URL) -> String {
        let name = FileManager.default.displayName(atPath: url.path)
        return name.isEmpty ? url.lastPathComponent : name
    }

    public func status(of url: URL) -> FolderStatus {
        let fileManager = FileManager.default

        if isOnUnmountedVolume(url) {
            return .volumeUnavailable
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return .missing
        }

        guard fileManager.isReadableFile(atPath: url.path) else {
            return .permissionDenied
        }

        return .available
    }

    public func contents(of url: URL) throws -> [DirectoryEntry] {
        let keys: [URLResourceKey] = [
            .nameKey,
            .isDirectoryKey,
            .isPackageKey,
            .contentModificationDateKey
        ]

        let urls = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )

        return urls.compactMap { child in
            guard let values = try? child.resourceValues(forKeys: Set(keys)) else {
                return nil
            }

            return DirectoryEntry(
                url: child,
                name: values.name ?? child.lastPathComponent,
                isDirectory: values.isDirectory ?? false,
                isPackage: values.isPackage ?? false,
                modifiedAt: values.contentModificationDate
            )
        }
    }

    /// `/Volumes/<name>/...` 的挂载点不存在时，视为卷未连接。
    private func isOnUnmountedVolume(_ url: URL) -> Bool {
        let components = url.pathComponents
        guard components.count >= 3, components[1] == "Volumes" else {
            return false
        }
        return !FileManager.default.fileExists(atPath: "/Volumes/\(components[2])")
    }
}
