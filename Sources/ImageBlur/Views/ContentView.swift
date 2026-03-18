import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: EditorViewModel
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        HSplitView {
            EditorCanvasView(viewModel: viewModel)
                .frame(minWidth: 760, minHeight: 520)

            inspector
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 340)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(viewModel.document?.url.lastPathComponent ?? "Image Blur")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Öffnen", action: viewModel.openPanel)
                Button("Speichern als Kopie", action: viewModel.saveCopyPanel)
                    .disabled(!viewModel.hasImage)

                Divider()

                Picker("Werkzeug", selection: $viewModel.activeTool) {
                    ForEach(EditorTool.allCases) { tool in
                        Text(tool.title).tag(tool)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)

                Divider()

                Button {
                    viewModel.zoomOut()
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .disabled(!viewModel.hasImage)

                Button {
                    viewModel.resetViewport()
                } label: {
                    Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                }
                .disabled(!viewModel.hasImage)

                Button {
                    viewModel.zoomIn()
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .disabled(!viewModel.hasImage)
            }

            ToolbarItem(placement: .automatic) {
                HStack {
                    Text("Pixel")
                    Slider(
                        value: Binding(
                            get: { viewModel.selectedRegion?.pixelation ?? viewModel.defaultPixelation },
                            set: { viewModel.updatePixelation(to: $0) }
                        ),
                        in: 1...80,
                        onEditingChanged: { editing in
                            if editing {
                                viewModel.beginPixelationChange()
                            } else {
                                viewModel.endPixelationChange()
                            }
                        }
                    )
                    .frame(width: 180)
                }
            }
        }
        .dropDestination(for: URL.self) { items, _ in
            viewModel.handleDroppedFiles(items)
        }
        .alert("Fehler", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
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

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Inspector")
                .font(.headline)

            if let document = viewModel.document {
                GroupBox("Bild") {
                    LabeledContent("Datei", value: document.url.lastPathComponent)
                    LabeledContent("Größe", value: "\(Int(document.size.width)) × \(Int(document.size.height)) px")
                    LabeledContent("Format", value: document.fileExtension.uppercased())
                }
            } else {
                Text("Kein Bild geladen")
                    .foregroundStyle(.secondary)
            }

            GroupBox("Regionen") {
                if viewModel.regions.isEmpty {
                    Text("Noch keine Verpixelungsbereiche angelegt.")
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
                            }
                            .tag(region.id)
                        }
                    }
                    .frame(minHeight: 180)
                }
            }

            GroupBox("Auswahl") {
                if let region = viewModel.selectedRegion {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Form", value: region.shape.title)
                        LabeledContent("Drehung", value: "\(Int(region.rotation * 180 / .pi))°")
                        LabeledContent("Pixelation", value: "\(Int(region.pixelation))")

                        Slider(
                            value: Binding(
                                get: { region.pixelation },
                                set: { viewModel.updatePixelation(to: $0) }
                            ),
                            in: 1...80,
                            onEditingChanged: { editing in
                                if editing {
                                    viewModel.beginPixelationChange()
                                } else {
                                    viewModel.endPixelationChange()
                                }
                            }
                        )

                        Button("Region löschen", role: .destructive, action: viewModel.deleteSelectedRegion)
                    }
                } else {
                    Text("Keine Region ausgewählt")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(18)
    }
}
