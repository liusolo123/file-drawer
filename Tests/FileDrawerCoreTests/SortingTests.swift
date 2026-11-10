import Testing
import Foundation
@testable import FileDrawerCore

@Suite("排序与特殊项目")
struct SortingTests {
    private func setModificationDate(_ url: URL, _ seconds: TimeInterval) throws {
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: seconds)],
            ofItemAtPath: url.path
        )
    }

    /// 固定夹具：两个文件夹、两个文件，修改时间互不相同。
    private func makeFixture(in sandbox: TempSandbox) throws -> URL {
        let root = try sandbox.makeFolder("根")
        let folderA = try sandbox.makeFolder("folderA", in: root)
        let folderB = try sandbox.makeFolder("folderB", in: root)
        let fileA = try sandbox.makeFile("a.txt", in: root)
        let fileB = try sandbox.makeFile("b.txt", in: root)

        try setModificationDate(folderA, 400)
        try setModificationDate(folderB, 300)
        try setModificationDate(fileA, 200)
        try setModificationDate(fileB, 100)
        return root
    }

    @Test("四种排序组合都正确，且文件夹始终在前")
    func supportsFourSortCombinations() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }
        let root = try makeFixture(in: sandbox)
        let browser = DirectoryBrowser()

        let nameAscending = try browser.contents(
            of: root,
            sortRule: SortRule(key: .name, ascending: true)
        )
        #expect(nameAscending.map(\.name) == ["folderA", "folderB", "a.txt", "b.txt"])

        let nameDescending = try browser.contents(
            of: root,
            sortRule: SortRule(key: .name, ascending: false)
        )
        #expect(nameDescending.map(\.name) == ["folderB", "folderA", "b.txt", "a.txt"])

        let modifiedAscending = try browser.contents(
            of: root,
            sortRule: SortRule(key: .modified, ascending: true)
        )
        #expect(modifiedAscending.map(\.name) == ["folderB", "folderA", "b.txt", "a.txt"])

        let modifiedDescending = try browser.contents(
            of: root,
            sortRule: SortRule(key: .modified, ascending: false)
        )
        #expect(modifiedDescending.map(\.name) == ["folderA", "folderB", "a.txt", "b.txt"])
    }

    @Test("排序规则按常用文件夹记忆并跨实例恢复")
    func sortRulePersistsPerFolder() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let first = try sandbox.makeFolder("甲")
        let second = try sandbox.makeFolder("乙")
        let library = FolderLibrary()
        let firstFolder = try library.addFolder(at: first)
        let secondFolder = try library.addFolder(at: second)

        library.setSortRule(SortRule(key: .name, ascending: true), for: firstFolder.id)
        library.setSortRule(SortRule(key: .modified, ascending: true), for: secondFolder.id)

        let restored = FolderLibrary(state: library.state)

        #expect(restored.folders[0].sortRule == SortRule(key: .name, ascending: true))
        #expect(restored.folders[1].sortRule == SortRule(key: .modified, ascending: true))
    }

    @Test("隐藏文件默认跳过，开启后出现在列表中")
    func hiddenFilesRespectSetting() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        try sandbox.makeFile("可见.txt")
        try sandbox.makeFile(".隐藏")
        let browser = DirectoryBrowser()

        let hiddenOff = try browser.contents(of: sandbox.root, showHiddenFiles: false)
        #expect(hiddenOff.map(\.name) == ["可见.txt"])

        let hiddenOn = try browser.contents(of: sandbox.root, showHiddenFiles: true)
        #expect(Set(hiddenOn.map(\.name)) == ["可见.txt", ".隐藏"])
    }

    @Test("符号链接作为叶子排在文件夹之后，不参与进入")
    func symbolicLinkIsLeaf() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let container = try sandbox.makeFolder("容器")
        let target = try sandbox.makeFolder("目标")
        let link = container.appendingPathComponent("链接")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        try sandbox.makeFolder("真实目录", in: container)

        let entries = try DirectoryBrowser().contents(of: container)
        let linkEntry = try #require(entries.first(where: { $0.name == "链接" }))

        #expect(entries.map(\.name) == ["真实目录", "链接"])
        #expect(linkEntry.isSymbolicLink)
        #expect(!linkEntry.isBrowsable)
    }

    @Test("隐藏文件设置随状态文件往返")
    func settingsRoundTrip() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let store = StateStore(directory: sandbox.root)
        var state = DrawerState()
        state.settings.showsHiddenFiles = true
        try store.save(state)

        #expect(try store.load().settings.showsHiddenFiles)
    }

    @Test("旧状态文件缺少 settings 时默认不显示隐藏文件")
    func legacyStateWithoutSettingsDefaultsToHiddenOff() throws {
        let json = """
        {
          "schemaVersion": 1,
          "folders": []
        }
        """

        let state = try JSONDecoder().decode(DrawerState.self, from: Data(json.utf8))
        #expect(!state.settings.showsHiddenFiles)
    }
}
