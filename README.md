# Assula

Open-source Vim mode for macOS. Brings Vim-style modal editing to any application using the macOS Accessibility APIs.

## Features

### Modes
- **Normal** - Navigation and commands
- **Insert** - Text input (passthrough)
- **Visual** - Character-wise selection
- **Visual Line** - Line-wise selection
- **Operator Pending** - Waiting for motion/text object

### Motions
- `h`, `j`, `k`, `l` - Character movement (left, down, up, right)
- `w`, `b`, `e` - Word forward, backward, end
- `W`, `B`, `E` - WORD forward, backward, end (whitespace-delimited)
- `0`, `$` - Line start, line end
- `^` - First non-blank character
- `gg`, `G` - Document start, document end
- `f`, `F`, `t`, `T` - Find character (forward/backward, to/till)
- `;`, `,` - Repeat find motion (same/reverse direction)

### Operators
- `d{motion}` - Delete
- `c{motion}` - Change (delete and enter Insert mode)
- `y{motion}` - Yank (copy)
- `dd`, `cc`, `yy` - Operate on entire line
- `x`, `X` - Delete character under/before cursor
- `p`, `P` - Paste after/before cursor
- `u` - Undo

### Text Objects
- `iw`, `aw` - Inner/around word
- `iW`, `aW` - Inner/around WORD
- `i"`, `a"` - Inner/around double quotes
- `i'`, `a'` - Inner/around single quotes
- `i(`, `a(` / `ib`, `ab` - Inner/around parentheses
- `i[`, `a[` - Inner/around square brackets
- `i{`, `a{` / `iB`, `aB` - Inner/around curly braces
- `i<`, `a<` - Inner/around angle brackets
- `is`, `as` - Inner/around sentence
- `ip`, `ap` - Inner/around paragraph

### Other Features
- **Count prefixes**: `3w`, `5j`, `2dd`, etc.
- **Escape sequence**: `jk` (configurable) to exit Insert mode
- **Menu bar indicator**: Shows current mode (N/I/V/VL/O)
- **SketchyBar integration**: Real-time mode indicator in your status bar
- **Fallback mode**: Keyboard simulation for apps without full Accessibility support

## Requirements

- macOS 14.0 (Sonoma) or later
- Accessibility permissions (prompted on first launch)

## Installation

### From Source

```bash
git clone https://github.com/mpalazzo02/assula.git
cd assula
open Assula.xcodeproj
```

Build and run with Xcode (Cmd+R).

### Homebrew (coming soon)

```bash
brew install --cask assula
```

## Usage

1. Launch Assula - it runs in the menu bar
2. Grant Accessibility permissions when prompted
3. Start using Vim motions in any text field!

### Modes

| Mode | Enter | Exit |
|------|-------|------|
| Normal | `Esc` or `jk` | - |
| Insert | `i`, `a`, `I`, `A`, `o`, `O` | `Esc` or `jk` |
| Visual | `v` | `Esc` or `v` |
| Visual Line | `V` | `Esc` or `V` |

### Mode Switching
- `i` - Insert before cursor
- `a` - Insert after cursor
- `I` - Insert at line start
- `A` - Insert at line end
- `o` - Open line below
- `O` - Open line above

## Configuration

Configuration file location: `~/.config/assula/config.json`

```json
{
    "escapeSequence": "jk",
    "escapeTimeoutMs": 200,
    "startInInsertMode": true,
    "ignoredApps": ["com.apple.Terminal"]
}
```

Settings are also available via the menu bar icon -> Settings (Cmd+,).

## Supported Applications

### Full Support (Accessibility API)
Apps with full text manipulation support:
- TextEdit
- Notes
- Xcode
- Most native macOS apps with standard text fields

### Fallback Mode (Keyboard Simulation)
Apps where Accessibility APIs don't provide full text access use keyboard simulation:
- Safari, Chrome, Firefox, Arc (text fields)
- Mail compose window (WebArea)
- VS Code
- Electron-based apps
- Raycast

In fallback mode, basic motions (`h`, `j`, `k`, `l`, `w`, `b`, `e`) and operators work via arrow key simulation.

## SketchyBar Integration

Assula can notify SketchyBar of mode changes. Add this to your `~/.config/sketchybar/sketchybarrc`:

```bash
sketchybar --add item assula left \
           --set assula script="~/.config/sketchybar/plugins/assula.sh" \
                       icon.drawing=off \
                       label.font="JetBrainsMono Nerd Font:Bold:12.0"
```

