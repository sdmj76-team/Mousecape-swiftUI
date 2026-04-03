//
//  HomeView.swift
//  Mousecape
//
//  Home view with Cape icon grid and preview panel
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Preview Scale Constants

/// Scale factor for cursor previews in left sidebar grid
private let sidebarPreviewScale: CGFloat = 1.5

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isDropTargeted = false

    // MARK: - Home Toolbar Content
    @ToolbarContentBuilder
    private var homeToolbarContent: some ToolbarContent {
        // Flexible spacer pushes buttons to the right (macOS 26+ only)
        AdaptiveToolbarSpacer(.flexible)

        // Group 1: New, Delete
        ToolbarItemGroup {
            Menu {
                Button("New Cape") {
                    appState.createNewCape()
                }
                Divider()
                Button("Import from Windows Cursors...") {
                    appState.importWindowsCursorFolder()
                }
            } label: {
                Image(systemName: "plus")
            }
            .help("New Cape")

            Button(action: {
                if let cape = appState.selectedCape {
                    appState.confirmDeleteCape(cape)
                }
            }) {
                Image(systemName: "minus")
            }
            .help("Delete Cape")
            .disabled(appState.selectedCape == nil)
        }

        AdaptiveToolbarSpacer(.fixed)

        // Group 2: Edit, Apply
        ToolbarItemGroup {
            Button(action: {
                if let cape = appState.selectedCape {
                    appState.editCape(cape)
                }
            }) {
                Image(systemName: "square.and.pencil")
            }
            .help("Edit Cape")
            .disabled(appState.selectedCape == nil)

            Button(action: {
                if let cape = appState.selectedCape {
                    appState.applyCape(cape)
                }
            }) {
                Image(systemName: "checkmark.circle")
            }
            .help("Apply Cape")
            .disabled(appState.selectedCape == nil)
        }

        AdaptiveToolbarSpacer(.fixed)

        // Group 3: Import, Export
        ToolbarItemGroup {
            Button(action: { appState.importCape() }) {
                Image(systemName: "square.and.arrow.down")
            }
            .help("Import Cape")

            Button(action: {
                if let cape = appState.selectedCape {
                    appState.exportCape(cape)
                }
            }) {
                Image(systemName: "square.and.arrow.up")
            }
            .help("Export Cape")
            .disabled(appState.selectedCape == nil)
        }

        AdaptiveToolbarSpacer(.fixed)

        // Standalone: Settings
        ToolbarItem {
            Button(action: {
                appState.currentPage = .settings
            }) {
                Image(systemName: "gear")
            }
            .help("Settings")
        }
    }

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Left side: Cape grid or Cursor list depending on mode
            Group {
                if appState.isEditing, let cape = appState.editingCape {
                    // Edit mode: show cursor list
                    CursorListView(
                        cape: cape,
                        selection: $appState.editingSelectedCursor
                    )
                } else if appState.capes.isEmpty {
                    EmptyStateView()
                } else {
                    CapeIconGridView()
                }
            }
            .scrollContentBackground(.hidden)
            .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 400)
        } detail: {
            // Right side: Preview or Edit panel
            // Wrapped in NavigationStack for proper toolbar navigation placement
            NavigationStack {
                // Use conditional root view instead of ZStack for proper navigationTitle
                if appState.isEditing, let cape = appState.editingCape {
                    EditDetailContent(cape: cape)
                        .navigationTitle(cape.name)
                } else if let cape = appState.selectedCape {
                    CapePreviewPanel(cape: cape)
                        .id(cape.id)
                        .toolbar {
                            homeToolbarContent
                        }
                } else {
                    ContentUnavailableView(
                        "Select a Cape",
                        systemImage: "cursorarrow.click.2",
                        description: Text("Choose a cape from the list to preview")
                    )
                    .toolbar {
                        homeToolbarContent
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .focusedSceneValue(\.selectedCape, $appState.selectedCape)
        // Remove sidebar toggle button in edit mode
        .toolbar(removing: .sidebarToggle)
        // Delete confirmation dialog
        .confirmationDialog(
            "Delete Cape",
            isPresented: $appState.showDeleteConfirmation,
            titleVisibility: .visible,
            presenting: appState.capeToDelete
        ) { cape in
            Button("\(String(localized:"Delete")) \"\(cape.name)\"", role: .destructive) {
                appState.deleteCape(cape)
            }
            Button("Cancel", role: .cancel) {
                appState.capeToDelete = nil
            }
        } message: { cape in
            Text("\(String(localized:"Are you sure you want to delete")) \"\(cape.name)\"? \(String(localized:"This action cannot be undone."))")
        }
        // Discard changes confirmation alert (macOS native style)
        .alert(
            "Unsaved Changes",
            isPresented: $appState.showDiscardConfirmation
        ) {
            Button("Save") {
                appState.closeEditWithSave()
            }
            .keyboardShortcut(.defaultAction)

            Button("Don't Save", role: .destructive) {
                appState.closeEdit()
            }

            Button("Cancel", role: .cancel) {
                appState.showDiscardConfirmation = false
            }
        } message: {
            Text("Do you want to save the changes you made?")
        }
        // Delete cursor confirmation dialog
        .confirmationDialog(
            "Delete Cursor?",
            isPresented: $appState.showDeleteCursorConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                appState.deleteSelectedCursor()
            }
            Button("Cancel", role: .cancel) {
                appState.showDeleteCursorConfirmation = false
            }
        } message: {
            if let cursor = appState.editingSelectedCursor {
                Text("\(String(localized:"Are you sure you want to delete")) '\(cursor.displayName)'?")
            }
        }
        // Duplicate filename error alert
        .alert(
            "Duplicate Filename",
            isPresented: $appState.showDuplicateFilenameError
        ) {
            Button("OK", role: .cancel) {
                appState.showDuplicateFilenameError = false
            }
        } message: {
            Text("\(String(localized:"A cape with the filename")) \"\(appState.duplicateFilename)\" \(String(localized:"already exists. Please change the Name or Author to use a different filename."))")
        }
        // Validation error alert
        .alert(
            "Validation Error",
            isPresented: $appState.showValidationError
        ) {
            Button("OK", role: .cancel) {
                appState.showValidationError = false
            }
        } message: {
            Text(appState.validationErrorMessage)
        }
        // Validation warning alert (with option to continue)
        .alert(
            "Validation Warning",
            isPresented: $appState.showValidationWarning
        ) {
            Button("Cancel", role: .cancel) {
                appState.showValidationWarning = false
                appState.validationWarningAction = nil
            }
            Button("Continue") {
                appState.showValidationWarning = false
                appState.validationWarningAction?()
                appState.validationWarningAction = nil
            }
        } message: {
            Text(appState.validationWarningMessage)
        }
        // Image import warning alert (non-square image)
        .alert(
            "Image Adjusted",
            isPresented: $appState.showImageImportWarning
        ) {
            Button("OK", role: .cancel) {
                appState.showImageImportWarning = false
            }
        } message: {
            Text(appState.imageImportWarningMessage)
        }
        // Add cursor sheet
        .sheet(isPresented: $appState.showAddCursorSheet) {
            if let cape = appState.editingCape {
                AddCursorSheet(cape: cape)
            }
        }
        // Cape file drop-to-import (only active on home page, not during editing)
        .overlay {
            if isDropTargeted && !appState.isEditing {
                CapeDropOverlayView()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            guard !appState.isEditing else { return false }
            return handleCapeDrop(providers)
        }
    }

    // MARK: - Cape File Drop Handler

    private func handleCapeDrop(_ providers: [NSItemProvider]) -> Bool {
        var hasFileURL = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                hasFileURL = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async {
                        if url.pathExtension.lowercased() == "cape" {
                            appState.importCape(from: url)
                        } else {
                            appState.operationResultMessage = String(localized:"Unsupported format. Only .cape files can be imported.")
                            appState.operationResultIsSuccess = false
                            appState.showOperationResult = true
                        }
                    }
                }
            }
        }
        return hasFileURL
    }
}

