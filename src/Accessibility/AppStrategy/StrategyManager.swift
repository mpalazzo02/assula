import Foundation
import Cocoa

/// Manages app-specific strategies and provides the appropriate strategy for the current app
class StrategyManager {
    static let shared = StrategyManager()
    
    /// All registered strategies
    private var strategies: [String: AppStrategy] = [:]
    
    /// Default strategy for unknown apps
    private let defaultStrategy = DefaultStrategy()
    
    /// Fallback strategy for apps that don't support accessibility
    private let fallbackStrategy = FallbackStrategy()
    
    /// Currently active strategy
    private(set) var currentStrategy: AppStrategy
    
    /// Currently active app bundle identifier
    private(set) var currentBundleId: String?
    
    private init() {
        currentStrategy = defaultStrategy
        registerAllStrategies()
        
        // Observe app activation changes
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    // MARK: - Strategy Registration
    
    private func registerAllStrategies() {
        // Browsers
        register(SafariStrategy())
        register(ChromeStrategy())
        register(FirefoxStrategy())
        register(ArcStrategy())
        
        // Native Apps
        register(MailStrategy())
        register(NotesStrategy())
        register(TextEditStrategy())
        register(XcodeStrategy())
        
        // Electron Apps
        register(VSCodeStrategy())
        register(SlackStrategy())
        register(DiscordStrategy())
        
        // Terminal (special handling - mostly disabled)
        register(TerminalStrategy())
    }
    
    private func register(_ strategy: AppStrategy) {
        let bundleIds = type(of: strategy).bundleIdentifiers
        for bundleId in bundleIds {
            strategies[bundleId] = strategy
        }
    }
    
    // MARK: - Strategy Selection
    
    /// Gets the strategy for a given bundle identifier
    func strategy(for bundleId: String?) -> AppStrategy {
        guard let bundleId = bundleId else {
            return defaultStrategy
        }
        
        return strategies[bundleId] ?? defaultStrategy
    }
    
    /// Updates the current strategy based on the frontmost app
    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else {
            return
        }
        
        let oldBundleId = currentBundleId
        currentBundleId = bundleId
        
        // Notify old strategy of deactivation
        if oldBundleId != bundleId {
            currentStrategy.onAppDeactivated()
            
            // Reset to Insert mode when switching apps
            // This ensures a clean state and avoids confusion
            VimEngine.shared.setMode(.insert)
            print("[Strategy] App switch: Reset to Insert mode")
        }
        
        // Get and activate new strategy
        currentStrategy = strategy(for: bundleId)
        currentStrategy.onAppActivated()
        
        // Also reset KeyboardMonitor's text field tracking
        KeyboardMonitor.shared.resetTextFieldTracking()
        
        print("App activated: \(bundleId) -> Strategy: \(type(of: currentStrategy))")
    }
    
    /// Manually refresh the current strategy (call when app state might have changed)
    func refreshCurrentStrategy() {
        if let app = NSWorkspace.shared.frontmostApplication {
            currentBundleId = app.bundleIdentifier
            currentStrategy = strategy(for: currentBundleId)
        }
    }
    
    // MARK: - Accessibility Queries
    
    /// Checks if the current app supports accessibility text manipulation
    var currentAppSupportsAccessibility: Bool {
        currentStrategy.supportsAccessibility
    }
    
    /// Checks if a specific app supports accessibility
    func appSupportsAccessibility(bundleId: String?) -> Bool {
        strategy(for: bundleId).supportsAccessibility
    }
    
    /// Gets all registered bundle identifiers
    var registeredBundleIdentifiers: [String] {
        Array(strategies.keys)
    }
}
