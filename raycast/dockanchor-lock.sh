#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Lock Dock to Display
# @raycast.mode silent
# @raycast.packageName DockAnchor
# @raycast.icon 🖥️
# @raycast.argument1 { "type": "text", "placeholder": "display: name, #, cursor, next" }
# @raycast.description Lock the Dock to a display for the current screen setup

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
cli="$(command -v dockanchor || echo /Applications/DockAnchor.app/Contents/Helpers/dockanchor)"
"$cli" lock "$1" 2>&1 | tail -n 1
