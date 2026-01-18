import Foundation

/// Client for communicating with SketchyBar
class SketchyBarClient {
    static let shared = SketchyBarClient()
    
    /// The notification name for mode changes
    static let modeChangeNotification = "app.assula.modeChanged"
    
    private init() {}
    
    /// Notifies SketchyBar of a mode change via NSDistributedNotificationCenter
    func notifyModeChange(_ mode: VimMode) {
        DistributedNotificationCenter.default().post(
            name: Notification.Name(Self.modeChangeNotification),
            object: nil,
            userInfo: ["mode": mode.rawValue]
        )
        
        // Also trigger via CLI for immediate update
        triggerEvent(mode: mode)
    }
    
    /// Triggers a SketchyBar event directly via CLI
    private func triggerEvent(mode: VimMode) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/sketchybar")
        task.arguments = ["--trigger", "assula_mode_change", "MODE=\(mode.rawValue)"]
        
        // Run in background, don't block
        DispatchQueue.global(qos: .utility).async {
            do {
                try task.run()
            } catch {
                // SketchyBar might not be installed, that's fine
                print("SketchyBar trigger failed (probably not installed): \(error)")
            }
        }
    }
}
