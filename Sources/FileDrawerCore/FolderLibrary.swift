import Foundation

public enum FolderLibraryError: Error, Equatable {
    case notADirectory
}

/// 解析后的「浏览位置」。`didFallBackToRoot` 说明原记忆位置已不可用。
public struct BrowsingLocation: Equatable, Sendable {
    public let url: URL
    public let didFallBackToRoot: Bool

    public init(url: URL, didFallBackToRoot: Bool = false) {
        self.url = url
        self.didFallBackToRoot = didFallBackToRoot
    }
}

/// 「常用文件夹」集合：顺序、增删、状态与持久化快照。
///
/// 只处理领域规则，不碰 UI，也不决定何时落盘。
public final class FolderLibrary {
    public private(set) var folders: [CommonFolder] = []

    private var resolvedURLs: [UUID: URL] = [:]
    private let access: any FolderAccess

    /// 集合发生变化时调用，供上层安排持久化。
    public var onChange: (() -> Void)?

    public init(
        state: DrawerState = .empty,
        access: any FolderAccess = LocalFolderAccess()
    ) {
        self.folders = state.folders
        self.access = access
        reload()
    }

    public var state: DrawerState {
        DrawerState(folders: folders)
    }

    public func resolvedURL(for id: UUID) -> URL? {
        resolvedURLs[id]
    }

    /// 加入一个文件夹。重复加入同一路径时返回已有条目，不产生重复入口。
    @discardableResult
    public func addFolder(at url: URL) throws -> CommonFolder {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw FolderLibraryError.notADirectory
        }

        let standardized = url.standardizedFileURL

        if let existing = folders.first(where: {
            resolvedURLs[$0.id]?.standardizedFileURL == standardized
        }) {
            return existing
        }

        let bookmark = try access.makeBookmark(for: standardized)
        let folder = CommonFolder(
            displayName: access.displayName(for: standardized),
            bookmark: bookmark,
            status: access.status(of: standardized)
        )

        folders.append(folder)
        resolvedURLs[folder.id] = standardized
        onChange?()
        return folder
    }

    /// 只移除入口，不触碰原目录。
    public func removeFolder(id: UUID) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders.remove(at: index)
        resolvedURLs[id] = nil
        onChange?()
    }

    /// `destination` 是移动完成后的最终下标。
    public func moveFolder(from source: Int, to destination: Int) {
        guard folders.indices.contains(source),
              folders.indices.contains(destination),
              source != destination else {
            return
        }

        let folder = folders.remove(at: source)
        folders.insert(folder, at: destination)
        onChange?()
    }

    /// 当前「浏览位置」，相对于该文件夹根目录。
    public func browsingPath(for id: UUID) -> [String] {
        folders.first(where: { $0.id == id })?.browsingPath ?? []
    }

    /// 更新「浏览位置」。与当前值相同时不触发保存。
    public func setBrowsingPath(_ path: [String], for id: UUID) {
        guard let index = folders.firstIndex(where: { $0.id == id }),
              folders[index].browsingPath != path else {
            return
        }

        folders[index].browsingPath = path
        onChange?()
    }

    /// 解析可浏览的位置。记录的子目录已不可用时退回根目录并重置记忆。
    public func resolveBrowsingLocation(for id: UUID) -> BrowsingLocation? {
        guard let root = resolvedURLs[id],
              let index = folders.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        let components = folders[index].browsingPath
        guard !components.isEmpty else {
            return BrowsingLocation(url: root)
        }

        let candidate = components.reduce(root) { url, component in
            url.appendingPathComponent(component, isDirectory: true)
        }

        guard access.status(of: candidate) == .available else {
            folders[index].browsingPath = []
            onChange?()
            return BrowsingLocation(url: root, didFallBackToRoot: true)
        }

        return BrowsingLocation(url: candidate)
    }

    /// 重新解析全部书签并刷新状态。解析失败保留条目。
    public func reload() {        for index in folders.indices {
            let folder = folders[index]

            do {
                let resolved = try access.resolveBookmark(folder.bookmark)
                resolvedURLs[folder.id] = resolved.url
                folders[index].status = access.status(of: resolved.url)

                if resolved.isStale,
                   let refreshed = try? access.makeBookmark(for: resolved.url) {
                    folders[index].bookmark = refreshed
                }
            } catch {
                resolvedURLs[folder.id] = nil
                folders[index].status = .missing
            }
        }
    }
}
