# DockAnchor

A small native macOS menu bar app (Swift, no dependencies) that keeps the Dock on the display you choose, so it stops jumping to whichever screen your cursor brushes against.

- **Per screen setup locks**: the lock is saved against the exact set of connected displays. Dock to the external at your desk and the laptop on the go, and the lock applies on its own when the setup changes.
- **No Dock icon**: it only lives in the menu bar (`LSUIElement`).
- **CLI**: `dockanchor`
- **Global hotkeys**: you can rebind them in *Hotkeys…*
- **Raycast**: script commands in [`raycast/`](raycast/), which work on Raycast's free plan.

Requires macOS 13+.

## Install

```sh
make install          # builds, copies to /Applications, links the CLI into ~/.local/bin, launches
```

On first launch, grant **Accessibility** access (System Settings → Privacy & Security → Accessibility). DockAnchor needs it to watch the cursor and move the Dock.

The Makefile signs with your first `Apple Development` identity when one exists, so the Accessibility grant survives rebuilds. With ad-hoc signing (`SIGN_IDENTITY=-`) you have to grant it again after every build.

Overrides: `make install INSTALL_DIR=~/Applications BIN_DIR=/usr/local/bin SIGN_IDENTITY="…"`.

## How it works

macOS moves the Dock to a display when the cursor is pushed against that display's Dock edge. DockAnchor installs an event tap that keeps the cursor 2pt away from that edge on every display except the locked one. Edges shared with another display are left alone, so moving between stacked screens still works. Moving the Dock deliberately (locking, or a screen setup change) briefly pushes the cursor against the target display's edge and then puts the cursor back. The Dock position (bottom/left/right) is read from `com.apple.dock`.

### Maximized windows follow the Dock

When the Dock moves to another display, resizes, or a display is plugged in or out, DockAnchor resizes every window that filled its screen to the screen's current usable area. A window gets this treatment if it matched the previous usable area, the area below the menu bar ignoring the Dock, or the whole display (which is where macOS leaves windows from an unplugged display). Gaps to the screen edges, such as a Raycast window gap, are kept. Toggle it with *Resize Maximized Windows* in the menu.

## Menu

- **Enable Dock Lock**: global on/off
- **Lock Dock to Display ▸**: lock for the current screen setup and move the Dock there; *Don't Lock on This Setup* removes it
- **Resize Maximized Windows**: fit maximized windows to the Dock automatically (on by default)
- **Hotkeys…**, **Launch at Login**, **Quit**

## Hotkeys

| Action | Default |
| --- | --- |
| Toggle Dock lock | ⌃⌥⌘D |
| Lock Dock to display under cursor | ⌃⌥⌘L |
| Lock Dock to next display | ⌃⌥⌘N |

## CLI

```
dockanchor status [--json]     app running?, locking on/off, Dock edge, current lock
dockanchor list [--json]       connected displays (* = locked for this setup)
dockanchor lock <display>      lock for the current setup and move the Dock there
dockanchor unlock              remove the lock for the current setup
dockanchor enable|disable|toggle
dockanchor setups [--json]     saved screen setups
```

`<display>` can be a 1-based index from `list`, a full or partial name (`odyssey`), a UUID, or `main`, `cursor`, `next`.

The CLI edits the same config file as the app (`~/Library/Application Support/DockAnchor/config.json`) and signals the running app to reload it through a distributed notification.

## Raycast

In Raycast, open **Extensions → + → Add Script Directory** and pick this repo's `raycast/` folder. You get:

- Lock Dock to Display (argument)
- Lock Dock Here
- Lock Dock to Next Display
- Toggle Dock Lock
- Unlock Dock

Each script calls the `dockanchor` CLI and falls back to the copy inside `/Applications/DockAnchor.app`. Script commands are free on every Raycast plan.

## Development

```sh
swift build
make test
make run    # build the .app bundle into ./build and launch it
```

The code is split into three modules: `DockAnchorCore` (displays, config, edge clamping, Dock mover; shared and unit tested), `DockAnchorApp` (menu bar app) and `DockAnchorCLI` (the `dockanchor` binary, shipped in `DockAnchor.app/Contents/Helpers`).
