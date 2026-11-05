cask "dockanchor" do
  # Always the newest release, so a release needs no cask bump; the app updates itself.
  version :latest
  sha256 :no_check

  url "https://github.com/frbarbre/dockanchor/releases/latest/download/DockAnchor.zip"
  name "DockAnchor"
  desc "Menu bar app that locks the Dock to a display per screen setup"
  homepage "https://github.com/frbarbre/dockanchor"

  # Let the in-app updater own updates; Homebrew skips auto_updates casks unless --greedy.
  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :ventura

  app "DockAnchor.app"
  binary "#{appdir}/DockAnchor.app/Contents/Helpers/dockanchor"

  # Signed with an Apple Development certificate, not Developer ID, so Gatekeeper would refuse to open it.
  # Steps take only literal arguments, so a custom --appdir skips this and needs one "Open Anyway".
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "/Applications/DockAnchor.app"], must_succeed: false
  end

  uninstall quit: "io.frbarbre.dockanchor"

  zap trash: "~/Library/Application Support/DockAnchor"

  caveats <<~EOS
    DockAnchor needs Accessibility access to keep the Dock in place:
      System Settings → Privacy & Security → Accessibility

    Start it at login with:
      dockanchor login on
  EOS
end
