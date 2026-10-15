import Carbon.HIToolbox
import Foundation

/// One video and the hotkey that plays it.
public struct Clip: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var path: String
    public var hotKey: HotKeyCombo?

    public init(id: UUID = UUID(), name: String, path: String, hotKey: HotKeyCombo? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.hotKey = hotKey
    }
}

public struct AppConfig: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let scaleRange: ClosedRange<Double> = 0.5...4.0

    public var version: Int = AppConfig.currentVersion
    public var clips: [Clip]
    /// Multiplier applied to the video's native pixel size when displayed.
    public var scale: Double

    public init(clips: [Clip] = [], scale: Double = 2.0) {
        self.clips = clips
        self.scale = scale.clamped(to: Self.scaleRange)
    }

    /// The clip, other than `excluding`, that already uses `combo`.
    public func clip(using combo: HotKeyCombo, excluding id: UUID) -> Clip? {
        clips.first { $0.id != id && $0.hotKey == combo }
    }
}

extension Double {
    fileprivate func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// Reads and writes `AppConfig` as JSON.
public struct ConfigStore {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `~/Library/Application Support/Magic/config.json`
    public static var defaultURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Magic", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    /// Returns nil when no config exists yet. Throws when the file exists but is unreadable.
    public func load() throws -> AppConfig? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let config = try JSONDecoder().decode(AppConfig.self, from: Data(contentsOf: url))
        guard config.version <= AppConfig.currentVersion else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [
                NSLocalizedDescriptionKey: "Config version \(config.version) is newer than this app supports.",
            ])
        }
        var sanitized = config
        sanitized.scale = AppConfig(scale: config.scale).scale
        return sanitized
    }

    public func save(_ config: AppConfig) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: url, options: .atomic)
    }

    /// Moves an unreadable config aside so the user's data is not overwritten.
    @discardableResult
    public func quarantine() -> URL? {
        let aside = url.appendingPathExtension("corrupt")
        try? FileManager.default.removeItem(at: aside)
        do {
            try FileManager.default.moveItem(at: url, to: aside)
            return aside
        } catch {
            return nil
        }
    }
}
