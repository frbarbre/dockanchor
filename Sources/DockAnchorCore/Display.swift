import AppKit
import CoreGraphics

public struct Display: Equatable {
    public let id: CGDirectDisplayID
    public let uuid: String
    public let name: String
    /// Quartz global coordinates (top-left origin), unlike NSScreen.frame.
    public let frame: CGRect
    public let isMain: Bool

    public init(id: CGDirectDisplayID, uuid: String, name: String, frame: CGRect, isMain: Bool) {
        self.id = id
        self.uuid = uuid
        self.name = name
        self.frame = frame
        self.isMain = isMain
    }
}

public enum DisplayQueryError: Error, CustomStringConvertible {
    case notFound(String)
    case ambiguous(String, [Display])
    case noDisplays

    public var description: String {
        switch self {
        case .notFound(let q): return "no display matches \"\(q)\""
        case .ambiguous(let q, let matches):
            return "\"\(q)\" matches several displays: " + matches.map(\.name).joined(separator: ", ")
        case .noDisplays: return "no displays found"
        }
    }
}

public enum Displays {
    public static func active() -> [Display] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        let names = screenNames()
        return ids.prefix(Int(count))
            .filter { CGDisplayMirrorsDisplay($0) == kCGNullDirectDisplay }
            .map { id in
                Display(
                    id: id,
                    uuid: uuidString(for: id),
                    name: names[id] ?? "Display \(id)",
                    frame: CGDisplayBounds(id),
                    isMain: CGDisplayIsMain(id) != 0
                )
            }
            .sorted { ($0.frame.minX, $0.frame.minY) < ($1.frame.minX, $1.frame.minY) }
    }

    public static func setupKey(_ displays: [Display]) -> String {
        displays.map(\.uuid).sorted().joined(separator: "+")
    }

    public static func cursorLocation() -> CGPoint? {
        CGEvent(source: nil)?.location
    }

    public static func display(at point: CGPoint?, in displays: [Display]) -> Display? {
        guard let point else { return nil }
        return displays.first { $0.frame.contains(point) }
    }

    public static func next(after uuid: String?, in displays: [Display]) -> Display? {
        guard !displays.isEmpty else { return nil }
        guard let uuid, let i = displays.firstIndex(where: { $0.uuid == uuid }) else { return displays.first }
        return displays[(i + 1) % displays.count]
    }

    public static func resolve(
        _ query: String,
        in displays: [Display],
        locked: String? = nil,
        cursor: CGPoint? = nil
    ) throws -> Display {
        guard !displays.isEmpty else { throw DisplayQueryError.noDisplays }
        let q = query.trimmingCharacters(in: .whitespaces)
        let lower = q.lowercased()

        switch lower {
        case "main":
            if let d = displays.first(where: \.isMain) { return d }
        case "cursor", "here":
            if let d = display(at: cursor, in: displays) { return d }
            throw DisplayQueryError.notFound(q)
        case "next":
            let current = locked ?? display(at: cursor, in: displays)?.uuid
            if let d = next(after: current, in: displays) { return d }
        default:
            break
        }

        if let index = Int(lower.hasPrefix("#") ? String(lower.dropFirst()) : lower),
           displays.indices.contains(index - 1) {
            return displays[index - 1]
        }
        if let d = displays.first(where: { $0.uuid.lowercased() == lower }) { return d }
        if let d = displays.first(where: { $0.name.lowercased() == lower }) { return d }

        let partial = displays.filter { $0.name.lowercased().contains(lower) }
        switch partial.count {
        case 1: return partial[0]
        case 0: throw DisplayQueryError.notFound(q)
        default: throw DisplayQueryError.ambiguous(q, partial)
        }
    }

    private static func uuidString(for id: CGDirectDisplayID) -> String {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return "display-\(id)" }
        return CFUUIDCreateString(nil, uuid) as String
    }

    private static func screenNames() -> [CGDirectDisplayID: String] {
        var names: [CGDirectDisplayID: String] = [:]
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            names[number.uint32Value] = screen.localizedName
        }
        return names
    }
}
