import AppKit
import Combine
import CoreGraphics
import Foundation
import UniformTypeIdentifiers

struct EditorSnapshot {
    var regions: [BlurRegion]
    var selectedRegionID: UUID?
}

@MainActor
final class EditorViewModel: ObservableObject {
    @Published private(set) var document: ImageDocument?
    @Published var regions: [BlurRegion] = []
    @Published var selectedRegionID: UUID?
    @Published var activeTool: EditorTool = .select
    @Published var defaultPixelation: Double = 24
    @Published var zoom: CGFloat = 1
    @Published var panOffset: CGSize = .zero
    @Published private(set) var previewImage: CGImage?
    @Published var errorMessage: String?

    private let imageIO = ImageIOService()
    private let renderer = BlurRenderer()
    private weak var undoManager: UndoManager?
    private var pixelationChangeSnapshot: EditorSnapshot?

    var selectedRegion: BlurRegion? {
        guard let selectedRegionID else { return nil }
        return regions.first(where: { $0.id == selectedRegionID })
    }

    var hasImage: Bool {
        document != nil
    }

    func attachUndoManager(_ undoManager: UndoManager?) {
        self.undoManager = undoManager
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = imageIO.supportedContentTypes

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        loadImage(from: url)
    }

    func saveCopyPanel() {
        guard let document, let renderedImage = renderer.render(document: document, regions: regions) else {
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(document.typeIdentifier as String)].compactMap { $0 }
        panel.nameFieldStringValue = "\(document.fileName)-blurred.\(document.fileExtension)"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try imageIO.saveImage(renderedImage, from: document, to: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleDroppedFiles(_ urls: [URL]) -> Bool {
        guard let url = urls.first else {
            return false
        }

        loadImage(from: url)
        return true
    }

    func loadImage(from url: URL) {
        do {
            document = try imageIO.loadImage(from: url)
            regions = []
            selectedRegionID = nil
            zoom = 1
            panOffset = .zero
            previewImage = document?.cgImage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetViewport() {
        zoom = 1
        panOffset = .zero
    }

    func zoomIn() {
        zoom = min(zoom * 1.2, 8)
    }

    func zoomOut() {
        zoom = max(zoom / 1.2, 0.2)
    }

    func setPreviewNeedsRefresh() {
        refreshPreview()
    }

    func selectRegion(_ regionID: UUID?) {
        selectedRegionID = regionID
    }

    func deleteSelectedRegion() {
        guard let selectedRegionID else { return }
        let before = snapshot()
        regions.removeAll(where: { $0.id == selectedRegionID })
        self.selectedRegionID = nil
        refreshPreview()
        registerUndo(from: before, actionName: "Region löschen")
    }

    func beginPixelationChange() {
        pixelationChangeSnapshot = snapshot()
    }

    func updatePixelation(to value: Double) {
        if let selectedRegionID, let index = regions.firstIndex(where: { $0.id == selectedRegionID }) {
            regions[index].pixelation = value
            refreshPreview()
        } else {
            defaultPixelation = value
        }
    }

    func endPixelationChange() {
        guard let before = pixelationChangeSnapshot else {
            return
        }

        pixelationChangeSnapshot = nil
        if before.regions != regions {
            registerUndo(from: before, actionName: "Pixelation ändern")
        }
    }

    func replaceRegions(_ newRegions: [BlurRegion], selected selectedID: UUID? = nil) {
        regions = newRegions
        if let selectedID {
            selectedRegionID = selectedID
        }
        refreshPreview()
    }

    func commitChange(from before: EditorSnapshot, actionName: String) {
        refreshPreview()
        registerUndo(from: before, actionName: actionName)
    }

    func addRegion(_ region: BlurRegion, actionName: String = "Region hinzufügen") {
        let before = snapshot()
        regions.append(region)
        selectedRegionID = region.id
        refreshPreview()
        registerUndo(from: before, actionName: actionName)
    }

    func updateRegion(_ region: BlurRegion) {
        guard let index = regions.firstIndex(where: { $0.id == region.id }) else { return }
        regions[index] = region
        refreshPreview()
    }

    func snapshot() -> EditorSnapshot {
        EditorSnapshot(regions: regions, selectedRegionID: selectedRegionID)
    }

    private func refreshPreview() {
        guard let document else {
            previewImage = nil
            return
        }

        previewImage = renderer.render(document: document, regions: regions)
    }

    private func registerUndo(from before: EditorSnapshot, actionName: String) {
        let after = snapshot()
        guard before.regions != after.regions || before.selectedRegionID != after.selectedRegionID else {
            return
        }

        undoManager?.registerUndo(withTarget: self) { target in
            target.restore(snapshot: before, inverseSnapshot: after, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
    }

    private func restore(snapshot: EditorSnapshot, inverseSnapshot: EditorSnapshot, actionName: String) {
        regions = snapshot.regions
        selectedRegionID = snapshot.selectedRegionID
        refreshPreview()

        undoManager?.registerUndo(withTarget: self) { target in
            target.restore(snapshot: inverseSnapshot, inverseSnapshot: snapshot, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
    }
}
