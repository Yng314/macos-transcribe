import Carbon
import Foundation

enum HotKeyManagerError: LocalizedError {
    case eventHandlerInstallFailed(OSStatus)
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .eventHandlerInstallFailed(let status):
            return "InstallEventHandler failed with OSStatus \(status)"
        case .registrationFailed(let status):
            return "RegisterEventHotKey failed with OSStatus \(status)"
        }
    }
}

final class HotKeyManager: @unchecked Sendable {
    typealias Handler = () -> Void

    private static let hotKeySignature: OSType = 0x54524352 // TRCR
    private static let hotKeyID: UInt32 = 1
    private static let carbonCallback: EventHandlerUPP = { _, eventRef, userData in
        guard let eventRef, let userData else { return noErr }
        let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
        return manager.handle(eventRef: eventRef)
    }

    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var handler: Handler?

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping Handler) throws {
        unregister()

        self.handler = handler

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.carbonCallback,
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            throw HotKeyManagerError.eventHandlerInstallFailed(handlerStatus)
        }

        let hotKeyID = EventHotKeyID(signature: HotKeyManager.hotKeySignature, id: HotKeyManager.hotKeyID)
        let registrationStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registrationStatus == noErr else {
            unregister()
            throw HotKeyManagerError.registrationFailed(registrationStatus)
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        handler = nil
    }

    fileprivate func handle(eventRef: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else {
            return status
        }

        guard hotKeyID.signature == HotKeyManager.hotKeySignature, hotKeyID.id == HotKeyManager.hotKeyID else {
            return noErr
        }

        if let handler {
            DispatchQueue.main.async {
                handler()
            }
        }

        return noErr
    }
}
