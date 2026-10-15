import AppKit
import MagicCore

/// Owns the preloaded players and the global hotkeys, and keeps both in sync with the config.
@MainActor
final class PlaybackController {
    private var players: [UUID: ClipPlayer] = [:]
    private let hotKeys = HotKeyManager()
    private var scale = AppConfig().scale
    private var observers: [NSObjectProtocol] = []

    /// Reports a problem with a clip's file (nil clears it).
    var onFileIssue: ((UUID, String?) -> Void)?

    init() {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: .hotKeyRecordingBegan, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.hotKeys.setSuspended(true) }
            },
            center.addObserver(forName: .hotKeyRecordingEnded, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.hotKeys.setSuspended(false) }
            },
        ]
    }

    /// Applies a config. Players are reused when the clip's file is unchanged, so editing a name or
    /// hotkey never re-decodes video. Returns hotkey problems keyed by clip id.
    @discardableResult
    func apply(_ config: AppConfig) -> [UUID: String] {
        scale = config.scale

        let keep = Dictionary(uniqueKeysWithValues: config.clips.map { ($0.id, $0.path) })
        for (id, player) in players where keep[id] != player.clip.path {
            player.teardown()
            players[id] = nil
        }
        for clip in config.clips where players[clip.id] == nil {
            let player = ClipPlayer(clip: clip)
            player.onIssue = { [weak self] issue in self?.onFileIssue?(clip.id, issue) }
            players[clip.id] = player
        }

        let bound = config.clips.compactMap { clip in clip.hotKey.map { (clip, $0) } }
        let failed = hotKeys.replaceAll(
            with: bound.map { clip, combo in
                (combo, { [weak self] in self?.play(clip.id) })
            })
        return Dictionary(
            uniqueKeysWithValues: failed.map {
                (bound[$0].0.id, "\(bound[$0].1.displayString) is already used by the system or another app.")
            })
    }

    func play(_ id: UUID) {
        for (otherID, other) in players where otherID != id { other.stop() }
        players[id]?.play(scale: scale)
    }
}
