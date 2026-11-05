# DockAnchor

A small native macOS menu bar app (Swift, no dependencies) that keeps the Dock on the display you choose, so it stops jumping to whichever screen your cursor brushes against.

- **Per screen setup locks**: the lock is saved against the exact set of connected displays. Dock to the external at your desk and the laptop on the go, and the lock applies on its own when the setup changes.
- **No Dock icon**: it only lives in the menu bar (`LSUIElement`).
- **CLI**: `dockanchor`
- **Global hotkeys**: you can rebind them in *Hotkeys…*
- **Raycast**: script commands in [`raycast/`](raycast/), which work on Raycast's free plan.

Requires macOS 13+.

## Install

With Homebrew (Apple silicon):

```sh
brew tap frbarbre/dockanchor https://github.com/frbarbre/dockanchor
brew install --cask frbarbre/dockanchor/dockanchor
```

The cask installs the app and the `dockanchor` CLI. It always pulls the newest release, and after that DockAnchor updates itself (see [Updates](#updates)).

From source:

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

## Updates

DockAnchor checks the latest GitHub release 15 seconds after launch and every 6 hours. When a newer version exists, it:

1. downloads `DockAnchor.zip`,
2. verifies it against the SHA-256 in the release's `latest.json`,
3. quits, letting a detached script swap `/Applications/DockAnchor.app`,
4. relaunches.

The previous version is kept at `~/Library/Application Support/DockAnchor/updates/DockAnchor.previous.app`, and every failure relaunches the version that is still installed. The swap script's log is `updates/update.log` in the same folder.

Turn off *Install Updates Automatically* in the menu to only update through *Check for Updates…*. Homebrew leaves the cask alone (`auto_updates true`) unless you run `brew upgrade --greedy`.

## Menu

- **Enable Dock Lock**: global on/off
- **Lock Dock to Display ▸**: lock for the current screen setup and move the Dock there; *Don't Lock on This Setup* removes it
- **Resize Maximized Windows**: fit maximized windows to the Dock automatically (on by default)
- **Check for Updates…** / **Install Update x.y.z**, **Install Updates Automatically**
- **Hotkeys…**, **Launch at Login**, **Quit**

The first line of the menu shows the current state (locked display, no lock for this setup, or locking off). While Accessibility hasn't been granted, the menu also shows *Grant Accessibility Access…*.

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
dockanchor login [on|off|toggle|status]   start DockAnchor at login (app must be running)
dockanchor setups [--json]     saved screen setups
```

`<display>` can be a 1-based index from `list`, a full or partial name (`odyssey`), a UUID, or `main`, `cursor`, `next`.

The CLI edits the same config file as the app (`~/Library/Application Support/DockAnchor/config.json`) and signals the running app to reload it through a distributed notification.

## Raycast

The [`raycast/`](raycast/) folder holds Raycast script commands. They work on Raycast's free plan.

1. Open Raycast Settings (**⌘ ,**) → **Script Commands** → **Add Script Directory**.
   On Raycast 1.x this was **Extensions → + → Add Script Directory** instead.
2. Press **⌘⇧G**, paste `~/Documents/github/dockanchor/raycast` (or wherever you cloned the repo), and confirm.
3. Type "dock" in Raycast to find the commands.

| Command | What it does |
| --- | --- |
| Lock Dock to Display | Asks for a display (name, number, `cursor`, `next`) and locks the Dock to it |
| Lock Dock Here | Locks to the display under the cursor |
| Lock Dock to Next Display | Cycles the lock through your displays |
| Toggle Dock Lock | Turns locking on/off |
| Unlock Dock | Removes the lock for the current screen setup |
| Toggle DockAnchor at Login | Turns starting at login on/off |

To give a command a hotkey or alias, select it under **Script Commands** in Raycast Settings.

Each script calls the `dockanchor` CLI from `~/.local/bin`, `/opt/homebrew/bin` or `/usr/local/bin`. If none is found, it uses the copy inside `/Applications/DockAnchor.app`. Raycast runs the scripts from the folder you added, so keep the repo where it is.

## Troubleshooting

- **The Dock doesn't move or isn't locked.** Check that DockAnchor is enabled under System Settings → Privacy & Security → Accessibility. If you built with ad-hoc signing, remove the entry and add it again after each rebuild.
- **Raycast says `dockanchor: command not found`.** Run `make install`, or check that `/Applications/DockAnchor.app` exists.
- **A maximized window wasn't resized.** Only windows that fill their screen are touched (gaps up to 24pt are allowed). Half-screen and freely placed windows are left alone by design. Restarting the app runs a pass over all windows.
- **Check the current state.** `dockanchor status` shows the locked display and the display the Dock is actually on.

## Development

```sh
swift build
make test
make run    # build the .app bundle into ./build and launch it
make icon   # regenerate Resources/AppIcon.icns from scripts/make-icon.swift
```

### Releasing

1. Bump `CFBundleShortVersionString` in `Resources/Info.plist`.
2. Commit and push to `main`.
3. Run `make release`.

The release step needs a clean tree that matches `origin/main`. It builds and signs the app with your keychain identity, zips it, writes `latest.json` (version and SHA-256), and creates the `vX.Y.Z` GitHub release with both files. The cask and the in-app updater both read from `releases/latest`, so nothing else needs updating.

Releases are built locally on purpose. CI could only sign ad hoc, and an ad-hoc signature changes with every build, so macOS would drop the Accessibility permission after every auto-update.

The code is split into three modules: `DockAnchorCore` (displays, config, edge clamping, Dock mover, window fitting; shared and unit tested), `DockAnchorApp` (menu bar app) and `DockAnchorCLI` (the `dockanchor` binary, shipped in `DockAnchor.app/Contents/Helpers`).
