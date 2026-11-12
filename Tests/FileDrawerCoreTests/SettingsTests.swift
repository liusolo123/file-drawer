import Testing
import Foundation
@testable import FileDrawerCore

@Suite("快捷键与设置")
struct SettingsTests {
    @Test("默认快捷键显示为 ⌃⌥F")
    func defaultHotkeyDisplay() {
        #expect(HotkeySpec.default.displayName == "⌃⌥F")
        #expect(HotkeySpec.default.enabled)
        #expect(HotkeySpec.default.hasPrimaryModifier)
    }

    @Test("禁用后显示「已禁用」")
    func disabledHotkeyDisplay() {
        var spec = HotkeySpec.default
        spec.enabled = false
        #expect(spec.displayName == "已禁用")
    }

    @Test("只有 Shift 不算主修饰键")
    func shiftOnlyIsRejected() {
        let spec = HotkeySpec(
            enabled: true,
            keyCode: 3,
            keyLabel: "F",
            modifiers: [.shift]
        )
        #expect(!spec.hasPrimaryModifier)
    }

    @Test("快捷键随状态文件往返")
    func hotkeyRoundTrip() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        let store = StateStore(directory: sandbox.root)
        var state = DrawerState()
        state.settings.hotkey = HotkeySpec(
            enabled: true,
            keyCode: 15,
            keyLabel: "R",
            modifiers: [.control, .shift]
        )
        try store.save(state)

        let loaded = try store.load()
        #expect(loaded.settings.hotkey == state.settings.hotkey)
        #expect(loaded.settings.hotkey.displayName == "⌃⇧R")
    }

    @Test("旧状态文件缺少 hotkey 时使用默认值")
    func legacyStateWithoutHotkey() throws {
        let json = """
        {
          "schemaVersion": 1,
          "folders": [],
          "settings": { "showsHiddenFiles": true }
        }
        """

        let state = try JSONDecoder().decode(DrawerState.self, from: Data(json.utf8))
        #expect(state.settings.showsHiddenFiles)
        #expect(state.settings.hotkey == .default)
    }

    @Test("目录不可写时保存失败")
    func saveToReadOnlyDirectoryThrows() throws {
        let sandbox = try TempSandbox()
        defer { sandbox.destroy() }

        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500],
            ofItemAtPath: sandbox.root.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: sandbox.root.path
            )
        }

        let store = StateStore(directory: sandbox.root)

        var didThrow = false
        do {
            try store.save(.empty)
        } catch {
            didThrow = true
        }

        #expect(didThrow)
    }
}