// MARK: - Cape Drop Overlay View

struct CapeDropOverlayView: View {

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white)

                Text("Drop .cape files to import")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            .padding(40)
            .adaptiveGlassClear(in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .foregroundStyle(.white.opacity(0.6))
            )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ContentUnavailableView {
            Label("No Capes", systemImage: "cursorarrow.slash")
        } description: {
            Text("Create a new cape or import an existing one to get started.")
        } actions: {
            HStack(spacing: 12) {
                Button("New Cape") {
                    appState.createNewCape()
                }
                .buttonStyle(.borderedProminent)

                Button("Import Cape") {
                    appState.importCape()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Cape Icon Grid View

struct CapeIconGridView: View {
    @Environment(AppState.self) private var appState
    @State private var draggingCapeId: String?

    private let columns = [
        GridItem(.adaptive(minimum: 64, maximum: 80), spacing: 12)
    ]

    var body: some View {
        @Bindable var appState = appState

        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(appState.capes) { cape in
                    CapeIconCell(
                        cape: cape,
                        isDragging: draggingCapeId == cape.identifier,
                        onSelect: {
                            appState.selectedCape = cape
                        },
                        onDoubleClick: {
                            handleDoubleClick(cape)
                        }
                    )
                    .draggable(cape.identifier) {
                        // Drag preview - without selection border
                        CapeIconCell(
                            cape: cape,
                            isDragging: false,
                            showSelection: false,
                            onSelect: {},
                            onDoubleClick: {}
                        )
                        .opacity(0.8)
                        .onAppear {
                            draggingCapeId = cape.identifier
                        }
                    }
                    .dropDestination(for: String.self) { items, _ in
                        guard let draggedId = items.first,
                              let fromIndex = appState.capes.firstIndex(where: { $0.identifier == draggedId }),
                              let toIndex = appState.capes.firstIndex(where: { $0.identifier == cape.identifier })
                        else { return false }

                        if fromIndex != toIndex {
                            withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                                appState.moveCape(
                                    from: IndexSet(integer: fromIndex),
                                    to: toIndex > fromIndex ? toIndex + 1 : toIndex
                                )
                            }
                        }
                        draggingCapeId = nil
                        return true
                    }
                }
            }
            .padding()
            .animation(.spring(duration: 0.3, bounce: 0.2), value: appState.capes.map { $0.identifier })
        }
        .onDrop(of: [.text], isTargeted: nil) { _ in
            // Reset dragging state when drop ends outside valid targets
            draggingCapeId = nil
            return false
        }
    }

    private func handleDoubleClick(_ cape: CursorLibrary) {
        let action = DoubleClickAction(rawValue: UserDefaults.standard.integer(forKey: "doubleClickAction")) ?? .applyCape
        switch action {
        case .applyCape:
            appState.applyCape(cape)
        case .editCape:
            appState.editCape(cape)
        case .doNothing:
            break
        }
    }
}

