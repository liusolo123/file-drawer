import Foundation

/// 文件列表右键菜单里的动作。
public enum ContextMenuAction: String, CaseIterable, Sendable {
    case open
    case preview
    case revealInFinder
    case copyToClipboard
    case copyPath
}

/// 决定每个菜单项对给定项目是否可用。
public enum ContextMenuPolicy {
    /// 普通文件夹用「打开」进入，不支持 Quick Look 预览；
    /// 文件、包目录与符号链接可以预览。
    public static func isEnabled(
        _ action: ContextMenuAction,
        for entry: DirectoryEntry
    ) -> Bool {
        switch action {
        case .preview:
            return !entry.isBrowsable
        case .open, .revealInFinder, .copyToClipboard, .copyPath:
            return true
        }
    }
}
