import Cocoa
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    
    private let vimEngine = VimEngine.shared
    private let keyboardMonitor = KeyboardMonitor.shared
    private let sketchyBarClient = SketchyBarClient.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        requestAccessibilityPermissions()
        setupModeObserver()
        startKeyboardMonitor()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor.stop()
    }
    
    // MARK: - Setup
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateStatusBarIcon(for: .insert)
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Assula v0.1.0", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let modeItem = NSMenuItem(title: "Mode: Insert", action: nil, keyEquivalent: "")
        modeItem.tag = 100
        menu.addItem(modeItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Assula", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    private func updateStatusBarIcon(for mode: VimMode) {
        guard let button = statusItem?.button else { return }
        
        let symbol: String
        let color: NSColor
        
        switch mode {
        case .normal:
            symbol = "N"
            color = .systemBlue
        case .insert:
            symbol = "I"
            color = .systemGreen
        case .visual:
            symbol = "V"
            color = .systemYellow
        case .visualLine:
            symbol = "VL"
            color = .systemOrange
        case .operatorPending:
            symbol = "O"
            color = .systemPurple
        }
        
        let attributed = NSAttributedString(
            string: " \(symbol) ",
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold),
                .foregroundColor: color
            ]
        )
        button.attributedTitle = attributed
        
        // Update menu item
        if let menu = statusItem?.menu,
           let modeItem = menu.item(withTag: 100) {
            modeItem.title = "Mode: \(mode.displayName)"
        }
    }
    
    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if !trusted {
            print("⚠️ Accessibility permissions not granted. Please enable in System Settings > Privacy & Security > Accessibility")
        } else {
            print("✅ Accessibility permissions granted")
        }
    }
    
    private func setupModeObserver() {
        vimEngine.$currentMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.updateStatusBarIcon(for: mode)
                self?.sketchyBarClient.notifyModeChange(mode)
            }
            .store(in: &cancellables)
    }
    
    private func startKeyboardMonitor() {
        do {
            try keyboardMonitor.start()
            print("✅ Keyboard monitor started")
        } catch {
            print("❌ Failed to start keyboard monitor: \(error)")
        }
    }
    
    // MARK: - Actions
    
    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
