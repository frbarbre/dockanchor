#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Lock Dock Here
# @raycast.mode silent
# @raycast.packageName DockAnchor
# @raycast.icon 🖥️
# @raycast.description Lock the Dock to the display under the cursor

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
cli="$(command -v dockanchor || echo /Applications/DockAnchor.app/Contents/Helpers/dockanchor)"
"$cli" lock cursor 2>&1 | tail -n 1
