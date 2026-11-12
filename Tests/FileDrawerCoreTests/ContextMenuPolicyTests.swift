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

    @Test("多选时只保留可批量执行的动作")
    func multiSelectionKeepsBatchActionsOnly() {
        let files = [
            entry(name: "a.txt", isDirectory: false),
            entry(name: "b.txt", isDirectory: false)
        ]

        #expect(!ContextMenuPolicy.isEnabled(.open, for: files))
        #expect(!ContextMenuPolicy.isEnabled(.preview, for: files))
        #expect(ContextMenuPolicy.isEnabled(.revealInFinder, for: files))
        #expect(ContextMenuPolicy.isEnabled(.copyToClipboard, for: files))
        #expect(!ContextMenuPolicy.isEnabled(.copyPath, for: files))
    }

    @Test("空选择时所有动作不可用")
    func emptySelectionDisablesEveryAction() {
        for action in ContextMenuAction.allCases {
            #expect(!ContextMenuPolicy.isEnabled(action, for: [DirectoryEntry]()))
        }
    }

    @Test("右键已选行保留多选，右键未选行只选该行")
    func contextClickPreservesOrReplacesSelection() {
        #expect(
            SelectionPolicy.rowsAfterContextClick(row: 1, currentSelection: [0, 1, 2])
                == [0, 1, 2]
        )
        #expect(
            SelectionPolicy.rowsAfterContextClick(row: 3, currentSelection: [0, 1, 2])
                == [3]
        )
    }
}
