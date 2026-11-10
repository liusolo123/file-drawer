import Testing
import Foundation
@testable import FileDrawerCore

@Suite("右键菜单可用性")
struct ContextMenuPolicyTests {
    private func entry(
        name: String,
        isDirectory: Bool,
        isPackage: Bool = false,
        isSymbolicLink: Bool = false
    ) -> DirectoryEntry {
        DirectoryEntry(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            name: name,
            isDirectory: isDirectory,
            isPackage: isPackage,
            isSymbolicLink: isSymbolicLink,
            modifiedAt: nil
        )
    }

    @Test("普通文件五项全部可用")
    func fileEnablesEveryAction() {
        let file = entry(name: "note.txt", isDirectory: false)

        for action in ContextMenuAction.allCases {
            #expect(ContextMenuPolicy.isEnabled(action, for: file))
        }
    }

    @Test("普通文件夹不可预览，其余可用")
    func folderDisablesPreviewOnly() {
        let folder = entry(name: "工作", isDirectory: true)

        #expect(ContextMenuPolicy.isEnabled(.open, for: folder))
        #expect(!ContextMenuPolicy.isEnabled(.preview, for: folder))
        #expect(ContextMenuPolicy.isEnabled(.revealInFinder, for: folder))
        #expect(ContextMenuPolicy.isEnabled(.copyToClipboard, for: folder))
        #expect(ContextMenuPolicy.isEnabled(.copyPath, for: folder))
    }

    @Test("包目录可预览，打开交给默认应用")
    func packageEnablesPreview() {
        let package = entry(name: "工具.app", isDirectory: true, isPackage: true)

        #expect(ContextMenuPolicy.isEnabled(.open, for: package))
        #expect(ContextMenuPolicy.isEnabled(.preview, for: package))
    }

    @Test("符号链接可预览，但不能作为容器进入")
    func symbolicLinkEnablesPreview() {
        let link = entry(name: "链接", isDirectory: true, isSymbolicLink: true)

        #expect(ContextMenuPolicy.isEnabled(.preview, for: link))
        #expect(!link.isBrowsable)
    }
}
