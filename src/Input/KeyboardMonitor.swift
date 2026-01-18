import Cocoa
import Carbon

/// Monitors global keyboard events using CGEventTap
class KeyboardMonitor {
    static let shared = KeyboardMonitor()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    private let vimEngine = VimEngine.shared
    
    private init() {}
    
    // MARK: - Start/Stop
    
    func start() throws {
        guard eventTap == nil else { return }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        // Create event tap
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return KeyboardMonitor.shared.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: nil
        ) else {
            throw KeyboardMonitorError.failedToCreateEventTap
        }
        
        eventTap = tap
        
        // Create run loop source and add to current run loop
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        
        // Enable the tap
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
    }
    
    // MARK: - Event Handling
    
    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // Handle tap disabled events
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            print("[KB] ⚠️ Event tap was disabled, re-enabling...")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }
        
        // Check if Assula is disabled for the current app - pass all keys through
        if !AccessibilityService.shared.isEnabledForCurrentApp {
            return Unmanaged.passRetained(event)
        }
        
        // Check if we're in a text input field - if not, switch to insert mode and pass through
        // This allows Vimium and other browser extensions to work when not in a text field
        if !AccessibilityService.shared.isTextInputFocused() {
            print("[KB] Not in text field, passing through")
            if vimEngine.currentMode != .insert {
                vimEngine.setMode(.insert)
            }
            return Unmanaged.passRetained(event)
        }
        
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        
        // Convert to our KeyEvent type
        let keyEvent = createKeyEvent(keyCode: keyCode, flags: flags, event: event)
        
        print("[KB] Key captured: '\(keyEvent.key)' keyCode=\(keyCode)")
        
        // Let VimEngine decide if we should consume the event
        let consumed = vimEngine.handleKey(keyEvent)
        
        print("[KB] Consumed: \(consumed)")
        
        if consumed {
            return nil // Consume the event
        } else {
            return Unmanaged.passRetained(event) // Let it pass through
        }
    }
    
    private func createKeyEvent(keyCode: UInt16, flags: CGEventFlags, event: CGEvent) -> KeyEvent {
        var modifiers: KeyEvent.Modifiers = []
        
        if flags.contains(.maskShift) {
            modifiers.insert(.shift)
        }
        if flags.contains(.maskControl) {
            modifiers.insert(.control)
        }
        if flags.contains(.maskAlternate) {
            modifiers.insert(.option)
        }
        if flags.contains(.maskCommand) {
            modifiers.insert(.command)
        }
        
        // Get the character for this key
        let key = keyCodeToString(keyCode: keyCode, flags: flags, event: event)
        
        return KeyEvent(key: key, keyCode: keyCode, modifiers: modifiers)
    }
    
    private func keyCodeToString(keyCode: UInt16, flags: CGEventFlags, event: CGEvent) -> String {
        // Get the Unicode characters from the event
        var length: Int = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        
        if length > 0 {
            return String(utf16CodeUnits: chars, count: length)
        }
        
        // Fallback to key code mapping for special keys
        return keyCodeFallback(keyCode)
    }
    
    private func keyCodeFallback(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 36: return "return"
        case 48: return "tab"
        case 49: return "space"
        case 51: return "delete"
        case 53: return "escape"
        case 123: return "left"
        case 124: return "right"
        case 125: return "down"
        case 126: return "up"
        default: return ""
        }
    }
}

// MARK: - Errors

enum KeyboardMonitorError: Error {
    case failedToCreateEventTap
    case accessibilityNotGranted
}
