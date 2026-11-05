#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Lock Dock to Next Display
# @raycast.mode silent
# @raycast.packageName DockAnchor
# @raycast.icon 🖥️
# @raycast.description Cycle the Dock lock to the next display

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
cli="$(command -v dockanchor || echo /Applications/DockAnchor.app/Contents/Helpers/dockanchor)"
"$cli" lock next 2>&1 | tail -n 1
