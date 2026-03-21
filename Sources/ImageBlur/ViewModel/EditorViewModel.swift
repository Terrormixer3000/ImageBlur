import AppKit
import Combine
import CoreGraphics
import Foundation
import UniformTypeIdentifiers

/// Enough editor state to register reversible undo operations.
struct EditorSnapshot {
    var regions: [BlurRegion]
    var selectedRegionID: UUID?
}

private struct ExportDestination {
    let sourceURL: URL
    let exportURL: URL
}

/// Owns the editor state, image lifecycle, preview rendering, and undo integration.
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
    private var savedRegions: [BlurRegion] = []
    private var exportDestination: ExportDestination?

    var selectedRegion: BlurRegion? {
        guard let selectedRegionID else { return nil }
        return regions.first(where: { $0.id == selectedRegionID })
    }

    var hasImage: Bool {
        document != nil
    }

    var hasUnsavedChanges: Bool {
        guard document != nil else { return false }
        return regions != savedRegions
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

        _ = openImageReplacingCurrentIfNeeded(from: url)
    }

    @discardableResult
    func save() -> Bool {
        guard let document, let renderedImage = renderer.render(document: document, regions: regions) else {
            return false
        }

        if let exportURL = exportDestination(for: document) {
            return saveRenderedImage(renderedImage, from: document, to: exportURL)
        }

        return saveCopyPanel()
    }

    @discardableResult
    func saveCopyPanel() -> Bool {
        guard let document, let renderedImage = renderer.render(document: document, regions: regions) else {
            return false
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(document.typeIdentifier as String)].compactMap { $0 }
        if let exportURL = exportDestination(for: document) {
            panel.directoryURL = exportURL.deletingLastPathComponent()
            panel.nameFieldStringValue = exportURL.lastPathComponent
        } else {
            panel.nameFieldStringValue = "\(document.fileName)-\(localized("export.filename.suffix")).\(document.fileExtension)"
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }

        return saveRenderedImage(renderedImage, from: document, to: url)
    }

    func handleDroppedFiles(_ urls: [URL]) -> Bool {
        guard let url = urls.first else {
            return false
        }

        return openImageReplacingCurrentIfNeeded(from: url)
    }

    @discardableResult
    func openImageReplacingCurrentIfNeeded(from url: URL) -> Bool {
        // The current image is only replaced after the unsaved-changes prompt resolves.
        guard confirmReplacementIfNeeded() else {
            return false
        }

        loadImage(from: url)
        return document != nil
    }

    func loadImage(from url: URL) {
        do {
            document = try imageIO.loadImage(from: url)
            regions = []
            savedRegions = []
            if exportDestination?.sourceURL != normalizedFileURL(url) {
                exportDestination = nil
            }
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
        zoom = min(zoom * 1.08, 8)
    }

    func zoomOut() {
        zoom = max(zoom / 1.08, 0.2)
    }

    func setPreviewNeedsRefresh() {
        refreshPreview()
    }

    func selectRegion(_ regionID: UUID?) {
        selectedRegionID = regionID
    }

    func deleteSelectedRegion() {
        guard let selectedRegionID else { return }
        deleteRegion(withID: selectedRegionID)
    }

    func deleteRegion(withID regionID: UUID) {
        let before = snapshot()
        regions.removeAll(where: { $0.id == regionID })
        if selectedRegionID == regionID {
            selectedRegionID = nil
        }
        refreshPreview()
        registerUndo(from: before, actionName: localized("undo.delete-region"))
    }

    func beginPixelationChange() {
        // Slider drags can emit many intermediate values, so capture one undo snapshot
        // at the start and commit it once editing ends.
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
            registerUndo(from: before, actionName: localized("undo.change-pixelation"))
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

    func addRegion(_ region: BlurRegion, actionName: String = localized("undo.add-region")) {
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

    private func confirmReplacementIfNeeded() -> Bool {
        guard hasUnsavedChanges else {
            return true
        }

        // The app exports edited copies instead of saving in place, so "save" here means
        // opening the existing export flow before the current document is replaced.
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = localized("unsaved-changes.title")
        alert.informativeText = localized("unsaved-changes.message")
        alert.addButton(withTitle: localized("unsaved-changes.save"))
        alert.addButton(withTitle: localized("unsaved-changes.discard"))
        alert.addButton(withTitle: localized("unsaved-changes.cancel"))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return save()
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }

    private func saveRenderedImage(_ renderedImage: CGImage, from document: ImageDocument, to url: URL) -> Bool {
        do {
            try imageIO.saveImage(renderedImage, from: document, to: url)
            exportDestination = ExportDestination(
                sourceURL: normalizedFileURL(document.url),
                exportURL: normalizedFileURL(url)
            )
            savedRegions = regions
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func exportDestination(for document: ImageDocument) -> URL? {
        guard let exportDestination, exportDestination.sourceURL == normalizedFileURL(document.url) else {
            return nil
        }

        return exportDestination.exportURL
    }

    private func normalizedFileURL(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }
}
