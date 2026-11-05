import DockAnchorCore
import Foundation
import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static var state: String {
        switch SMAppService.mainApp.status {
        case .enabled: return "enabled"
        case .requiresApproval: return "requires approval in System Settings → General → Login Items"
        case .notFound: return "not found (install the app to /Applications first)"
        default: return "disabled"
        }
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    // The CLI cannot register the app itself: SMAppService.mainApp belongs to the calling bundle.
    static func listenForCLI() {
        DistributedNotificationCenter.default().addObserver(forName: IPC.launchAtLogin, object: nil, queue: .main) { note in
            var reply: [String: String] = [:]
            do {
                switch note.userInfo?[IPC.actionKey] as? String {
                case "on": if !isEnabled { try set(true) }
                case "off": if isEnabled { try set(false) }
                default: break
                }
            } catch {
                reply[IPC.errorKey] = error.localizedDescription
            }
            reply[IPC.stateKey] = state
            IPC.post(IPC.launchAtLoginState, userInfo: reply)
        }
    }
}
