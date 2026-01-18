import Foundation

/// Executes find/till motions (f, F, t, T)
struct FindMotionExecutor: MotionExecutor {
    let character: Character
    let forward: Bool      // f/t = true, F/T = false
    let tillBefore: Bool   // t/T = true, f/F = false
    
    func execute(from position: Int, in text: String, count: Int) -> Int {
        var currentPosition = position
        
        for _ in 0..<count {
            if let newPos = findCharacter(from: currentPosition, in: text) {
                currentPosition = newPos
            } else {
                // Character not found, stay at current position
                break
            }
        }
        
        return currentPosition
    }
    
    func getRange(from position: Int, in text: String, count: Int) -> Range<Int> {
        let newPosition = execute(from: position, in: text, count: count)
        let start = min(position, newPosition)
        let end = max(position, newPosition) + 1 // Inclusive
        return start..<min(end, text.count)
    }
    
    private func findCharacter(from position: Int, in text: String) -> Int? {
        let chars = Array(text)
        
        if forward {
            // Search forward from position + 1
            var searchStart = position + 1
            while searchStart < chars.count {
                if chars[searchStart] == character {
                    return tillBefore ? searchStart - 1 : searchStart
                }
                searchStart += 1
            }
        } else {
            // Search backward from position - 1
            var searchStart = position - 1
            while searchStart >= 0 {
                if chars[searchStart] == character {
                    return tillBefore ? searchStart + 1 : searchStart
                }
                searchStart -= 1
            }
        }
        
        return nil
    }
}

/// Executes repeat find motion (;) - repeats last f/F/t/T
struct RepeatFindMotionExecutor: MotionExecutor {
    let lastFind: FindMotionExecutor
    let reverse: Bool  // ; = false, , = true
    
    func execute(from position: Int, in text: String, count: Int) -> Int {
        let executor: FindMotionExecutor
        if reverse {
            // Reverse the direction
            executor = FindMotionExecutor(
                character: lastFind.character,
                forward: !lastFind.forward,
                tillBefore: lastFind.tillBefore
            )
        } else {
            executor = lastFind
        }
        
        return executor.execute(from: position, in: text, count: count)
    }
    
    func getRange(from position: Int, in text: String, count: Int) -> Range<Int> {
        let newPosition = execute(from: position, in: text, count: count)
        let start = min(position, newPosition)
        let end = max(position, newPosition) + 1
        return start..<min(end, text.count)
    }
}
