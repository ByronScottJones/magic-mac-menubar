import AppKit

@main
@MainActor
enum MagicApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Menu-bar-only: no Dock icon. The bundle's LSUIElement key does the same when run as an .app.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
