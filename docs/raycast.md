# Raycast

DockAnchor comes with [Raycast script commands](https://manual.raycast.com/script-commands) in the repo's `raycast/` folder. Script commands are free on every Raycast plan.

## Setup (Raycast 2)

1. Open Raycast Settings (**⌘ ,**) → **Script Commands** → **Add Script Directory**.
2. Press **⌘⇧G**, paste the path to the folder (for example `~/Documents/github/dockanchor/raycast`) and confirm.
3. Type "dock" in Raycast.

On Raycast 1.x the option is under **Extensions → + → Add Script Directory**.

Raycast runs the scripts from the folder you added, so don't move or delete the clone.

## Commands

| Command | Runs |
| --- | --- |
| Lock Dock to Display | `dockanchor lock <argument>` (name, number, `cursor`, `next`) |
| Lock Dock Here | `dockanchor lock cursor` |
| Lock Dock to Next Display | `dockanchor lock next` |
| Toggle Dock Lock | `dockanchor toggle` |
| Unlock Dock | `dockanchor unlock` |
| Toggle DockAnchor at Login | `dockanchor login toggle` |

Every command runs in `silent` mode, so Raycast shows the CLI's last line of output (for example *Dock locked to PL2797Q*) as a short notification.

To assign a hotkey or alias, select the command under **Script Commands** in Raycast Settings.

## How the scripts find the CLI

Each script adds `~/.local/bin`, `/opt/homebrew/bin` and `/usr/local/bin` to `PATH` and calls `dockanchor`. If that isn't found, it uses `/Applications/DockAnchor.app/Contents/Helpers/dockanchor`.
