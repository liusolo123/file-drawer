import AppKit
import FileDrawerCore

/// 右侧内容：当前「浏览位置」的路径、返回与文件列表。
@MainActor
final class BrowserView: NSView {
    private enum Metrics {
        static let rowHeight: CGFloat = 28
        static let headerHeight: CGFloat = 26
    }

    private static let entryCellIdentifier = NSUserInterfaceItemIdentifier("EntryCell")

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private let library: FolderLibrary
    private let browser = DirectoryBrowser()
    private let searchEngine = SearchEngine()
    private let searchQueue = DispatchQueue(
        label: "com.liusolo.filedrawer.search",
        qos: .userInitiated
    )

    private let backButton = NSButton()
    private let pathLabel = NSTextField(labelWithString: "")
    private let searchField = NSSearchField()
    private let sortButton = NSPopUpButton()
    private let noticeLabel = NSTextField(labelWithString: "")
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let placeholder = NSTextField(wrappingLabelWithString: "")

    private var currentFolder: CommonFolder?
    private var currentURL: URL?
    private var entries: [DirectoryEntry] = []
    private var showsHiddenFiles = false

    private var searchDebounce: DispatchWorkItem?
    private var searchCancellation: SearchCancellation?
    private var searchGeneration = 0
    private var isShowingSearchResults = false
    private var searchMatches: [SearchMatch] = []

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

    /// 显示指定「常用文件夹」。会按记忆恢复「浏览位置」。
    func show(folder: CommonFolder) {
        resetSearchState()

        currentFolder = folder
        noticeLabel.isHidden = true
        selectSortItem(for: folder.sortRule)

        guard folder.status == .available else {
            presentMessage(folder.status.localizedDescription)
            updatePathLabel()
            return
        }

        guard let location = library.resolveBrowsingLocation(for: folder.id) else {
            presentMessage("无法解析这个文件夹的位置")
            updatePathLabel()
            return
        }

        currentURL = location.url
        updatePathLabel()
        loadEntries()

        if location.didFallBackToRoot {
            noticeLabel.stringValue = "原浏览位置已不存在，已回到根目录"
            noticeLabel.isHidden = false
        }
    }

    /// 外部状态变化后重新读取当前文件夹。
    func refresh() {
        guard let folder = currentFolder,
              let updated = library.folders.first(where: { $0.id == folder.id }) else {
            return
        }
        show(folder: updated)
    }

    /// 把键盘焦点放进搜索框。
    func focusSearchField() {
        guard let window else { return }
        window.makeFirstResponder(searchField)
    }

    /// 隐藏文件开关变化时刷新当前列表。
    func setShowsHiddenFiles(_ value: Bool) {
        guard showsHiddenFiles != value else { return }
        showsHiddenFiles = value

        if currentFolder != nil {
            refresh()
        }
    }

    // MARK: - 搜索

    /// 退出搜索状态，恢复普通目录列表由调用方负责。
    private func resetSearchState() {
        searchDebounce?.cancel()
        searchDebounce = nil
        searchCancellation?.cancel()
        searchCancellation = nil
        searchGeneration += 1
        isShowingSearchResults = false
        searchMatches = []

        if !searchField.stringValue.isEmpty {
            searchField.stringValue = ""
        }
    }

    private func scheduleSearch() {
        searchDebounce?.cancel()
        searchDebounce = nil
        searchCancellation?.cancel()
        searchCancellation = nil
        searchGeneration += 1

        let generation = searchGeneration
        let query = searchField.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            if let folder = currentFolderSnapshot() {
                show(folder: folder)
            }
            return
        }

        let work = DispatchWorkItem { [weak self] in
            self?.startSearch(query: query, generation: generation)
        }
        searchDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func startSearch(query: String, generation: Int) {
        guard let folder = currentFolderSnapshot(),
              let rootURL = library.resolvedURL(for: folder.id) else {
            return
        }

        let cancellation = SearchCancellation()
        searchCancellation = cancellation

        let rule = folder.sortRule
        let hidden = showsHiddenFiles

        entries = []
        searchMatches = []
        isShowingSearchResults = true
        tableView.reloadData()
        placeholder.stringValue = "搜索中…"
        placeholder.isHidden = false

        searchQueue.async { [weak self] in
            let matches = (try? SearchEngine().search(
                query: query,
                in: rootURL,
                sortRule: rule,
                showHiddenFiles: hidden,
                isCancelled: { cancellation.isCancelled }
            )) ?? []

            DispatchQueue.main.async {
                guard let self, self.searchGeneration == generation else { return }
                self.applySearchResults(matches)
            }
        }
    }

