import Foundation

/// Carbon 全局热键修饰键的位值。与 `RegisterEventHotKey` 使用的值一致。
public struct HotkeyModifiers: OptionSet, Codable, Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let command = HotkeyModifiers(rawValue: 1 << 8)
    public static let shift = HotkeyModifiers(rawValue: 1 << 9)
    public static let option = HotkeyModifiers(rawValue: 1 << 11)
    public static let control = HotkeyModifiers(rawValue: 1 << 12)
}

/// 全局快捷键配置。
public struct HotkeySpec: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var keyCode: UInt32
    public var keyLabel: String
    public var modifiers: HotkeyModifiers

    /// 默认 Control + Option + F（Carbon keyCode 3）。
    public static let `default` = HotkeySpec(
        enabled: true,
        keyCode: 3,
        keyLabel: "F",
        modifiers: [.control, .option]
    )

    public init(
        enabled: Bool,
        keyCode: UInt32,
        keyLabel: String,
        modifiers: HotkeyModifiers
    ) {
        self.enabled = enabled
        self.keyCode = keyCode
        self.keyLabel = keyLabel
        self.modifiers = modifiers
    }

    public var displayName: String {
        guard enabled else { return "已禁用" }

        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + keyLabel
    }

    /// 至少包含 Control / Option / Command 之一，避免只用单键做全局热键。
    public var hasPrimaryModifier: Bool {
        !modifiers.intersection([.control, .option, .command]).isEmpty
    }

    /// 把 Carbon keyCode 转成可读标签。
    public static func keyLabel(for keyCode: UInt32) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 25: return "9"
        case 26: return "7"
        case 28: return "8"
        case 29: return "0"
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 45: return "N"
        case 46: return "M"
        case 48: return "Tab"
        case 49: return "Space"
        case 36: return "Return"
        case 51: return "Delete"
        case 53: return "Esc"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 109: return "F10"
        case 111: return "F12"
        case 118: return "F4"
        case 120: return "F2"
        case 122: return "F1"
        default: return "键\(keyCode)"
        }
    }
}
