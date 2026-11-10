import AppKit
import Carbon.HIToolbox

/// 全局快捷键：使用系统热键 API 注册，不请求辅助功能权限。
@MainActor
final class HotkeyCenter {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let onPressed: () -> Void

    init(onPressed: @escaping () -> Void) {
        self.onPressed = onPressed
    }

    /// 注册默认快捷键 Control + Option + F。
    /// - Returns: 是否注册成功；失败通常意味着组合已被其他应用占用。
    @discardableResult
    func registerDefault() -> Bool {
        installHandlerIfNeeded()
        guard handlerRef != nil else { return false }

        let hotKeyID = EventHotKeyID(signature: OSType(0x46445257), id: 1) // "FDRW"
        var reference: EventHotKeyRef?

        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_F),
            UInt32(controlKey | optionKey),
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
