# Usage

## Menu bar

| Item | What it does |
| --- | --- |
| *Status line* | Shows the locked display, *No lock for this screen setup*, or *Dock lock is off* |
| Grant Accessibility Access… | Only shown until the permission is granted |
| Enable Dock Lock | Global on/off switch |
| Lock Dock to Display ▸ | Lock to a display for the current screen setup and move the Dock there. *Don't Lock on This Setup* removes the lock |
| Resize Maximized Windows | Fit maximized windows to the Dock automatically (on by default) |
| Check for Updates… | Shows the installed version. Becomes *Install Update x.y.z* when a newer release is found |
| Install Updates Automatically | Install new releases without asking (on by default) |
| Hotkeys… | Rebind the global hotkeys |
| Launch at Login | Start DockAnchor when you log in |

## Screen setups

A *screen setup* is the set of displays connected at the moment, identified by each display's UUID. Arrangement and order don't matter. Each setup has its own lock, so you can, for example:

- lock to the external monitor when docked at your desk,
- have no lock (or a different one) when only the laptop screen is connected.

When the connected displays change, DockAnchor looks up the lock for the new setup and moves the Dock there.

## Hotkeys

| Action | Default |
| --- | --- |
| Toggle Dock lock | ⌃⌥⌘D |
| Lock Dock to display under cursor | ⌃⌥⌘L |
| Lock Dock to next display | ⌃⌥⌘N |

To rebind, open *Hotkeys…* and click a field. Then press a combination that includes ⌘, ⌃ or ⌥. *Clear* removes the binding, and Esc cancels.

## CLI

```
dockanchor status [--json]     app running?, locking on/off, Dock edge, locked display, display the Dock is on
dockanchor list [--json]       connected displays (* = locked for this setup)
dockanchor lock <display>      lock for the current setup and move the Dock there
dockanchor unlock              remove the lock for the current setup
dockanchor enable | disable | toggle
dockanchor login [on|off|toggle|status]   start DockAnchor at login
dockanchor setups [--json]     saved screen setups (* = current)
```

`login` needs the app to be running. macOS only lets an app register *itself* as a login item, so the CLI asks the app to do it and prints the result. If macOS answers *requires approval*, switch DockAnchor on under System Settings → General → Login Items.

`<display>` accepts any of:

- a 1-based index from `list` (`3` or `#3`),
- a display UUID,
- a full or partial name, case-insensitive (`odyssey`, `pl27`),
- `main` (the display with the menu bar), `cursor` / `here`, or `next` (the display after the locked one).

Example:

```sh
$ dockanchor list
  1  PL2797Q  (2560x1440)  BB16062A-…
* 2  Odyssey G85SD  (main, 3440x1440)  A085A260-…
  3  Built-in Retina Display  (1512x982)  37D8832A-…

$ dockanchor lock pl27
Dock locked to PL2797Q
```

## Configuration file

The app and the CLI share `~/Library/Application Support/DockAnchor/config.json`:

```json
{
  "enabled": true,
  "resizeMaximizedWindows": true,
  "hotkeys": { "toggleLock": { "keyCode": 2, "modifiers": 6400, "label": "⌃⌥⌘D" } },
  "setups": {
    "<display-uuid>+<display-uuid>": {
      "displayUUID": "<display-uuid>",
      "displayName": "PL2797Q",
      "setupDisplayNames": ["PL2797Q", "Built-in Retina Display"]
    }
  }
}
```

After the CLI changes the file, it posts a distributed notification that tells the running app to reload. If you edit the file by hand, run `dockanchor toggle` twice or restart the app to apply your changes.
