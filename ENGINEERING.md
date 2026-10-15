# Engineering Handover Notes

Audience: the engineer or agent continuing work on Magic. Update this file in
the same change set whenever architecture, decisions, verification, or risks
change.

## What this is

A macOS menu bar app that plays a video in a borderless overlay when a global
hotkey is pressed and removes the overlay the instant the video ends. Each video
has its own hotkey, managed in a Settings window. See [`README.md`](README.md)
for user-facing behavior.

## Tech stack

- Swift 6 toolchain (Swift 5 language mode), SwiftPM, macOS 14+.
- AppKit, SwiftUI, AVFoundation, Carbon (`RegisterEventHotKey`).
- No third-party dependencies.

## File map

| Path | Purpose |
| --- | --- |
| `Package.swift` | Targets: `MagicCore`, `Magic`, `MagicCoreTests` |
| `Sources/MagicCore/AppConfig.swift` | `Clip` and `AppConfig` models, JSON persistence |
| `Sources/MagicCore/HotKeyCombo.swift` | Hotkey value type, validation, display string |
| `Sources/Magic/MagicApp.swift` | `@main` entry point |
| `Sources/Magic/AppDelegate.swift` | Status item, Dock fallback, menu, lifecycle |
| `Sources/Magic/ClipPlayer.swift` | Per-clip `AVPlayer`, preroll, codec diagnostics |
| `Sources/Magic/PlaybackController.swift` | Overlay window and play/stop orchestration |
| `Sources/Magic/HotKeyManager.swift` | Carbon hotkey registration |
| `Sources/Magic/HotKeyRecorder.swift` | Shortcut recorder control |
| `Sources/Magic/SettingsModel.swift` | Settings state and config sync |
| `Sources/Magic/SettingsView.swift` | SwiftUI Settings window |
| `Tests/MagicCoreTests/` | Unit tests for `MagicCore` |
| `scripts/build-app.sh` | Release build and ad-hoc signed `.app` assembly |
| `Makefile` | Task runner (`make help`) |
| `.github/workflows/ci.yml` | Manual (workflow_dispatch) build, test, lint |
| `agents/` | Project copies of agent topic guidance |
| `assets/magic.mp4` | Default bundled clip (only tracked asset) |

## Architecture

`MagicCore` holds UI-free models and persistence. `Magic` wires them to the
system: `AppDelegate` owns a `ClipPlayer` per clip and a `PlaybackController`;
`HotKeyManager` maps hotkey events to playback. The overlay window is created
up front at alpha 0 so triggering is one alpha change plus `play()`; when the
clip ends it is hidden, rewound, and prerolled again.

## Key decisions

- Carbon hotkeys: no Accessibility permission needed. Rejected: `CGEventTap`.
- Prerolled players and a persistent overlay window for minimal latency.
- `Task { @MainActor in ... }` instead of `MainActor.assumeIsolated`, which
  crashed in the Swift runtime in timer callbacks (Swift 6.4, macOS 27).
- Polling `AVPlayerItem.status` before `preroll`; Combine KVO did not deliver
  the change.
- Ad-hoc signing only; no notarization.
- Third-party source downloads are not tracked in git (copyright and size).

## Verified

- 2026-10-15: `swift test` passes, 10 tests, 0 failures (local, macOS 27).
- 2026-10-15: `shellcheck scripts/build-app.sh` is clean.
- Not exercised here: the GitHub Actions workflow on a hosted runner (first
  run after push), the Markdown lint run in CI, and notarized distribution.

## Risks and future work

- Inside Claude Code's sandbox `swift build` and `open` fail with "Operation not
  permitted"; build and launch from a normal terminal.
- No UI tests; playback and overlay behavior are verified manually.
- Releases are unsigned/ad-hoc; add notarization before wide distribution.
- The bundled clip is third-party content; confirm rights before making the
  repository public or distributing binaries.

## Commands

```bash
make help     # list targets
make test     # swift test
make app      # dist/Magic.app
make lint     # shellcheck + markdownlint
```