    private func applySearchResults(_ matches: [SearchMatch]) {
        searchMatches = matches
        entries = matches.map(\.entry)
        isShowingSearchResults = true
        tableView.reloadData()

        if matches.isEmpty {
            placeholder.stringValue = "没有匹配的项目"
            placeholder.isHidden = false
        } else {
            placeholder.isHidden = true
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    private func build() {
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        backButton.image = NSImage(
            systemSymbolName: "chevron.left",
            accessibilityDescription: "返回上一级"
        )?.withSymbolConfiguration(configuration)
        backButton.imagePosition = .imageOnly
        backButton.bezelStyle = .inline
        backButton.isBordered = false
        backButton.target = self
        backButton.action = #selector(goBack)
        backButton.toolTip = "返回上一级"
        backButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backButton.widthAnchor.constraint(equalToConstant: 30),
            backButton.heightAnchor.constraint(equalToConstant: 28)
        ])

        pathLabel.font = .systemFont(ofSize: 12, weight: .medium)
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let headerRow = NSStackView(views: [backButton, pathLabel, sortButton])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 6

        noticeLabel.font = .systemFont(ofSize: 11)
        noticeLabel.textColor = .secondaryLabelColor
        noticeLabel.isHidden = true

        searchField.placeholderString = "搜索当前常用文件夹"
        searchField.font = .systemFont(ofSize: 12)
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false

        sortButton.addItems(withTitles: [
            SortRule(key: .name, ascending: true).displayName,
            SortRule(key: .name, ascending: false).displayName,
            SortRule(key: .modified, ascending: true).displayName,
            SortRule(key: .modified, ascending: false).displayName
        ])
        sortButton.font = .systemFont(ofSize: 11)
        sortButton.bezelStyle = .inline
        sortButton.target = self
        sortButton.action = #selector(sortChanged)
        sortButton.translatesAutoresizingMaskIntoConstraints = false
        sortButton.setContentHuggingPriority(.required, for: .horizontal)
        sortButton.widthAnchor.constraint(equalToConstant: 108).isActive = true

        let header = NSStackView(views: [headerRow, searchField, noticeLabel])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 4
        header.translatesAutoresizingMaskIntoConstraints = false
        searchField.widthAnchor.constraint(equalTo: header.widthAnchor).isActive = true

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        configureTable()

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        placeholder.font = .systemFont(ofSize: 12)
        placeholder.textColor = .secondaryLabelColor
        placeholder.alignment = .center
        placeholder.isHidden = true
        placeholder.translatesAutoresizingMaskIntoConstraints = false

        addSubview(header)
        addSubview(divider)
        addSubview(scrollView)
        addSubview(placeholder)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            divider.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            scrollView.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),

