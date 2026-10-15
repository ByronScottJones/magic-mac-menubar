import Combine
import Foundation
import MagicCore

/// Editable state behind the options window. Every change is persisted and applied immediately.
@MainActor
final class SettingsModel: ObservableObject {
    @Published var config: AppConfig {
        didSet { if config != oldValue { onChange(config) } }
    }
    /// Per-clip problems: a rejected hotkey choice, a hotkey the system refused, or an unplayable file.
    @Published private(set) var conflictIssues: [UUID: String] = [:]
    @Published private(set) var registrationIssues: [UUID: String] = [:]
    @Published private(set) var fileIssues: [UUID: String] = [:]

    func issue(for id: UUID) -> String? {
        conflictIssues[id] ?? registrationIssues[id] ?? fileIssues[id]
    }

    private let onChange: (AppConfig) -> Void

    init(config: AppConfig, onChange: @escaping (AppConfig) -> Void) {
        self.config = config
        self.onChange = onChange
    }

    func addClip(url: URL) {
        config.clips.append(
            Clip(name: url.deletingPathExtension().lastPathComponent, path: url.path))
    }

    func remove(_ id: UUID) {
        config.clips.removeAll { $0.id == id }
        conflictIssues[id] = nil
        fileIssues[id] = nil
    }

    func setPath(_ url: URL, for id: UUID) {
        guard let index = config.clips.firstIndex(where: { $0.id == id }) else { return }
        fileIssues[id] = nil
        config.clips[index].path = url.path
    }

    /// Rejects hotkeys already assigned to another clip; clearing (nil) always succeeds.
    func setHotKey(_ combo: HotKeyCombo?, for id: UUID) {
        guard let index = config.clips.firstIndex(where: { $0.id == id }) else { return }
        if let combo, let other = config.clip(using: combo, excluding: id) {
            conflictIssues[id] = "\(combo.displayString) is already assigned to “\(other.name)”."
            return
        }
        conflictIssues[id] = nil
        config.clips[index].hotKey = combo
    }

    func setRegistrationIssues(_ issues: [UUID: String]) {
        registrationIssues = issues
    }

    func setFileIssue(_ issue: String?, for id: UUID) {
        fileIssues[id] = issue
    }
}
