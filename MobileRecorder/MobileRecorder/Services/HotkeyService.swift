import Carbon
import AppKit

/// Global hotkey service using Carbon API (works even when app is not focused)
final class HotkeyService {
    private var hotkeyRef: EventHotKeyRef?
    private var onToggleRecording: (() -> Void)?
    private var onScreenshot: (() -> Void)?

    /// Register Cmd+Shift+R for toggle recording, Cmd+Shift+S for screenshot
    func register(onToggleRecording: @escaping () -> Void, onScreenshot: @escaping () -> Void) {
        self.onToggleRecording = onToggleRecording
        self.onScreenshot = onScreenshot

        // Install event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)

        // Cmd+Shift+R (keycode 15 = R)
        let hotkeyID1 = EventHotKeyID(signature: OSType(0x4D525231), id: 1) // "MRR1"
        var ref1: EventHotKeyRef?
        RegisterEventHotKey(UInt32(kVK_ANSI_R), UInt32(cmdKey | shiftKey), hotkeyID1, GetApplicationEventTarget(), 0, &ref1)

        // Cmd+Shift+S (keycode 1 = S)
        let hotkeyID2 = EventHotKeyID(signature: OSType(0x4D525232), id: 2) // "MRR2"
        var ref2: EventHotKeyRef?
        RegisterEventHotKey(UInt32(kVK_ANSI_S), UInt32(cmdKey | shiftKey), hotkeyID2, GetApplicationEventTarget(), 0, &ref2)
    }

    func handleHotKey(id: UInt32) {
        switch id {
        case 1: onToggleRecording?()
        case 2: onScreenshot?()
        default: break
        }
    }
}

/// C-function callback for Carbon event handler
private func hotKeyHandler(nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }

    var hotkeyID = EventHotKeyID()
    GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)

    let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
    service.handleHotKey(id: hotkeyID.id)

    return noErr
}
