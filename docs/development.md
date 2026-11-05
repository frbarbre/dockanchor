# Development

```sh
swift build        # debug build of all targets
make test          # unit tests (DockAnchorCore)
make run           # build the signed .app into ./build and launch it
make install       # build and install to /Applications
make icon          # regenerate Resources/AppIcon.icns from scripts/make-icon.swift
```

## Releasing

1. Bump `CFBundleShortVersionString` in `Resources/Info.plist`.
2. Commit and push to `main`.
3. Run `make release`.

`scripts/release.sh` refuses to run unless the tree is clean, `HEAD` equals `origin/main`, and the tag doesn't exist yet. It then:

- builds and signs the app,
- zips it as `DockAnchor.zip`,
- writes `latest.json` (`version`, `sha256`, `file`),
- creates the `vX.Y.Z` GitHub release with both files attached.

The cask and the in-app updater both read `releases/latest/download/…`, so nothing else needs updating.

Releases are built locally rather than in CI on purpose. macOS ties the Accessibility grant to the app's code-signing identity. Your keychain's Apple Development certificate keeps that identity stable across versions, whereas an ad-hoc CI build changes it with every release and would silently revoke the permission after each auto-update.

## Layout

| Path | Contents |
| --- | --- |
| `Sources/DockAnchorCore` | Display discovery and querying, config store, edge clamping (`EdgeGuard`), Dock mover, window-fit math, IPC names. Shared by the app and the CLI and unit tested |
| `Sources/DockAnchorApp` | Menu bar app: event tap (`DockLocker`), `Controller`, Carbon hotkeys, settings window, Accessibility window resizing |
| `Sources/DockAnchorCLI` | The `dockanchor` binary, shipped as `DockAnchor.app/Contents/Helpers/dockanchor` |
| `Tests/DockAnchorCoreTests` | Tests for edge clamping, display resolution, config decoding and window fitting |
| `Resources/` | `Info.plist` (`LSUIElement` hides the Dock icon) and `AppIcon.icns` |
| `raycast/` | Raycast script commands |
| `Casks/dockanchor.rb` | Homebrew cask (the repo is its own tap) |
| `scripts/make-icon.swift` | Draws the app icon |
| `scripts/release.sh` | Builds and publishes a GitHub release (`make release`) |

The app target's executable is named `DockAnchorApp` and the CLI's `dockanchor`, because two names differing only in case would collide on a case-insensitive file system. The Makefile renames the app executable to `DockAnchor` inside the bundle.

## Debugging

- `dockanchor status` shows both the *locked* display and the display the Dock is *actually* on, read from the Dock's window bounds.
- The app logs failed Dock moves with `NSLog`. You can view them with `log stream --predicate 'process == "DockAnchor"'`.
