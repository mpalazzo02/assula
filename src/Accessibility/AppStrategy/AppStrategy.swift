import Foundation
import Cocoa

/// Protocol defining app-specific behavior for accessibility operations
protocol AppStrategy {
    /// The bundle identifiers this strategy handles
    static var bundleIdentifiers: [String] { get }
    
    /// Whether this app supports full accessibility text manipulation
    var supportsAccessibility: Bool { get }
    
    /// Whether this app needs special handling for certain operations
    var needsDelayAfterWrite: Bool { get }
    
    /// Delay in seconds after write operations (for apps that need it)
    var writeDelay: TimeInterval { get }
    
    /// Get the text content from the focused element
    func getText(from element: AXUIElement) -> String?
    
    /// Set the text content of the focused element
    func setText(_ text: String, in element: AXUIElement)
    
    /// Get the cursor position
    func getCursorPosition(from element: AXUIElement) -> Int?
    
    /// Set the cursor position
    func setCursorPosition(_ position: Int, in element: AXUIElement)
    
    /// Get the selected text range
    func getSelectedRange(from element: AXUIElement) -> CFRange?
    
    /// Set the selected text range
    func setSelectedRange(_ range: CFRange, in element: AXUIElement)
    
    /// Get the selected text
    func getSelectedText(from element: AXUIElement) -> String?
    
    /// Replace the selected text
    func setSelectedText(_ text: String, in element: AXUIElement)
    
    /// Perform undo operation
    func undo()
    
    /// Any setup needed when this app becomes active
    func onAppActivated()
    
    /// Any cleanup needed when leaving this app
    func onAppDeactivated()
}

/// Default implementations
extension AppStrategy {
    var needsDelayAfterWrite: Bool { false }
    var writeDelay: TimeInterval { 0 }
    
    func onAppActivated() {}
    func onAppDeactivated() {}
    
    func undo() {
        // Default: simulate Cmd+Z
        simulateKeyPress(keyCode: 6, modifiers: .maskCommand)
    }
    
    // MARK: - Default Accessibility Implementations
    
    func getText(from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        guard result == .success, let text = value as? String else { return nil }
        return text
    }
    
    func setText(_ text: String, in element: AXUIElement) {
        AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
    }
    
    func getCursorPosition(from element: AXUIElement) -> Int? {
        guard let range = getSelectedRange(from: element) else { return nil }
        return range.location
    }
    
    func setCursorPosition(_ position: Int, in element: AXUIElement) {
        setSelectedRange(CFRange(location: position, length: 0), in: element)
    }
    
    func getSelectedRange(from element: AXUIElement) -> CFRange? {
        var rangeValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue)
        guard result == .success, let value = rangeValue else { return nil }
        
        var range = CFRange()
        if AXValueGetValue(value as! AXValue, .cfRange, &range) {
            return range
        }
        return nil
    }
    
    func setSelectedRange(_ range: CFRange, in element: AXUIElement) {
        var mutableRange = range
        if let value = AXValueCreate(.cfRange, &mutableRange) {
            AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value)
        }
    }
    
    func getSelectedText(from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
        guard result == .success, let text = value as? String else { return nil }
        return text
    }
    
    func setSelectedText(_ text: String, in element: AXUIElement) {
        AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
    }
    
    // MARK: - Helper
    
    func simulateKeyPress(keyCode: CGKeyCode, modifiers: CGEventFlags) {
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
}
