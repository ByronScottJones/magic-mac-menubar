import AppKit
import MagicCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Videos")
                .font(.headline)

            if model.config.clips.isEmpty {
                Text("No videos yet. Add one to assign a hotkey to it.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach($model.config.clips) { $clip in
                        ClipRow(clip: $clip, model: model)
                    }
                }
            }

            HStack {
                Button("Add Video…", action: addVideo)
                Spacer()
                Text("Size")
                Slider(value: $model.config.scale, in: AppConfig.scaleRange)
                    .frame(width: 160)
                    .accessibilityLabel("Video size")
                Text(String(format: "%.1f×", model.config.scale))
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .padding()
        .frame(minWidth: 640, minHeight: 320)
    }

    private func addVideo() {
        if let url = chooseVideo() { model.addClip(url: url) }
    }
}

private struct ClipRow: View {
    @Binding var clip: Clip
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                TextField("Name", text: $clip.name)
                    .frame(width: 130)
                Text(URL(fileURLWithPath: clip.path).lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(clip.path)
                Button("Choose…") {
                    if let url = chooseVideo() { model.setPath(url, for: clip.id) }
                }
                HotKeyRecorder(combo: clip.hotKey, label: "Shortcut for \(clip.name)") {
                    model.setHotKey($0, for: clip.id)
                }
                .frame(width: 140)
                Button(role: .destructive) {
                    model.remove(clip.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove \(clip.name)")
            }
            if let issue = model.issue(for: clip.id) {
                Label(issue, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Presents a file picker limited to movie formats AVFoundation can play (MP4, MOV, M4V).
@MainActor
private func chooseVideo() -> URL? {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.movie]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.message = "Choose a video (MP4, MOV or M4V)"
    return panel.runModal() == .OK ? panel.url : nil
}
