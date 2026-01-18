import Cocoa
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var cancellables = Set<AnyCancellable>()
    
    private let vimEngine = VimEngine.shared
    private let keyboardMonitor = KeyboardMonitor.shared
    private let sketchyBarClient = SketchyBarClient.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityPermissions()
        setupModeObserver()
        startKeyboardMonitor()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor.stop()
    }
    
    // MARK: - Setup
    
    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if !trusted {
            print("[Assula] Accessibility permissions not granted. Please enable in System Settings > Privacy & Security > Accessibility")
        } else {
            print("[Assula] Accessibility permissions granted")
        }
    }
    
    private func setupModeObserver() {
        vimEngine.$currentMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.sketchyBarClient.notifyModeChange(mode)
            }
            .store(in: &cancellables)
    }
    
    private func startKeyboardMonitor() {
        do {
            try keyboardMonitor.start()
            print("[Assula] Keyboard monitor started")
        } catch {
            print("[Assula] Failed to start keyboard monitor: \(error)")
        }
    }
}
