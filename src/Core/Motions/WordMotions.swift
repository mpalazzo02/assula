import Foundation

/// Executes word-based motions (w, b, e, W, B, E)
struct WordMotionExecutor: MotionExecutor {
    let motion: Motion
    
    func execute(from position: Int, in text: String, count: Int) -> Int {
        var newPosition = position
        
        for _ in 0..<count {
            switch motion {
            case .wordForward:
                newPosition = moveWordForward(from: newPosition, in: text, bigWord: false)
            case .wordBackward:
                newPosition = moveWordBackward(from: newPosition, in: text, bigWord: false)
            case .wordEnd:
                newPosition = moveWordEnd(from: newPosition, in: text, bigWord: false)
            case .wordForwardBig:
                newPosition = moveWordForward(from: newPosition, in: text, bigWord: true)
            case .wordBackwardBig:
                newPosition = moveWordBackward(from: newPosition, in: text, bigWord: true)
            case .wordEndBig:
                newPosition = moveWordEnd(from: newPosition, in: text, bigWord: true)
            default:
                break
            }
        }
        
        return newPosition
    }
    
    func getRange(from position: Int, in text: String, count: Int) -> Range<Int> {
        let newPosition = execute(from: position, in: text, count: count)
        let start = min(position, newPosition)
        var end = max(position, newPosition)
        
        // Inclusive motions include the destination character
        if motion.isInclusive {
            end += 1
        }
        
        return start..<min(end, text.count)
    }
    
    // MARK: - Word Classification
    
    private func isWordChar(_ char: Character, bigWord: Bool) -> Bool {
        if bigWord {
            return !char.isWhitespace
        }
        return char.isLetter || char.isNumber || char == "_"
    }
    
    private func isPunctuation(_ char: Character) -> Bool {
        return !char.isLetter && !char.isNumber && char != "_" && !char.isWhitespace
    }
    
    // MARK: - Motion Implementations
    
    private func moveWordForward(from position: Int, in text: String, bigWord: Bool) -> Int {
        guard position < text.count else { return position }
        
        var pos = position
        let chars = Array(text)
        
        // Skip current word
        if pos < chars.count {
            let currentChar = chars[pos]
            if bigWord {
                // For big words, skip all non-whitespace
                while pos < chars.count && !chars[pos].isWhitespace {
                    pos += 1
                }
            } else {
                // For small words, handle word chars and punctuation separately
                if isWordChar(currentChar, bigWord: false) {
                    while pos < chars.count && isWordChar(chars[pos], bigWord: false) {
                        pos += 1
                    }
                } else if isPunctuation(currentChar) {
                    while pos < chars.count && isPunctuation(chars[pos]) {
                        pos += 1
                    }
                }
            }
        }
        
        // Skip whitespace
        while pos < chars.count && chars[pos].isWhitespace {
            pos += 1
        }
        
        return min(pos, text.count - 1)
    }
    
    private func moveWordBackward(from position: Int, in text: String, bigWord: Bool) -> Int {
        guard position > 0 else { return 0 }
        
        var pos = position - 1
        let chars = Array(text)
        
        // Skip whitespace
        while pos > 0 && chars[pos].isWhitespace {
            pos -= 1
        }
        
        // Find start of word
        if pos >= 0 {
            let currentChar = chars[pos]
            if bigWord {
                while pos > 0 && !chars[pos - 1].isWhitespace {
                    pos -= 1
                }
            } else {
                if isWordChar(currentChar, bigWord: false) {
                    while pos > 0 && isWordChar(chars[pos - 1], bigWord: false) {
                        pos -= 1
                    }
                } else if isPunctuation(currentChar) {
                    while pos > 0 && isPunctuation(chars[pos - 1]) {
                        pos -= 1
                    }
                }
            }
        }
        
        return max(pos, 0)
    }
    
    private func moveWordEnd(from position: Int, in text: String, bigWord: Bool) -> Int {
        guard position < text.count - 1 else { return position }
        
        var pos = position + 1
        let chars = Array(text)
        
        // Skip whitespace
        while pos < chars.count && chars[pos].isWhitespace {
            pos += 1
        }
        
        // Find end of word
        if pos < chars.count {
            let currentChar = chars[pos]
            if bigWord {
                while pos < chars.count - 1 && !chars[pos + 1].isWhitespace {
                    pos += 1
                }
            } else {
                if isWordChar(currentChar, bigWord: false) {
                    while pos < chars.count - 1 && isWordChar(chars[pos + 1], bigWord: false) {
                        pos += 1
                    }
                } else if isPunctuation(currentChar) {
                    while pos < chars.count - 1 && isPunctuation(chars[pos + 1]) {
                        pos += 1
                    }
                }
            }
        }
        
        return min(pos, text.count - 1)
    }
}
