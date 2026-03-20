import AppKit
import Foundation
import Sparkle

/// Wraps Sparkle so update checks can stay optional for local and unsigned builds.
@MainActor
final class SparkleController: NSObject {
    private(set) var updaterController: SPUStandardUpdaterController?

    var isAvailable: Bool {
        updaterController != nil
    }

    var canCheckForUpdates: Bool {
        updaterController?.updater.canCheckForUpdates ?? false
    }

    var automaticallyChecksForUpdates: Bool {
        updaterController?.updater.automaticallyChecksForUpdates ?? false
    }

    func startIfConfigured() {
        guard updaterController == nil, Self.isConfigured(bundle: .main) else {
            return
        }

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func configureCheckForUpdatesMenuItem(_ item: NSMenuItem) {
        guard let updaterController else {
            item.isEnabled = false
            return
        }

        item.target = updaterController
        item.action = #selector(SPUStandardUpdaterController.checkForUpdates(_:))
        item.isEnabled = updaterController.updater.canCheckForUpdates
    }

    func configureAutomaticUpdatesMenuItem(_ item: NSMenuItem, target: AnyObject, action: Selector) {
        guard let updaterController else {
            item.isEnabled = false
            item.state = .off
            return
        }

        item.target = target
        item.action = action
        item.state = updaterController.updater.automaticallyChecksForUpdates ? .on : .off
        item.isEnabled = true
    }

    func toggleAutomaticChecks() {
        guard let updaterController else {
            return
        }

        updaterController.updater.automaticallyChecksForUpdates.toggle()
    }

    private static func isConfigured(bundle: Bundle) -> Bool {
        guard bundle.bundleURL.pathExtension == "app" else {
            return false
        }

        guard
            let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        else {
            return false
        }

        return !feedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
