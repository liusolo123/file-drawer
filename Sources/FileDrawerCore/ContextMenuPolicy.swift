import Foundation

/// 文件列表右键菜单里的动作。
public enum ContextMenuAction: String, CaseIterable, Sendable {
    case open
    case preview
    case revealInFinder
    case copyToClipboard
    case copyPath
}

/// 决定每个菜单项对当前选择是否可用。
public enum ContextMenuPolicy {
    /// 多选时只保留可批量执行的动作：
    /// 打开与预览需要单个项目，复制路径也只对单个项目有意义。
    public static func isEnabled(
        _ action: ContextMenuAction,
        for entries: [DirectoryEntry]
    ) -> Bool {
        switch action {
        case .open:
            return entries.count == 1
        case .preview:
            return entries.count == 1 && !entries[0].isBrowsable
        case .revealInFinder, .copyToClipboard:
            return !entries.isEmpty
        case .copyPath:
            return entries.count == 1
        }
    }

    public static func isEnabled(
        _ action: ContextMenuAction,
        for entry: DirectoryEntry
    ) -> Bool {
        isEnabled(action, for: [entry])
    }
}

/// 选择相关的纯规则，便于测试。
public enum SelectionPolicy {
    /// 右键点击某行后应保留的选择：
    /// 点在已选中的行上时保留当前多选，否则只选中该行。
    public static func rowsAfterContextClick(
        row: Int,
        currentSelection: Set<Int>
    ) -> Set<Int> {
        currentSelection.contains(row) ? currentSelection : [row]
    }
}
