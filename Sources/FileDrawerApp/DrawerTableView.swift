import AppKit

/// 文件列表：空格触发预览，右键先选中行再询问菜单。
final class DrawerTableView: NSTableView {
    var onSpace: (() -> Void)?
    var contextMenuProvider: ((Int) -> NSMenu?)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 { // Space
            onSpace?()
            return
        }

        super.keyDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)

        if row >= 0 {
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }

        return contextMenuProvider?(row)
    }
}
