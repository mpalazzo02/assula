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
            
            IntegrationsSettingsView()
                .tabItem {
                    Label("Integrations", systemImage: "puzzlepiece")
                }
            
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
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
