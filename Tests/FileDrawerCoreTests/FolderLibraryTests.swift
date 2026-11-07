import Testing
import Foundation
@testable import FileDrawerCore

/// 每个测试自建临时沙盒，互不共享状态。
struct TempSandbox {
    let root: URL

    init() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("FileDrawerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
    }

    @discardableResult
    func makeFolder(_ name: String, in parent: URL? = nil) throws -> URL {
        let url = (parent ?? root).appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    func makeFile(_ name: String, in parent: URL? = nil) throws -> URL {
        let url = (parent ?? root).appendingPathComponent(name, isDirectory: false)
        try Data("test".utf8).write(to: url)
        return url
    }

    func destroy() {
        try? FileManager.default.removeItem(at: root)
    }
}

@Suite("常用文件夹集合")
struct FolderLibraryTests {
    @Test("添加文件夹后记录名称、书签与可用状态")
    func addFolderRecordsNameAndStatus() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let directory = try sandbox.makeFolder("工作")
        let library = FolderLibrary()

        let folder = try library.addFolder(at: directory)

        #expect(library.folders.count == 1)
        #expect(folder.displayName == "工作")
        #expect(folder.status == .available)
        #expect(!folder.bookmark.isEmpty)
        #expect(
            library.resolvedURL(for: folder.id)?.standardizedFileURL
                == directory.standardizedFileURL
        )
    }

    @Test("重复添加同一文件夹不会产生重复入口")
    func addingSameFolderTwiceKeepsOneEntry() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let directory = try sandbox.makeFolder("工作")
        let library = FolderLibrary()

        let first = try library.addFolder(at: directory)
        let second = try library.addFolder(at: directory)

        #expect(library.folders.count == 1)
        #expect(first.id == second.id)
    }

    @Test("添加普通文件会被拒绝")
    func addingFileThrows() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let file = try sandbox.makeFile("note.txt")
        let library = FolderLibrary()

        #expect(throws: FolderLibraryError.notADirectory) {
            try library.addFolder(at: file)
        }
        #expect(library.folders.isEmpty)
    }

    @Test("移动调整顺序")
    func moveReordersFolders() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let library = FolderLibrary()
        for name in ["甲", "乙", "丙"] {
            try library.addFolder(at: try sandbox.makeFolder(name))
        }

        library.moveFolder(from: 0, to: 2)

        #expect(library.folders.map(\.displayName) == ["乙", "丙", "甲"])
    }

    @Test("移除入口不会删除原目录与其中的文件")
    func removeKeepsDirectoryAndContents() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let directory = try sandbox.makeFolder("工作")
        let file = try sandbox.makeFile("note.txt", in: directory)
        let library = FolderLibrary()

        let folder = try library.addFolder(at: directory)
        library.removeFolder(id: folder.id)

        #expect(library.folders.isEmpty)
        #expect(FileManager.default.fileExists(atPath: directory.path))
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test("目录被删除后重新加载会标记失效但保留条目")
    func deletedFolderIsMarkedMissing() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let directory = try sandbox.makeFolder("临时")
        let library = FolderLibrary()
        try library.addFolder(at: directory)

        try FileManager.default.removeItem(at: directory)
        library.reload()

        #expect(library.folders.count == 1)
        #expect(library.folders[0].status == .missing)
        #expect(library.resolvedURL(for: library.folders[0].id) == nil)
    }

    @Test("无读取权限的目录会被标记为权限不足")
    func unreadableFolderIsMarkedPermissionDenied() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let directory = try sandbox.makeFolder("受限")
        let library = FolderLibrary()
        try library.addFolder(at: directory)

        try FileManager.default.setAttributes(
            [.posixPermissions: 0o000],
            ofItemAtPath: directory.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: directory.path
            )
        }

        library.reload()

        #expect(library.folders[0].status == .permissionDenied)
    }

    @Test("书签可以跨实例恢复同一目录")
    func bookmarkSurvivesRoundTrip() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let directory = try sandbox.makeFolder("项目")
        let original = FolderLibrary()
        try original.addFolder(at: directory)

        let restored = FolderLibrary(state: original.state)
        let folder = try #require(restored.folders.first)

        #expect(restored.folders.count == 1)
        #expect(folder.displayName == "项目")
        #expect(folder.status == .available)
        #expect(
            restored.resolvedURL(for: folder.id)?.standardizedFileURL
                == directory.standardizedFileURL
        )
    }

    @Test("书签损坏时保留条目并标记失效")
    func corruptBookmarkKeepsEntry() {
        let broken = CommonFolder(
            displayName: "已损坏",
            bookmark: Data([0x00, 0x01, 0x02])
        )
        let library = FolderLibrary(state: DrawerState(folders: [broken]))

        #expect(library.folders.count == 1)
        #expect(library.folders[0].status == .missing)
    }
}

@Suite("状态文件")
struct StateStoreTests {
    @Test("保存后重新加载得到相同状态")
    func saveAndLoadRoundTrip() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let directory = try sandbox.makeFolder("工作")
        let library = FolderLibrary()
        try library.addFolder(at: directory)

        let store = StateStore(directory: sandbox.root)
        try store.save(library.state)

        let loaded = try store.load()
        #expect(loaded == library.state)
        #expect(loaded.schemaVersion == DrawerState.currentSchemaVersion)
    }

    @Test("文件不存在时返回空状态")
    func missingFileReturnsEmptyState() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let store = StateStore(directory: sandbox.root)
        #expect(try store.load() == .empty)
    }

    @Test("未来版本的状态文件被拒绝")
    func futureSchemaVersionIsRejected() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let store = StateStore(directory: sandbox.root)
        try store.save(DrawerState(schemaVersion: 99))

        #expect(throws: StateStoreError.unsupportedSchemaVersion(99)) {
            try store.load()
        }
    }

    @Test("入口顺序在往返后保持不变")
    func folderOrderIsPreserved() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let library = FolderLibrary()
        for name in ["甲", "乙", "丙"] {
            try library.addFolder(at: try sandbox.makeFolder(name))
        }

        let store = StateStore(directory: sandbox.root)
        try store.save(library.state)

        let loaded = try store.load()
        #expect(loaded.folders.map(\.displayName) == ["甲", "乙", "丙"])
    }
}
