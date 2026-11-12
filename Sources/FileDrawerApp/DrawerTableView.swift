import AppKit
import FileDrawerCore

/// 文件列表：空格触发预览，⌘C 复制文件，右键先处理选择再询问菜单。
final class DrawerTableView: NSTableView {
    var onSpace: (() -> Void)?
    var onCopy: (() -> Void)?
    var contextMenuProvider: ((Int) -> NSMenu?)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 { // Space
            onSpace?()
            return
        }

        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "c" {
            onCopy?()
            return
        }

        super.keyDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)

        if row >= 0 {
            let next = SelectionPolicy.rowsAfterContextClick(
                row: row,
                currentSelection: Set(selectedRowIndexes)
            )
            selectRowIndexes(IndexSet(next), byExtendingSelection: false)
        }

        return contextMenuProvider?(row)
    }
}
