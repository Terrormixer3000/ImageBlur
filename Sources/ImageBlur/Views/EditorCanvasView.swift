import SwiftUI

private enum CanvasAction {
    case none
    case panning(initialPan: CGSize)
    case moving(regionID: UUID, initialRegion: BlurRegion, initialSnapshot: EditorSnapshot)
    case resizing(regionID: UUID, handle: ResizeHandle, initialRegion: BlurRegion, initialSnapshot: EditorSnapshot)
    case rotating(regionID: UUID, initialRegion: BlurRegion, initialAngle: CGFloat, initialSnapshot: EditorSnapshot)
    case drawingRect(start: CGPoint, shape: BlurShape)
    case drawingLasso(points: [CGPoint])
}

struct EditorCanvasView: View {
    @ObservedObject var viewModel: EditorViewModel

    @State private var canvasAction: CanvasAction = .none
    @State private var draftRegion: BlurRegion?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()

                if let document = viewModel.document,
                   let previewImage = viewModel.previewImage {
                    let imageFrame = fittedRect(for: document.size, in: geometry.size)

                    Image(decorative: previewImage, scale: 1, orientation: .up)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: imageFrame.width, height: imageFrame.height)
                        .position(x: imageFrame.midX, y: imageFrame.midY)

                    regionOverlay(in: imageFrame)

