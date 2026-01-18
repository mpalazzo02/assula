import Foundation
import Combine

/// The main Vim engine that processes key events and manages state
class VimEngine: ObservableObject {
    static let shared = VimEngine()
    
    @Published private(set) var currentMode: VimMode = .insert
    @Published private(set) var state = VimState()
    
    private let accessibilityService = AccessibilityService.shared
    private let keySequenceParser = KeySequenceParser()
    private let config = ConfigManager.shared
    
    private var countAccumulator: String = ""
    
    private init() {
        // Start in insert mode by default (configurable)
        if config.config.startInInsertMode {
            currentMode = .insert
        } else {
            currentMode = .normal
        }
    }
    
    // MARK: - Mode Management
    
    func setMode(_ mode: VimMode) {
        let previousMode = currentMode
        currentMode = mode
        
        // Reset state when entering normal mode
        if mode == .normal {
            state.reset()
            keySequenceParser.reset()
        }
        
        // Reset visual anchor when leaving visual mode
        if previousMode == .visual || previousMode == .visualLine {
            if mode != .visual && mode != .visualLine {
                state.resetVisual()
            }
        }
        
        // Set visual anchor when entering visual mode
        if mode == .visual || mode == .visualLine {
            if previousMode != .visual && previousMode != .visualLine {
                state.visualAnchor = accessibilityService.getCursorPosition()
            }
        }
        
        print("Mode changed: \(previousMode) -> \(mode)")
    }
    
    // MARK: - Key Processing
    
    /// Processes a key event and returns whether it was consumed
    @discardableResult
    func handleKey(_ event: KeyEvent) -> Bool {
        NSLog("[VIM] handleKey START: key='%@' mode=%@ pendingOp=%@", 
              event.key, 
              currentMode.rawValue,
              String(describing: state.pendingOperator))
        
        // In insert mode, check for escape sequence
        if currentMode == .insert {
            return handleInsertModeKey(event)
        }
        
        // Handle escape to return to normal mode
        if event.isEscape {
            if currentMode != .normal {
                setMode(.normal)
                return true
            }
            return false
        }
        
        NSLog("[VIM] handleKey: about to switch on mode %@", currentMode.rawValue)
        
        // In normal/visual modes, process vim commands
        switch currentMode {
        case .normal:
            NSLog("[VIM] switch: .normal")
            return handleNormalModeKey(event)
        case .visual, .visualLine:
            NSLog("[VIM] switch: .visual/.visualLine")
            return handleVisualModeKey(event)
        case .operatorPending:
            NSLog("[VIM] switch: .operatorPending - calling handleOperatorPendingKey")
            let result = handleOperatorPendingKey(event)
            NSLog("[VIM] handleOperatorPendingKey returned: %d", result ? 1 : 0)
            return result
        case .insert:
            NSLog("[VIM] switch: .insert (shouldn't happen)")
            return false // Already handled above
        }
    }
    
    // MARK: - Insert Mode
    
    private func handleInsertModeKey(_ event: KeyEvent) -> Bool {
        print("[INSERT] Key: '\(event.key)' keyCode: \(event.keyCode)")
        
        // Check for escape key
        if event.isEscape {
            print("[INSERT] Escape key pressed")
            setMode(.normal)
            return true
        }
        
        // Check for escape sequence (e.g., "jk")
        if !event.isModified && event.key.count == 1 {
            let escapeSeq = config.config.escapeSequenceChars
            print("[INSERT] Checking escape sequence, buffer before: \(keySequenceParser.pendingKeys)")
            
            if keySequenceParser.addKey(event.key) {
                print("[INSERT] Escape sequence matched! Deleting \(escapeSeq.count - 1) chars then switching to normal mode")
                
                // Delete the first character(s) of escape sequence BEFORE switching modes
                // This ensures deletion happens while still in the text field context
                let charsToDelete = escapeSeq.count - 1
                if charsToDelete > 0 {
                    if accessibilityService.needsFallbackMode() {
                        print("[INSERT] Using fallback delete for \(charsToDelete) chars")
                        accessibilityService.simulateDelete(count: charsToDelete)
                    } else {
                        print("[INSERT] Using accessibility delete for \(charsToDelete) chars")
                        for _ in 0..<charsToDelete {
                            accessibilityService.deleteBackward()
                        }
                    }
                }
                
                // Now switch to normal mode
                setMode(.normal)
                return true // Consume the final key
            }
            print("[INSERT] Buffer after: \(keySequenceParser.pendingKeys)")
        }
        
        // Let the key pass through to the application
        return false
    }
    
