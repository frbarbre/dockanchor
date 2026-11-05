import AppKit

public enum IPC {
    public static let bundleID = "io.frbarbre.dockanchor"
    public static let reloadConfig = Notification.Name("io.frbarbre.dockanchor.reload")
    public static let moveDock = Notification.Name("io.frbarbre.dockanchor.move")
    public static let displayKey = "displayUUID"

    public static var isAppRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    public static func post(_ name: Notification.Name, userInfo: [String: String]? = nil) {
        DistributedNotificationCenter.default().postNotificationName(
            name, object: nil, userInfo: userInfo, deliverImmediately: true
        )
    }
}
