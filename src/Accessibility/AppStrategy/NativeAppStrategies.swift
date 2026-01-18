import Foundation
import Cocoa

/// Strategy for Apple Mail
class MailStrategy: AppStrategy {
    static var bundleIdentifiers: [String] { ["com.apple.mail"] }
    
    var supportsAccessibility: Bool { true }
    var needsDelayAfterWrite: Bool { false }
    var writeDelay: TimeInterval { 0 }
    
    // Mail has excellent accessibility support as a native app
    // Uses default implementations
}

/// Strategy for Apple Notes
class NotesStrategy: AppStrategy {
    static var bundleIdentifiers: [String] { ["com.apple.Notes"] }
    
    var supportsAccessibility: Bool { true }
    var needsDelayAfterWrite: Bool { false }
    var writeDelay: TimeInterval { 0 }
    
    // Notes has excellent accessibility support
}

/// Strategy for TextEdit
class TextEditStrategy: AppStrategy {
    static var bundleIdentifiers: [String] { ["com.apple.TextEdit"] }
    
    var supportsAccessibility: Bool { true }
    var needsDelayAfterWrite: Bool { false }
    var writeDelay: TimeInterval { 0 }
    
    // TextEdit has excellent accessibility support
}

/// Strategy for Xcode
class XcodeStrategy: AppStrategy {
    static var bundleIdentifiers: [String] { ["com.apple.dt.Xcode"] }
    
    var supportsAccessibility: Bool { true }
    var needsDelayAfterWrite: Bool { true }
    var writeDelay: TimeInterval { 0.02 } // Xcode can be slow with large files
    
    // Xcode has good accessibility but can be slow
    // Note: Many Xcode users may prefer native Vim mode extension instead
}

/// Strategy for VS Code
class VSCodeStrategy: AppStrategy {
    static var bundleIdentifiers: [String] { 
        ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.vscodium.codium"]
    }
    
    var supportsAccessibility: Bool { true }
    var needsDelayAfterWrite: Bool { true }
    var writeDelay: TimeInterval { 0.05 }
    
    // VS Code (Electron) has accessibility but it's not always reliable
    // Many users may prefer the built-in Vim extension
    
    func getText(from element: AXUIElement) -> String? {
        // VS Code uses AXValue for the editor content
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        
        if result == .success, let text = value as? String {
            return text
        }
        
        return nil
    }
}

/// Strategy for Terminal
class TerminalStrategy: AppStrategy {
    static var bundleIdentifiers: [String] { 
        ["com.apple.Terminal", "com.googlecode.iterm2", "io.alacritty", "com.mitchellh.ghostty"]
    }
    
    // Terminal apps handle their own Vim - we should be minimal here
    var supportsAccessibility: Bool { false }
    var needsDelayAfterWrite: Bool { false }
    var writeDelay: TimeInterval { 0 }
    
    func getText(from element: AXUIElement) -> String? {
        // Don't try to read terminal text
        return nil
    }
    
    func setText(_ text: String, in element: AXUIElement) {
        // Don't try to set terminal text
    }
}

/// Strategy for Slack
class SlackStrategy: AppStrategy {
    static var bundleIdentifiers: [String] { ["com.tinyspeck.slackmacgap"] }
    
    var supportsAccessibility: Bool { true }
    var needsDelayAfterWrite: Bool { true }
    var writeDelay: TimeInterval { 0.05 }
    
    // Slack (Electron) has decent accessibility
}

/// Strategy for Discord
class DiscordStrategy: AppStrategy {
    static var bundleIdentifiers: [String] { ["com.hnc.Discord"] }
    
    var supportsAccessibility: Bool { true }
    var needsDelayAfterWrite: Bool { true }
    var writeDelay: TimeInterval { 0.05 }
    
    // Discord (Electron) has accessibility but can be inconsistent
}
