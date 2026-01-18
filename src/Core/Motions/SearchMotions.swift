import Foundation

/// Manages search state for / and ? commands
class SearchState {
    static let shared = SearchState()
    
    /// The last search pattern
    var lastPattern: String?
    
    /// Whether last search was forward
    var lastSearchForward: Bool = true
    
    /// All match positions in current text
    var matches: [Int] = []
    
    /// Current match index
    var currentMatchIndex: Int = 0
    
    private init() {}
    
    /// Performs a search and stores results
    func search(pattern: String, in text: String, forward: Bool) {
        lastPattern = pattern
        lastSearchForward = forward
        matches = []
        
        guard !pattern.isEmpty else { return }
        
        // Find all occurrences
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: pattern, options: forward ? [] : .backwards, range: searchRange) {
            let position = text.distance(from: text.startIndex, to: range.lowerBound)
            matches.append(position)
            
            if forward {
                searchRange = range.upperBound..<text.endIndex
            } else {
                if range.lowerBound > text.startIndex {
                    searchRange = text.startIndex..<range.lowerBound
                } else {
                    break
                }
            }
        }
        
        // Sort matches by position
        matches.sort()
    }
    
    /// Finds the next match from the given position
    func nextMatch(from position: Int, forward: Bool) -> Int? {
        guard !matches.isEmpty else { return nil }
        
        if forward {
            // Find first match after position
            for match in matches {
                if match > position {
                    return match
                }
            }
            // Wrap around
            return matches.first
        } else {
            // Find last match before position
            for match in matches.reversed() {
                if match < position {
                    return match
                }
            }
            // Wrap around
            return matches.last
        }
    }
    
    /// Clears search state
    func clear() {
        lastPattern = nil
        matches = []
        currentMatchIndex = 0
    }
}

/// Executes search motions (n, N, *, #)
struct SearchMotionExecutor: MotionExecutor {
    let forward: Bool  // n = last direction, N = opposite
    let useLastDirection: Bool
    
    init(forward: Bool = true, useLastDirection: Bool = true) {
        self.forward = forward
        self.useLastDirection = useLastDirection
    }
    
    func execute(from position: Int, in text: String, count: Int) -> Int {
        let searchState = SearchState.shared
        
        guard searchState.lastPattern != nil else {
            return position
        }
        
        var direction: Bool
        if useLastDirection {
            direction = forward ? searchState.lastSearchForward : !searchState.lastSearchForward
        } else {
            direction = forward
        }
        
        var currentPos = position
        for _ in 0..<count {
            if let nextPos = searchState.nextMatch(from: currentPos, forward: direction) {
                currentPos = nextPos
            } else {
                break
            }
        }
        
        return currentPos
    }
    
    func getRange(from position: Int, in text: String, count: Int) -> Range<Int> {
        let newPosition = execute(from: position, in: text, count: count)
        let start = min(position, newPosition)
        let end = max(position, newPosition)
        return start..<min(end + 1, text.count)
    }
}

/// Executes word-under-cursor search (* and #)
struct WordSearchExecutor: MotionExecutor {
    let forward: Bool  // * = forward, # = backward
    
    func execute(from position: Int, in text: String, count: Int) -> Int {
        // First, find the word under cursor
        guard let word = getWordUnderCursor(at: position, in: text) else {
            return position
        }
        
        // Search for this word
        let searchState = SearchState.shared
        searchState.search(pattern: word, in: text, forward: forward)
        
        var currentPos = position
        for _ in 0..<count {
            if let nextPos = searchState.nextMatch(from: currentPos, forward: forward) {
                currentPos = nextPos
            } else {
                break
            }
        }
        
        return currentPos
    }
    
    func getRange(from position: Int, in text: String, count: Int) -> Range<Int> {
        let newPosition = execute(from: position, in: text, count: count)
        let start = min(position, newPosition)
        let end = max(position, newPosition)
        return start..<min(end + 1, text.count)
    }
    
    private func getWordUnderCursor(at position: Int, in text: String) -> String? {
        let chars = Array(text)
        guard position < chars.count else { return nil }
        
        // Check if cursor is on a word character
        let currentChar = chars[position]
        guard currentChar.isLetter || currentChar.isNumber || currentChar == "_" else {
            return nil
        }
        
        // Find word boundaries
        var start = position
        var end = position
        
        // Go backward to find start
        while start > 0 {
            let prevChar = chars[start - 1]
            if prevChar.isLetter || prevChar.isNumber || prevChar == "_" {
                start -= 1
            } else {
                break
            }
        }
        
        // Go forward to find end
        while end < chars.count - 1 {
            let nextChar = chars[end + 1]
            if nextChar.isLetter || nextChar.isNumber || nextChar == "_" {
                end += 1
            } else {
                break
            }
        }
        
        let startIndex = text.index(text.startIndex, offsetBy: start)
        let endIndex = text.index(text.startIndex, offsetBy: end + 1)
        return String(text[startIndex..<endIndex])
    }
}
