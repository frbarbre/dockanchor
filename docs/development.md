# Development

```sh
swift build        # debug build of all targets
make test          # unit tests (DockAnchorCore)
make run           # build the signed .app into ./build and launch it
make install       # build and install to /Applications
make icon          # regenerate Resources/AppIcon.icns from scripts/make-icon.swift
```

## Layout

| Path | Contents |
| --- | --- |
| `Sources/DockAnchorCore` | Display discovery and querying, config store, edge clamping (`EdgeGuard`), Dock mover, window-fit math, IPC names. Shared by the app and the CLI and unit tested |
| `Sources/DockAnchorApp` | Menu bar app: event tap (`DockLocker`), `Controller`, Carbon hotkeys, settings window, Accessibility window resizing |
| `Sources/DockAnchorCLI` | The `dockanchor` binary, shipped as `DockAnchor.app/Contents/Helpers/dockanchor` |
| `Tests/DockAnchorCoreTests` | Tests for edge clamping, display resolution, config decoding and window fitting |
| `Resources/` | `Info.plist` (`LSUIElement` hides the Dock icon) and `AppIcon.icns` |
| `raycast/` | Raycast script commands |
| `scripts/make-icon.swift` | Draws the app icon |

The app target's executable is named `DockAnchorApp` and the CLI's `dockanchor`, because two names differing only in case would collide on a case-insensitive file system. The Makefile renames the app executable to `DockAnchor` inside the bundle.

## Debugging

- `dockanchor status` shows both the *locked* display and the display the Dock is *actually* on, read from the Dock's window bounds.
- The app logs failed Dock moves with `NSLog`. You can view them with `log stream --predicate 'process == "DockAnchor"'`.
