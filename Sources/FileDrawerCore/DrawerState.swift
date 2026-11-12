import Foundation

/// 全局设置。
public struct DrawerSettings: Codable, Equatable, Sendable {
    /// 是否在列表与搜索中显示隐藏文件。默认关闭。
    public var showsHiddenFiles: Bool
    /// 面板的期望尺寸。屏幕放不下时只在显示时夹取。
    public var panelSize: PanelSize
    /// 全局快捷键配置。
    public var hotkey: HotkeySpec

    public init(
        showsHiddenFiles: Bool = false,
        panelSize: PanelSize = .default,
        hotkey: HotkeySpec = .default
    ) {
        self.showsHiddenFiles = showsHiddenFiles
        self.panelSize = panelSize
        self.hotkey = hotkey
    }

    public static let `default` = DrawerSettings()

    private enum CodingKeys: String, CodingKey {
        case showsHiddenFiles
        case panelSize
        case hotkey
    }

    /// 早期状态文件缺少新字段时按默认值处理。
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showsHiddenFiles = try container.decodeIfPresent(Bool.self, forKey: .showsHiddenFiles)
            ?? false
        panelSize = try container.decodeIfPresent(PanelSize.self, forKey: .panelSize)
            ?? .default
        hotkey = try container.decodeIfPresent(HotkeySpec.self, forKey: .hotkey)
            ?? .default
    }
}

/// 需要持久化的全部抽屉状态。
public struct DrawerState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    /// 顺序即侧栏顺序。
    public var folders: [CommonFolder]
    public var settings: DrawerSettings

    public init(
        schemaVersion: Int = DrawerState.currentSchemaVersion,
        folders: [CommonFolder] = [],
        settings: DrawerSettings = .default
    ) {
        self.schemaVersion = schemaVersion
        self.folders = folders
        self.settings = settings
    }

    public static let empty = DrawerState()

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case folders
        case settings
    }

    /// 早期状态文件没有 `settings`，按默认值处理。
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        folders = try container.decode([CommonFolder].self, forKey: .folders)
        settings = try container.decodeIfPresent(DrawerSettings.self, forKey: .settings)
            ?? .default
    }
}
