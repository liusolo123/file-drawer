import Testing
import Foundation
@testable import FileDrawerCore

@Suite("失效与恢复")
struct FailureRecoveryTests {
    @Test("重新选择文件夹保留入口身份与原排序，重置浏览位置")
    func replaceFolderKeepsIdentity() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let oldURL = try sandbox.makeFolder("旧位置")
        let newURL = try sandbox.makeFolder("新位置")
        try sandbox.makeFolder("子目录", in: oldURL)

        let library = FolderLibrary()
        let folder = try library.addFolder(at: oldURL)
        library.setBrowsingPath(["子目录"], for: folder.id)
        library.setSortRule(SortRule(key: .name, ascending: true), for: folder.id)

        try library.replaceFolder(id: folder.id, with: newURL)

        #expect(library.folders.count == 1)
        #expect(library.folders[0].id == folder.id)
        #expect(library.folders[0].displayName == "新位置")
        #expect(library.folders[0].status == .available)
        #expect(library.folders[0].browsingPath.isEmpty)
        #expect(library.folders[0].sortRule == SortRule(key: .name, ascending: true))
        #expect(
            library.resolvedURL(for: folder.id)?.standardizedFileURL
                == newURL.standardizedFileURL
        )
    }

    @Test("重新选择普通文件会被拒绝")
    func replaceWithFileThrows() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let folderURL = try sandbox.makeFolder("工作")
        let fileURL = try sandbox.makeFile("note.txt")

        let library = FolderLibrary()
        let folder = try library.addFolder(at: folderURL)

        #expect(throws: FolderLibraryError.notADirectory) {
            try library.replaceFolder(id: folder.id, with: fileURL)
        }
    }

    @Test("不存在的卷被判为卷未连接")
    func missingVolumeIsClassified() {
        let url = URL(
            fileURLWithPath: "/Volumes/FileDrawerMissing-\(UUID().uuidString)/folder"
        )

        #expect(LocalFolderAccess().status(of: url) == .volumeUnavailable)
    }

    @Test("每种失效状态都给出原因与恢复建议")
    func failureStatusesExplainThemselves() {
        let statuses: [FolderStatus] = [.missing, .permissionDenied, .volumeUnavailable]

        for status in statuses {
            #expect(!status.localizedDescription.isEmpty)
            #expect(!status.recoverySuggestion.isEmpty)
        }

        #expect(FolderStatus.available.recoverySuggestion.isEmpty)
    }

    @Test("删除目录后入口保留并标记 missing")
    func deletedFolderIsRetained() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let folderURL = try sandbox.makeFolder("临时")
        let library = FolderLibrary()
        try library.addFolder(at: folderURL)

        try FileManager.default.removeItem(at: folderURL)
        library.reload()

        #expect(library.folders.count == 1)
        #expect(library.folders[0].status == .missing)
    }
}
