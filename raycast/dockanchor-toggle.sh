#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Toggle Dock Lock
# @raycast.mode silent
# @raycast.packageName DockAnchor
# @raycast.icon 🖥️
# @raycast.description Turn Dock locking on or off

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
cli="$(command -v dockanchor || echo /Applications/DockAnchor.app/Contents/Helpers/dockanchor)"
"$cli" toggle 2>&1 | tail -n 1
