import AppKit
import Carbon.HIToolbox
import FileDrawerCore

/// 全局快捷键：使用系统热键 API 注册，不请求辅助功能权限。
@MainActor
final class HotkeyCenter {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let onPressed: () -> Void

    init(onPressed: @escaping () -> Void) {
        self.onPressed = onPressed
    }

    /// 注册给定快捷键；`enabled` 为 false 时只注销当前热键。
    /// - Returns: 是否成功；失败通常意味着组合已被其他应用占用。
    @discardableResult
    func register(_ spec: HotkeySpec) -> Bool {
        unregister()

        guard spec.enabled else { return true }

        installHandlerIfNeeded()
        guard handlerRef != nil else { return false }

        let hotKeyID = EventHotKeyID(signature: OSType(0x46445257), id: 1) // "FDRW"
        var reference: EventHotKeyRef?

        let status = RegisterEventHotKey(
            spec.keyCode,
            spec.modifiers.rawValue,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )

        guard status == noErr, let reference else { return false }
        hotKeyRef = reference
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )

        if status != noErr {
            handlerRef = nil
        }
    }

    private func handlePressed() {
        onPressed()
    }

    /// Carbon 回调不带捕获上下文，通过 userData 取回实例。
    private static let callback: EventHandlerUPP = { _, _, userData in
        guard let userData else { return noErr }
        let center = Unmanaged<HotkeyCenter>
            .fromOpaque(userData)
            .takeUnretainedValue()

        MainActor.assumeIsolated {
            center.handlePressed()
        }
        return noErr
    }
}
