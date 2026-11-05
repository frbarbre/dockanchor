import AppKit
import CryptoKit
import DockAnchorCore

final class Updater {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(UpdateManifest)
        case installing(String)
        case failed(String)
    }

    private(set) var state: State = .idle {
        didSet { onChange?() }
    }
    var onChange: (() -> Void)?

    private var timer: Timer?
    private let workDir = ConfigStore.defaultURL.deletingLastPathComponent().appendingPathComponent("updates", isDirectory: true)

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    func start(autoInstall: @escaping () -> Bool) {
        // Let display setup and the first Dock move settle before touching the network.
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in self?.check(install: autoInstall()) }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            self?.check(install: autoInstall())
        }
    }

    func check(install: Bool, completion: ((State) -> Void)? = nil) {
        if case .installing = state { return }
        state = .checking
        URLSession.shared.dataTask(with: Updates.manifestURL) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.finish(.failed(error.localizedDescription), completion)
                    return
                }
                guard (response as? HTTPURLResponse)?.statusCode == 200, let data,
                      let manifest = try? JSONDecoder().decode(UpdateManifest.self, from: data) else {
                    self.finish(.failed("No release manifest found"), completion)
                    return
                }
                guard Updates.isNewer(manifest.version, than: self.currentVersion) else {
                    self.finish(.upToDate, completion)
                    return
                }
                self.finish(.available(manifest), completion)
                if install { self.install(manifest) }
            }
        }.resume()
    }

    func install(_ manifest: UpdateManifest) {
        if case .installing = state { return }
        let appURL = Bundle.main.bundleURL
        guard FileManager.default.isWritableFile(atPath: appURL.deletingLastPathComponent().path) else {
            state = .failed("Can't write to \(appURL.deletingLastPathComponent().path)")
            return
        }
        state = .installing(manifest.version)

        let source = Updates.feedBase.appendingPathComponent(manifest.file)
        URLSession.shared.downloadTask(with: source) { [weak self] location, response, error in
            guard let self else { return }
            do {
                guard let location, error == nil, (response as? HTTPURLResponse)?.statusCode == 200 else {
                    throw UpdateError(error?.localizedDescription ?? "Download failed")
                }
                try FileManager.default.createDirectory(at: self.workDir, withIntermediateDirectories: true)
                let zip = self.workDir.appendingPathComponent("DockAnchor.zip")
                try? FileManager.default.removeItem(at: zip)
                try FileManager.default.moveItem(at: location, to: zip)

                // Integrity comes from the manifest's hash; the bundle's signature can't be checked before it is expanded.
                let digest = SHA256.hash(data: try Data(contentsOf: zip)).map { String(format: "%02x", $0) }.joined()
                guard digest == manifest.sha256.lowercased() else { throw UpdateError("Checksum mismatch") }

                let script = self.workDir.appendingPathComponent("swap.sh")
                let plan = UpdateSwapPlan(
                    appPath: appURL.path,
                    pid: getpid(),
                    zipPath: zip.path,
                    stagingDir: self.workDir.appendingPathComponent("staging").path,
                    backupPath: self.workDir.appendingPathComponent("DockAnchor.previous.app").path,
                    logPath: self.workDir.appendingPathComponent("update.log").path
                )
                try Updates.swapScript(plan).write(to: script, atomically: true, encoding: .utf8)
                try spawnDetached(script.path)
                DispatchQueue.main.async { NSApp.terminate(nil) }
            } catch {
                DispatchQueue.main.async { self.state = .failed(error.localizedDescription) }
            }
        }.resume()
    }

    private func finish(_ state: State, _ completion: ((State) -> Void)?) {
        self.state = state
        completion?(state)
    }
}

private struct UpdateError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

// A new session keeps the script alive after the app it is replacing exits.
private func spawnDetached(_ scriptPath: String) throws {
    var attributes: posix_spawnattr_t?
    posix_spawnattr_init(&attributes)
    defer { posix_spawnattr_destroy(&attributes) }
    posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSID))

    var pid: pid_t = 0
    let argv: [UnsafeMutablePointer<CChar>?] = [strdup("/bin/bash"), strdup(scriptPath), nil]
    defer { argv.forEach { free($0) } }
    let status = posix_spawn(&pid, "/bin/bash", nil, &attributes, argv, environ)
    guard status == 0 else { throw UpdateError("Could not start the installer (\(status))") }
}
