import CoreGraphics
import Foundation

/// The loaded source image plus the metadata needed to export back in the original format.
struct ImageDocument {
    let url: URL
    let cgImage: CGImage
    let typeIdentifier: CFString
    let properties: [CFString: Any]

    var size: CGSize {
        CGSize(width: cgImage.width, height: cgImage.height)
    }

    var fileName: String {
        url.deletingPathExtension().lastPathComponent
    }

    var fileExtension: String {
        url.pathExtension
    }
}
