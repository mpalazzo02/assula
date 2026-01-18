import Foundation

/// Executes line-based motions (0, $, ^, gg, G)
struct LineMotionExecutor: MotionExecutor {
    let motion: Motion
    
    func execute(from position: Int, in text: String, count: Int) -> Int {
        switch motion {
        case .lineStart:
            return moveToLineStart(from: position, in: text)
        case .lineEnd:
            return moveToLineEnd(from: position, in: text)
        case .firstNonBlank:
            return moveToFirstNonBlank(from: position, in: text)
        case .documentStart:
            return 0
        case .documentEnd:
            // With count, G goes to line number
            if count > 1 {
                return moveToLine(count, in: text)
            }
            return moveToLastLine(in: text)
        default:
            return position
        }
    }
    
    func getRange(from position: Int, in text: String, count: Int) -> Range<Int> {
        let newPosition = execute(from: position, in: text, count: count)
        
        // Line motions are linewise for operators
        if motion.isLinewise {
            let startLine = getLineStart(for: min(position, newPosition), in: text)
            let endLine = getLineEnd(for: max(position, newPosition), in: text)
            return startLine..<min(endLine + 1, text.count)
        }
        
        let start = min(position, newPosition)
        let end = max(position, newPosition)
        return start..<min(end + 1, text.count)
    }
    
    // MARK: - Motion Implementations
    
    private func moveToLineStart(from position: Int, in text: String) -> Int {
        return getLineStart(for: position, in: text)
    }
    
    private func moveToLineEnd(from position: Int, in text: String) -> Int {
        let end = getLineEnd(for: position, in: text)
        // In normal mode, cursor sits on last character, not after it
        return max(getLineStart(for: position, in: text), end - 1)
    }
    
    private func moveToFirstNonBlank(from position: Int, in text: String) -> Int {
        let lineStart = getLineStart(for: position, in: text)
        let lineEnd = getLineEnd(for: position, in: text)
        
        var pos = lineStart
        let chars = Array(text)
        
        while pos < lineEnd && chars[pos].isWhitespace && chars[pos] != "\n" {
            pos += 1
        }
        
        return pos
    }
    
    private func moveToLine(_ lineNumber: Int, in text: String) -> Int {
        let lines = text.components(separatedBy: "\n")
        let targetLine = min(lineNumber, lines.count) - 1
        
        var position = 0
        for i in 0..<targetLine {
            position += lines[i].count + 1
        }
        
        // Move to first non-blank on that line
        return moveToFirstNonBlank(from: position, in: text)
    }
    
    private func moveToLastLine(in text: String) -> Int {
        let lines = text.components(separatedBy: "\n")
        
        var position = 0
        for i in 0..<(lines.count - 1) {
            position += lines[i].count + 1
        }
        
        return moveToFirstNonBlank(from: position, in: text)
    }
    
    // MARK: - Helpers
    
    private func getLineStart(for position: Int, in text: String) -> Int {
        guard position > 0 else { return 0 }
        
        let chars = Array(text)
        var pos = position
        
        // If we're on a newline, back up one
        if pos < chars.count && chars[pos] == "\n" {
            pos -= 1
        }
        
        while pos > 0 && chars[pos - 1] != "\n" {
            pos -= 1
        }
        
        return pos
    }
    
    private func getLineEnd(for position: Int, in text: String) -> Int {
        let chars = Array(text)
        var pos = position
        
        while pos < chars.count && chars[pos] != "\n" {
            pos += 1
        }
        
        return pos
    }
}
