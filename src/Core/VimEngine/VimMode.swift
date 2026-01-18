import Foundation

/// Represents the current Vim editing mode
enum VimMode: String, CaseIterable {
    case normal = "NORMAL"
    case insert = "INSERT"
    case visual = "VISUAL"
    case visualLine = "VISUAL_LINE"
    case operatorPending = "OPERATOR_PENDING"
    
    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .insert: return "Insert"
        case .visual: return "Visual"
        case .visualLine: return "Visual Line"
        case .operatorPending: return "Operator Pending"
        }
    }
}
