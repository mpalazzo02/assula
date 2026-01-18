import SwiftUI

@main
struct AssulaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var vimEngine = VimEngine.shared
    @StateObject private var menuState = MenuBarState.shared
    
    var body: some Scene {
        // Menu bar using SwiftUI MenuBarExtra
        MenuBarExtra {
            MenuBarMenu()
        } label: {
            Text(vimEngine.currentMode.menuBarSymbol)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .menuBarExtraStyle(.menu)
        
        Settings {
            SettingsView()
        }
    }
}

// MARK: - Menu Bar Menu View

struct MenuBarMenu: View {
    @ObservedObject private var vimEngine = VimEngine.shared
    @ObservedObject private var menuState = MenuBarState.shared
    @Environment(\.openSettings) private var openSettings
    
    var body: some View {
        Text("Assula v0.1.0")
        
        Divider()
        
        Text("Mode: \(vimEngine.currentMode.displayName)")
        
        Divider()
        
        if !menuState.currentAppBundleId.isEmpty {
            Button {
                menuState.toggleCurrentApp()
            } label: {
                if menuState.isCurrentAppIgnored {
                    Text("Enable for \(menuState.currentAppName)")
                } else {
                    Text("Disable for \(menuState.currentAppName)")
                }
            }
            
            Divider()
        }
        
        Button("Settings...") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
        
        Divider()
        
        Button("Quit Assula") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

// MARK: - Menu Bar State

class MenuBarState: ObservableObject {
    static let shared = MenuBarState()
    
    @Published var currentAppName: String = ""
    @Published var currentAppBundleId: String = ""
    @Published var isCurrentAppIgnored: Bool = false
    
    private init() {
        updateCurrentApp()
        
        // Observe frontmost app changes
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.updateCurrentApp()
        }
    }
    
    func updateCurrentApp() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleId = app.bundleIdentifier,
              bundleId != Bundle.main.bundleIdentifier else {
            currentAppName = ""
            currentAppBundleId = ""
            isCurrentAppIgnored = false
            return
        }
        
        currentAppName = app.localizedName ?? bundleId
        currentAppBundleId = bundleId
        isCurrentAppIgnored = ConfigManager.shared.isAppIgnored(bundleId)
    }
    
    func toggleCurrentApp() {
        guard !currentAppBundleId.isEmpty else { return }
        ConfigManager.shared.toggleIgnoredApp(currentAppBundleId)
        isCurrentAppIgnored = ConfigManager.shared.isAppIgnored(currentAppBundleId)
    }
}

// MARK: - VimMode Extensions for Menu Bar

extension VimMode {
    var menuBarSymbol: String {
        switch self {
        case .normal: return " N "
        case .insert: return " I "
        case .visual: return " V "
        case .visualLine: return " VL "
        case .operatorPending: return " O "
        }
    }
    
    var menuBarColor: Color {
        switch self {
        case .normal: return .blue
        case .insert: return .green
        case .visual: return .yellow
        case .visualLine: return .orange
        case .operatorPending: return .purple
        }
    }
}
