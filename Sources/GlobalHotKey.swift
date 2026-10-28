// Floating Camera — MIT License. See LICENSE.

import Carbon.HIToolbox
import Foundation

private let floatingCameraHotKeySignature: OSType = 0x4643414D // "FCAM"
private let floatingCameraHotKeyID: UInt32 = 1

final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let callback: () -> Void

    init(callback: @escaping () -> Void) {
        self.callback = callback
    }

    deinit {
        unregister()
    }

    func register() {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        var handler: EventHandlerRef?

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return OSStatus(eventNotHandledErr)
                }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr,
                      hotKeyID.signature == floatingCameraHotKeySignature,
                      hotKeyID.id == floatingCameraHotKeyID
                else {
                    return OSStatus(eventNotHandledErr)
                }

                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    hotKey.callback()
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &handler
        )

        guard handlerStatus == noErr else {
            NSLog("Floating Camera: failed to install hot key handler (%d)", handlerStatus)
            return
        }
        eventHandlerRef = handler

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(
            signature: floatingCameraHotKeySignature,
            id: floatingCameraHotKeyID
        )
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_H),
            UInt32(controlKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard registerStatus == noErr else {
            NSLog("Floating Camera: failed to register hot key (%d)", registerStatus)
            unregister()
            return
        }
        hotKeyRef = ref
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        eventHandlerRef = nil
    }
}
