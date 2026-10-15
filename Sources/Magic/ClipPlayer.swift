import AVFoundation
import AppKit
import MagicCore

/// A layer-backed view whose backing layer is the `AVPlayerLayer`, so video frames are
/// composited directly with no intermediate drawing.
private final class PlayerView: NSView {
    override func makeBackingLayer() -> CALayer { AVPlayerLayer() }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

private final class OverlayPanel: NSPanel {
    // Never take focus from the app the user is working in.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Holds one clip fully prepared for instant playback.
///
/// The decoded first frame and audio buffers are preloaded (`preroll`), and the overlay window is kept
/// on screen at alpha 0 so the window server already has its backing store. Showing the clip is then
/// just "set alpha to 1 and play", with no asset loading, window creation or ordering work.
@MainActor
final class ClipPlayer {
    let clip: Clip

    /// Called with a user-presentable problem, or nil once the clip loaded successfully.
    var onIssue: ((String?) -> Void)?

    private let player = AVPlayer()
    private let panel: OverlayPanel
    private let view = PlayerView()
    private var nativeSize = CGSize(width: 320, height: 240)
    private var endObserver: NSObjectProtocol?
    private var isReady = false
    private(set) var isShowing = false

    init(clip: Clip) {
        self.clip = clip
        panel = OverlayPanel(
            contentRect: NSRect(origin: .zero, size: nativeSize),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.alphaValue = 0
        view.wantsLayer = true
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        panel.contentView = view

        player.automaticallyWaitsToMinimizeStalling = false
        player.actionAtItemEnd = .pause
        Task { await load() }
    }

    func teardown() {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        panel.orderOut(nil)
    }

    /// Friendly codec name for the error message, e.g. "VP9" for the `vp09` FourCC.
    private static func videoCodecName(_ track: AVAssetTrack?) async -> String? {
        guard let track, let description = try? await track.load(.formatDescriptions).first else {
            return nil
        }
        switch CMFormatDescriptionGetMediaSubType(description) {
        case kCMVideoCodecType_VP9: return "VP9"
        case 0x6176_3031: return "AV1"  // 'av01'
        case let code:
            let bytes = (0..<4).map { UInt8((code >> (24 - 8 * UInt32($0))) & 0xFF) }
            return String(bytes: bytes, encoding: .ascii)
        }
    }

    private func load() async {
        let url = URL(fileURLWithPath: clip.path)
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            onIssue?("File not found: \(url.lastPathComponent)")
            return
        }
        let asset = AVURLAsset(url: url)
        do {
            let playable = try await asset.load(.isPlayable)
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            guard playable, let track = videoTracks.first else {
                let codec = await Self.videoCodecName(videoTracks.first)
                onIssue?(
                    "macOS can't play this video\(codec.map { " (\($0))" } ?? ""). "
                        + "Convert it to H.264 or HEVC in an MP4 or MOV, e.g. "
                        + "ffmpeg -i in -c:v libx264 -c:a aac out.mp4")
                return
            }
            let size = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            nativeSize = CGRect(origin: .zero, size: size).applying(transform).standardized.size
        } catch {
            onIssue?("Could not read video: \(error.localizedDescription)")
            return
        }

        let item = AVPlayerItem(asset: asset)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.finished() }
        }
        player.replaceCurrentItem(with: item)
        guard await waitUntilReady(item) else {
            onIssue?("Could not prepare video: \(item.error?.localizedDescription ?? "unknown error")")
            return
        }
        await rearm()
        isReady = true
        panel.orderFrontRegardless()  // stays invisible (alpha 0) but resident in the window server
        onIssue?(nil)
    }

    /// `preroll` raises an exception unless the item is `readyToPlay`, so wait for that first. Polls
    /// (about 100 ms for a local file) because a Combine KVO stream never delivered the status change.
    private func waitUntilReady(_ item: AVPlayerItem) async -> Bool {
        for _ in 0..<100 {
            switch item.status {
            case .readyToPlay: return true
            case .failed: return false
            default: try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        return false
    }

    /// Rewinds to the first frame and fills the playback buffers so the next `play()` starts at once.
    private func rearm() async {
        await player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        _ = await player.preroll(atRate: 1.0)
    }

    func play(scale: Double) {
        guard isReady else { return }
        if isShowing {
            // Retriggered mid-playback: the hotkey toggles, so dismiss.
            stop()
            return
        }
        panel.setFrame(frame(scale: scale), display: false)
        panel.alphaValue = 1
        isShowing = true
        player.play()
    }

    /// Hides the overlay immediately, then gets ready for the next trigger.
    func stop() {
        guard isShowing else { return }
        panel.alphaValue = 0
        isShowing = false
        player.pause()
        Task { await rearm() }
    }

    private func finished() {
        stop()
    }

    /// Centered on the screen containing the mouse pointer.
    private func frame(scale: Double) -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var size = CGSize(width: nativeSize.width * scale, height: nativeSize.height * scale)
        let fit = min(1, visible.width / size.width, visible.height / size.height)
        size = CGSize(width: size.width * fit, height: size.height * fit)
        return NSRect(
            x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
            width: size.width, height: size.height)
    }
}