            placeholder.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            placeholder.leadingAnchor.constraint(
                greaterThanOrEqualTo: scrollView.leadingAnchor,
                constant: 24
            ),
            placeholder.trailingAnchor.constraint(
                lessThanOrEqualTo: scrollView.trailingAnchor,
                constant: -24
            )
        ])
    }

    private func configureTable() {
        tableView.headerView = nil
        tableView.style = .fullWidth
        tableView.rowHeight = Metrics.rowHeight
        tableView.selectionHighlightStyle = .regular
        tableView.allowsMultipleSelection = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(openSelection)
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle

        // 单列承载「图标 + 名称 + 修改时间」，避免多列固定宽度在窄面板里被裁切。
        let entryColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("entry"))
        entryColumn.width = 400
        entryColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(entryColumn)
    }

    private func updatePathLabel() {
        guard let folder = currentFolder else {
            pathLabel.stringValue = ""
            return
        }

        let components = [folder.displayName] + library.browsingPath(for: folder.id)
        pathLabel.stringValue = components.joined(separator: "  /  ")
    }

    private func loadEntries() {
        guard let currentURL else { return }

        let rule = currentFolderSnapshot()?.sortRule ?? .default

        do {
            entries = try browser.contents(
                of: currentURL,
                sortRule: rule,
                showHiddenFiles: showsHiddenFiles
            )
            tableView.reloadData()
            placeholder.stringValue = "这个文件夹是空的"
            placeholder.isHidden = !entries.isEmpty
        } catch {
            presentMessage("无法读取内容：\(error.localizedDescription)")
        }

        if !entries.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    private func presentMessage(_ message: String) {
        entries = []
        tableView.reloadData()
        placeholder.stringValue = message
        placeholder.isHidden = false
    }

    private func currentFolderSnapshot() -> CommonFolder? {
        guard let currentFolder else { return nil }
        return library.folders.first(where: { $0.id == currentFolder.id }) ?? currentFolder
    }

    // MARK: - 排序

    private func selectSortItem(for rule: SortRule) {
        let index: Int

        switch (rule.key, rule.ascending) {
        case (.name, true):
            index = 0
        case (.name, false):
            index = 1
        case (.modified, true):
            index = 2
        case (.modified, false):
            index = 3
        }

        sortButton.selectItem(at: index)
    }

    @objc private func sortChanged() {
        guard let folder = currentFolderSnapshot() else { return }

        let rule: SortRule
        switch sortButton.indexOfSelectedItem {
        case 0:
            rule = SortRule(key: .name, ascending: true)
        case 1:
            rule = SortRule(key: .name, ascending: false)
        case 2:
            rule = SortRule(key: .modified, ascending: true)
        default:
            rule = SortRule(key: .modified, ascending: false)
        }

        library.setSortRule(rule, for: folder.id)
        show(folder: currentFolderSnapshot() ?? folder)
    }

    // MARK: - 导航

    @objc private func goBack() {
        guard let folder = currentFolderSnapshot() else { return }

        if isShowingSearchResults || !searchField.stringValue.isEmpty {
            show(folder: folder)
            return
        }

        var path = library.browsingPath(for: folder.id)
        guard !path.isEmpty else { return }

        path.removeLast()
        library.setBrowsingPath(path, for: folder.id)
        show(folder: currentFolderSnapshot() ?? folder)
    }

    @objc private func openSelection() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard entries.indices.contains(row),
              let folder = currentFolderSnapshot() else {
            return
        }

        let entry = entries[row]

        if isShowingSearchResults {
            openSearchResult(entry, folder: folder)
            return
        }

        if entry.isPackage {
            NSWorkspace.shared.open(entry.url)
            return
        }

        guard entry.isBrowsable else { return }

        var path = library.browsingPath(for: folder.id)
        path.append(entry.name)
        library.setBrowsingPath(path, for: folder.id)
        show(folder: currentFolderSnapshot() ?? folder)
    }

    /// 搜索结果里的文件夹：跳到它所在的位置并进入。
    private func openSearchResult(_ entry: DirectoryEntry, folder: CommonFolder) {
        if entry.isPackage {
            NSWorkspace.shared.open(entry.url)
            return
        }

        guard entry.isBrowsable,
              let match = searchMatches.first(where: { $0.entry.id == entry.id }) else {
            return
        }

        library.setBrowsingPath(match.relativePath + [entry.name], for: folder.id)
        show(folder: currentFolderSnapshot() ?? folder)
    }
}

extension BrowserView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        guard entries.indices.contains(row) else { return nil }
        let entry = entries[row]

        let cell = tableView.makeView(withIdentifier: Self.entryCellIdentifier, owner: self)
            as? EntryCellView ?? EntryCellView(identifier: Self.entryCellIdentifier)

        cell.nameLabel.stringValue = entry.name

        if isShowingSearchResults, searchMatches.indices.contains(row) {
            let match = searchMatches[row]
            cell.dateLabel.stringValue = match.relativePath.isEmpty
                ? "根目录"
                : match.relativePath.joined(separator: " / ")
            cell.dateLabel.lineBreakMode = .byTruncatingHead
            cell.toolTip = match.entry.url.path
        } else {
            cell.dateLabel.stringValue = entry.modifiedAt
                .map(Self.dateFormatter.string(from:)) ?? ""
            cell.dateLabel.lineBreakMode = .byTruncatingTail
            cell.toolTip = nil
        }

        cell.iconView.image = NSImage(
            systemSymbolName: symbolName(for: entry),
            accessibilityDescription: nil
        )
        cell.iconView.contentTintColor = entry.isBrowsable
            ? .controlAccentColor
            : .secondaryLabelColor
        return cell
    }

    private func symbolName(for entry: DirectoryEntry) -> String {
        if entry.isSymbolicLink { return "link" }
        if entry.isBrowsable { return "folder" }
        if entry.isPackage { return "shippingbox" }
        return "doc"
    }

}

/// 单列单元格：图标、名称、修改时间。名称可截断，时间固定贴右。
@MainActor
final class EntryCellView: NSTableCellView {
    let iconView = NSImageView()
    let nameLabel = NSTextField(labelWithString: "")
    let dateLabel = NSTextField(labelWithString: "")

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        build()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 13)
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = .systemFont(ofSize: 11)
        dateLabel.textColor = .secondaryLabelColor
        dateLabel.alignment = .right
        dateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        dateLabel.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(iconView)
        addSubview(nameLabel)
        addSubview(dateLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: dateLabel.leadingAnchor,
                constant: -10
            ),

            dateLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            dateLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

extension BrowserView: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard (obj.object as? NSSearchField) === searchField else { return }
        scheduleSearch()
    }
}
