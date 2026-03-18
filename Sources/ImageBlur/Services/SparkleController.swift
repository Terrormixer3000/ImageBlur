import AppKit
import Foundation
import Sparkle

/// Wraps Sparkle so update checks can stay optional for local and unsigned builds.
@MainActor
final class SparkleController: NSObject {
    private(set) var updaterController: SPUStandardUpdaterController?

    override init() {
        super.init()

        // Sparkle is only started for packaged app bundles that provide a real feed URL
        // and public signing key. This avoids noisy failures in local development runs.
        guard Self.isConfigured(bundle: .main) else {
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
