import Foundation

/// Protocol for text object implementations
protocol TextObject {
    /// Gets the range of text for this text object
    func getRange(around position: Int, in text: String, inner: Bool) -> Range<Int>?
}

/// Word text object (iw, aw)
struct WordTextObject: TextObject {
    func getRange(around position: Int, in text: String, inner: Bool) -> Range<Int>? {
        let chars = Array(text)
        guard position < chars.count else { return nil }
        
        let currentChar = chars[position]
        
        // Determine what kind of "word" we're in
        let isWordChar = currentChar.isLetter || currentChar.isNumber || currentChar == "_"
        let isWhitespace = currentChar.isWhitespace
        
        var start = position
        var end = position
        
        if isWordChar {
            // Find word boundaries
            while start > 0 && isWord(chars[start - 1]) {
                start -= 1
            }
            while end < chars.count - 1 && isWord(chars[end + 1]) {
                end += 1
            }
            
            // For 'aw', include trailing whitespace (or leading if at end of line)
            if !inner {
                // Try trailing whitespace first
                var trailingEnd = end + 1
                while trailingEnd < chars.count && chars[trailingEnd].isWhitespace && chars[trailingEnd] != "\n" {
                    trailingEnd += 1
                }
                if trailingEnd > end + 1 {
                    end = trailingEnd - 1
                } else {
                    // Try leading whitespace
                    while start > 0 && chars[start - 1].isWhitespace && chars[start - 1] != "\n" {
                        start -= 1
                    }
                }
            }
        } else if isWhitespace {
            // Select whitespace block
            while start > 0 && chars[start - 1].isWhitespace && chars[start - 1] != "\n" {
                start -= 1
            }
            while end < chars.count - 1 && chars[end + 1].isWhitespace && chars[end + 1] != "\n" {
                end += 1
            }
        } else {
            // Punctuation - select contiguous punctuation
            while start > 0 && isPunctuation(chars[start - 1]) {
                start -= 1
            }
            while end < chars.count - 1 && isPunctuation(chars[end + 1]) {
                end += 1
            }
        }
        
        return start..<(end + 1)
    }
    
    private func isWord(_ char: Character) -> Bool {
        char.isLetter || char.isNumber || char == "_"
    }
    
    private func isPunctuation(_ char: Character) -> Bool {
        !char.isLetter && !char.isNumber && char != "_" && !char.isWhitespace
    }
}

/// WORD text object (iW, aW) - whitespace delimited
struct BigWordTextObject: TextObject {
    func getRange(around position: Int, in text: String, inner: Bool) -> Range<Int>? {
        let chars = Array(text)
        guard position < chars.count else { return nil }
        
        let currentChar = chars[position]
        
        if currentChar.isWhitespace {
            // Select whitespace block
            var start = position
            var end = position
            
            while start > 0 && chars[start - 1].isWhitespace && chars[start - 1] != "\n" {
                start -= 1
            }
            while end < chars.count - 1 && chars[end + 1].isWhitespace && chars[end + 1] != "\n" {
                end += 1
            }
            return start..<(end + 1)
        }
        
        // Find WORD boundaries (non-whitespace)
        var start = position
        var end = position
        
        while start > 0 && !chars[start - 1].isWhitespace {
            start -= 1
        }
        while end < chars.count - 1 && !chars[end + 1].isWhitespace {
            end += 1
        }
        
        // For 'aW', include trailing whitespace
        if !inner {
            var trailingEnd = end + 1
            while trailingEnd < chars.count && chars[trailingEnd].isWhitespace && chars[trailingEnd] != "\n" {
                trailingEnd += 1
            }
            if trailingEnd > end + 1 {
                end = trailingEnd - 1
            } else {
                while start > 0 && chars[start - 1].isWhitespace && chars[start - 1] != "\n" {
                    start -= 1
                }
            }
        }
        
        return start..<(end + 1)
    }
}

/// Quoted string text object (i", a", i', a')
struct QuotedTextObject: TextObject {
    let quoteChar: Character
    
    func getRange(around position: Int, in text: String, inner: Bool) -> Range<Int>? {
        let chars = Array(text)
        guard position < chars.count else { return nil }
        
        // Find quote boundaries on the current line
        var lineStart = position
        var lineEnd = position
        
        // Find line boundaries
        while lineStart > 0 && chars[lineStart - 1] != "\n" {
            lineStart -= 1
        }
        while lineEnd < chars.count - 1 && chars[lineEnd] != "\n" {
            lineEnd += 1
        }
        
        // Find quotes on this line
        var quotes: [Int] = []
        for i in lineStart...lineEnd {
            if chars[i] == quoteChar {
                // Check if escaped
                if i > 0 && chars[i - 1] == "\\" {
                    continue
                }
                quotes.append(i)
            }
        }
        
        // Need at least 2 quotes
        guard quotes.count >= 2 else { return nil }
        
        // Find the pair that contains or is nearest to position
        for i in stride(from: 0, to: quotes.count - 1, by: 2) {
            let openQuote = quotes[i]
            let closeQuote = quotes[i + 1]
            
            if position >= openQuote && position <= closeQuote {
                if inner {
                    return (openQuote + 1)..<closeQuote
                } else {
                    return openQuote..<(closeQuote + 1)
                }
            }
        }
        
        // Position is outside quotes - find next pair
        for i in stride(from: 0, to: quotes.count - 1, by: 2) {
            let openQuote = quotes[i]
            let closeQuote = quotes[i + 1]
            
            if openQuote > position {
                if inner {
                    return (openQuote + 1)..<closeQuote
                } else {
                    return openQuote..<(closeQuote + 1)
                }
            }
        }
        
        return nil
    }
}

