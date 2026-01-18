import Cocoa
import ApplicationServices

/// Service for interacting with accessible elements in other applications
class AccessibilityService {
    static let shared = AccessibilityService()
    
    private let strategyManager = StrategyManager.shared
    private let config = ConfigManager.shared
    
    private init() {}
    
    // MARK: - App Context
    
    /// Returns the current app strategy
    var currentStrategy: AppStrategy {
        strategyManager.currentStrategy
    }
    
    /// Returns whether the current app supports accessibility
    var currentAppSupportsAccessibility: Bool {
        strategyManager.currentAppSupportsAccessibility
    }
    
    /// Returns whether Assula should be enabled for the current app
    var isEnabledForCurrentApp: Bool {
        guard let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return true
        }
        
        // Check if app is in ignored list
        if config.config.ignoredApps.contains(bundleId) {
            return false
        }
        
        return true
    }
    
    // MARK: - Focused Element
    
    /// Gets the currently focused UI element
    func getFocusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        guard result == .success, let element = focusedElement else {
            return nil
        }
        
        // Debug: print element info
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element as! AXUIElement, kAXRoleAttribute as CFString, &role)
        var roleDesc: CFTypeRef?
        AXUIElementCopyAttributeValue(element as! AXUIElement, kAXRoleDescriptionAttribute as CFString, &roleDesc)
        print("[AX] Focused element - Role: \(role ?? "nil" as CFString), Desc: \(roleDesc ?? "nil" as CFString)")
        
        return (element as! AXUIElement)
    }
    
    /// Gets the currently focused application
    func getFocusedApp() -> NSRunningApplication? {
        return NSWorkspace.shared.frontmostApplication
    }
    
    // MARK: - Text Reading
    
    /// Gets the full text content of the focused element
    func getText() -> String? {
        guard let element = getFocusedElement() else {
            print("[AX] getText: No focused element")
            return nil
        }
        
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        
        guard result == .success, let text = value as? String else {
            print("[AX] getText: Failed to get AXValue, result: \(result.rawValue)")
            return nil
        }
        
        print("[AX] getText: Got \(text.count) chars")
        return text
    }
    
    /// Gets the selected text in the focused element
    func getSelectedText() -> String? {
        guard let element = getFocusedElement() else { return nil }
        
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
        
        guard result == .success, let text = value as? String else {
            return nil
        }
        
        return text
    }
    
    /// Gets the current cursor position
    func getCursorPosition() -> Int? {
        guard let element = getFocusedElement() else { return nil }
        
        var rangeValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue)
        
        guard result == .success, let value = rangeValue else {
            return nil
        }
        
        var range = CFRange()
        if AXValueGetValue(value as! AXValue, .cfRange, &range) {
            return range.location
        }
        
        return nil
    }
    
    /// Gets the selected range
    func getSelectedRange() -> CFRange? {
        guard let element = getFocusedElement() else { return nil }
        
        var rangeValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue)
        
        guard result == .success, let value = rangeValue else {
            return nil
        }
        
        var range = CFRange()
        if AXValueGetValue(value as! AXValue, .cfRange, &range) {
            return range
        }
        
        return nil
    }
    
    // MARK: - Text Writing
    
    /// Sets the text content of the focused element
    func setText(_ text: String) {
        guard let element = getFocusedElement() else { return }
        
        AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
    }
    
    /// Sets the selected text (replaces current selection)
    func setSelectedText(_ text: String) {
        guard let element = getFocusedElement() else { return }
        
        AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
    }
    
    /// Sets the cursor position
    func setCursorPosition(_ position: Int) {
        guard let element = getFocusedElement() else { return }
        
        var range = CFRange(location: position, length: 0)
        if let value = AXValueCreate(.cfRange, &range) {
            AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value)
        }
    }
    
    /// Sets the selected range
    func setSelectedRange(_ range: CFRange) {
        guard let element = getFocusedElement() else { return }
        
        var mutableRange = range
        if let value = AXValueCreate(.cfRange, &mutableRange) {
            AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value)
        }
    }
    
    /// Inserts text at the current cursor position
    func insertText(_ text: String) {
        setSelectedText(text)
    }
    
    // MARK: - Cursor Movement
    
    /// Moves the cursor using a motion
    func moveCursor(_ motion: Motion, count: Int = 1) {
        guard let text = getText(), let position = getCursorPosition() else { return }
        
        let executor = getExecutor(for: motion)
        let newPosition = executor.execute(from: position, in: text, count: count)
        setCursorPosition(newPosition)
    }
    
    /// Extends the selection using a motion (for visual mode)
    func extendSelection(_ motion: Motion, count: Int = 1) {
        guard let text = getText(), let range = getSelectedRange() else { return }
        
        let executor = getExecutor(for: motion)
        let cursorPosition = range.location + range.length
        let newPosition = executor.execute(from: cursorPosition, in: text, count: count)
        
        let newRange = CFRange(
            location: range.location,
            length: newPosition - range.location
        )
        setSelectedRange(newRange)
    }
    
    // MARK: - Deletion
    
    /// Deletes text covered by a motion
    func deleteWithMotion(_ motion: Motion, count: Int = 1) {
        guard let text = getText(), let position = getCursorPosition() else { return }
        
        let executor = getExecutor(for: motion)
        let range = executor.getRange(from: position, in: text, count: count)
        
        // Select the range and delete
        setSelectedRange(CFRange(location: range.lowerBound, length: range.count))
        setSelectedText("")
    }
    
    /// Deletes the current selection
    func deleteSelection() {
        setSelectedText("")
    }
    
    /// Deletes one character backward (backspace)
    func deleteBackward() {
        // Use Command+Delete simulation or manipulate text directly
        guard let text = getText(), let position = getCursorPosition(), position > 0 else { return }
        
        setSelectedRange(CFRange(location: position - 1, length: 1))
        setSelectedText("")
    }
    
    /// Deletes entire lines
    func deleteLines(count: Int = 1) {
        guard let text = getText(), let position = getCursorPosition() else { return }
        
        let executor = LineMotionExecutor(motion: .lineStart)
        let lineStart = executor.execute(from: position, in: text, count: 1)
        
        // Find end of the last line to delete
        var lineEnd = lineStart
        var linesFound = 0
        let chars = Array(text)
        
        while lineEnd < chars.count && linesFound < count {
            if chars[lineEnd] == "\n" {
                linesFound += 1
            }
            lineEnd += 1
        }
        
        setSelectedRange(CFRange(location: lineStart, length: lineEnd - lineStart))
        setSelectedText("")
    }
    
    // MARK: - Text Retrieval for Operations
    
    /// Gets text that would be affected by a motion
    func getTextForMotion(_ motion: Motion, count: Int = 1) -> String? {
        guard let text = getText(), let position = getCursorPosition() else { return nil }
        
        let executor = getExecutor(for: motion)
        let range = executor.getRange(from: position, in: text, count: count)
        
        let startIndex = text.index(text.startIndex, offsetBy: range.lowerBound)
        let endIndex = text.index(text.startIndex, offsetBy: min(range.upperBound, text.count))
        
        return String(text[startIndex..<endIndex])
    }
    
    /// Gets the current line(s)
    func getCurrentLines(count: Int = 1) -> String? {
        guard let text = getText(), let position = getCursorPosition() else { return nil }
        
        let executor = LineMotionExecutor(motion: .lineStart)
        let lineStart = executor.execute(from: position, in: text, count: 1)
        
        var lineEnd = lineStart
        var linesFound = 0
        let chars = Array(text)
        
        while lineEnd < chars.count && linesFound < count {
            if chars[lineEnd] == "\n" {
                linesFound += 1
            }
            lineEnd += 1
        }
        
        let startIndex = text.index(text.startIndex, offsetBy: lineStart)
        let endIndex = text.index(text.startIndex, offsetBy: min(lineEnd, text.count))
        
        return String(text[startIndex..<endIndex])
    }
    
    // MARK: - Undo
    
    func undo() {
        // Simulate Cmd+Z
        simulateKeyPress(keyCode: 6, modifiers: .maskCommand)
    }
    
    // MARK: - Helpers
    
    private func getExecutor(for motion: Motion) -> MotionExecutor {
        switch motion {
        case .left, .right, .up, .down:
            return CharacterMotionExecutor(motion: motion)
        case .wordForward, .wordBackward, .wordEnd, .wordForwardBig, .wordBackwardBig, .wordEndBig:
            return WordMotionExecutor(motion: motion)
        case .lineStart, .lineEnd, .firstNonBlank, .documentStart, .documentEnd:
            return LineMotionExecutor(motion: motion)
        case .findChar:
            // TODO: Implement find motion executor
            return CharacterMotionExecutor(motion: .right)
        }
    }
    
    func simulateKeyPress(keyCode: CGKeyCode, modifiers: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
            keyDown.flags = modifiers
            keyDown.post(tap: .cghidEventTap)
        }
        
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            keyUp.flags = modifiers
            keyUp.post(tap: .cghidEventTap)
        }
    }
    
    // MARK: - Fallback Mode (Keyboard Simulation)
    
    /// Bundle IDs of apps that should always use fallback mode for text manipulation
    /// These are apps where accessibility APIs (setSelectedRange, setSelectedText) don't work reliably
    private static let fallbackModeApps: Set<String> = [
        "org.mozilla.firefox",           // Firefox
        "org.mozilla.firefoxdeveloperedition",
        "org.mozilla.nightly",
        "com.google.Chrome",             // Chrome
        "com.google.Chrome.canary",
        "com.brave.Browser",             // Brave
        "com.microsoft.edgemac",         // Edge
        "com.operasoftware.Opera",       // Opera
        "com.vivaldi.Vivaldi",           // Vivaldi
        "company.thebrowser.Browser",    // Arc
    ]
    
    /// Check if current element needs fallback mode (keyboard simulation instead of accessibility APIs)
    /// Returns true for:
    /// - WebArea elements (contenteditable, web-based text fields)
    /// - Browser apps where accessibility text manipulation doesn't work reliably
    func needsFallbackMode() -> Bool {
        guard let element = getFocusedElement() else { 
            print("[AX] needsFallbackMode: no focused element, returning true")
            return true 
        }
        
        // Check if current app is a browser that needs fallback mode
        if let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
            if AccessibilityService.fallbackModeApps.contains(bundleId) {
                print("[AX] needsFallbackMode: returning TRUE (browser app: \(bundleId))")
                return true
            }
        }
        
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        if let roleStr = role as? String {
            print("[AX] needsFallbackMode: role=\(roleStr)")
            if roleStr == "AXWebArea" {
                print("[AX] needsFallbackMode: returning TRUE (WebArea)")
                return true
            }
        }
        print("[AX] needsFallbackMode: returning false")
        return false
    }
    
    /// Simulate cursor movement using arrow keys (fallback for WebAreas)
    /// Emulates Vim behavior:
    ///   w = start of next word
    ///   e = end of current/next word
    ///   b = start of previous word
    func simulateMotion(_ motion: Motion, count: Int = 1) {
        for _ in 0..<count {
            switch motion {
            case .left:
                simulateKeyPress(keyCode: 123) // Left arrow
            case .right:
                simulateKeyPress(keyCode: 124) // Right arrow
            case .up:
                simulateKeyPress(keyCode: 126) // Up arrow
            case .down:
                simulateKeyPress(keyCode: 125) // Down arrow
            case .wordForward, .wordForwardBig:
                // w = start of next word
                // macOS: Option+Right goes to end of word
                // To get to START of next word: Option+Right, then Option+Right again
                // But that overshoots. Instead: Option+Right (end of word), then move right past space
                // Actually in macOS, Option+Right from middle of word goes to END of that word
                // Then Option+Right again goes to END of next word
                // We want START of next word, so: Option+Right (to end), Right (skip one char into next word territory)
                // But that's not quite right either...
                // 
                // Better approach: Select word forward then collapse selection to end
                // Simplest: just use Option+Right once - it gets us close enough
                // For true vim 'w': Option+Right moves to word boundary, if at start of word it goes to end
                // Let's do: Right first (to get off start of word if we're there), then Option+Right
                simulateKeyPress(keyCode: 124) // Right (move off potential word start)
                simulateKeyPress(keyCode: 124, modifiers: .maskAlternate) // Option+Right (to end of word/start of next)
            case .wordEnd, .wordEndBig:
                // e = end of current/next word
                simulateKeyPress(keyCode: 124, modifiers: .maskAlternate) // Option+Right
            case .wordBackward, .wordBackwardBig:
                // b = start of previous word
                simulateKeyPress(keyCode: 123, modifiers: .maskAlternate) // Option+Left
            case .lineStart, .firstNonBlank:
                simulateKeyPress(keyCode: 123, modifiers: .maskCommand) // Cmd+Left
            case .lineEnd:
                simulateKeyPress(keyCode: 124, modifiers: .maskCommand) // Cmd+Right
            case .documentStart:
                simulateKeyPress(keyCode: 126, modifiers: .maskCommand) // Cmd+Up
            case .documentEnd:
                simulateKeyPress(keyCode: 125, modifiers: .maskCommand) // Cmd+Down
            default:
                print("[AX] simulateMotion: unhandled motion \(motion)")
                return
            }
        }
    }
    
    /// Simulate delete using backspace (fallback for WebAreas)
    func simulateDelete(count: Int = 1) {
        print("[AX] simulateDelete called with count=\(count)")
        for i in 0..<count {
            print("[AX] simulateDelete: pressing backspace \(i+1)/\(count)")
            simulateKeyPress(keyCode: 51) // Backspace
        }
        print("[AX] simulateDelete done")
    }
    
    /// Simulate selection with shift+arrow (fallback for WebAreas)
    /// Emulates Vim selection behavior for operators like dw, cw, etc.
    func simulateSelect(_ motion: Motion, count: Int = 1) {
        for _ in 0..<count {
            switch motion {
            case .left:
                simulateKeyPress(keyCode: 123, modifiers: .maskShift)
            case .right:
                simulateKeyPress(keyCode: 124, modifiers: .maskShift)
            case .up:
                simulateKeyPress(keyCode: 126, modifiers: .maskShift)
            case .down:
                simulateKeyPress(keyCode: 125, modifiers: .maskShift)
            case .wordForward, .wordForwardBig:
                // Select to start of next word (like dw in Vim)
                simulateKeyPress(keyCode: 124, modifiers: [.maskShift, .maskAlternate]) // Shift+Option+Right
                simulateKeyPress(keyCode: 124, modifiers: [.maskShift, .maskAlternate]) // Again to get past whitespace
            case .wordEnd, .wordEndBig:
                // Select to end of word (like de in Vim)
                simulateKeyPress(keyCode: 124, modifiers: [.maskShift, .maskAlternate])
            case .wordBackward, .wordBackwardBig:
                // Select to start of previous word
                simulateKeyPress(keyCode: 123, modifiers: [.maskShift, .maskAlternate])
            case .lineStart, .firstNonBlank:
                simulateKeyPress(keyCode: 123, modifiers: [.maskShift, .maskCommand])
            case .lineEnd:
                simulateKeyPress(keyCode: 124, modifiers: [.maskShift, .maskCommand])
            default:
                print("[AX] simulateSelect: unhandled motion \(motion)")
                return
            }
        }
    }
    
    /// Simulate delete with motion (select then delete) - fallback for WebAreas
    func simulateDeleteWithMotion(_ motion: Motion, count: Int = 1) {
        simulateSelect(motion, count: count)
        simulateDelete()
    }
    
    /// Simulate delete entire line (Cmd+Shift+K or select line + delete) - fallback for WebAreas
    func simulateDeleteLine(count: Int = 1) {
        for _ in 0..<count {
            // Move to line start
            simulateKeyPress(keyCode: 123, modifiers: .maskCommand) // Cmd+Left
            // Select to line end
            simulateKeyPress(keyCode: 124, modifiers: [.maskCommand, .maskShift]) // Cmd+Shift+Right
            // Also select the newline if present (Shift+Right)
            simulateKeyPress(keyCode: 124, modifiers: .maskShift)
            // Delete
            simulateDelete()
        }
    }
    
    /// Simulate selecting inner word (for ciw, diw, etc.) - fallback for WebAreas
    /// Use double-click to select word - most reliable method in macOS
    func simulateSelectInnerWord() {
        simulateDoubleClick()
        // Small delay to let selection complete before any subsequent delete
        usleep(50000) // 50ms
    }
    
    /// Simulate a double-click at current cursor position to select word
    private func simulateDoubleClick() {
        // Get current mouse position (we'll click in place, text cursor stays where it is)
        let mouseLocation = NSEvent.mouseLocation
        
        // Convert to screen coordinates (flip Y for CG)
        guard let screen = NSScreen.main else { return }
        let screenHeight = screen.frame.height
        let cgPoint = CGPoint(x: mouseLocation.x, y: screenHeight - mouseLocation.y)
        
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Double click
        if let mouseDown1 = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: cgPoint, mouseButton: .left) {
            mouseDown1.setIntegerValueField(.mouseEventClickState, value: 1)
            mouseDown1.post(tap: .cghidEventTap)
        }
        if let mouseUp1 = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: cgPoint, mouseButton: .left) {
            mouseUp1.setIntegerValueField(.mouseEventClickState, value: 1)
            mouseUp1.post(tap: .cghidEventTap)
        }
        if let mouseDown2 = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: cgPoint, mouseButton: .left) {
            mouseDown2.setIntegerValueField(.mouseEventClickState, value: 2)
            mouseDown2.post(tap: .cghidEventTap)
        }
        if let mouseUp2 = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: cgPoint, mouseButton: .left) {
            mouseUp2.setIntegerValueField(.mouseEventClickState, value: 2)
            mouseUp2.post(tap: .cghidEventTap)
        }
    }
    
    /// Simulate selecting around word including trailing space (for caw, daw) - fallback for WebAreas
    func simulateSelectAroundWord() {
        // Move to start of current word
        simulateKeyPress(keyCode: 123, modifiers: .maskAlternate) // Option+Left
        // Select to end of word
        simulateKeyPress(keyCode: 124, modifiers: [.maskShift, .maskAlternate]) // Shift+Option+Right
        // Select trailing space(s)
        simulateKeyPress(keyCode: 124, modifiers: .maskShift) // Shift+Right for one space
    }
    
    /// Simulate selecting to end of line (for c$, d$, C, D) - fallback for WebAreas
    func simulateSelectToEndOfLine() {
        simulateKeyPress(keyCode: 124, modifiers: [.maskShift, .maskCommand]) // Shift+Cmd+Right
    }
    
    /// Simulate selecting to start of line (for c0, d0) - fallback for WebAreas
    func simulateSelectToStartOfLine() {
        simulateKeyPress(keyCode: 123, modifiers: [.maskShift, .maskCommand]) // Shift+Cmd+Left
    }
    
    /// Simulate typing a character - fallback for WebAreas
    func simulateType(_ text: String) {
        for char in text {
            if char == "\n" {
                simulateKeyPress(keyCode: 36) // Return
            } else {
                // Use CGEvent to type the character
                let source = CGEventSource(stateID: .hidSystemState)
                if let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                    var chars = [UniChar](String(char).utf16)
                    event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
                    event.post(tap: .cghidEventTap)
                }
                if let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                    event.post(tap: .cghidEventTap)
                }
            }
        }
    }
    
    /// Simulate copy (Cmd+C) - fallback for WebAreas
    func simulateCopy() {
        simulateKeyPress(keyCode: 8, modifiers: .maskCommand) // Cmd+C
    }
    
    /// Simulate paste (Cmd+V) - fallback for WebAreas
    func simulatePaste() {
        simulateKeyPress(keyCode: 9, modifiers: .maskCommand) // Cmd+V
    }
    
    /// Simulate cut (Cmd+X) - fallback for WebAreas
    func simulateCut() {
        simulateKeyPress(keyCode: 7, modifiers: .maskCommand) // Cmd+X
    }
    
    /// Simulate select all (Cmd+A) - fallback for WebAreas
    func simulateSelectAll() {
        simulateKeyPress(keyCode: 0, modifiers: .maskCommand) // Cmd+A
    }
}