// MARK: - Cape Icon Cell (for Icon Mode)

struct CapeIconCell: View {
    let cape: CursorLibrary
    var isDragging: Bool = false
    var showSelection: Bool = true
    let onSelect: () -> Void
    let onDoubleClick: () -> Void
    @Environment(AppState.self) private var appState
    @State private var isHovered = false
    @State private var lastClickTime: Date?

    private var isSelected: Bool {
        showSelection && appState.selectedCape?.id == cape.id
    }

    private var isApplied: Bool {
        appState.appliedCape?.id == cape.id
    }

    var body: some View {
        VStack(spacing: 6) {
            // Cursor preview
            ZStack {
                if let cursor = cape.previewCursor {
                    AnimatingCursorView(
                        cursor: cursor,
                        showHotspot: false,
                        scale: sidebarPreviewScale
                    )
                    .frame(width: 48, height: 48)
                } else {
                    Image(systemName: "cursorarrow.slash")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                        .frame(width: 48, height: 48)
                }
            }

            // Cape name with applied indicator
            HStack(spacing: 2) {
                if isApplied {
                    Text("\u{25CF}")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
                Text(cape.name)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .truncationMode(.tail)
            }
        }
        .frame(width: 64)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .adaptiveGlassConditional(isActive: isSelected || isHovered, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
        .scaleEffect(isDragging ? 1.05 : (isHovered ? 1.05 : 1.0))
        .opacity(isDragging ? 0.5 : 1.0)
        .animation(.spring(duration: 0.2), value: isHovered)
        .animation(.spring(duration: 0.2), value: isDragging)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture {
            let now = Date()
            if let last = lastClickTime, now.timeIntervalSince(last) < 0.3 {
                // Double click detected
                onDoubleClick()
                lastClickTime = nil
            } else {
                // Single click - select immediately
                onSelect()
                lastClickTime = now
            }
        }
        .contextMenu {
            CapeContextMenu(cape: cape)
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environment(AppState.shared)
}
