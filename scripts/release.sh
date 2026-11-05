#!/bin/bash
# Publishes the version in Resources/Info.plist as a GitHub release that the cask and the in-app updater pick up.
# Runs locally rather than in CI: the keychain's signing identity keeps the Accessibility grant valid across updates.
set -euo pipefail

repo="frbarbre/dockanchor"
cd "$(dirname "$0")/.."

version="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)"
tag="v$version"

[[ -z "$(git status --porcelain)" ]] || { echo "error: working tree is not clean" >&2; exit 1; }
git fetch -q origin main
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || { echo "error: HEAD is not origin/main; push first" >&2; exit 1; }
if gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
  echo "error: $tag already exists; bump CFBundleShortVersionString in Resources/Info.plist" >&2
  exit 1
fi

make app
codesign --verify --strict build/DockAnchor.app

dist="build/dist"
rm -rf "$dist" && mkdir -p "$dist"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent build/DockAnchor.app "$dist/DockAnchor.zip"
sha="$(shasum -a 256 "$dist/DockAnchor.zip" | awk '{print $1}')"
printf '{"version":"%s","sha256":"%s","file":"DockAnchor.zip"}\n' "$version" "$sha" > "$dist/latest.json"

gh release create "$tag" "$dist/DockAnchor.zip" "$dist/latest.json" \
  --repo "$repo" --target "$(git rev-parse HEAD)" --title "DockAnchor $version" --generate-notes

echo "Released $tag (sha256 $sha)"
