import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// User-facing image import and export errors.
enum ImageIOServiceError: LocalizedError {
    case unsupportedFile
    case unableToReadImage
    case unableToCreateDestination
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            localized("error.unsupported-file")
        case .unableToReadImage:
            localized("error.unable-to-read-image")
        case .unableToCreateDestination:
            localized("error.unable-to-create-destination")
        case .saveFailed:
            localized("error.save-failed")
        }
    }
}

/// Loads source images with metadata and writes edited copies back in the original format.
final class ImageIOService {
    private let ciContext = CIContext()

    func loadImage(from url: URL) throws -> ImageDocument {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let typeIdentifier = CGImageSourceGetType(source)
        else {
            throw ImageIOServiceError.unsupportedFile
        }

        guard let inputImage = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]),
              let cgImage = ciContext.createCGImage(inputImage, from: inputImage.extent.integral)
        else {
            throw ImageIOServiceError.unableToReadImage
        }

        // Keeping the original metadata allows exports to preserve format-specific properties
        // like color profiles and camera metadata where possible.
        let sourceProperties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]

        return ImageDocument(
            url: url,
            cgImage: cgImage,
            typeIdentifier: typeIdentifier,
            properties: sourceProperties
        )
    }

    func saveImage(_ cgImage: CGImage, from document: ImageDocument, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            document.typeIdentifier,
            1,
            nil
        ) else {
            throw ImageIOServiceError.unableToCreateDestination
        }

        var properties = document.properties
        properties[kCGImagePropertyOrientation] = 1

        // JPEG has to be re-encoded after editing, so keep compression quality high by default.
        if UTType(document.typeIdentifier as String)?.conforms(to: .jpeg) == true {
            properties[kCGImageDestinationLossyCompressionQuality] = 0.95
        }

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ImageIOServiceError.saveFailed
        }
    }

    var supportedContentTypes: [UTType] {
        var types: [UTType] = [.png, .jpeg, .tiff]
        if let heic = UTType(filenameExtension: "heic") {
            types.append(heic)
        }
        return types
    }
}
