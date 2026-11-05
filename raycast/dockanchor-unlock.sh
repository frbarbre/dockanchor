#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Unlock Dock
# @raycast.mode silent
# @raycast.packageName DockAnchor
# @raycast.icon 🖥️
# @raycast.description Remove the Dock lock for the current screen setup

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
cli="$(command -v dockanchor || echo /Applications/DockAnchor.app/Contents/Helpers/dockanchor)"
"$cli" unlock 2>&1 | tail -n 1
