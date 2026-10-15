import AppKit
import Carbon.HIToolbox
import MagicCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ConfigStore(url: ConfigStore.defaultURL)
    private let controller = PlaybackController()
    private var model: SettingsModel!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()

        model = SettingsModel(config: loadConfig()) { [weak self] config in
            self?.configDidChange(config)
        }
        controller.onFileIssue = { [weak self] id, issue in self?.model.setFileIssue(issue, for: id) }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "wand.and.stars", accessibilityDescription: "Magic")
        rebuildMenu()
        model.setRegistrationIssues(controller.apply(model.config))
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.ensureReachable() }
        }
    }

    // MARK: Fallback

    /// macOS gives a status item no room when the menu bar is full (common under a notch), parking its
    /// window off screen. Rather than leave the app running with no way in, show a Dock icon and the
    /// Settings window.
    private func ensureReachable() {
        guard let frame = statusItem.button?.window?.frame,
            !NSScreen.screens.contains(where: { $0.frame.intersects(frame) })
        else { return }
        NSApp.setActivationPolicy(.regular)
        showSettings()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showSettings() }
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        statusItem.menu
    }

    // MARK: Config

    private func loadConfig() -> AppConfig {
        do {
            if let existing = try store.load() { return existing }
        } catch {
            let aside = store.quarantine()
            let alert = NSAlert()
            alert.messageText = "Magic couldn’t read its settings"
            alert.informativeText =
                "\(error.localizedDescription)\n\nStarting with defaults."
                + (aside.map { "\nThe old file was kept at \($0.path)." } ?? "")
            alert.runModal()
        }
        return seedConfig()
    }

    /// First run: copy the bundled video somewhere stable and bind it to ⌃⌥M.
    private func seedConfig() -> AppConfig {
        guard let bundled = Bundle.main.url(forResource: "magic", withExtension: "mp4") else {
            return AppConfig()
        }
        let folder = store.url.deletingLastPathComponent().appendingPathComponent("Videos")
        let destination = folder.appendingPathComponent(bundled.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.copyItem(at: bundled, to: destination)
            }
        } catch {
            return AppConfig()
        }
        let combo = HotKeyCombo(keyCode: 46, modifiers: UInt32(controlKey | optionKey))
        let config = AppConfig(clips: [Clip(name: "Magic", path: destination.path, hotKey: combo)])
        try? store.save(config)
        return config
    }

    private func configDidChange(_ config: AppConfig) {
        do {
            try store.save(config)
        } catch {
            NSLog("Magic: failed to save settings: \(error.localizedDescription)")
        }
        model.setRegistrationIssues(controller.apply(config))
        rebuildMenu()
    }

    // MARK: Menu

    private func rebuildMenu() {
        let menu = NSMenu()
        for clip in model.config.clips {
            let hotKey = clip.hotKey.map { "  \($0.displayString)" } ?? ""
            let item = NSMenuItem(
                title: "Play \(clip.name)\(hotKey)", action: #selector(playClip(_:)), keyEquivalent: "")
            item.representedObject = clip.id
            item.target = self
            menu.addItem(item)
        }
        if !model.config.clips.isEmpty { menu.addItem(.separator()) }
        let settings = NSMenuItem(
            title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(
            NSMenuItem(
                title: "Quit Magic", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func playClip(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        controller.play(id)
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = "Magic Settings"
            window.styleMask = [.titled, .closable, .resizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// A menu-bar-only app has no menu bar of its own, but text fields still need the standard
    /// Edit key equivalents (⌘C/⌘V/⌘A…) to resolve.
    private func installMainMenu() {
        let main = NSMenu()
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(NSMenuItem())
        main.addItem(editItem)
        NSApp.mainMenu = main
    }
}
