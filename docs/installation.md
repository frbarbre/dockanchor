# Installation

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

## Uninstall

```sh
make uninstall
rm -rf ~/Library/Application\ Support/DockAnchor   # saved locks and hotkeys
```
