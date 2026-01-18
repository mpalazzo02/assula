import Foundation

/// Holds the current state of the Vim engine
struct VimState {
    /// The count prefix for the next command (e.g., "3" in "3dw")
    var count: Int = 1
    
    /// The pending operator waiting for a motion (e.g., "d" waiting for "w")
    var pendingOperator: OperatorType?
    
    /// The register to use for yank/paste operations
    var register: String = "\""
    
    /// Content stored in registers (key is register name)
    var registers: [String: RegisterContent] = [:]
    
    /// Visual mode anchor position (where visual selection started)
    var visualAnchor: Int?
    
    /// Keys accumulated for multi-key sequences (gg, diw, etc.)
    var keyBuffer: [String] = []
    
    /// Timestamp of last key press (for escape sequence timing)
    var lastKeyTime: Date?
    
    /// Last find motion for ; and , repeat
    var lastFindMotion: FindMotionState?
    
    /// Pending find motion type (waiting for character)
    var pendingFindType: FindType?
    
    /// Pending text object modifier (waiting for object type)
    var pendingTextObjectInner: Bool?
    
    /// Resets state after a command is executed
    mutating func reset() {
        count = 1
        pendingOperator = nil
        keyBuffer = []
        pendingFindType = nil
        pendingTextObjectInner = nil
    }
    
    /// Resets visual mode state
    mutating func resetVisual() {
        visualAnchor = nil
    }
}

/// Find motion types (f, F, t, T)
enum FindType {
    case f  // find forward
    case F  // find backward
    case t  // till forward
    case T  // till backward
    
    var forward: Bool {
        self == .f || self == .t
    }
    
    var tillBefore: Bool {
        self == .t || self == .T
    }
}

/// State for repeating find motions with ; and ,
struct FindMotionState {
    let character: Character
    let findType: FindType
}

/// Types of operators in Vim
enum OperatorType: String {
    case delete = "d"
    case change = "c"
    case yank = "y"
    
    var deletesText: Bool {
        switch self {
        case .delete, .change: return true
        case .yank: return false
        }
    }
    
    var entersInsertMode: Bool {
        self == .change
    }
}

/// Content stored in a register
struct RegisterContent {
    let text: String
    let isLinewise: Bool
    
    init(text: String, isLinewise: Bool = false) {
        self.text = text
        self.isLinewise = isLinewise
    }
}
