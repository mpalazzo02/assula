import Foundation

/// Protocol for motion implementations
protocol MotionExecutor {
    /// Calculates the new cursor position after applying this motion
    func execute(from position: Int, in text: String, count: Int) -> Int
    
    /// Gets the range of text affected by this motion (for operators)
    func getRange(from position: Int, in text: String, count: Int) -> Range<Int>
}

/// Executes character-based motions (h, j, k, l)
struct CharacterMotionExecutor: MotionExecutor {
    let motion: Motion
    
    func execute(from position: Int, in text: String, count: Int) -> Int {
        var newPosition = position
        
        for _ in 0..<count {
            switch motion {
            case .left:
                newPosition = moveLeft(from: newPosition, in: text)
            case .right:
                newPosition = moveRight(from: newPosition, in: text)
            case .up:
                newPosition = moveUp(from: newPosition, in: text)
            case .down:
                newPosition = moveDown(from: newPosition, in: text)
            default:
                break
            }
        }
        
        return newPosition
    }
    
    func getRange(from position: Int, in text: String, count: Int) -> Range<Int> {
        let newPosition = execute(from: position, in: text, count: count)
        let start = min(position, newPosition)
        let end = max(position, newPosition) + 1
        return start..<min(end, text.count)
    }
    
    private func moveLeft(from position: Int, in text: String) -> Int {
        guard position > 0 else { return position }
        
        // Don't move past the beginning of the line
        let index = text.index(text.startIndex, offsetBy: position)
        if position > 0 {
            let prevIndex = text.index(before: index)
            if text[prevIndex] == "\n" {
                return position
            }
        }
        
        return position - 1
    }
    
    private func moveRight(from position: Int, in text: String) -> Int {
        guard position < text.count - 1 else { return position }
        
        let index = text.index(text.startIndex, offsetBy: position)
        
        // Don't move past end of line
        if text[index] == "\n" {
            return position
        }
        
        return position + 1
    }
    
    private func moveUp(from position: Int, in text: String) -> Int {
        let lines = text.components(separatedBy: "\n")
        var currentLine = 0
        var charCount = 0
        var columnInLine = 0
        
        // Find current line and column
        for (index, line) in lines.enumerated() {
            let lineLength = line.count + 1 // +1 for newline
            if charCount + lineLength > position {
                currentLine = index
                columnInLine = position - charCount
                break
            }
            charCount += lineLength
        }
        
        // Can't go up from first line
        if currentLine == 0 {
            return position
        }
        
        // Calculate position in previous line
        let prevLine = lines[currentLine - 1]
        let newColumn = min(columnInLine, prevLine.count)
        
        var newPosition = 0
        for i in 0..<(currentLine - 1) {
            newPosition += lines[i].count + 1
        }
        newPosition += newColumn
        
        return newPosition
    }
    
    private func moveDown(from position: Int, in text: String) -> Int {
        let lines = text.components(separatedBy: "\n")
        var currentLine = 0
        var charCount = 0
        var columnInLine = 0
        
        // Find current line and column
        for (index, line) in lines.enumerated() {
            let lineLength = line.count + (index < lines.count - 1 ? 1 : 0)
            if charCount + lineLength > position || index == lines.count - 1 {
                currentLine = index
                columnInLine = position - charCount
                break
            }
            charCount += lineLength
        }
        
        // Can't go down from last line
        if currentLine >= lines.count - 1 {
            return position
        }
        
        // Calculate position in next line
        let nextLine = lines[currentLine + 1]
        let newColumn = min(columnInLine, nextLine.count)
        
        var newPosition = 0
        for i in 0...currentLine {
            newPosition += lines[i].count + 1
        }
        newPosition += newColumn
        
        return min(newPosition, text.count - 1)
    }
}
