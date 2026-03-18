import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageIOServiceError: LocalizedError {
    case unsupportedFile
    case unableToReadImage
    case unableToCreateDestination
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            "Die Datei wird nicht als Bildformat unterstützt."
        case .unableToReadImage:
            "Das Bild konnte nicht geladen werden."
        case .unableToCreateDestination:
            "Die Ausgabedatei konnte nicht erstellt werden."
        case .saveFailed:
            "Das Bild konnte nicht gespeichert werden."
        }
    }
}

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