                    if let draftRegion {
                        let path = Path(draftRegion.transformedPath())
                            .applying(imageToViewTransform(for: imageFrame, imageSize: document.size))
                        path
                            .stroke(Color.accentColor.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    }
                } else {
                    emptyState
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(in: geometry.size))
            .simultaneousGesture(tapGesture(in: geometry.size))
            .simultaneousGesture(magnifyGesture())
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Bild hierhin ziehen oder über \"Öffnen\" laden")
                .font(.title3.weight(.semibold))

            Text("Mehrere drehbare Verpixelungsbereiche werden nicht-destruktiv bearbeitet.")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func regionOverlay(in imageFrame: CGRect) -> some View {
        if let document = viewModel.document {
            let transform = imageToViewTransform(for: imageFrame, imageSize: document.size)

            ForEach(viewModel.regions) { region in
                let isSelected = region.id == viewModel.selectedRegionID
                let path = Path(region.transformedPath()).applying(transform)

                path
                    .fill(Color.accentColor.opacity(isSelected ? 0.18 : 0.1))

                path
                    .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.85), lineWidth: isSelected ? 2 : 1)
            }

            if let selectedRegion = viewModel.selectedRegion {
                selectionAdornment(for: selectedRegion, in: imageFrame)
            }
        }
    }

    @ViewBuilder
    private func selectionAdornment(for region: BlurRegion, in imageFrame: CGRect) -> some View {
        let handleScale = 1 / imageScale(for: imageFrame, imageSize: viewModel.document?.size ?? .zero)
        let overlayTransform = imageToViewTransform(for: imageFrame, imageSize: viewModel.document?.size ?? .zero)
        let selectionPath = Path(region.transformedPath()).applying(overlayTransform)

        selectionPath
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8, 4]))

        ForEach(ResizeHandle.allCases, id: \.self) { handle in
            let point = viewPoint(for: region.handlePosition(handle), in: imageFrame, imageSize: viewModel.document?.size ?? .zero)
            Circle()
                .fill(Color.white)
                .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                .frame(width: 12, height: 12)
                .position(point)
        }

        let rotationPoint = viewPoint(
            for: region.rotationHandlePosition(offset: 28 * handleScale),
            in: imageFrame,
            imageSize: viewModel.document?.size ?? .zero
        )

        Circle()
            .fill(Color.orange)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .position(rotationPoint)
    }

    private func dragGesture(in canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard let document = viewModel.document else { return }
                let imageFrame = fittedRect(for: document.size, in: canvasSize)

                switch canvasAction {
                case .none:
                    beginAction(with: value, imageFrame: imageFrame, imageSize: document.size)
                case .panning(let initialPan):
                    viewModel.panOffset = CGSize(
                        width: initialPan.width + (value.translation.width),
                        height: initialPan.height + (value.translation.height)
                    )
                case .moving(let regionID, let initialRegion, _):
                    guard let currentPoint = imagePoint(from: value.location, in: imageFrame, imageSize: document.size),
                          let startPoint = imagePoint(from: value.startLocation, in: imageFrame, imageSize: document.size),
                          let index = viewModel.regions.firstIndex(where: { $0.id == regionID })
                    else { return }

                    let delta = CGSize(width: currentPoint.x - startPoint.x, height: currentPoint.y - startPoint.y)
                    viewModel.regions[index] = initialRegion.translated(by: delta)
                    viewModel.setPreviewNeedsRefresh()
                case .resizing(let regionID, let handle, let initialRegion, _):
                    guard let currentPoint = imagePoint(from: value.location, in: imageFrame, imageSize: document.size),
                          let index = viewModel.regions.firstIndex(where: { $0.id == regionID })
                    else { return }

                    let localCurrent = initialRegion.localPoint(from: currentPoint)
                    let fixedCorner = oppositeCorner(of: handle, in: initialRegion.rect)
                    let newRect = CGRect(
                        x: min(fixedCorner.x, localCurrent.x),
                        y: min(fixedCorner.y, localCurrent.y),
                        width: max(abs(localCurrent.x - fixedCorner.x), 4),
                        height: max(abs(localCurrent.y - fixedCorner.y), 4)
                    )
                    viewModel.regions[index] = initialRegion.applyingRectChange(newRect, from: initialRegion)
                    viewModel.setPreviewNeedsRefresh()
                case .rotating(let regionID, let initialRegion, let initialAngle, _):
                    guard let currentPoint = imagePoint(from: value.location, in: imageFrame, imageSize: document.size),
                          let index = viewModel.regions.firstIndex(where: { $0.id == regionID })
                    else { return }

                    let currentAngle = atan2(currentPoint.y - initialRegion.center.y, currentPoint.x - initialRegion.center.x)
                    viewModel.regions[index] = initialRegion.rotated(by: currentAngle - initialAngle)
                    viewModel.setPreviewNeedsRefresh()
                case .drawingRect(let start, let shape):
                    guard let currentPoint = imagePoint(from: value.location, in: imageFrame, imageSize: document.size) else {
                        return
                    }

                    let rect = CGRect(
                        x: min(start.x, currentPoint.x),
                        y: min(start.y, currentPoint.y),
                        width: abs(currentPoint.x - start.x),
                        height: abs(currentPoint.y - start.y)
                    )
                    draftRegion = BlurRegion(shape: shape, rect: rect, pixelation: viewModel.defaultPixelation)
                case .drawingLasso(let points):
                    guard let currentPoint = imagePoint(from: value.location, in: imageFrame, imageSize: document.size) else {
                        return
                    }

                    if points.last.map({ hypot($0.x - currentPoint.x, $0.y - currentPoint.y) > 2 }) ?? true {
                        var updatedPoints = points
                        updatedPoints.append(currentPoint)
                        canvasAction = .drawingLasso(points: updatedPoints)
                        draftRegion = lassoDraft(from: updatedPoints)
                    }
                }
            }
            .onEnded { value in
                guard let document = viewModel.document else { return }
                let imageFrame = fittedRect(for: document.size, in: canvasSize)

                switch canvasAction {
                case .moving(_, _, let before):
                    viewModel.commitChange(from: before, actionName: "Region verschieben")
                case .resizing(_, _, _, let before):
                    viewModel.commitChange(from: before, actionName: "Region skalieren")
                case .rotating(_, _, _, let before):
                    viewModel.commitChange(from: before, actionName: "Region drehen")
                case .drawingRect(_, let shape):
                    if let finalRegion = draftRegion, finalRegion.rect.width > 4, finalRegion.rect.height > 4 {
                        viewModel.addRegion(finalRegion, actionName: shape == .rectangle ? "Rechteck hinzufügen" : "Ellipse hinzufügen")
                    }
                case .drawingLasso(let points):
                    if points.count > 2, let region = lassoDraft(from: points) {
                        viewModel.addRegion(region, actionName: "Lasso hinzufügen")
                    }
                case .panning, .none:
                    break
                }

                if case .none = canvasAction,
                   let point = imagePoint(from: value.location, in: imageFrame, imageSize: document.size) {
                    selectRegion(at: point)
                }

                canvasAction = .none
                draftRegion = nil
            }
    }

    private func tapGesture(in canvasSize: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard viewModel.activeTool == .select, let document = viewModel.document else { return }
                let imageFrame = fittedRect(for: document.size, in: canvasSize)
                guard let point = imagePoint(from: value.location, in: imageFrame, imageSize: document.size) else {
                    viewModel.selectRegion(nil)
                    return
                }
                selectRegion(at: point)
            }
    }

    private func magnifyGesture() -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                viewModel.zoom = min(max(value.magnification * viewModel.zoom, 0.2), 8)
            }
    }

    private func beginAction(with value: DragGesture.Value, imageFrame: CGRect, imageSize: CGSize) {
        switch viewModel.activeTool {
        case .rectangle, .ellipse:
            guard let start = imagePoint(from: value.startLocation, in: imageFrame, imageSize: imageSize) else {
                return
            }
            let shape: BlurShape = viewModel.activeTool == .rectangle ? .rectangle : .ellipse
            canvasAction = .drawingRect(start: start, shape: shape)
            draftRegion = BlurRegion(shape: shape, rect: CGRect(origin: start, size: .zero), pixelation: viewModel.defaultPixelation)
        case .lasso:
            guard let start = imagePoint(from: value.startLocation, in: imageFrame, imageSize: imageSize) else {
                return
            }
            canvasAction = .drawingLasso(points: [start])
            draftRegion = lassoDraft(from: [start])
        case .select:
            guard let start = imagePoint(from: value.startLocation, in: imageFrame, imageSize: imageSize) else {
                canvasAction = .panning(initialPan: viewModel.panOffset)
                return
            }

            if let selectedRegion = viewModel.selectedRegion {
                let rotationRadius: CGFloat = 10 / imageScale(for: imageFrame, imageSize: imageSize)
                let rotationHandle = selectedRegion.rotationHandlePosition(offset: 28 / imageScale(for: imageFrame, imageSize: imageSize))
                if hypot(rotationHandle.x - start.x, rotationHandle.y - start.y) < rotationRadius {
                    let angle = atan2(start.y - selectedRegion.center.y, start.x - selectedRegion.center.x)
                    canvasAction = .rotating(
                        regionID: selectedRegion.id,
                        initialRegion: selectedRegion,
                        initialAngle: angle,
                        initialSnapshot: viewModel.snapshot()
                    )
                    return
                }

                for handle in ResizeHandle.allCases {
                    let point = selectedRegion.handlePosition(handle)
                    let hitRadius: CGFloat = 10 / imageScale(for: imageFrame, imageSize: imageSize)
                    if hypot(point.x - start.x, point.y - start.y) < hitRadius {
                        canvasAction = .resizing(
                            regionID: selectedRegion.id,
                            handle: handle,
                            initialRegion: selectedRegion,
                            initialSnapshot: viewModel.snapshot()
                        )
                        return
                    }
                }
            }

            if let region = hitTestRegion(at: start) {
                viewModel.selectRegion(region.id)
                canvasAction = .moving(
                    regionID: region.id,
                    initialRegion: region,
                    initialSnapshot: viewModel.snapshot()
                )
            } else {
                viewModel.selectRegion(nil)
                canvasAction = .panning(initialPan: viewModel.panOffset)
            }
        }
    }

    private func hitTestRegion(at point: CGPoint) -> BlurRegion? {
        for region in viewModel.regions.reversed() {
            if region.contains(point) {
                return region
            }
        }
        return nil
    }

    private func selectRegion(at point: CGPoint) {
        viewModel.selectRegion(hitTestRegion(at: point)?.id)
    }

    private func lassoDraft(from points: [CGPoint]) -> BlurRegion? {
        guard points.count > 1 else { return nil }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let rect = CGRect(
            x: xs.min() ?? 0,
            y: ys.min() ?? 0,
            width: (xs.max() ?? 0) - (xs.min() ?? 0),
            height: (ys.max() ?? 0) - (ys.min() ?? 0)
        )

        return BlurRegion(
            shape: .lasso,
            rect: rect.standardizedWithMinimumSize(4),
            points: points,
            pixelation: viewModel.defaultPixelation
        )
    }

    private func fittedRect(for imageSize: CGSize, in canvasSize: CGSize) -> CGRect {
        let availableWidth = max(canvasSize.width - 24, 1)
        let availableHeight = max(canvasSize.height - 24, 1)
        let scale = min(availableWidth / imageSize.width, availableHeight / imageSize.height) * viewModel.zoom
        let width = imageSize.width * scale
        let height = imageSize.height * scale

        return CGRect(
            x: (canvasSize.width - width) / 2 + viewModel.panOffset.width,
            y: (canvasSize.height - height) / 2 + viewModel.panOffset.height,
            width: width,
            height: height
        )
    }

    private func imageScale(for imageFrame: CGRect, imageSize: CGSize) -> CGFloat {
        guard imageSize.width > 0 else { return 1 }
        return imageFrame.width / imageSize.width
    }

    private func imagePoint(from viewPoint: CGPoint, in imageFrame: CGRect, imageSize: CGSize) -> CGPoint? {
        guard imageFrame.contains(viewPoint) else {
            return nil
        }

        let x = (viewPoint.x - imageFrame.minX) / imageFrame.width * imageSize.width
        let y = (viewPoint.y - imageFrame.minY) / imageFrame.height * imageSize.height
        return CGPoint(x: x, y: y)
    }

    private func viewPoint(for imagePoint: CGPoint, in imageFrame: CGRect, imageSize: CGSize) -> CGPoint {
        CGPoint(
            x: imageFrame.minX + (imagePoint.x / imageSize.width) * imageFrame.width,
            y: imageFrame.minY + (imagePoint.y / imageSize.height) * imageFrame.height
        )
    }

    private func imageToViewTransform(for imageFrame: CGRect, imageSize: CGSize) -> CGAffineTransform {
        let scaleX = imageFrame.width / imageSize.width
        let scaleY = imageFrame.height / imageSize.height

        return CGAffineTransform.identity
            .translatedBy(x: imageFrame.minX, y: imageFrame.minY)
            .scaledBy(x: scaleX, y: scaleY)
    }

    private func oppositeCorner(of handle: ResizeHandle, in rect: CGRect) -> CGPoint {
        switch handle {
        case .topLeft:
            CGPoint(x: rect.maxX, y: rect.maxY)
        case .topRight:
            CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomLeft:
            CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomRight:
            CGPoint(x: rect.minX, y: rect.minY)
        }
    }
}
