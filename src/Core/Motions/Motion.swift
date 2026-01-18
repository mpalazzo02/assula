import Foundation

/// Represents a cursor motion in Vim
enum Motion {
    // Character motions
    case left
    case right
    case up
    case down
    
    // Word motions
    case wordForward        // w
    case wordBackward       // b
    case wordEnd            // e
    case wordForwardBig     // W
    case wordBackwardBig    // B
    case wordEndBig         // E
    
    // Line motions
    case lineStart          // 0
    case lineEnd            // $
    case firstNonBlank      // ^
    
    // Document motions
    case documentStart      // gg
    case documentEnd        // G
    
    // Find motions
    case findChar(Character, forward: Bool, tillBefore: Bool)  // f, F, t, T
    
    /// Creates a motion from a key press
    static func from(key: String) -> Motion? {
        switch key {
        case "h": return .left
        case "j": return .down
        case "k": return .up
        case "l": return .right
        case "w": return .wordForward
        case "b": return .wordBackward
        case "e": return .wordEnd
        case "W": return .wordForwardBig
        case "B": return .wordBackwardBig
        case "E": return .wordEndBig
        case "0": return .lineStart
        case "$": return .lineEnd
        case "^": return .firstNonBlank
        case "G": return .documentEnd
        // Note: "gg" requires multi-key handling
        default: return nil
        }
    }
    
    /// Whether this motion moves by lines (affects how operators work)
    var isLinewise: Bool {
        switch self {
        case .up, .down, .documentStart, .documentEnd:
            return true
        default:
            return false
        }
    }
    
    /// Whether this motion is inclusive (includes the character at destination)
    var isInclusive: Bool {
        switch self {
        case .wordEnd, .wordEndBig, .findChar:
            return true
        case .left, .right, .up, .down, .wordForward, .wordBackward,
             .wordForwardBig, .wordBackwardBig, .lineStart, .lineEnd,
             .firstNonBlank, .documentStart, .documentEnd:
            return false
        }
    }
}