Example plugin script (`~/.config/sketchybar/plugins/assula.sh`):

```bash
#!/bin/bash
MODE="$INFO"
case $MODE in
    "NORMAL") sketchybar --set assula label=" N " label.color=0xff8aadf4 ;;
    "INSERT") sketchybar --set assula label=" I " label.color=0xffa6da95 ;;
    "VISUAL") sketchybar --set assula label=" V " label.color=0xffeed49f ;;
    "VISUAL_LINE") sketchybar --set assula label=" VL " label.color=0xfff5a97f ;;
    *) sketchybar --set assula label=" ? " ;;
esac
```

## Architecture

```
src/
├── App/                    # SwiftUI app entry, AppDelegate, menu bar
├── Core/
│   ├── Config/            # ConfigManager (~/.config/assula/config.json)
│   ├── Motions/           # Motion implementations
│   │   ├── Motion.swift           # Motion enum
│   │   ├── CharacterMotions.swift # h, j, k, l
│   │   ├── WordMotions.swift      # w, b, e, W, B, E
│   │   ├── LineMotions.swift      # 0, $, ^, gg, G
│   │   ├── FindMotions.swift      # f, F, t, T
│   │   └── SearchMotions.swift    # /, ?, n, N (planned)
│   ├── TextObjects/       # Text object implementations (iw, aw, etc.)
│   └── VimEngine/         # Core state machine
│       ├── VimMode.swift          # Mode enum
│       ├── VimState.swift         # State, registers, operators
│       ├── VimEngine.swift        # Main key processing
│       └── KeySequence.swift      # Escape sequence parser
├── Accessibility/
│   ├── AccessibilityService.swift # AX API wrapper + fallback mode
│   └── AppStrategy/               # Per-app behavior strategies
├── Input/
│   └── KeyboardMonitor.swift      # CGEventTap global key capture
├── Integrations/
│   └── SketchyBar/               # SketchyBar notifications
├── UI/
│   └── SettingsView.swift        # SwiftUI preferences
└── Resources/
    ├── Info.plist
    └── Assula.entitlements
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Roadmap

### Current (v0.1)
- [x] Basic modes (Normal, Insert, Visual, Visual Line)
- [x] Character motions (h, j, k, l)
- [x] Word motions (w, b, e, W, B, E)
- [x] Line motions (0, $, ^)
- [x] Document motions (gg, G)
- [x] Find motions (f, F, t, T, ;, ,)
- [x] Operators (d, c, y) with motions
- [x] Line operations (dd, cc, yy)
- [x] Text objects (iw, aw, i", a", etc.)
- [x] Count prefixes
- [x] Escape sequence (jk)
- [x] Fallback mode for WebAreas
- [x] Menu bar indicator
- [x] SketchyBar integration
- [x] Config file support

### Planned (v0.2)
- [ ] Search motions (/, ?, n, N, *, #)
- [ ] Marks (m, ', `)
- [ ] Macros (q, @)
- [ ] Dot repeat (.)
- [ ] More text objects (it/at for tags)
- [ ] Improved fallback mode for Mail
- [ ] Unit tests

### Future
- [ ] Homebrew installation
- [ ] Custom key mappings
- [ ] Plugin system
- [ ] Lua configuration
- [ ] vim-surround style commands
- [ ] vim-commentary style commands

## Alternatives

- [kindaVim](https://kindavim.app) - The original inspiration (closed source, paid)
- [VimMode.spoon](https://github.com/dbalatero/VimMode.spoon) - Hammerspoon-based
- [Karabiner-Elements](https://karabiner-elements.pqrs.org) - Key remapping

## Troubleshooting

### Accessibility Permissions
If Assula stops working, try resetting permissions:
```bash
tccutil reset Accessibility app.assula.Assula
```
Then re-enable in System Settings -> Privacy & Security -> Accessibility.

### Debug Logging
Run from Xcode to see debug logs in the console. Log prefixes:
- `[VIM]` - VimEngine key processing
- `[AX]` - Accessibility service
- `[KB]` - Keyboard monitor

## License

MIT License - see [LICENSE](LICENSE)

## Acknowledgments

- Inspired by [kindaVim](https://kindavim.app) by Guillaume Leclerc
- Built with SwiftUI and macOS Accessibility APIs
