# How it works

## Keeping the Dock in place

macOS moves the Dock to a display when the cursor is pushed against that display's Dock edge. The edge is the bottom, left or right, depending on the Dock's position, which DockAnchor reads from `com.apple.dock`.

DockAnchor installs a HID-level event tap for mouse-move and drag events. On every display except the locked one, it keeps the cursor 2pt away from the Dock edge, so the Dock is never triggered there. An edge that borders another display isn't a screen edge, so it isn't clamped, and you can still move the cursor freely between stacked monitors.

## Moving the Dock

When you lock to a display, or a screen setup with a saved lock connects, DockAnchor:

1. pauses the clamp,
2. moves the cursor in steps down to the target display's Dock edge and holds it there briefly,
3. checks where the Dock window actually is and retries up to three times,
4. puts the cursor back where it was.

The CLI and Raycast ask the running app to do this through a distributed notification, because posting cursor events needs the app's Accessibility permission.

## Resizing maximized windows

Moving the Dock changes each screen's *visible frame*, which is the area without the menu bar and Dock. macOS signals this with the same notification it sends when displays change. DockAnchor uses it to fit maximized windows:

1. It reads every standard window of every visible app through the Accessibility API. Minimized and native full-screen windows are skipped.
2. A window counts as *maximized* if its edges are within 24pt of any of:
    - the screen's previous visible frame,
    - the screen below the menu bar without the Dock,
    - the screen below the menu bar *with* the Dock (calculated from the Dock's thickness, which is the same on every display),
    - the whole display, which is where macOS puts windows from an unplugged monitor.
3. Matching windows are resized to the current visible frame. A uniform gap, such as a Raycast window gap, is kept. The window's top edge stays where it is, because the Dock never sits at the top and macOS sometimes reports a secondary display's visible frame without its menu bar after a reconnect.

Half-screen and freely placed windows don't match and are never touched. The app also runs this pass once when it starts.

## Screen setups

Real display changes (added, removed or rearranged) are told apart from Dock-only changes by comparing display IDs and frames. Only real changes re-apply a setup's lock. Without that check, a manual Dock move would be undone right away.
