# DockAnchor

DockAnchor is a native macOS menu bar app, written in Swift with no dependencies, that keeps the Dock on the display you choose. With it running, the Dock no longer jumps to whichever screen the cursor touches at the bottom edge.

## Features

- **Locks per screen setup.** Each lock is saved for the exact set of connected displays and applies on its own when that setup comes back. Locking also moves the Dock to the chosen display.
- **Maximized windows follow the Dock.** When the Dock changes display or a monitor is plugged in or out, windows that filled their screen are resized to the new usable area.
- **No Dock icon.** It only lives in the menu bar.
- **CLI.** The `dockanchor` command handles status, listing displays, locking and toggling.
- **Global hotkeys** that you can rebind.
- **Raycast script commands** that work on the free plan.

Requires macOS 13 or later.

## Pages

- [Installation](installation.md)
- [Usage](usage.md): menu, hotkeys, CLI
- [Raycast](raycast.md)
- [How it works](how-it-works.md)
- [Development](development.md)
