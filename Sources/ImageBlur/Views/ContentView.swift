import SwiftUI

/// Main split view hosting the canvas and the lightweight inspector sidebar.
struct ContentView: View {
    @ObservedObject var viewModel: EditorViewModel
    @Environment(\.undoManager) private var undoManager

    private var pixelationBinding: Binding<Double> {
        // The toolbar slider edits the selected region when available,
        // otherwise it changes the default value for newly created regions.
        Binding(
            get: { viewModel.selectedRegion?.pixelation ?? viewModel.defaultPixelation },
            set: { viewModel.updatePixelation(to: $0) }
        )
    }

    private var currentPixelationValue: Int {
        Int((viewModel.selectedRegion?.pixelation ?? viewModel.defaultPixelation).rounded())
    }

    var body: some View {
        HSplitView {
            EditorCanvasView(viewModel: viewModel)
                .frame(minWidth: 760, minHeight: 520)

            inspector
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 340)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: viewModel.openPanel) {
                    Image(systemName: "folder")
                }
                .help(localized("toolbar.open"))

                Button {
                    _ = viewModel.saveCopyPanel()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(!viewModel.hasImage)
                .help(localized("toolbar.save-copy"))
            }

            ToolbarItem(placement: .primaryAction) {
                toolbarPalette
            }
        }
        .dropDestination(for: URL.self) { items, _ in
            viewModel.handleDroppedFiles(items)
        }
        .alert(localized("alert.error.title"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(localized("common.ok"), role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            viewModel.attachUndoManager(undoManager)
        }
        .onChange(of: undoManager) { _, newUndoManager in
            viewModel.attachUndoManager(newUndoManager)
        }
    }

    private var toolbarPalette: some View {
        HStack(spacing: 10) {
            toolMenu

            Divider()
                .frame(height: 22)

            zoomControls

            Divider()
                .frame(height: 22)

            pixelationControls
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .controlSize(.small)
    }

    private var toolMenu: some View {
        Menu {
            toolMenuItem(.select)
            toolMenuItem(.rectangle)
            toolMenuItem(.ellipse)
            toolMenuItem(.lasso)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: viewModel.activeTool.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16)
                Text(viewModel.activeTool.title)
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.05), in: Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    @ViewBuilder
    private func toolMenuItem(_ tool: EditorTool) -> some View {
        Button {
            viewModel.activeTool = tool
        } label: {
            HStack {
                Label(tool.title, systemImage: tool.symbolName)
                Spacer()
                if viewModel.activeTool == tool {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 4) {
            toolbarIconButton(systemName: "minus.magnifyingglass", help: localized("toolbar.zoom-out"), action: viewModel.zoomOut)
                .disabled(!viewModel.hasImage)

            Button {
                viewModel.resetViewport()
            } label: {
                Text("\(Int((viewModel.zoom * 100).rounded()))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(minWidth: 44)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(viewModel.hasImage ? .primary : .secondary)
            .disabled(!viewModel.hasImage)
            .help(localized("toolbar.reset-zoom"))

            toolbarIconButton(systemName: "plus.magnifyingglass", help: localized("toolbar.zoom-in"), action: viewModel.zoomIn)
                .disabled(!viewModel.hasImage)
        }
        .padding(.horizontal, 4)
    }

    private var pixelationControls: some View {
        HStack(spacing: 8) {
            Label(localized("toolbar.pixelation"), systemImage: "square.grid.3x3.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)

            Slider(
                value: pixelationBinding,
                in: 1...80,
                onEditingChanged: { editing in
                    // Bracket slider drags so pixelation changes collapse into a single undo step.
                    if editing {
                        viewModel.beginPixelationChange()
                    } else {
                        viewModel.endPixelationChange()
                    }
                }
            )
            .frame(width: 130)

            Text("\(currentPixelationValue)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 26, alignment: .trailing)
        }
        .disabled(!viewModel.hasImage)
    }

    private func toolbarIconButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    private func inspectorRow(_ title: String, value: String, allowWrapping: Bool = false) -> some View {
        HStack(alignment: allowWrapping ? .top : .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)

            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .lineLimit(allowWrapping ? 3 : 1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(localized("inspector.title"))
                .font(.headline)

            if let document = viewModel.document {
                GroupBox(localized("inspector.image")) {
                    VStack(alignment: .leading, spacing: 12) {
                        inspectorRow(localized("inspector.file"), value: document.url.lastPathComponent, allowWrapping: true)
                        inspectorRow(localized("inspector.size"), value: "\(Int(document.size.width)) × \(Int(document.size.height)) px")
                        inspectorRow(localized("inspector.format"), value: document.fileExtension.uppercased())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(localized("inspector.no-image"))
                    .foregroundStyle(.secondary)
            }

            GroupBox(localized("inspector.regions")) {
                if viewModel.regions.isEmpty {
                    Text(localized("inspector.no-regions"))
                        .foregroundStyle(.secondary)
                } else {
                    List(selection: Binding(
                        get: { viewModel.selectedRegionID.map { Set([ $0 ]) } ?? [] },
                        set: { selection in
                            viewModel.selectRegion(selection.first)
                        }
                    )) {
                        ForEach(viewModel.regions) { region in
                            HStack {
                                Text(region.shape.title)
                                Spacer()
                                Text("\(Int(region.pixelation))")
                                    .foregroundStyle(.secondary)
                                Button {
                                    viewModel.deleteRegion(withID: region.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help(localized("region.delete"))
                            }
                            .tag(region.id)
                        }
                    }
                    .frame(minHeight: 180)
                }
            }

            Spacer()
        }
        .padding(18)
    }
}

private extension EditorTool {
    var symbolName: String {
        switch self {
        case .select:
            "cursorarrow"
        case .rectangle:
            "rectangle"
        case .ellipse:
            "circle"
        case .lasso:
            "lasso"
        }
    }
}