/// Parentheses/bracket text object (i(, a(, i), a), i[, a], i{, a})
struct BracketTextObject: TextObject {
    let openBracket: Character
    let closeBracket: Character
    
    init(type: BracketType) {
        switch type {
        case .parentheses:
            openBracket = "("
            closeBracket = ")"
        case .square:
            openBracket = "["
            closeBracket = "]"
        case .curly:
            openBracket = "{"
            closeBracket = "}"
        case .angle:
            openBracket = "<"
            closeBracket = ">"
        }
    }
    
    enum BracketType {
        case parentheses, square, curly, angle
    }
    
    func getRange(around position: Int, in text: String, inner: Bool) -> Range<Int>? {
        let chars = Array(text)
        guard position < chars.count else { return nil }
        
        // Find matching brackets
        var openPos: Int?
        var closePos: Int?
        
        // Search backward for opening bracket
        var depth = 0
        var searchPos = position
        
        // If cursor is on a bracket, include it in search
        if chars[position] == closeBracket {
            depth = 1
        } else if chars[position] == openBracket {
            openPos = position
            depth = 1
            searchPos = position + 1
        }
        
        // Search backward for opening bracket if not found
        if openPos == nil {
            searchPos = position
            depth = 0
            while searchPos >= 0 {
                if chars[searchPos] == closeBracket {
                    depth += 1
                } else if chars[searchPos] == openBracket {
                    if depth == 0 {
                        openPos = searchPos
                        break
                    }
                    depth -= 1
                }
                searchPos -= 1
            }
        }
        
        guard let start = openPos else { return nil }
        
        // Search forward for closing bracket
        depth = 1
        searchPos = start + 1
        while searchPos < chars.count {
            if chars[searchPos] == openBracket {
                depth += 1
            } else if chars[searchPos] == closeBracket {
                depth -= 1
                if depth == 0 {
                    closePos = searchPos
                    break
                }
            }
            searchPos += 1
        }
        
        guard let end = closePos else { return nil }
        
        if inner {
            return (start + 1)..<end
        } else {
            return start..<(end + 1)
        }
    }
}

/// Sentence text object (is, as)
struct SentenceTextObject: TextObject {
    func getRange(around position: Int, in text: String, inner: Bool) -> Range<Int>? {
        let chars = Array(text)
        guard position < chars.count else { return nil }
        
        // Find sentence boundaries (ends with . ! ? followed by whitespace or end)
        var start = position
        var end = position
        
        // Find start of sentence
        while start > 0 {
            let char = chars[start - 1]
            if isSentenceEnd(char) && (start == 1 || chars[start - 2].isWhitespace || start - 2 < 0) {
                break
            }
            start -= 1
        }
        
        // Skip leading whitespace for inner
        if inner {
            while start < chars.count && chars[start].isWhitespace {
                start += 1
            }
        }
        
        // Find end of sentence
        while end < chars.count - 1 {
            let char = chars[end]
            if isSentenceEnd(char) {
                break
            }
            end += 1
        }
        
        // For outer, include trailing whitespace
        if !inner && end < chars.count - 1 {
            while end < chars.count - 1 && chars[end + 1].isWhitespace {
                end += 1
            }
        }
        
        return start..<(end + 1)
    }
    
    private func isSentenceEnd(_ char: Character) -> Bool {
        char == "." || char == "!" || char == "?"
    }
}

/// Paragraph text object (ip, ap)
struct ParagraphTextObject: TextObject {
    func getRange(around position: Int, in text: String, inner: Bool) -> Range<Int>? {
        let chars = Array(text)
        guard position < chars.count else { return nil }
        
        var start = position
        var end = position
        
        // Find start of paragraph (blank line or start of text)
        while start > 0 {
            if chars[start - 1] == "\n" && (start == 1 || chars[start - 2] == "\n") {
                break
            }
            start -= 1
        }
        
        // Find end of paragraph (blank line or end of text)
        while end < chars.count - 1 {
            if chars[end] == "\n" && (end == chars.count - 2 || chars[end + 1] == "\n") {
                break
            }
            end += 1
        }
        
        // For outer, include trailing blank lines
        if !inner {
            while end < chars.count - 1 && chars[end + 1] == "\n" {
                end += 1
            }
        }
        
        return start..<(end + 1)
    }
}
