import Foundation
import Cocoa

/// Default strategy for native macOS apps with good accessibility support
class DefaultStrategy: AppStrategy {
    static var bundleIdentifiers: [String] { [] } // Fallback for unknown apps
    
    var supportsAccessibility: Bool { true }
    var needsDelayAfterWrite: Bool { false }
    var writeDelay: TimeInterval { 0 }
}

/// Strategy for apps that don't support accessibility - uses key simulation
class FallbackStrategy: AppStrategy {
    static var bundleIdentifiers: [String] { [] }
    
    var supportsAccessibility: Bool { false }
    var needsDelayAfterWrite: Bool { false }
    var writeDelay: TimeInterval { 0 }
    
    func getText(from element: AXUIElement) -> String? {
        // Can't read text in fallback mode
        return nil
    }
    
    func setText(_ text: String, in element: AXUIElement) {
        // Can't set text directly - would need to select all and type
    }
    
    func getCursorPosition(from element: AXUIElement) -> Int? {
        return nil
    }
    
    func setCursorPosition(_ position: Int, in element: AXUIElement) {
        // Can't set cursor position
    }
    
    func getSelectedRange(from element: AXUIElement) -> CFRange? {
        return nil
    }
    
    func setSelectedRange(_ range: CFRange, in element: AXUIElement) {
        // Can't set selection range
    }
    
    func getSelectedText(from element: AXUIElement) -> String? {
        return nil
    }
    
    func setSelectedText(_ text: String, in element: AXUIElement) {
        // Type the text character by character
        typeText(text)
    }
    
    // MARK: - Key Simulation for Fallback Mode
    
    private func typeText(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        for char in text {
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
    
    /// Simulates cursor movement using arrow keys
    func moveCursor(direction: CursorDirection, count: Int = 1) {
        let keyCode: CGKeyCode
        switch direction {
        case .left: keyCode = 123
        case .right: keyCode = 124
        case .up: keyCode = 126
        case .down: keyCode = 125
        }
        
        for _ in 0..<count {
            simulateKeyPress(keyCode: keyCode, modifiers: [])
        }
    }
    
    /// Simulates word movement using Option+Arrow
    func moveWord(forward: Bool, count: Int = 1) {
        let keyCode: CGKeyCode = forward ? 124 : 123
        for _ in 0..<count {
            simulateKeyPress(keyCode: keyCode, modifiers: .maskAlternate)
        }
    }
    
    /// Simulates line start/end movement using Cmd+Arrow
    func moveLine(toEnd: Bool) {
        let keyCode: CGKeyCode = toEnd ? 124 : 123
        simulateKeyPress(keyCode: keyCode, modifiers: .maskCommand)
    }
    
    /// Simulates deletion
    func deleteCharacter(forward: Bool = false) {
        if forward {
            // Fn+Delete or just Delete on full keyboards
            simulateKeyPress(keyCode: 117, modifiers: [])
        } else {
            simulateKeyPress(keyCode: 51, modifiers: [])
        }
    }
    
    /// Simulates word deletion
    func deleteWord(forward: Bool = false) {
        if forward {
            simulateKeyPress(keyCode: 117, modifiers: .maskAlternate)
        } else {
            simulateKeyPress(keyCode: 51, modifiers: .maskAlternate)
        }
    }
    
    enum CursorDirection {
        case left, right, up, down
    }
}
