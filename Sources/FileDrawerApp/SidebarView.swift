import AppKit
import FileDrawerCore

/// 侧栏：常用文件夹列表、添加与移除、拖动排序。
@MainActor
final class SidebarView: NSView {
    private enum Metrics {
        static let width: CGFloat = 220
        static let rowHeight: CGFloat = 32
    }

    private static let cellIdentifier = NSUserInterfaceItemIdentifier("FolderCell")
    private static let rowPasteboardType = NSPasteboard.PasteboardType(
        "com.liusolo.filedrawer.sidebar-row"
    )

    private let library: FolderLibrary
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let addButton = NSButton()
    private let removeButton = NSButton()

    var onAddRequested: (() -> Void)?
    var onSelectionChange: ((CommonFolder?) -> Void)?

    init(library: FolderLibrary) {
        self.library = library
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        build()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reload() {
        let selectedID = selectedFolder()?.id
        tableView.reloadData()

        if let selectedID,
           let index = library.folders.firstIndex(where: { $0.id == selectedID }) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }

        if library.folders.isEmpty {
            tableView.deselectAll(nil)
        }

        updateRemoveButton()
    }

    func select(id: UUID) {
        guard let index = library.folders.firstIndex(where: { $0.id == id }) else { return }
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }

    func selectedFolder() -> CommonFolder? {
        let row = tableView.selectedRow
        guard library.folders.indices.contains(row) else { return nil }
        return library.folders[row]
    }

    private func build() {
        let header = NSTextField(labelWithString: "常用文件夹")
        header.font = .systemFont(ofSize: 11, weight: .semibold)
        header.textColor = .secondaryLabelColor
        header.translatesAutoresizingMaskIntoConstraints = false

        tableView.headerView = nil
        tableView.style = .sourceList
        tableView.rowHeight = Metrics.rowHeight
        tableView.selectionHighlightStyle = .regular
        tableView.allowsEmptySelection = true
        tableView.allowsMultipleSelection = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.registerForDraggedTypes([Self.rowPasteboardType])
        tableView.setDraggingSourceOperationMask(.move, forLocal: true)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("folder"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        configureActionButton(addButton, symbol: "plus", action: #selector(addTapped))
        configureActionButton(removeButton, symbol: "minus", action: #selector(removeTapped))
        addButton.toolTip = "添加常用文件夹"
        removeButton.toolTip = "移除选中的入口"

        let buttonRow = NSStackView(views: [addButton, removeButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 4
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        addSubview(header)
        addSubview(scrollView)
        addSubview(separator)
        addSubview(buttonRow)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Metrics.width),

            header.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            header.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            scrollView.bottomAnchor.constraint(equalTo: separator.topAnchor, constant: -6),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: buttonRow.topAnchor, constant: -6),

            buttonRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            buttonRow.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            buttonRow.heightAnchor.constraint(equalToConstant: 28)
        ])

        updateRemoveButton()
    }

    private func configureActionButton(
        _ button: NSButton,
        symbol: String,
        action: Selector
    ) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        button.imagePosition = .imageOnly
        button.bezelStyle = .inline
        button.isBordered = false
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 28),
            button.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private func updateRemoveButton() {
        removeButton.isEnabled = selectedFolder() != nil
    }

    @objc private func addTapped() {
        onAddRequested?()
    }

    @objc private func removeTapped() {
        guard let folder = selectedFolder(),
              let index = library.folders.firstIndex(where: { $0.id == folder.id }) else {
            return
        }

        library.removeFolder(id: folder.id)
        tableView.reloadData()

        guard !library.folders.isEmpty else {
            updateRemoveButton()
            onSelectionChange?(nil)
            return
        }

        let next = min(index, library.folders.count - 1)
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        updateRemoveButton()
    }
}

extension SidebarView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        library.folders.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        guard library.folders.indices.contains(row) else { return nil }
        let folder = library.folders[row]

        let cell = tableView.makeView(withIdentifier: Self.cellIdentifier, owner: self)
            as? NSTableCellView ?? makeCell()

        cell.textField?.stringValue = folder.displayName
        cell.textField?.textColor = folder.isAvailable ? .labelColor : .secondaryLabelColor
        cell.imageView?.image = NSImage(
            systemSymbolName: folder.isAvailable ? "folder" : "exclamationmark.triangle",
            accessibilityDescription: folder.isAvailable ? "文件夹" : "入口失效"
        )
        cell.toolTip = folder.isAvailable ? nil : folder.status.localizedDescription
        return cell
    }

    private func makeCell() -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = Self.cellIdentifier

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.imageScaling = .scaleProportionallyDown
        icon.contentTintColor = .controlAccentColor

        let text = NSTextField(labelWithString: "")
        text.translatesAutoresizingMaskIntoConstraints = false
        text.font = .systemFont(ofSize: 13)
        text.lineBreakMode = .byTruncatingMiddle

        cell.addSubview(icon)
        cell.addSubview(text)
        cell.imageView = icon
        cell.textField = text

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),

            text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateRemoveButton()
        onSelectionChange?(selectedFolder())
    }

    func tableView(
        _ tableView: NSTableView,
        pasteboardWriterForRow row: Int
    ) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: Self.rowPasteboardType)
        return item
    }

    func tableView(
        _ tableView: NSTableView,
        validateDrop info: NSDraggingInfo,
        proposedRow row: Int,
        proposedDropOperation dropOperation: NSTableView.DropOperation
    ) -> NSDragOperation {
        dropOperation == .above ? .move : []
    }

    func tableView(
        _ tableView: NSTableView,
        acceptDrop info: NSDraggingInfo,
        row: Int,
        dropOperation: NSTableView.DropOperation
    ) -> Bool {
        guard let text = info.draggingPasteboard.string(forType: Self.rowPasteboardType),
              let source = Int(text) else {
            return false
        }

        let destination = row > source ? row - 1 : row
        library.moveFolder(from: source, to: destination)
        tableView.reloadData()

        if library.folders.indices.contains(destination) {
            select(id: library.folders[destination].id)
        } else {
            onSelectionChange?(selectedFolder())
        }

        return true
    }
}
