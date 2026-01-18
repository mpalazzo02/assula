# Contributing to Assula

Contributions are welcome! Here's how to get started.

## Development Setup

1. Clone the repository
   ```bash
   git clone https://github.com/your-username/assula.git
   cd assula
   ```

2. Open in Xcode
   ```bash
   open Assula.xcodeproj
   ```

3. Build and run (Cmd+R)

4. Grant Accessibility permissions when prompted

## Code Style

- Swift standard naming conventions
- Use `// MARK: -` comments to organize code sections
- Add debug prints with prefixes like `[VIM]`, `[AX]`, `[KB]` for easy filtering

## Adding New Features

### Adding a New Motion

1. Add the motion case to `src/Core/Motions/Motion.swift`
2. Implement the executor in the appropriate file (or create new one)
3. Add key binding in `VimEngine.handleNormalModeKey()`
4. Add fallback support in `AccessibilityService.simulateMotion()` if needed

### Adding a New Text Object

1. Create a new class conforming to `TextObject` protocol in `src/Core/TextObjects/`
2. Register it in `VimEngine.getTextObject(for:)`
3. Add fallback support in `VimEngine.handleTextObjectFallback()` if needed

### Adding App-Specific Behavior

1. Create a new strategy in `src/Accessibility/AppStrategy/`
2. Register the bundle ID in `StrategyManager.swift`

## Testing

Currently testing is manual:
- Test in TextEdit (full Accessibility support)
- Test in Safari/Chrome text fields (fallback mode)
- Test in Mail compose (WebArea fallback)

## Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
