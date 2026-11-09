import AppKit
import FileDrawerCore

/// 抽屉内容：左侧常用文件夹，右侧当前浏览位置。
@MainActor
final class DrawerRootView: NSView {
    private let library: FolderLibrary
    private let sidebar: SidebarView
    private let browser: BrowserView
    private let contentHost = NSView()

    private let emptyStack = NSStackView()

    /// 打开系统文件面板等模态界面时通知外层暂停自动收起。
    var onModalStateChange: ((Bool) -> Void)?

    init(library: FolderLibrary) {
        self.library = library
        self.sidebar = SidebarView(library: library)
        self.browser = BrowserView(library: library)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        build()

        sidebar.onAddRequested = { [weak self] in self?.presentAddPanel() }
        sidebar.onSelectionChange = { [weak self] folder in self?.showDetail(folder) }

        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refresh() {
        sidebar.reload()

        guard !library.folders.isEmpty else {
            showEmptyState()
            return
        }

        if let selected = sidebar.selectedFolder() {
            showDetail(selected)
        } else if let first = library.folders.first {
            sidebar.select(id: first.id)
            showDetail(first)
        }
    }

    private func build() {
        contentHost.translatesAutoresizingMaskIntoConstraints = false

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        addSubview(sidebar)
        addSubview(divider)
        addSubview(contentHost)

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: bottomAnchor),

            divider.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            divider.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            divider.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            divider.widthAnchor.constraint(equalToConstant: 1),

            contentHost.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            contentHost.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentHost.topAnchor.constraint(equalTo: topAnchor),
            contentHost.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        browser.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(browser)
        NSLayoutConstraint.activate([
            browser.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
            browser.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
            browser.topAnchor.constraint(equalTo: contentHost.topAnchor),
            browser.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor)
        ])

        buildEmptyState()
        browser.isHidden = true
    }

    private func buildEmptyState() {
        let title = NSTextField(labelWithString: "还没有常用文件夹")
        title.font = .systemFont(ofSize: 16, weight: .semibold)

        let subtitle = NSTextField(
            wrappingLabelWithString: "添加日常最常用的文件夹，随时唤出抽屉取用文件。"
        )
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center

        let button = NSButton(
            title: "选择文件夹…",
            target: self,
            action: #selector(addFromEmptyState)
        )
        button.bezelStyle = .rounded

        emptyStack.orientation = .vertical
        emptyStack.alignment = .centerX
        emptyStack.spacing = 10
        emptyStack.translatesAutoresizingMaskIntoConstraints = false
        [title, subtitle, button].forEach { emptyStack.addArrangedSubview($0) }

        contentHost.addSubview(emptyStack)
        NSLayoutConstraint.activate([
            emptyStack.centerXAnchor.constraint(equalTo: contentHost.centerXAnchor),
            emptyStack.centerYAnchor.constraint(equalTo: contentHost.centerYAnchor),
            emptyStack.leadingAnchor.constraint(
                greaterThanOrEqualTo: contentHost.leadingAnchor,
                constant: 24
            ),
            emptyStack.trailingAnchor.constraint(
                lessThanOrEqualTo: contentHost.trailingAnchor,
                constant: -24
            )
        ])
    }

    private func showEmptyState() {
        emptyStack.isHidden = false
        browser.isHidden = true
    }

    private func showDetail(_ folder: CommonFolder?) {
        guard let folder else {
            emptyStack.isHidden = !library.folders.isEmpty
            browser.isHidden = true
            return
        }

        emptyStack.isHidden = true
        browser.isHidden = false
        browser.show(folder: folder)
    }

    // MARK: - 添加

    @objc private func addFromEmptyState() {
        presentAddPanel()
    }

    private func presentAddPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = "添加"
        panel.message = "选择要加入文件抽屉的文件夹"

        onModalStateChange?(true)
        NSApp.activate()

        panel.begin { [weak self] response in
            guard let self else { return }
            self.onModalStateChange?(false)
            guard response == .OK else { return }
            self.add(urls: panel.urls)
        }
    }

    private func add(urls: [URL]) {
        var firstError: Error?

        for url in urls {
            do {
                try library.addFolder(at: url)
            } catch {
                if firstError == nil {
                    firstError = error
                }
            }
        }

        refresh()

        if let firstError {
            presentAddError(firstError)
        }
    }

    private func presentAddError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "无法添加这个文件夹"
        if error as? FolderLibraryError == .notADirectory {
            alert.informativeText = "请选择一个文件夹，而不是文件。"
        } else {
            alert.informativeText = error.localizedDescription
        }
        alert.alertStyle = .warning
        alert.runModal()
    }
}
