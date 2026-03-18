import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case german = "de"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            "English"
        case .german:
            "Deutsch"
        }
    }
}

/// Stores the selected app language and resolves strings from the matching resource bundle.
final class LocalizationManager: ObservableObject, @unchecked Sendable {
    static let shared = LocalizationManager()
    static let languageDidChangeNotification = Notification.Name("LocalizationManager.languageDidChange")

    @Published private(set) var language: AppLanguage

    private let defaults: UserDefaults
    private let languageDefaultsKey = "selectedAppLanguage"

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let storedValue = defaults.string(forKey: languageDefaultsKey),
           let storedLanguage = AppLanguage(rawValue: storedValue) {
            language = storedLanguage
        } else {
            language = .english
        }
    }

    func setLanguage(_ language: AppLanguage) {
        guard self.language != language else {
            return
        }

        self.language = language
        defaults.set(language.rawValue, forKey: languageDefaultsKey)
        NotificationCenter.default.post(name: Self.languageDidChangeNotification, object: nil)
    }

    func localizedString(forKey key: String) -> String {
        let preferredBundle = bundle(for: language) ?? bundle(for: .english) ?? .module
        let fallback = bundle(for: .english) ?? .module
        let localizedValue = preferredBundle.localizedString(forKey: key, value: nil, table: nil)

        if localizedValue != key {
            return localizedValue
        }

        return fallback.localizedString(forKey: key, value: key, table: nil)
    }

    private func bundle(for language: AppLanguage) -> Bundle? {
        guard let path = Bundle.module.path(forResource: language.rawValue, ofType: "lproj") else {
            return nil
        }

        return Bundle(path: path)
    }
}

/// Resolves localized strings from the currently selected in-app language.
func localized(_ key: String) -> String {
    LocalizationManager.shared.localizedString(forKey: key)
}
