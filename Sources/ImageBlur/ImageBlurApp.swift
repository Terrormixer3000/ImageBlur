import AppKit
import SwiftUI

/// Drives the native AppKit window and menu setup for the SwiftUI editor.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let viewModel = EditorViewModel()
    private let localization = LocalizationManager.shared
    private let sparkleController = SparkleController()
    private var window: NSWindow?
    private var languageObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        sparkleController.startIfConfigured()
        languageObserver = NotificationCenter.default.addObserver(
            forName: LocalizationManager.languageDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.buildMenu()
            }
        }
        buildMenu()
        createMainWindow()
        installApplicationIcon()
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

    @objc private func changeLanguage(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let language = AppLanguage(rawValue: rawValue)
        else {
            return
        }

        localization.setLanguage(language)
    }

    @objc private func toggleAutomaticUpdateChecks(_ sender: NSMenuItem) {
        sparkleController.toggleAutomaticChecks()
        buildMenu()
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

    private func installApplicationIcon() {
        guard let iconURL = AppResources.bundle.url(forResource: "AppIcon", withExtension: "icns"),
              let iconImage = NSImage(contentsOf: iconURL)
        else {
            return
        }

        NSApp.applicationIconImage = iconImage
    }

    private func buildMenu() {
        // Menus are built manually because the app uses a fully programmatic AppKit entry point.
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let languageMenuItem = NSMenuItem(title: localized("menu.language"), action: nil, keyEquivalent: "")
        let languageMenu = NSMenu(title: localized("menu.language"))
        languageMenuItem.submenu = languageMenu
        appMenu.addItem(languageMenuItem)

        for language in AppLanguage.allCases {
            let item = NSMenuItem(title: language.displayName, action: #selector(changeLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.rawValue
            item.state = localization.language == language ? .on : .off
            languageMenu.addItem(item)
        }

        appMenu.addItem(.separator())

        appMenu.addItem(
            withTitle: localized("menu.quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        let checkForUpdatesItem = NSMenuItem(
            title: localized("menu.check-for-updates"),
            action: nil,
            keyEquivalent: ""
        )
        sparkleController.configureCheckForUpdatesMenuItem(checkForUpdatesItem)
        appMenu.insertItem(checkForUpdatesItem, at: 2)

        let automaticUpdatesItem = NSMenuItem(
            title: localized("menu.automatic-updates"),
            action: #selector(toggleAutomaticUpdateChecks(_:)),
            keyEquivalent: ""
        )
        sparkleController.configureAutomaticUpdatesMenuItem(
            automaticUpdatesItem,
            target: self,
            action: #selector(toggleAutomaticUpdateChecks(_:))
        )
        appMenu.insertItem(automaticUpdatesItem, at: 3)
        appMenu.insertItem(.separator(), at: 4)

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: localized("menu.file"))
        fileMenuItem.submenu = fileMenu

        let openItem = NSMenuItem(title: localized("menu.open-image"), action: #selector(openImage(_:)), keyEquivalent: "o")
        openItem.target = self
        fileMenu.addItem(openItem)

        let saveItem = NSMenuItem(title: localized("menu.save-copy"), action: #selector(saveCopy(_:)), keyEquivalent: "S")
        saveItem.target = self
        fileMenu.addItem(saveItem)

        fileMenu.addItem(.separator())

        let deleteItem = NSMenuItem(title: localized("menu.delete-region"), action: #selector(deleteRegion(_:)), keyEquivalent: "\u{8}")
        deleteItem.target = self
        fileMenu.addItem(deleteItem)

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: localized("menu.edit"))
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: localized("menu.undo"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: localized("menu.redo"), action: Selector(("redo:")), keyEquivalent: "Z")
    }
}

@main
enum ImageBlurApp {
    static func main() {
        // The app uses NSApplication directly instead of SwiftUI's App lifecycle
        // so AppKit window and menu customization stay predictable.
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
