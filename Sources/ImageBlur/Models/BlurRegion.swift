import CoreGraphics
import Foundation

enum BlurShape: String, CaseIterable, Identifiable {
    case rectangle
    case ellipse
    case lasso

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rectangle: "Rechteck"
        case .ellipse: "Ellipse"
        case .lasso: "Lasso"
        }
    }
}

enum EditorTool: String, CaseIterable, Identifiable {
    case select
    case rectangle
    case ellipse
    case lasso

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: "Auswählen"
        case .rectangle: "Rechteck"
        case .ellipse: "Ellipse"
        case .lasso: "Lasso"
        }
    }
}

enum ResizeHandle: CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

struct BlurRegion: Identifiable, Equatable {
    let id: UUID
    var shape: BlurShape
    var rect: CGRect
    var points: [CGPoint]
    var rotation: CGFloat
    var pixelation: Double

    init(
        id: UUID = UUID(),
        shape: BlurShape,
        rect: CGRect,
        points: [CGPoint] = [],
        rotation: CGFloat = 0,
        pixelation: Double
    ) {
        self.id = id
        self.shape = shape
        self.rect = rect.standardizedWithMinimumSize(1)
        self.points = points
        self.rotation = rotation
        self.pixelation = pixelation
    }

    var center: CGPoint {
        CGPoint(x: rect.midX, y: rect.midY)
    }

    var supportsFreeformPoints: Bool {
        shape == .lasso
    }

    func transformedPath() -> CGPath {
        let base = CGMutablePath()

        switch shape {
        case .rectangle:
            base.addRect(rect)
        case .ellipse:
            base.addEllipse(in: rect)
        case .lasso:
            if let first = points.first {
                base.move(to: first)
                for point in points.dropFirst() {
                    base.addLine(to: point)
                }
                base.closeSubpath()
            } else {
                base.addRect(rect)
            }
        }

        var transform = CGAffineTransform.identity
            .translatedBy(x: center.x, y: center.y)
            .rotated(by: rotation)
            .translatedBy(x: -center.x, y: -center.y)

        return base.copy(using: &transform) ?? base
    }

    func contains(_ point: CGPoint) -> Bool {
        transformedPath().contains(point)
    }

    func translated(by delta: CGSize) -> BlurRegion {
        var copy = self
        copy.rect = rect.offsetBy(dx: delta.width, dy: delta.height)
        if supportsFreeformPoints {
            copy.points = points.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
        }
        return copy
    }

    func rotated(by delta: CGFloat) -> BlurRegion {
        var copy = self
        copy.rotation += delta
        return copy
    }

    func applyingRectChange(_ newRect: CGRect, from initial: BlurRegion) -> BlurRegion {
        let clampedRect = newRect.standardizedWithMinimumSize(4)
        var copy = self
        copy.rect = clampedRect

        guard supportsFreeformPoints else {
            return copy
        }

        let oldRect = initial.rect.standardizedWithMinimumSize(1)
        let scaleX = clampedRect.width / oldRect.width
        let scaleY = clampedRect.height / oldRect.height

        copy.points = initial.points.map { point in
            let normalizedX = (point.x - oldRect.minX) * scaleX
            let normalizedY = (point.y - oldRect.minY) * scaleY
            return CGPoint(
                x: clampedRect.minX + normalizedX,
                y: clampedRect.minY + normalizedY
            )
        }

        return copy
    }

    func localPoint(from imagePoint: CGPoint) -> CGPoint {
        imagePoint.rotated(around: center, angle: -rotation)
    }

    func handlePosition(_ handle: ResizeHandle) -> CGPoint {
        let localPoint: CGPoint
        switch handle {
        case .topLeft:
            localPoint = CGPoint(x: rect.minX, y: rect.minY)
        case .topRight:
            localPoint = CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft:
            localPoint = CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight:
            localPoint = CGPoint(x: rect.maxX, y: rect.maxY)
        }

        return localPoint.rotated(around: center, angle: rotation)
    }

    func rotationHandlePosition(offset: CGFloat) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.minY - offset)
            .rotated(around: center, angle: rotation)
    }
}

extension CGRect {
    func standardizedWithMinimumSize(_ minimum: CGFloat) -> CGRect {
        let standardized = standardized
        return CGRect(
            x: standardized.origin.x,
            y: standardized.origin.y,
            width: max(standardized.width, minimum),
            height: max(standardized.height, minimum)
        )
    }
}

extension CGPoint {
    func rotated(around center: CGPoint, angle: CGFloat) -> CGPoint {
        let translatedX = x - center.x
        let translatedY = y - center.y
        let cosine = cos(angle)
        let sine = sin(angle)

        return CGPoint(
            x: center.x + translatedX * cosine - translatedY * sine,
            y: center.y + translatedX * sine + translatedY * cosine
        )
    }
}