    // MARK: - Normal Mode
    
    private func handleNormalModeKey(_ event: KeyEvent) -> Bool {
        let key = event.key
        
        // Handle pending find motion (waiting for character after f/F/t/T)
        if let findType = state.pendingFindType {
            return handleFindCharacter(key, findType: findType, count: state.count)
        }
        
        // Handle multi-key sequences (g commands)
        if !state.keyBuffer.isEmpty {
            return handleMultiKeySequence(key)
        }
        
        // Check for count prefix (digits)
        if let digit = Int(key), (digit > 0 || !countAccumulator.isEmpty) {
            countAccumulator += key
            return true
        }
        
        // Get the count and reset accumulator
        let count = Int(countAccumulator) ?? 1
        countAccumulator = ""
        state.count = count
        
        // Mode switching
        switch key {
        case "i":
            setMode(.insert)
            return true
        case "a":
            if accessibilityService.needsFallbackMode() {
                accessibilityService.simulateMotion(.right, count: 1)
            } else {
                accessibilityService.moveCursor(.right, count: 1)
            }
            setMode(.insert)
            return true
        case "I":
            if accessibilityService.needsFallbackMode() {
                accessibilityService.simulateMotion(.lineStart)
            } else {
                accessibilityService.moveCursor(.lineStart)
            }
            setMode(.insert)
            return true
        case "A":
            if accessibilityService.needsFallbackMode() {
                accessibilityService.simulateMotion(.lineEnd)
            } else {
                accessibilityService.moveCursor(.lineEnd)
            }
            setMode(.insert)
            return true
        case "o":
            if accessibilityService.needsFallbackMode() {
                accessibilityService.simulateMotion(.lineEnd)
                accessibilityService.simulateType("\n")
            } else {
                accessibilityService.moveCursor(.lineEnd)
                accessibilityService.insertText("\n")
            }
            setMode(.insert)
            return true
        case "O":
            if accessibilityService.needsFallbackMode() {
                accessibilityService.simulateMotion(.lineStart)
                accessibilityService.simulateType("\n")
                accessibilityService.simulateMotion(.up, count: 1)
            } else {
                accessibilityService.moveCursor(.lineStart)
                accessibilityService.insertText("\n")
                accessibilityService.moveCursor(.up, count: 1)
            }
            setMode(.insert)
            return true
        case "v":
            setMode(.visual)
            return true
        case "V":
            setMode(.visualLine)
            return true
            
        // Operators
        case "d":
            state.pendingOperator = .delete
            setMode(.operatorPending)
            return true
        case "c":
            state.pendingOperator = .change
            setMode(.operatorPending)
            return true
        case "y":
            state.pendingOperator = .yank
            setMode(.operatorPending)
            return true
            
        // Find motions (f, F, t, T)
        case "f":
            state.pendingFindType = .f
            return true
        case "F":
            state.pendingFindType = .F
            return true
        case "t":
            state.pendingFindType = .t
            return true
        case "T":
            state.pendingFindType = .T
            return true
            
        // Repeat find motions (; and ,)
        case ";":
            if let lastFind = state.lastFindMotion {
                executeFindMotion(lastFind.character, findType: lastFind.findType, count: count)
            }
            return true
        case ",":
            if let lastFind = state.lastFindMotion {
                // Reverse the direction
                let reversedType: FindType
                switch lastFind.findType {
                case .f: reversedType = .F
                case .F: reversedType = .f
                case .t: reversedType = .T
                case .T: reversedType = .t
                }
                executeFindMotion(lastFind.character, findType: reversedType, count: count)
            }
            return true
            
        // Multi-key sequence start (g)
        case "g":
            state.keyBuffer.append(key)
            return true
            
        // Single-key operations
        case "x":
            if accessibilityService.needsFallbackMode() {
                // Fallback: select right then delete
                accessibilityService.simulateSelect(.right, count: count)
                accessibilityService.simulateDelete()
            } else {
                executeDelete(motion: .right, count: count)
            }
            return true
        case "X":
            if accessibilityService.needsFallbackMode() {
                // Fallback: select left then delete
                accessibilityService.simulateSelect(.left, count: count)
                accessibilityService.simulateDelete()
            } else {
                executeDelete(motion: .left, count: count)
            }
            return true
        case "p":
            executePaste(after: true)
            return true
        case "P":
            executePaste(after: false)
            return true
        case "u":
            accessibilityService.undo()
            return true
            
        // Motions
        default:
            if let motion = Motion.from(key: key) {
                // Use fallback mode for WebAreas
                if accessibilityService.needsFallbackMode() {
                    accessibilityService.simulateMotion(motion, count: count)
                } else {
                    accessibilityService.moveCursor(motion, count: count)
                }
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Find Motions (f/F/t/T)
    
    private func handleFindCharacter(_ key: String, findType: FindType, count: Int) -> Bool {
        guard let char = key.first, key.count == 1 else {
            state.pendingFindType = nil
            return false
        }
        
        // Save for repeat with ; and ,
        state.lastFindMotion = FindMotionState(character: char, findType: findType)
        state.pendingFindType = nil
        
        executeFindMotion(char, findType: findType, count: count)
        return true
    }
    
    private func executeFindMotion(_ char: Character, findType: FindType, count: Int) {
        guard let text = accessibilityService.getText(),
              let position = accessibilityService.getCursorPosition() else { return }
        
        let executor = FindMotionExecutor(
            character: char,
            forward: findType.forward,
            tillBefore: findType.tillBefore
        )
        
        let newPosition = executor.execute(from: position, in: text, count: count)
        accessibilityService.setCursorPosition(newPosition)
    }
    
    // MARK: - Multi-Key Sequences (gg, etc.)
    
    private func handleMultiKeySequence(_ key: String) -> Bool {
        state.keyBuffer.append(key)
        let sequence = state.keyBuffer.joined()
        
        switch sequence {
        case "gg":
            accessibilityService.moveCursor(.documentStart, count: state.count)
            state.keyBuffer = []
            return true
        default:
            // Unknown sequence, reset
            state.keyBuffer = []
            return false
        }
    }
    
    // MARK: - Visual Mode
    
    private func handleVisualModeKey(_ event: KeyEvent) -> Bool {
        let key = event.key
        
        // Count prefix
        if let digit = Int(key), (digit > 0 || !countAccumulator.isEmpty) {
            countAccumulator += key
            return true
        }
        
        let count = Int(countAccumulator) ?? 1
        countAccumulator = ""
        
        // Mode switching
        switch key {
        case "v":
            if currentMode == .visual {
                setMode(.normal)
            } else {
                setMode(.visual)
            }
            return true
        case "V":
            if currentMode == .visualLine {
                setMode(.normal)
            } else {
                setMode(.visualLine)
            }
            return true
            
        // Operators on selection
        case "d", "x":
            executeOperatorOnSelection(.delete)
            return true
        case "c", "s":
            executeOperatorOnSelection(.change)
            return true
        case "y":
            executeOperatorOnSelection(.yank)
            return true
            
        // Motions extend selection
        default:
            if let motion = Motion.from(key: key) {
                // In fallback mode, use shift+arrow to extend selection
                if accessibilityService.needsFallbackMode() {
                    accessibilityService.simulateSelect(motion, count: count)
                } else {
                    accessibilityService.extendSelection(motion, count: count)
                }
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Operator Pending Mode
    
    private func handleOperatorPendingKey(_ event: KeyEvent) -> Bool {
        print("[VIM] handleOperatorPendingKey ENTERED: key='\(event.key)' pendingOp=\(String(describing: state.pendingOperator))")
        
        guard let pendingOp = state.pendingOperator else {
            print("[VIM] handleOperatorPendingKey: NO PENDING OPERATOR, resetting to normal")
            setMode(.normal)
            return false
        }
        
        let key = event.key
        print("[VIM] handleOperatorPendingKey: key='\(key)' pendingOp=\(pendingOp) pendingTextObjectInner=\(String(describing: state.pendingTextObjectInner))")
        
        // Handle pending find motion (df{char}, ct{char}, etc.)
        if let findType = state.pendingFindType {
            return handleOperatorWithFindMotion(pendingOp, key: key, findType: findType)
        }
        
        // Handle pending text object (diw, ci", etc.)
        if let inner = state.pendingTextObjectInner {
            print("[VIM] Processing text object with key='\(key)' inner=\(inner)")
            return handleOperatorWithTextObject(pendingOp, key: key, inner: inner)
        }
        
        // Count prefix
        if let digit = Int(key), (digit > 0 || !countAccumulator.isEmpty) {
            countAccumulator += key
            return true
        }
        
        let count = (Int(countAccumulator) ?? 1) * state.count
        countAccumulator = ""
        
        // Double operator means line operation (dd, cc, yy)
        if key == pendingOp.rawValue {
            executeLineOperation(pendingOp, count: count)
            setMode(pendingOp.entersInsertMode ? .insert : .normal)
            state.reset()
            return true
        }
        
        // Text object modifiers (i = inner, a = around)
        if key == "i" {
            print("[VIM] Setting pendingTextObjectInner = true")
            state.pendingTextObjectInner = true
            return true
        }
        if key == "a" {
            print("[VIM] Setting pendingTextObjectInner = false (around)")
            state.pendingTextObjectInner = false
            return true
        }
        
        // Find motions (df{char}, ct{char}, etc.)
        switch key {
        case "f":
            state.pendingFindType = .f
            return true
        case "F":
            state.pendingFindType = .F
            return true
        case "t":
            state.pendingFindType = .t
            return true
        case "T":
            state.pendingFindType = .T
            return true
        default:
            break
        }
        
        // Motion completes the operator
        if let motion = Motion.from(key: key) {
            executeOperatorWithMotion(pendingOp, motion: motion, count: count)
            setMode(pendingOp.entersInsertMode ? .insert : .normal)
            state.reset()
            return true
        }
        
        // Invalid key, cancel operator
        setMode(.normal)
        state.reset()
        return false
    }
    
    // MARK: - Operator with Find Motion (df{char}, ct{char}, etc.)
    
    private func handleOperatorWithFindMotion(_ op: OperatorType, key: String, findType: FindType) -> Bool {
        guard let char = key.first, key.count == 1 else {
            state.reset()
            setMode(.normal)
            return false
        }
        
        guard let text = accessibilityService.getText(),
              let position = accessibilityService.getCursorPosition() else {
            state.reset()
            setMode(.normal)
            return false
        }
        
        let executor = FindMotionExecutor(
            character: char,
            forward: findType.forward,
            tillBefore: findType.tillBefore
        )
        
        let range = executor.getRange(from: position, in: text, count: state.count)
        
        // Get text for register
        let startIdx = text.index(text.startIndex, offsetBy: range.lowerBound)
        let endIdx = text.index(text.startIndex, offsetBy: min(range.upperBound, text.count))
        let affectedText = String(text[startIdx..<endIdx])
        
        state.registers[state.register] = RegisterContent(text: affectedText)
        
        // Save for repeat
        state.lastFindMotion = FindMotionState(character: char, findType: findType)
        
        if op.deletesText {
            accessibilityService.setSelectedRange(CFRange(location: range.lowerBound, length: range.count))
            accessibilityService.deleteSelection()
        }
        
        setMode(op.entersInsertMode ? .insert : .normal)
        state.reset()
        return true
    }
    
    // MARK: - Operator with Text Object (diw, ci", etc.)
    
    private func handleOperatorWithTextObject(_ op: OperatorType, key: String, inner: Bool) -> Bool {
        print("[VIM] handleOperatorWithTextObject: op=\(op) key=\(key) inner=\(inner)")
        
        // In fallback mode, handle common text objects with keyboard simulation
        let needsFallback = accessibilityService.needsFallbackMode()
        print("[VIM] needsFallbackMode = \(needsFallback)")
        
        if needsFallback {
            print("[VIM] Using fallback mode for text object")
            return handleTextObjectFallback(op: op, key: key, inner: inner)
        }
        
        guard let textObject = getTextObject(for: key) else {
            state.reset()
            setMode(.normal)
            return false
        }
        
        guard let text = accessibilityService.getText(),
              let position = accessibilityService.getCursorPosition() else {
            state.reset()
            setMode(.normal)
            return false
        }
        
        guard let range = textObject.getRange(around: position, in: text, inner: inner) else {
            state.reset()
            setMode(.normal)
            return false
        }
        
        // Get text for register
        let startIdx = text.index(text.startIndex, offsetBy: range.lowerBound)
        let endIdx = text.index(text.startIndex, offsetBy: min(range.upperBound, text.count))
        let affectedText = String(text[startIdx..<endIdx])
        
        state.registers[state.register] = RegisterContent(text: affectedText)
        
        if op.deletesText {
            accessibilityService.setSelectedRange(CFRange(location: range.lowerBound, length: range.count))
            accessibilityService.deleteSelection()
        }
        
        setMode(op.entersInsertMode ? .insert : .normal)
        state.reset()
        return true
    }
    
    /// Handle text objects in fallback mode using keyboard simulation
    private func handleTextObjectFallback(op: OperatorType, key: String, inner: Bool) -> Bool {
        print("[VIM] handleTextObjectFallback: op=\(op) key=\(key) inner=\(inner)")
        
        switch key {
        case "w", "W":
            // iw/aw = inner/around word
            if inner {
                accessibilityService.simulateSelectInnerWord()
            } else {
                accessibilityService.simulateSelectAroundWord()
            }
        case "$":
            // To end of line
            accessibilityService.simulateSelectToEndOfLine()
        case "0", "^":
            // To start of line
            accessibilityService.simulateSelectToStartOfLine()
        default:
            // Unsupported text object in fallback mode
            print("[VIM] Unsupported text object '\(key)' in fallback mode")
            state.reset()
            setMode(.normal)
            return false
        }
        
        // Now perform the operation
        if op.deletesText {
            accessibilityService.simulateDelete()
        } else if op == .yank {
            accessibilityService.simulateCopy()
            // Deselect by pressing Right then Left
            accessibilityService.simulateKeyPress(keyCode: 124)
            accessibilityService.simulateKeyPress(keyCode: 123)
        }
        
        setMode(op.entersInsertMode ? .insert : .normal)
        state.reset()
        return true
    }
    
    /// Returns the appropriate TextObject for a given key
    private func getTextObject(for key: String) -> TextObject? {
        switch key {
        case "w":
            return WordTextObject()
        case "W":
            return BigWordTextObject()
        case "\"":
            return QuotedTextObject(quoteChar: "\"")
        case "'":
            return QuotedTextObject(quoteChar: "'")
        case "`":
            return QuotedTextObject(quoteChar: "`")
        case "(", ")", "b":
            return BracketTextObject(type: .parentheses)
        case "[", "]":
            return BracketTextObject(type: .square)
        case "{", "}", "B":
            return BracketTextObject(type: .curly)
        case "<", ">":
            return BracketTextObject(type: .angle)
        case "s":
            return SentenceTextObject()
        case "p":
            return ParagraphTextObject()
        default:
            return nil
        }
    }
    
    // MARK: - Command Execution
    
    private func executeDelete(motion: Motion, count: Int) {
        // In fallback mode, use keyboard simulation
        if accessibilityService.needsFallbackMode() {
            accessibilityService.simulateDeleteWithMotion(motion, count: count)
            return
        }
        
        let text = accessibilityService.getTextForMotion(motion, count: count)
        if let text = text {
            state.registers[state.register] = RegisterContent(text: text)
        }
        accessibilityService.deleteWithMotion(motion, count: count)
    }
    
    private func executeOperatorWithMotion(_ op: OperatorType, motion: Motion, count: Int) {
        print("[VIM] executeOperatorWithMotion: op=\(op) motion=\(motion) count=\(count) fallback=\(accessibilityService.needsFallbackMode())")
        
        // In fallback mode, use keyboard simulation
        if accessibilityService.needsFallbackMode() {
            if op.deletesText {
                print("[VIM] Fallback: simulateDeleteWithMotion")
                accessibilityService.simulateDeleteWithMotion(motion, count: count)
            }
            // Note: yank in fallback mode would need clipboard access
            return
        }
        
        let text = accessibilityService.getTextForMotion(motion, count: count)
        
        if let text = text {
            state.registers[state.register] = RegisterContent(text: text)
        }
        
        if op.deletesText {
            accessibilityService.deleteWithMotion(motion, count: count)
        }
    }
    
    private func executeLineOperation(_ op: OperatorType, count: Int) {
        // In fallback mode, use keyboard simulation
        if accessibilityService.needsFallbackMode() {
            if op.deletesText {
                accessibilityService.simulateDeleteLine(count: count)
            }
            // Note: yank in fallback mode would need clipboard access
            return
        }
        
        let text = accessibilityService.getCurrentLines(count: count)
        
        if let text = text {
            state.registers[state.register] = RegisterContent(text: text, isLinewise: true)
        }
        
        if op.deletesText {
            accessibilityService.deleteLines(count: count)
        }
    }
    
    private func executeOperatorOnSelection(_ op: OperatorType) {
        // In fallback mode, use keyboard simulation
        if accessibilityService.needsFallbackMode() {
            if op == .yank {
                // Copy selection to clipboard
                accessibilityService.simulateCopy()
            } else if op.deletesText {
                // Delete selection (backspace on selected text)
                accessibilityService.simulateDelete()
            }
            setMode(op.entersInsertMode ? .insert : .normal)
            return
        }
        
        let text = accessibilityService.getSelectedText()
        
        if let text = text {
            let isLinewise = currentMode == .visualLine
            state.registers[state.register] = RegisterContent(text: text, isLinewise: isLinewise)
        }
        
        if op.deletesText {
            accessibilityService.deleteSelection()
        }
        
        setMode(op.entersInsertMode ? .insert : .normal)
    }
    
    private func executePaste(after: Bool) {
        guard let content = state.registers[state.register] else { return }
        
        if content.isLinewise {
            if after {
                accessibilityService.moveCursor(.lineEnd)
                accessibilityService.insertText("\n" + content.text.trimmingCharacters(in: .newlines))
            } else {
                accessibilityService.moveCursor(.lineStart)
                accessibilityService.insertText(content.text.trimmingCharacters(in: .newlines) + "\n")
                accessibilityService.moveCursor(.up, count: 1)
            }
        } else {
            if after {
                accessibilityService.moveCursor(.right, count: 1)
            }
            accessibilityService.insertText(content.text)
        }
    }
}
