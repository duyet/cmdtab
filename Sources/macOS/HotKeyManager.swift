import Carbon
import Foundation

public final class HotKeyManager {
    public static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    public var onHotKeyPressed: (() -> Void)?

    private init() {}

    public func registerGlobalHotKey() {
        // Unregister existing handlers to prevent double-registration
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            self.eventHandler = nil
        }
        if let hotKey = hotKeyRef {
            UnregisterEventHotKey(hotKey)
            self.hotKeyRef = nil
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.onHotKeyPressed?()
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandler
        )

        if installStatus != noErr {
            print("Warning: Failed to install Carbon event handler. Status: \(installStatus)")
        }

        // "Cmtb" in hex is 0x436d7462
        let hotKeyID = EventHotKeyID(signature: OSType(0x436d7462), id: 1)

        // Register Option + Space (Keycode 49, Option modifier)
        let registerStatus = RegisterEventHotKey(
            49,  // Spacebar keycode
            UInt32(optionKey),  // Option modifier mask
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus != noErr {
            print("Warning: Failed to register global Carbon hotkey. Status: \(registerStatus)")
        }
    }
}
