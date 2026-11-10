import Testing
import Foundation
@testable import FileDrawerCore

@Suite("搜索")
struct SearchEngineTests {
    private func search(
        _ query: String,
        in root: URL,
        showHiddenFiles: Bool = false,
        sortRule: SortRule = .default
    ) throws -> [SearchMatch] {
        try SearchEngine().search(
            query: query,
            in: root,
            sortRule: sortRule,
            showHiddenFiles: showHiddenFiles
        )
    }

    @Test("命中深层子目录并返回相对路径")
    func findsDeepMatchWithRelativePath() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let sub = try sandbox.makeFolder("sub")
        let deeper = try sandbox.makeFolder("deeper", in: sub)
        try sandbox.makeFile("target.txt", in: deeper)

        let matches = try search("target", in: sandbox.root)

        #expect(matches.count == 1)
        #expect(matches[0].entry.name == "target.txt")
        #expect(matches[0].relativePath == ["sub", "deeper"])
    }

    @Test("忽略大小写与变音符号")
    func matchesCaseAndDiacriticsInsensitively() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }
        try sandbox.makeFile("Café.txt")

        #expect(try search("cafe", in: sandbox.root).count == 1)
        #expect(try search("CAFÉ", in: sandbox.root).count == 1)
    }

    @Test("同名文件在不同目录各自返回路径")
    func disambiguatesSameName() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let first = try sandbox.makeFolder("甲")
        let second = try sandbox.makeFolder("乙")
        try sandbox.makeFile("report.txt", in: first)
        try sandbox.makeFile("report.txt", in: second)

        let matches = try search(
            "report",
            in: sandbox.root,
            sortRule: SortRule(key: .name, ascending: true)
        )

        #expect(matches.count == 2)
        #expect(Set(matches.map { $0.relativePath }) == [["甲"], ["乙"]])
    }

    @Test("不进入包目录内部")
    func skipsPackageContents() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let package = try sandbox.makeFolder("工具.app")
        try sandbox.makeFolder("Contents", in: package)
        try sandbox.makeFile("inner-secret.txt", in: package.appendingPathComponent("Contents"))

        #expect(try search("inner-secret", in: sandbox.root).isEmpty)
    }

    @Test("不沿符号链接或替身越界")
    func doesNotFollowSymbolicLinks() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let outside = try sandbox.makeFolder("范围外")
        try sandbox.makeFile("secret.txt", in: outside)

        let root = try sandbox.makeFolder("搜索根目录")
        let link = root.appendingPathComponent("外部链接")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)

        #expect(try search("secret", in: root).isEmpty)
    }

    @Test("隐藏文件按开关决定是否参与搜索")
    func hiddenFilesRespectSetting() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }
        try sandbox.makeFile(".secret-note")

        #expect(try search("secret-note", in: sandbox.root, showHiddenFiles: false).isEmpty)
        #expect(try search("secret-note", in: sandbox.root, showHiddenFiles: true).count == 1)
    }

    @Test("空白查询返回空结果")
    func blankQueryReturnsNothing() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }
        try sandbox.makeFile("a.txt")

        #expect(try search("", in: sandbox.root).isEmpty)
        #expect(try search("   ", in: sandbox.root).isEmpty)
    }

    @Test("取消后立即返回空结果")
    func cancellationStopsSearch() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }
        try sandbox.makeFile("a.txt")

        let matches = try SearchEngine().search(
            query: "a",
            in: sandbox.root,
            isCancelled: { true }
        )

        #expect(matches.isEmpty)
    }

    @Test("结果按给定排序规则排序")
    func sortsResultsByRule() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let sub = try sandbox.makeFolder("sub")
        try sandbox.makeFile("b.txt")
        try sandbox.makeFile("a.txt", in: sub)

        let ascending = try search(
            ".txt",
            in: sandbox.root,
            sortRule: SortRule(key: .name, ascending: true)
        )
        #expect(ascending.map(\.entry.name) == ["a.txt", "b.txt"])

        let descending = try search(
            ".txt",
            in: sandbox.root,
            sortRule: SortRule(key: .name, ascending: false)
        )
        #expect(descending.map(\.entry.name) == ["b.txt", "a.txt"])
    }
}
