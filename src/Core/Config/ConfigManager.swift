import Foundation

/// Configuration manager for Assula
/// Handles loading/saving config from ~/.config/assula/config.json
class ConfigManager {
    static let shared = ConfigManager()
    
    /// Current configuration
    private(set) var config: AssulaConfig
    
    /// Path to config directory
    private let configDirectory: URL
    
    /// Path to config file
    private let configFile: URL
    
    private init() {
        // Set up config paths
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        configDirectory = homeDir.appendingPathComponent(".config/assula")
        configFile = configDirectory.appendingPathComponent("config.json")
        
        // Load or create default config
        config = ConfigManager.loadConfig(from: configFile) ?? AssulaConfig.default
        
        // Ensure config directory exists
        createConfigDirectoryIfNeeded()
    }
    
    // MARK: - Config Operations
    
    /// Reloads configuration from disk
    func reload() {
        if let loaded = ConfigManager.loadConfig(from: configFile) {
            config = loaded
            print("Configuration reloaded from \(configFile.path)")
        }
    }
    
    /// Saves current configuration to disk
    func save() {
        createConfigDirectoryIfNeeded()
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let data = try encoder.encode(config)
            try data.write(to: configFile)
            print("Configuration saved to \(configFile.path)")
        } catch {
            print("Failed to save configuration: \(error)")
        }
    }
    
    /// Updates configuration with new values
    func update(_ newConfig: AssulaConfig) {
        config = newConfig
        save()
    }
    
    // MARK: - Ignored Apps Management
    
    /// Adds an app to the ignored list
    func addIgnoredApp(_ bundleId: String) {
        guard !config.ignoredApps.contains(bundleId) else { return }
        config.ignoredApps.append(bundleId)
        save()
        NotificationCenter.default.post(name: .assulaConfigChanged, object: nil)
    }
    
    /// Removes an app from the ignored list
    func removeIgnoredApp(_ bundleId: String) {
        config.ignoredApps.removeAll { $0 == bundleId }
        save()
        NotificationCenter.default.post(name: .assulaConfigChanged, object: nil)
    }
    
    /// Checks if an app is in the ignored list
    func isAppIgnored(_ bundleId: String) -> Bool {
        config.ignoredApps.contains(bundleId)
    }
    
    /// Toggles an app's ignored status
    func toggleIgnoredApp(_ bundleId: String) {
        if isAppIgnored(bundleId) {
            removeIgnoredApp(bundleId)
        } else {
            addIgnoredApp(bundleId)
        }
    }
    
    // MARK: - Helpers
    
    private func createConfigDirectoryIfNeeded() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: configDirectory.path) {
            do {
                try fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
            } catch {
                print("Failed to create config directory: \(error)")
            }
        }
    }
    
    private static func loadConfig(from url: URL) -> AssulaConfig? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(AssulaConfig.self, from: data)
        } catch {
            print("Failed to load configuration: \(error)")
            return nil
        }
    }
}

/// Assula configuration structure
struct AssulaConfig: Codable {
    // MARK: - Escape Sequence
    
    /// The key sequence to exit insert mode (e.g., "jk")
    var escapeSequence: String
    
    /// Timeout in milliseconds for escape sequence
    var escapeTimeoutMs: Int
    
    // MARK: - Behavior
    
    /// Start in insert mode when app launches
    var startInInsertMode: Bool
    
    /// Show mode indicator in menu bar
    var showMenuBarIndicator: Bool
    
    /// Show floating mode indicator window
    var showFloatingIndicator: Bool
    
    // MARK: - SketchyBar Integration
    
    /// Enable SketchyBar integration
    var sketchyBarEnabled: Bool
    
    /// Custom SketchyBar event name
    var sketchyBarEventName: String
    
    // MARK: - App-Specific Settings
    
    /// Apps to completely ignore (bundle identifiers)
    var ignoredApps: [String]
    
    /// Apps that should use fallback mode even if they support accessibility
    var fallbackApps: [String]
    
    // MARK: - Advanced
    
    /// Key repeat rate when holding a key in normal mode
    var keyRepeatRateMs: Int
    
    /// Initial delay before key repeat starts
    var keyRepeatDelayMs: Int
    
    // MARK: - Default Configuration
    
    static let `default` = AssulaConfig(
        escapeSequence: "jk",
        escapeTimeoutMs: 200,
        startInInsertMode: true,
        showMenuBarIndicator: true,
        showFloatingIndicator: false,
        sketchyBarEnabled: true,
        sketchyBarEventName: "app.assula.modeChanged",
        ignoredApps: [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "io.alacritty",
            "com.mitchellh.ghostty",
            "com.github.wez.wezterm"
        ],
        fallbackApps: [],
        keyRepeatRateMs: 35,
        keyRepeatDelayMs: 500
    )
    
    // MARK: - Computed Properties
    
    var escapeSequenceChars: [String] {
        escapeSequence.map { String($0) }
    }
    
    var escapeTimeoutSeconds: TimeInterval {
        TimeInterval(escapeTimeoutMs) / 1000.0
    }
}

// MARK: - Config Change Notification

extension Notification.Name {
    static let assulaConfigChanged = Notification.Name("app.assula.configChanged")
}
