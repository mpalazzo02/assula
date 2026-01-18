import Foundation
import Cocoa

/// Strategy for Safari browser
class SafariStrategy: AppStrategy {
    static var bundleIdentifiers: [String] { ["com.apple.Safari"] }
    
    var supportsAccessibility: Bool { true }
    var needsDelayAfterWrite: Bool { false }
    var writeDelay: TimeInterval { 0 }
    
    // Safari has good accessibility support for text fields
    // Uses default implementations from AppStrategy extension
}

/// Strategy for Google Chrome
class ChromeStrategy: AppStrategy {
    static var bundleIdentifiers: [String] { 
        ["com.google.Chrome", "com.google.Chrome.canary", "com.google.Chrome.beta"]
    }
    
    var supportsAccessibility: Bool { true }
    var needsDelayAfterWrite: Bool { true }
    var writeDelay: TimeInterval { 0.05 } // Small delay for Chrome to process
    
    func setText(_ text: String, in element: AXUIElement) {
        AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
        
        // Chrome sometimes needs a moment to register the change
        if needsDelayAfterWrite {
            Thread.sleep(forTimeInterval: writeDelay)
        }
    }
    
    func setSelectedText(_ text: String, in element: AXUIElement) {
        AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        
        if needsDelayAfterWrite {
            Thread.sleep(forTimeInterval: writeDelay)
        }
    }
}

/// Strategy for Firefox
class FirefoxStrategy: AppStrategy {
    static var bundleIdentifiers: [String] { 
        ["org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "org.mozilla.nightly"]
    }
    
    var supportsAccessibility: Bool { true }
    var needsDelayAfterWrite: Bool { true }
    var writeDelay: TimeInterval { 0.05 }
    
    // Firefox accessibility can be inconsistent
    // Some text fields work well, others don't
    
    func getText(from element: AXUIElement) -> String? {
        // Try standard value first
        var value: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        
        if result == .success, let text = value as? String {
            return text
        }
        
        // Fallback to trying to get children's text
        result = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &value)
        if result == .success, let text = value as? String {
            return text
        }
        
        return nil
    }
}

/// Strategy for Arc Browser
class ArcStrategy: AppStrategy {
    static var bundleIdentifiers: [String] { ["company.thebrowser.Browser"] }
    
    var supportsAccessibility: Bool { true }
    var needsDelayAfterWrite: Bool { true }
    var writeDelay: TimeInterval { 0.03 }
    
    // Arc is Chromium-based, similar to Chrome but sometimes better behaved
    
    func setSelectedText(_ text: String, in element: AXUIElement) {
        AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        
        if needsDelayAfterWrite {
            Thread.sleep(forTimeInterval: writeDelay)
        }
    }
}
