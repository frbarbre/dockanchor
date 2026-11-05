# Installation

## Homebrew (Apple silicon)

```sh
brew tap frbarbre/dockanchor https://github.com/frbarbre/dockanchor
brew install --cask frbarbre/dockanchor/dockanchor
```

The repo is its own tap, and the cask lives at `Casks/dockanchor.rb`. The cask:

- installs `DockAnchor.app` and puts the `dockanchor` CLI on your `PATH`,
- uses `version :latest`, so it always downloads the newest release and no release ever needs a cask change,
- sets `auto_updates true`, so DockAnchor [updates itself](#updates) and `brew upgrade` leaves it alone unless you pass `--greedy`,
- removes the quarantine flag after install, because the app is signed with an Apple Development certificate rather than a notarized Developer ID, and Gatekeeper would otherwise refuse to open it.

Uninstall with `brew uninstall --cask dockanchor`. Add `--zap` to also remove saved locks and hotkeys.

## From source

```sh
git clone https://github.com/frbarbre/dockanchor.git
cd dockanchor
make install
```

`make install` does four things:

1. Builds a release `DockAnchor.app` into `build/`.
2. Copies it to `/Applications` (replacing and quitting any running copy).
3. Links the CLI to `~/.local/bin/dockanchor`.
4. Launches the app.

## Accessibility permission

On first launch macOS asks you to grant **Accessibility** access (System Settings → Privacy & Security → Accessibility). DockAnchor needs it to:

- keep the cursor off the Dock edge on other displays,
- move the Dock when you lock it,
- resize maximized windows.

Until it's granted, the menu shows *Grant Accessibility Access…*.

## Signing

The Makefile signs with the first `Apple Development` identity in your keychain. A stable identity means the Accessibility grant survives rebuilds. With no identity, it signs ad hoc (`-`), and you then have to grant Accessibility again after every build.

## Options

| Variable | Default | Purpose |
| --- | --- | --- |
| `INSTALL_DIR` | `/Applications` | Where the app is copied |
| `BIN_DIR` | `~/.local/bin` | Where the `dockanchor` link goes |
| `SIGN_IDENTITY` | first Apple Development identity, else `-` | Code signing identity |

```sh
make install INSTALL_DIR=~/Applications BIN_DIR=/usr/local/bin
```

## Updates

DockAnchor checks `releases/latest/download/latest.json` 15 seconds after launch and then every 6 hours. When the manifest names a newer version, the app:

1. downloads `DockAnchor.zip` and checks it against the manifest's SHA-256,
2. writes a swap script to `~/Library/Application Support/DockAnchor/updates/` and starts it in its own session, so it outlives the app,
3. quits.

The script then:

1. waits for the app to exit,
2. expands the zip with `ditto`,
3. checks that the result is a launchable app,
4. moves the installed app to `updates/DockAnchor.previous.app`, moves the new one into place and relaunches it.

Every failure path relaunches the version that is still installed. The script logs to `updates/update.log`.

Turn off *Install Updates Automatically* in the menu to update only through *Check for Updates…*. That item turns into *Install Update x.y.z* when a newer version is known.

## Uninstall (source install)

```sh
make uninstall
rm -rf ~/Library/Application\ Support/DockAnchor   # saved locks and hotkeys
```
