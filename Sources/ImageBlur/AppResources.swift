import Foundation

enum AppResources {
    private static let bundleName = "ImageBlur_ImageBlur"

    static let bundle: Bundle = {
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("\(bundleName).bundle"),
            Bundle.main.bundleURL.appendingPathComponent("\(bundleName).bundle")
        ]

        for candidate in candidates {
            if let candidate, let bundle = Bundle(url: candidate) {
                return bundle
            }
        }

        return .module
    }()
}
