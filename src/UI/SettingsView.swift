import SwiftUI

struct SettingsView: View {
    @AppStorage("escapeSequence") private var escapeSequence = "jk"
    @AppStorage("escapeTimeout") private var escapeTimeout = 200.0
    @AppStorage("showModeIndicator") private var showModeIndicator = true
    @AppStorage("startInInsertMode") private var startInInsertMode = true
    
    var body: some View {
        TabView {
            GeneralSettingsView(
                escapeSequence: $escapeSequence,
                escapeTimeout: $escapeTimeout,
                showModeIndicator: $showModeIndicator,
                startInInsertMode: $startInInsertMode
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            AppsSettingsView()
                .tabItem {
                    Label("Apps", systemImage: "app.badge.checkmark")
                }
            
            IntegrationsSettingsView()
                .tabItem {
                    Label("Integrations", systemImage: "puzzlepiece")
                }
            
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 380)
    }
}

struct GeneralSettingsView: View {
    @Binding var escapeSequence: String
    @Binding var escapeTimeout: Double
    @Binding var showModeIndicator: Bool
    @Binding var startInInsertMode: Bool
    
    var body: some View {
        Form {
            Section {
                TextField("Escape Sequence:", text: $escapeSequence)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .help("Type this sequence quickly to exit Insert mode (e.g., 'jk')")
                
                HStack {
                    Text("Escape Timeout:")
                    Slider(value: $escapeTimeout, in: 100...500, step: 50)
                    Text("\(Int(escapeTimeout))ms")
                        .monospacedDigit()
                        .frame(width: 50)
                }
                .help("Maximum time between keys for escape sequence")
            } header: {
                Text("Escape Sequence")
            }
            
            Section {
                Toggle("Show mode in menu bar", isOn: $showModeIndicator)
                Toggle("Start in Insert mode", isOn: $startInInsertMode)
            } header: {
                Text("Behavior")
            }
        }
        .padding()
    }
}

// MARK: - Apps Settings

/// Represents an app with its metadata for display
struct AppInfo: Identifiable, Hashable {
    let id: String  // bundle ID
    let name: String
    let icon: NSImage?
    
    var bundleId: String { id }
    
    static func from(bundleId: String) -> AppInfo {
        // Try to find app info from bundle ID
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return from(url: appURL, bundleId: bundleId)
        }
        // Fallback: just show bundle ID
        return AppInfo(id: bundleId, name: bundleId, icon: nil)
    }
    
    static func from(url: URL, bundleId: String? = nil) -> AppInfo {
        let bundle = Bundle(url: url)
        let resolvedBundleId = bundleId ?? bundle?.bundleIdentifier ?? url.lastPathComponent
        let name = bundle?.infoDictionary?["CFBundleName"] as? String
            ?? bundle?.infoDictionary?["CFBundleDisplayName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        
        return AppInfo(id: resolvedBundleId, name: name, icon: icon)
    }
}

struct AppsSettingsView: View {
    @State private var ignoredApps: [AppInfo] = []
    @State private var showingFilePicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ignored Applications")
                .font(.headline)
            
            Text("Assula will be completely disabled in these applications.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // List of ignored apps
            List {
                ForEach(ignoredApps) { app in
                    HStack(spacing: 12) {
                        // App icon
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "app")
                                .frame(width: 24, height: 24)
                        }
                        
                        // App name and bundle ID
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .fontWeight(.medium)
                            Text(app.bundleId)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Remove button
                        Button(action: {
                            removeApp(app.bundleId)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Remove from ignored apps")
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.bordered)
            .frame(minHeight: 150)
            
            // Add button
            HStack {
                Button(action: {
                    showingFilePicker = true
                }) {
                    Label("Add Application...", systemImage: "plus")
                }
                
                Spacer()
                
                Text("\(ignoredApps.count) app\(ignoredApps.count == 1 ? "" : "s") ignored")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            loadIgnoredApps()
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
    }
    
    private func loadIgnoredApps() {
        let bundleIds = ConfigManager.shared.config.ignoredApps
        ignoredApps = bundleIds.map { AppInfo.from(bundleId: $0) }
    }
    
    private func removeApp(_ bundleId: String) {
        ConfigManager.shared.removeIgnoredApp(bundleId)
        loadIgnoredApps()
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result,
              let url = urls.first else { return }
        
        // Get bundle ID from the selected app
        guard let bundle = Bundle(url: url),
              let bundleId = bundle.bundleIdentifier else {
            print("[Settings] Could not get bundle ID from \(url.path)")
            return
        }
        
        ConfigManager.shared.addIgnoredApp(bundleId)
        loadIgnoredApps()
    }
}

struct IntegrationsSettingsView: View {
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("SketchyBar Integration")
                        .font(.headline)
                    
                    Text("Assula broadcasts mode changes via NSDistributedNotificationCenter. Add this to your sketchybarrc:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView {
                        Text(sketchyBarConfig)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .background(Color.black.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .frame(height: 120)
                    
                    Button("Copy to Clipboard") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(sketchyBarConfig, forType: .string)
                    }
                }
            }
        }
        .padding()
    }
    
    private var sketchyBarConfig: String {
        """
        # Assula SketchyBar Integration
        sketchybar --add event assula_mode_change "app.assula.modeChanged"
        sketchybar --add item assula left \\
                   --set assula script="~/.config/sketchybar/plugins/assula.sh" \\
                   --subscribe assula assula_mode_change
        """
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            Text("Assula")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Version 0.1.0")
                .foregroundColor(.secondary)
            
            Text("Open-source Vim mode for macOS")
                .font(.caption)
            
            Divider()
            
            Link("View on GitHub", destination: URL(string: "https://github.com/your-username/assula")!)
            
            Text("MIT License")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
