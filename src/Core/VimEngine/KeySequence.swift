import Foundation

/// Represents a key press event with modifiers
struct KeyEvent: Equatable, CustomStringConvertible {
    let key: String
    let keyCode: UInt16
    let modifiers: Modifiers
    
    struct Modifiers: OptionSet, Equatable {
        let rawValue: UInt
        
        static let shift = Modifiers(rawValue: 1 << 0)
        static let control = Modifiers(rawValue: 1 << 1)
        static let option = Modifiers(rawValue: 1 << 2)
        static let command = Modifiers(rawValue: 1 << 3)
        
        static let none: Modifiers = []
    }
    
    var description: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("C") }
        if modifiers.contains(.option) { parts.append("M") }
        if modifiers.contains(.command) { parts.append("D") }
        if modifiers.contains(.shift) && key.count == 1 { parts.append("S") }
        
        if parts.isEmpty {
            return key
        } else {
            return "<\(parts.joined(separator: "-"))-\(key)>"
        }
    }
    
    var isEscape: Bool {
        keyCode == 53 || (modifiers.contains(.control) && key.lowercased() == "[")
    }
    
    var isModified: Bool {
        !modifiers.subtracting(.shift).isEmpty
    }
}

/// Parses and manages key sequences for multi-key commands
class KeySequenceParser {
    private var buffer: [String] = []
    private var lastKeyTime: Date?
    private var escapeSequence: [String]
    private var escapeTimeout: TimeInterval
    
    init() {
        let config = ConfigManager.shared.config
        self.escapeSequence = config.escapeSequenceChars
        self.escapeTimeout = config.escapeTimeoutSeconds
        
        // Listen for config changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configDidChange),
            name: .assulaConfigChanged,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func configDidChange() {
        let config = ConfigManager.shared.config
        escapeSequence = config.escapeSequenceChars
        escapeTimeout = config.escapeTimeoutSeconds
    }
    
    /// Adds a key to the buffer and checks for escape sequence
    /// Returns true if escape sequence was detected
    func addKey(_ key: String) -> Bool {
        let now = Date()
        
        // Reset buffer if too much time has passed
        if let lastTime = lastKeyTime, now.timeIntervalSince(lastTime) > escapeTimeout {
            buffer.removeAll()
        }
        
        buffer.append(key)
        lastKeyTime = now
        
        // Check if buffer ends with escape sequence
        if buffer.count >= escapeSequence.count {
            let suffix = Array(buffer.suffix(escapeSequence.count))
            if suffix == escapeSequence {
                buffer.removeAll()
                return true
            }
        }
        
        // Trim buffer to prevent unbounded growth
        if buffer.count > 10 {
            buffer.removeFirst(buffer.count - 10)
        }
        
        return false
    }
    
    /// Clears the buffer
    func reset() {
        buffer.removeAll()
        lastKeyTime = nil
    }
    
    /// Returns pending keys that haven't been processed
    var pendingKeys: [String] {
        buffer
    }
}
