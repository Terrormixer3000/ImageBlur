import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let viewModel = EditorViewModel()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        createMainWindow()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        _ = viewModel.openImageReplacingCurrentIfNeeded(from: url)
        createMainWindowIfNeeded()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc private func openImage(_ sender: Any?) {
        viewModel.openPanel()
        createMainWindowIfNeeded()
    }

    @objc private func saveCopy(_ sender: Any?) {
        viewModel.saveCopyPanel()
    }

    @objc private func deleteRegion(_ sender: Any?) {
        viewModel.deleteSelectedRegion()
    }

    private func createMainWindowIfNeeded() {
        if window == nil {
            createMainWindow()
        }
    }

    private func createMainWindow() {
        let contentView = ContentView(viewModel: viewModel)
            .frame(minWidth: 1100, minHeight: 700)

        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "ImageBlur"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    private func buildMenu() {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "ImageBlur beenden",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "Ablage")
        fileMenuItem.submenu = fileMenu

        let openItem = NSMenuItem(title: "Bild öffnen", action: #selector(openImage(_:)), keyEquivalent: "o")
        openItem.target = self
        fileMenu.addItem(openItem)

        let saveItem = NSMenuItem(title: "Speichern als Kopie", action: #selector(saveCopy(_:)), keyEquivalent: "S")
        saveItem.target = self
        fileMenu.addItem(saveItem)

        fileMenu.addItem(.separator())

        let deleteItem = NSMenuItem(title: "Region löschen", action: #selector(deleteRegion(_:)), keyEquivalent: "\u{8}")
        deleteItem.target = self
        fileMenu.addItem(deleteItem)

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Bearbeiten")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Rückgängig", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Wiederholen", action: Selector(("redo:")), keyEquivalent: "Z")
    }
}

@main
enum ImageBlurApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
