import Testing
import Foundation
@testable import FileDrawerCore

@Suite("目录浏览")
struct DirectoryBrowserTests {
    private func setModificationDate(_ url: URL, _ seconds: TimeInterval) throws {
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: seconds)],
            ofItemAtPath: url.path
        )
    }

    @Test("只列出直接子项，不递归展开")
    func listsDirectChildrenOnly() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let nested = try sandbox.makeFolder("子目录")
        try sandbox.makeFile("深层文件.txt", in: nested)
        try sandbox.makeFile("顶层文件.txt")

        let entries = try DirectoryBrowser().contents(of: sandbox.root)
        #expect(Set(entries.map(\.name)) == ["子目录", "顶层文件.txt"])
    }

    @Test("文件夹在前，组内按修改时间降序")
    func sortsFoldersFirstThenByDateDescending() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let folderA = try sandbox.makeFolder("甲")
        let folderB = try sandbox.makeFolder("乙")
        let fileA = try sandbox.makeFile("a.txt")
        let fileB = try sandbox.makeFile("b.txt")

        try setModificationDate(folderA, 400)
        try setModificationDate(folderB, 300)
        try setModificationDate(fileA, 200)
        try setModificationDate(fileB, 100)

        let entries = try DirectoryBrowser().contents(of: sandbox.root)
        #expect(entries.map(\.name) == ["甲", "乙", "a.txt", "b.txt"])
    }

    @Test("修改时间相同时按名称升序兜底")
    func tiesBreakByName() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let first = try sandbox.makeFile("b.txt")
        let second = try sandbox.makeFile("c.txt")
        try setModificationDate(first, 100)
        try setModificationDate(second, 100)

        let entries = try DirectoryBrowser().contents(of: sandbox.root)
        #expect(entries.map(\.name) == ["b.txt", "c.txt"])
    }

    @Test("包目录按文件处理，不能进入")
    func packageIsTreatedAsLeaf() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let folder = try sandbox.makeFolder("甲")
        let package = try sandbox.makeFolder("工具.app")
        try setModificationDate(folder, 100)
        try setModificationDate(package, 500)

        let entries = try DirectoryBrowser().contents(of: sandbox.root)
        let packageEntry = try #require(entries.first(where: { $0.name == "工具.app" }))

        #expect(entries.map(\.name) == ["甲", "工具.app"])
        #expect(packageEntry.isPackage)
        #expect(!packageEntry.isBrowsable)
    }

    @Test("隐藏文件不出现在列表中")
    func hiddenFilesAreSkipped() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        try sandbox.makeFile("可见.txt")
        try sandbox.makeFile(".隐藏")

        let entries = try DirectoryBrowser().contents(of: sandbox.root)
        #expect(entries.map(\.name) == ["可见.txt"])
    }
}

@Suite("浏览位置")
struct BrowsingLocationTests {
    @Test("每个常用文件夹独立记住浏览位置并跨实例恢复")
    func browsingPathIsPerFolderAndPersists() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let firstRoot = try sandbox.makeFolder("甲")
        try sandbox.makeFolder("子目录", in: firstRoot)
        let secondRoot = try sandbox.makeFolder("乙")
        try sandbox.makeFolder("另一个", in: secondRoot)

        let library = FolderLibrary()
        let first = try library.addFolder(at: firstRoot)
        let second = try library.addFolder(at: secondRoot)

        library.setBrowsingPath(["子目录"], for: first.id)
        library.setBrowsingPath(["另一个"], for: second.id)

        let restored = FolderLibrary(state: library.state)

        #expect(restored.browsingPath(for: first.id) == ["子目录"])
        #expect(restored.browsingPath(for: second.id) == ["另一个"])

        let location = try #require(restored.resolveBrowsingLocation(for: first.id))
        #expect(!location.didFallBackToRoot)
        #expect(
            location.url.standardizedFileURL
                == firstRoot.appendingPathComponent("子目录").standardizedFileURL
        )
    }

    @Test("记忆的位置不存在时退回根目录并重置")
    func missingBrowsingPathFallsBackToRoot() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let root = try sandbox.makeFolder("工作")
        let library = FolderLibrary()
        let folder = try library.addFolder(at: root)
        library.setBrowsingPath(["已删除的子目录"], for: folder.id)

        let location = try #require(library.resolveBrowsingLocation(for: folder.id))

        #expect(location.didFallBackToRoot)
        #expect(location.url.standardizedFileURL == root.standardizedFileURL)
        #expect(library.browsingPath(for: folder.id).isEmpty)
    }

    @Test("早期没有 browsingPath 字段的状态文件按根目录解码")
    func legacyStateWithoutBrowsingPathDecodes() throws {
        let id = UUID()
        let json = """
        {
          "schemaVersion": 1,
          "folders": [
            {
              "id": "\(id.uuidString)",
              "displayName": "旧入口",
              "bookmark": "AAEC",
              "status": "available"
            }
          ]
        }
        """

        let state = try JSONDecoder().decode(DrawerState.self, from: Data(json.utf8))
        let folder = try #require(state.folders.first)

        #expect(folder.id == id)
        #expect(folder.browsingPath.isEmpty)
    }
}
