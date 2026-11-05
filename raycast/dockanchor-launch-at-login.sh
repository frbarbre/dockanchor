#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Toggle DockAnchor at Login
# @raycast.mode silent
# @raycast.packageName DockAnchor
# @raycast.icon 🖥️
# @raycast.description Start or stop starting DockAnchor when you log in

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
cli="$(command -v dockanchor || echo /Applications/DockAnchor.app/Contents/Helpers/dockanchor)"
"$cli" login toggle 2>&1 | tail -n 1
