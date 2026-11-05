import Foundation

public struct UpdateManifest: Codable, Equatable {
    public let version: String
    public let sha256: String
    public let file: String

    public init(version: String, sha256: String, file: String) {
        self.version = version
        self.sha256 = sha256
        self.file = file
    }
}

public struct UpdateSwapPlan {
    public let appPath: String
    public let pid: Int32
    public let zipPath: String
    public let stagingDir: String
    public let backupPath: String
    public let logPath: String

    public init(appPath: String, pid: Int32, zipPath: String, stagingDir: String, backupPath: String, logPath: String) {
        self.appPath = appPath
        self.pid = pid
        self.zipPath = zipPath
        self.stagingDir = stagingDir
        self.backupPath = backupPath
        self.logPath = logPath
    }
}

public enum Updates {
    public static let feedBase = URL(string: "https://github.com/frbarbre/dockanchor/releases/latest/download/")!
    public static var manifestURL: URL { feedBase.appendingPathComponent("latest.json") }

    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = components(candidate)
        let b = components(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func components(_ version: String) -> [Int] {
        version.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            .split(separator: ".")
            .map { Int($0.prefix { $0.isNumber }) ?? 0 }
    }

    /// The running bundle cannot replace itself, so a detached script waits for it to exit and does the swap.
    /// Every failure path relaunches the version that is still installed; the old bundle is kept as a backup.
    public static func swapScript(_ plan: UpdateSwapPlan) -> String {
        func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let app = quote(plan.appPath)
        let staging = quote(plan.stagingDir)
        let backup = quote(plan.backupPath)
        return """
        #!/bin/bash
        set -uo pipefail
        exec >>\(quote(plan.logPath)) 2>&1
        echo "[dockanchor-update] $(date) waiting for pid \(plan.pid) to exit"
        while kill -0 \(plan.pid) 2>/dev/null; do sleep 0.2; done
        # The process is gone before macOS has released every file handle in the bundle.
        sleep 1

        rm -rf \(staging)
        mkdir -p \(staging)
        if ! /usr/bin/ditto -x -k \(quote(plan.zipPath)) \(staging); then
          echo "[dockanchor-update] expand failed; keeping the installed app"
          /usr/bin/open \(app) || true
          exit 1
        fi

        NEW=\(staging)/DockAnchor.app
        if [ ! -x "$NEW/Contents/MacOS/DockAnchor" ] || ! /usr/bin/plutil -lint "$NEW/Contents/Info.plist" >/dev/null; then
          echo "[dockanchor-update] the archive did not contain a launchable app; keeping the installed app"
          /usr/bin/open \(app) || true
          exit 1
        fi
        /usr/bin/xattr -dr com.apple.quarantine "$NEW" 2>/dev/null || true

        rm -rf \(backup)
        if ! mv \(app) \(backup); then
          echo "[dockanchor-update] could not move the installed app aside; keeping it"
          /usr/bin/open \(app) || true
          exit 1
        fi
        if ! mv "$NEW" \(app); then
          echo "[dockanchor-update] install failed; restoring the previous app"
          mv \(backup) \(app)
          /usr/bin/open \(app) || true
          exit 1
        fi

        rm -rf \(staging)
        echo "[dockanchor-update] installed; previous version kept at \(plan.backupPath)"
        /usr/bin/open \(app)

        """
    }
}
