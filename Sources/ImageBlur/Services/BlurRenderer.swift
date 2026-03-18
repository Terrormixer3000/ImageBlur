import CoreGraphics
import CoreImage
import Foundation

final class BlurRenderer {
    private let ciContext = CIContext(options: [.cacheIntermediates: true])

    func render(document: ImageDocument, regions: [BlurRegion]) -> CGImage? {
        guard !regions.isEmpty else {
            return document.cgImage
        }

        let extent = CGRect(origin: .zero, size: document.size)
        var workingImage = CIImage(cgImage: document.cgImage)

        for region in regions {
            let pixelated = workingImage.applyingFilter(
                "CIPixellate",
                parameters: [kCIInputScaleKey: max(region.pixelation, 1)]
            )

            guard let maskImage = maskImage(for: region, canvasSize: document.size) else {
                continue
            }

            workingImage = pixelated.applyingFilter(
                "CIBlendWithMask",
                parameters: [
                    kCIInputBackgroundImageKey: workingImage,
                    kCIInputMaskImageKey: maskImage
                ]
            )
        }

        return ciContext.createCGImage(workingImage, from: extent)
    }

    private func maskImage(for region: BlurRegion, canvasSize: CGSize) -> CIImage? {
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        guard width > 0, height > 0 else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: 0
        ) else {
            return nil
        }

        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        context.translateBy(x: 0, y: canvasSize.height)
        context.scaleBy(x: 1, y: -1)
        context.setFillColor(gray: 1, alpha: 1)
        context.addPath(region.transformedPath())
        context.fillPath()

        guard let cgMask = context.makeImage() else {
            return nil
        }

        return CIImage(cgImage: cgMask)
    }
}
