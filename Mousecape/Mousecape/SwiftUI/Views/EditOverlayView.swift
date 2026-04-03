//
//  EditOverlayView.swift
//  Mousecape
//
//  Edit overlay view that covers the main interface
//  Slides in from the right with animation
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Windows Cursor UTType Extensions

extension UTType {
    /// Windows static cursor file (.cur)
    static let windowsCursor = UTType(filenameExtension: "cur") ?? .data

    /// Windows animated cursor file (.ani)
    static let windowsAnimatedCursor = UTType(filenameExtension: "ani") ?? .data
}

// MARK: - Edit Detail Content (right panel content only, used in HomeView)

struct EditDetailContent: View {
    let cape: CursorLibrary
    @Environment(AppState.self) private var appState
    @AppStorage("cursorEditMode") private var editMode: Int = 0  // 0=simple, 1=advanced

    var body: some View {
        Group {
            if appState.showCapeInfo {
                CapeInfoView(cape: cape)
            } else if let cursor = appState.editingSelectedCursor {
                CursorDetailView(cursor: cursor, cape: cape)
            } else {
                ContentUnavailableView(
                    "Select a Cursor",
                    systemImage: "cursorarrow.click",
                    description: Text("Choose a cursor from the list to edit")
                )
            }
        }
        .onAppear {
            // Invalidate cache to ensure we get fresh cursor data
            cape.invalidateCursorCache()
            // 进入编辑页面时保持无选择状态，由用户手动选择
        }
        // Edit mode toolbar (navigationTitle is now in HomeView)
        .toolbar {
            // Flexible spacer pushes buttons to the right (macOS 26+ only)
            AdaptiveToolbarSpacer(.flexible)

            // Mode toggle
            ToolbarItem {
                Picker("", selection: $editMode) {
                    Text("Simple").tag(0)
                    Text("Advanced").tag(1)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            // Main action buttons group
            ToolbarItemGroup {
                if editMode == 1 {
                Button(action: {
                    appState.showAddCursorSheet = true
                }) {
                    Image(systemName: "plus")
                }
                .help("Add Cursor")
                .accessibilityLabel("Add cursor")

                Button(action: {
                    appState.showDeleteCursorConfirmation = true
                }) {
                    Image(systemName: "minus")
                }
                .help("Delete Cursor")
                .accessibilityLabel("Delete cursor")
                .disabled(appState.editingSelectedCursor == nil)
                }

                Button(action: {
                    appState.showCapeInfo.toggle()
                    if appState.showCapeInfo {
                        appState.editingSelectedCursor = nil
                    }
                }) {
                    Image(systemName: appState.showCapeInfo ? "info.circle.fill" : "info.circle")
                }
                .help("Cape Info")
                .accessibilityLabel("Cape information")
            }

            AdaptiveToolbarSpacer(.fixed)

            // Done button (rightmost, standalone with green color)
            ToolbarItem {
                Button(action: {
                    appState.requestCloseEdit()
                }) {
                    Image(systemName: "checkmark")
                }
                .help("Done")
                .accessibilityLabel("Done editing")
            }
        }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }
}

// MARK: - Edit Overlay View (legacy, full screen)

struct EditOverlayView: View {
    let cape: CursorLibrary
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            // Left sidebar: Cursor list (same style as HomeView/SettingsView)
            CursorListView(
                cape: cape,
                selection: $appState.editingSelectedCursor
            )
            .scrollContentBackground(.hidden)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            // Right side: Content area
            detailContent
                .scrollContentBackground(.hidden)
        }
        .onAppear {
            // Invalidate cache to ensure we get fresh cursor data
            cape.invalidateCursorCache()
            // 进入编辑页面时保持无选择状态，由用户手动选择
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if appState.showCapeInfo {
            CapeInfoView(cape: cape)
        } else if let cursor = appState.editingSelectedCursor {
            CursorDetailView(cursor: cursor, cape: cape)
                .id(cursor.id)  // Force view recreation when cursor changes
        } else {
            ContentUnavailableView(
                "Select a Cursor",
                systemImage: "cursorarrow.click",
                description: Text("Choose a cursor from the list to edit")
            )
        }
    }
}

// MARK: - Cursor List View (for Edit)

struct CursorListView: View {
    let cape: CursorLibrary
    @Binding var selection: Cursor?
    @Environment(AppState.self) private var appState
    @AppStorage("cursorEditMode") private var editMode: Int = 0
    @State private var selectedGroup: WindowsCursorGroup?

    var body: some View {
        @Bindable var appState = appState

        Group {
        if editMode == 0 {
            // Simple mode: show Windows cursor groups
            List(WindowsCursorGroup.allCases, id: \.id, selection: $selectedGroup) { group in
                SimpleGroupRow(group: group, cape: cape)
                    .tag(group)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .id(appState.cursorListRefreshTrigger)
            .onChange(of: selectedGroup) { _, newGroup in
                guard let group = newGroup else { return }
                if appState.showCapeInfo {
                    appState.showCapeInfo = false
                }
                // Find existing primary cursor or create one
                let primaryCursor = findOrCreatePrimaryCursor(for: group)
                selection = primaryCursor
            }
            .onAppear {
                // Initialize group selection from current cursor
                if let cursor = selection,
                   let group = WindowsCursorGroup.group(for: cursor.identifier) {
                    selectedGroup = group
                }
                // 进入编辑页面时保持无选择状态，不自动选中分组
            }
            .onChange(of: selection) { _, newSelection in
                if newSelection == nil {
                    selectedGroup = nil
                }
            }
        } else {
            // Advanced mode: show all cursors (existing behavior)
            List(cape.cursors, id: \.id, selection: $selection) { cursor in
                CursorListRow(cursor: cursor, currentIdentifier: cursor.identifier)
                    .tag(cursor)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .id(appState.cursorListRefreshTrigger)
            .onChange(of: selection) { _, newValue in
                if newValue != nil && appState.showCapeInfo {
                    appState.showCapeInfo = false
                }
            }
        }
        } // Group
        .onChange(of: editMode) { _, _ in
            // 切换模式时强制清空选中状态，避免类型选择器暴露
            selectedGroup = nil
            selection = nil
            // 关闭 info 面板
            if appState.showCapeInfo {
                appState.showCapeInfo = false
            }
        }
    }

    /// Find the primary cursor for a group, or create one if none exists
    private func findOrCreatePrimaryCursor(for group: WindowsCursorGroup) -> Cursor? {
        // Prioritize the primaryType cursor
        if let primaryType = group.primaryType,
           let primaryCursor = cape.cursor(withIdentifier: primaryType.rawValue) {
            return primaryCursor
        }
        // Fallback: return the first existing cursor in this group
        for cursorType in group.cursorTypes {
            if let existing = cape.cursor(withIdentifier: cursorType.rawValue) {
                return existing
            }
        }
        // No cursor exists for this group yet - create the primary cursor
        if let primaryType = group.primaryType {
            let newCursor = Cursor(identifier: primaryType.rawValue)
            cape.addCursor(newCursor)
            appState.markAsChanged()
            return newCursor
        }
        return nil
    }

    private func duplicateCursor() {
        guard let cursor = selection else { return }
        let newCursor = cursor.copy(withIdentifier: cursor.identifier + ".copy")
        cape.addCursor(newCursor)
        selection = newCursor
        appState.markAsChanged()
    }
}

// MARK: - Simple Group Row

struct SimpleGroupRow: View {
    let group: WindowsCursorGroup
    let cape: CursorLibrary
    @AppStorage("MCHandedness") private var handedness = 0

    /// Get preview image from the first existing cursor in this group
    private var previewCursor: Cursor? {
        for cursorType in group.cursorTypes {
            if let cursor = cape.cursor(withIdentifier: cursorType.rawValue),
               cursor.hasAnyRepresentation {
                return cursor
            }
        }
        return nil
    }

    var body: some View {
        HStack {
            if let cursor = previewCursor, let image = cursor.previewImage(size: 32) {
                let shouldMirror = handedness != 0 && (CursorType(rawValue: cursor.identifier)?.shouldMirrorInLeftHandMode() ?? true)
                Image(nsImage: image)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .scaleEffect(x: shouldMirror ? -1 : 1, y: 1)
            } else {
                Image(systemName: group.previewSymbol)
                    .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(group.displayName)
                    .font(.headline)
                Text("\(group.cursorTypes.count) types")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(group.displayName)
    }
}

// MARK: - Cursor List Row

struct CursorListRow: View {
    let cursor: Cursor
    /// Pass the identifier to force refresh when type changes
    var currentIdentifier: String?
    @AppStorage("MCHandedness") private var handedness = 0

    private var displayName: String {
        let identifier = currentIdentifier ?? cursor.identifier
        if let type = CursorType(rawValue: identifier) {
            return type.displayName
        }
        // Fallback: extract name from identifier
        let name = identifier.components(separatedBy: ".").last ?? "Cursor"
        var result = ""
        for char in name {
            if char.isUppercase && !result.isEmpty {
                result += " "
            }
            result += String(char)
        }
        return result.isEmpty ? "Cursor" : result
    }

    var body: some View {
        HStack {
            // Preview thumbnail
            if let image = cursor.previewImage(size: 32) {
                let shouldMirror = handedness != 0 && (CursorType(rawValue: cursor.identifier)?.shouldMirrorInLeftHandMode() ?? true)
                Image(nsImage: image)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .scaleEffect(x: shouldMirror ? -1 : 1, y: 1)
            } else {
                let identifier = currentIdentifier ?? cursor.identifier
                Image(systemName: CursorType(rawValue: identifier)?.previewSymbol ?? "cursorarrow")
                    .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.headline)
                if cursor.isAnimated {
                    Text("\(cursor.frameCount) \(String(localized:"frames"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayName)
    }
}

// MARK: - Cursor Detail View

struct CursorDetailView: View {
    @Bindable var cursor: Cursor
    let cape: CursorLibrary
    @Environment(AppState.self) private var appState
    @AppStorage("cursorEditMode") private var editMode: Int = 0
    @State private var hotspotX: Double = 0
    @State private var hotspotY: Double = 0
    @State private var frameCount: Int = 1
    @State private var fps: Double = 1  // Frames per second
    @State private var isLoadingValues = true  // Prevent onChange during load
    @State private var selectedType: CursorType = .arrow
    @State private var previewRefreshTrigger: Int = 0  // Force preview refresh
    @State private var availableTypes: [CursorType] = CursorType.allCases
    @State private var showAliasOverwriteAlert = false
    @State private var hasCheckedAliasConsistency = false

    // MARK: - Validation

    /// Maximum allowed hotspot value (32x32 cursor, hot spot must be < size)
    /// Use the constant from MCDefs.h for consistency with apply.m
    private var maxHotspot: CGFloat { CGFloat(MCMaxHotspotValue) }

    /// Check if hotspot X is valid (0 <= x <= MCMaxHotspotValue)
    private var isHotspotXValid: Bool { hotspotX >= 0 && hotspotX <= maxHotspot }

    /// Check if hotspot Y is valid (0 <= y <= MCMaxHotspotValue)
    private var isHotspotYValid: Bool { hotspotY >= 0 && hotspotY <= maxHotspot }

    /// Check if frame count is valid (>= 1)
    private var isFrameCountValid: Bool { frameCount >= 1 }

    /// Check if FPS is valid (> 0)
    private var isFPSValid: Bool { fps > 0 }

    // Calculate available cursor types (current type + types not used by other cursors)
    private func calculateAvailableTypes() -> [CursorType] {
        let otherCursorIdentifiers = Set(cape.cursors
            .filter { $0.id != cursor.id }
            .map { $0.identifier })
        return CursorType.allCases.filter { type in
            !otherCursorIdentifiers.contains(type.rawValue)
        }
    }

    // Calculate frame duration from FPS
    private var frameDuration: Double {
        fps > 0 ? 1.0 / fps : 0
    }

    // Picker types - ensure selectedType is always included to avoid "invalid selection" warning
    private var pickerTypes: [CursorType] {
        if availableTypes.contains(selectedType) {
            return availableTypes
        } else {
            // Add current selection to the list if not present
            return [selectedType] + availableTypes
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Combined preview + drop zone
                CursorPreviewDropZone(
                    cursor: cursor,
                    refreshTrigger: previewRefreshTrigger,
                    cape: cape
                )

                // Properties panel
                VStack(alignment: .leading, spacing: 16) {
                    // Type section (advanced mode only)
                    if editMode == 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type")
                            .font(.headline)

                        Picker("", selection: $selectedType) {
                            ForEach(pickerTypes) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 200, alignment: .leading)
                        .id(previewRefreshTrigger)  // Force picker refresh
                        .onChange(of: selectedType) { oldValue, newValue in
                            guard !isLoadingValues else { return }
                            guard newValue != oldValue else { return }
                            let oldIdentifier = cursor.identifier
                            let newIdentifier = newValue.rawValue
                            cursor.identifier = newIdentifier
                            appState.cursorListRefreshTrigger += 1
                            appState.registerUndo(
                                undo: { [weak cursor] in
                                    cursor?.identifier = oldIdentifier
                                    if let type = CursorType(rawValue: oldIdentifier) {
                                        self.selectedType = type
                                    }
                                    self.appState.cursorListRefreshTrigger += 1
                                },
                                redo: { [weak cursor] in
                                    cursor?.identifier = newIdentifier
                                    self.selectedType = newValue
                                    self.appState.cursorListRefreshTrigger += 1
                                }
                            )
                        }

                        Text(selectedType.rawValue)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                    } // end if editMode == 1

                    // Hotspot section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hotspot")
                            .font(.headline)

                        HStack(spacing: 16) {
                            HStack {
                                Text("X:")
                                TextField("X", value: $hotspotX, format: .number.precision(.fractionLength(1)))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .accessibilityLabel("Hotspot X coordinate")
                                    .accessibilityValue("\(hotspotX)")
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(isHotspotXValid ? Color.clear : Color.red, lineWidth: 2)
                                    )
                                    .onChange(of: hotspotX) { oldValue, newValue in
                                        guard !isLoadingValues else { return }
                                        guard newValue != oldValue else { return }

                                        // Validate: must be in range [0, 32)
                                        let clamped = min(max(0, newValue), maxHotspot)
                                        if clamped != newValue {
                                            // Invalid input, revert to old value
                                            hotspotX = oldValue
                                            return
                                        }

                                        let capturedOld = oldValue
                                        cursor.hotSpot = NSPoint(x: CGFloat(clamped), y: cursor.hotSpot.y)
                                        previewRefreshTrigger += 1
                                        let capturedEditMode = editMode
                                        appState.registerUndo(
                                            undo: { [weak cursor] in
                                                guard let cursor = cursor else { return }
                                                cursor.hotSpot = NSPoint(x: CGFloat(capturedOld), y: cursor.hotSpot.y)
                                                self.hotspotX = capturedOld
                                                self.previewRefreshTrigger += 1
                                                if capturedEditMode == 0 {
                                                    cape.syncMetadataToAliases(cursor)
                                                }
                                            },
                                            redo: { [weak cursor] in
                                                guard let cursor = cursor else { return }
                                                cursor.hotSpot = NSPoint(x: CGFloat(clamped), y: cursor.hotSpot.y)
                                                self.hotspotX = clamped
                                                self.previewRefreshTrigger += 1
                                                if capturedEditMode == 0 {
                                                    cape.syncMetadataToAliases(cursor)
                                                }
                                            }
                                        )
                                        // Simple mode: sync metadata to aliases (no image deep copy needed)
                                        if editMode == 0 {
                                            cape.syncMetadataToAliases(cursor)
                                        }
                                    }
                            }
                            HStack {
                                Text("Y:")
                                TextField("Y", value: $hotspotY, format: .number.precision(.fractionLength(1)))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .accessibilityLabel("Hotspot Y coordinate")
                                    .accessibilityValue("\(hotspotY)")
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(isHotspotYValid ? Color.clear : Color.red, lineWidth: 2)
                                    )
                                    .onChange(of: hotspotY) { oldValue, newValue in
                                        guard !isLoadingValues else { return }
                                        guard newValue != oldValue else { return }

                                        // Validate: must be in range [0, 32)
                                        let clamped = min(max(0, newValue), maxHotspot)
                                        if clamped != newValue {
                                            // Invalid input, revert to old value
                                            hotspotY = oldValue
                                            return
                                        }

                                        let capturedOld = oldValue
                                        cursor.hotSpot = NSPoint(x: cursor.hotSpot.x, y: CGFloat(clamped))
                                        previewRefreshTrigger += 1
                                        let capturedEditMode = editMode
                                        appState.registerUndo(
                                            undo: { [weak cursor] in
                                                guard let cursor = cursor else { return }
                                                cursor.hotSpot = NSPoint(x: cursor.hotSpot.x, y: CGFloat(capturedOld))
                                                self.hotspotY = capturedOld
                                                self.previewRefreshTrigger += 1
                                                if capturedEditMode == 0 {
                                                    cape.syncMetadataToAliases(cursor)
                                                }
                                            },
                                            redo: { [weak cursor] in
                                                guard let cursor = cursor else { return }
                                                cursor.hotSpot = NSPoint(x: cursor.hotSpot.x, y: CGFloat(clamped))
                                                self.hotspotY = clamped
                                                self.previewRefreshTrigger += 1
                                                if capturedEditMode == 0 {
                                                    cape.syncMetadataToAliases(cursor)
                                                }
                                            }
                                        )
                                        // Simple mode: sync metadata to aliases (no image deep copy needed)
                                        if editMode == 0 {
                                            cape.syncMetadataToAliases(cursor)
                                        }
                                    }
                            }
                        }

                    }

                    Divider()

                    // Animation section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Animation")
                            .font(.headline)

                        HStack {
                            Text("Frames:")
                            TextField("Frames", value: $frameCount, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .accessibilityLabel("Animation frame count")
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(isFrameCountValid ? Color.clear : Color.red, lineWidth: 2)
                                )
                                .onChange(of: frameCount) { oldValue, newValue in
                                    guard !isLoadingValues else { return }
                                    guard newValue != oldValue else { return }
                                    let capturedOld = oldValue
                                    let actualNew = max(1, newValue)
                                    cursor.frameCount = actualNew
                                    previewRefreshTrigger += 1
                                    let capturedEditMode = editMode
                                    appState.registerUndo(
                                        undo: { [weak cursor] in
                                            guard let cursor = cursor else { return }
                                            cursor.frameCount = capturedOld
                                            self.frameCount = capturedOld
                                            self.previewRefreshTrigger += 1
                                            if capturedEditMode == 0 {
                                                cape.syncMetadataToAliases(cursor)
                                            }
                                        },
                                        redo: { [weak cursor] in
                                            guard let cursor = cursor else { return }
                                            cursor.frameCount = actualNew
                                            self.frameCount = actualNew
                                            self.previewRefreshTrigger += 1
                                            if capturedEditMode == 0 {
                                                cape.syncMetadataToAliases(cursor)
                                            }
                                        }
                                    )
                                    // Simple mode: sync metadata to aliases (no image deep copy needed)
                                    if editMode == 0 {
                                        cape.syncMetadataToAliases(cursor)
                                    }
                                }
                        }

                        HStack {
                            Text("Speed:")
                            TextField("Speed", value: $fps, format: .number.precision(.fractionLength(1)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .accessibilityLabel("Animation speed in frames per second")
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(isFPSValid ? Color.clear : Color.red, lineWidth: 2)
                                )
                                .onChange(of: fps) { oldValue, newValue in
                                    guard !isLoadingValues else { return }
                                    guard newValue != oldValue else { return }
                                    let capturedOld = oldValue
                                    let actualNew = max(0.1, newValue)
                                    let newDuration = 1.0 / actualNew
                                    cursor.frameDuration = CGFloat(newDuration)
                                    previewRefreshTrigger += 1
                                    let capturedEditMode = editMode
                                    appState.registerUndo(
                                        undo: { [weak cursor] in
                                            guard let cursor = cursor else { return }
                                            let oldDuration = capturedOld > 0 ? 1.0 / capturedOld : 0
                                            cursor.frameDuration = CGFloat(oldDuration)
                                            self.fps = capturedOld
                                            self.previewRefreshTrigger += 1
                                            if capturedEditMode == 0 {
                                                cape.syncMetadataToAliases(cursor)
                                            }
                                        },
                                        redo: { [weak cursor] in
                                            guard let cursor = cursor else { return }
                                            cursor.frameDuration = CGFloat(newDuration)
                                            self.fps = actualNew
                                            self.previewRefreshTrigger += 1
                                            if capturedEditMode == 0 {
                                                cape.syncMetadataToAliases(cursor)
                                            }
                                        }
                                    )
                                    // Simple mode: sync metadata to aliases (no image deep copy needed)
                                    if editMode == 0 {
                                        cape.syncMetadataToAliases(cursor)
                                    }
                                }
                            Text("frames/sec")
                                .foregroundStyle(.secondary)
                        }

                        if cursor.isAnimated {
                            Text(String(format: String(localized: "Duration: %@s per frame, %@s total"), String(format: "%.3f", frameDuration), String(format: "%.2f", Double(frameCount) * frameDuration)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .adaptiveGlass(in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .onAppear {
            loadCursorValues()
            checkAliasConsistencyOnAppear()
        }
        .onChange(of: cursor.id) { _, _ in
            loadCursorValues()
            hasCheckedAliasConsistency = false
            checkAliasConsistencyOnAppear()
        }
        .onChange(of: appState.cursorListRefreshTrigger) { _, _ in
            // Refresh preview and reload values when image is imported
            previewRefreshTrigger += 1
            loadCursorValues()
        }
        .alert("Overwrite Alias Cursors?", isPresented: $showAliasOverwriteAlert) {
            Button("Continue") {
                hasCheckedAliasConsistency = true
            }
            Button("Cancel", role: .cancel) {
                hasCheckedAliasConsistency = true
                // 返回无选择状态
                appState.editingSelectedCursor = nil
            }
        } message: {
            Text("This group contains alias cursors with different settings. Editing in Simple mode will overwrite all aliases with the primary cursor's settings.")
        }
    }

    private func loadCursorValues() {
        isLoadingValues = true
        hotspotX = Double(cursor.hotSpot.x)
        hotspotY = Double(cursor.hotSpot.y)
        frameCount = cursor.frameCount
        // Calculate FPS from frame duration
        let duration = Double(cursor.frameDuration)
        fps = duration > 0 ? 1.0 / duration : 1.0
        // Refresh available types
        availableTypes = calculateAvailableTypes()
        // Load cursor type
        if let type = CursorType(rawValue: cursor.identifier) {
            selectedType = type
        } else if let firstAvailable = availableTypes.first {
            selectedType = firstAvailable
        }
        // Delay resetting the flag to ensure onChange doesn't fire during load
        DispatchQueue.main.async {
            isLoadingValues = false
        }
    }

    private func checkAliasConsistencyOnAppear() {
        guard editMode == 0, !hasCheckedAliasConsistency else { return }
        if !checkAliasConsistency() {
            showAliasOverwriteAlert = true
        } else {
            hasCheckedAliasConsistency = true
        }
    }

    private func checkAliasConsistency() -> Bool {
        guard let group = WindowsCursorGroup.group(for: cursor.identifier) else { return true }
        for cursorType in group.cursorTypes where cursorType.rawValue != cursor.identifier {
            if let alias = cape.cursor(withIdentifier: cursorType.rawValue) {
                if alias.hotSpot != cursor.hotSpot ||
                   alias.frameCount != cursor.frameCount ||
                   alias.frameDuration != cursor.frameDuration {
                    return false
                }
            }
        }
        return true
    }
}

// MARK: - Background Image Processing Results

/// Sendable result for static image processing
private struct StaticImageResult: Sendable {
    let cgImage: CGImage
    let originalWidth: Int
    let originalHeight: Int
    let isSquare: Bool
}

/// Sendable result for GIF processing
private struct GIFProcessingResult: Sendable {
    let cgImage: CGImage  // scaled sprite sheet (or single frame)
    let frameCount: Int
    let avgFrameDuration: Double
    let frameWidth: Int
    let frameHeight: Int
    let failedFrames: Int
    let totalSourceFrames: Int
}

/// Sendable result for Windows cursor processing
private struct WindowsCursorProcessingResult: Sendable {
    let cgImage: CGImage
    let frameCount: Int
    let frameDuration: Double
    let hotspotX: CGFloat
    let hotspotY: CGFloat
    let originalWidth: Int
    let originalHeight: Int
}

// MARK: - Nonisolated Background Processing Functions

/// Process a static image (PNG/JPEG/TIFF) off the main actor
private func _processStaticImage(data: Data) async -> StaticImageResult? {
    guard let image = NSImage(data: data) else { return nil }
    guard let originalBitmap = CursorImageScaler.getOriginalBitmapRep(from: image) else { return nil }
    let w = originalBitmap.pixelsWide
    let h = originalBitmap.pixelsHigh
    guard let scaled = CursorImageScaler.scaleImageToStandardSize(originalBitmap) else { return nil }
    guard let cg = scaled.cgImage else { return nil }
    return StaticImageResult(cgImage: cg, originalWidth: w, originalHeight: h, isSquare: w == h)
}

/// Process a GIF file off the main actor
private func _processGIF(data: Data) async -> GIFProcessingResult? {
    guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    let sourceFrameCount = CGImageSourceGetCount(imageSource)
    guard sourceFrameCount > 0 else { return nil }

    // Single-frame GIF
    if sourceFrameCount == 1 {
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let scaled = CursorImageScaler.scaleImageToStandardSize(bitmap) else { return nil }
        guard let cg = scaled.cgImage else { return nil }
        return GIFProcessingResult(cgImage: cg, frameCount: 1, avgFrameDuration: 0.0,
                                   frameWidth: bitmap.pixelsWide, frameHeight: bitmap.pixelsHigh,
                                   failedFrames: 0, totalSourceFrames: sourceFrameCount)
    }

    // Multi-frame GIF
    var frames: [NSBitmapImageRep] = []
    var totalDuration: Double = 0.0
    var frameWidth: Int = 0
    var frameHeight: Int = 0
    var failedFrames = 0

    for i in 0..<sourceFrameCount {
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, i, nil) else {
            failedFrames += 1
            continue
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        frames.append(bitmap)
        if i == 0 {
            frameWidth = bitmap.pixelsWide
            frameHeight = bitmap.pixelsHigh
        }
        if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil) as? [String: Any],
           let gifProps = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
            if let delay = gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double, delay > 0 {
                totalDuration += delay
            } else if let delay = gifProps[kCGImagePropertyGIFDelayTime as String] as? Double, delay > 0 {
                totalDuration += delay
            } else {
                totalDuration += 0.1
            }
        } else {
            totalDuration += 0.1
        }
    }

    guard !frames.isEmpty else { return nil }

    // Downsample if needed
    let maxFrameCount = CursorImageScaler.maxFrameCount
    if frames.count > maxFrameCount {
        frames = CursorImageScaler.downsampleFrames(frames, targetCount: maxFrameCount)
    }

    let avgFrameDuration = totalDuration / Double(frames.count)

    guard let spriteSheet = CursorImageScaler.createSpriteSheet(from: frames, frameWidth: frameWidth, frameHeight: frameHeight) else { return nil }
    guard let scaledSheet = CursorImageScaler.scaleSpriteSheet(spriteSheet, frameCount: frames.count, originalFrameWidth: frameWidth, originalFrameHeight: frameHeight) else { return nil }
    guard let cg = scaledSheet.cgImage else { return nil }

    return GIFProcessingResult(cgImage: cg, frameCount: frames.count, avgFrameDuration: avgFrameDuration,
                               frameWidth: frameWidth, frameHeight: frameHeight,
                               failedFrames: failedFrames, totalSourceFrames: sourceFrameCount)
}

/// Process a Windows cursor file off the main actor
private func _processWindowsCursor(convertResult: WindowsCursorResult) async -> WindowsCursorProcessingResult? {
    guard let originalBitmap = convertResult.createBitmapImageRep() else { return nil }

    let originalWidth = CGFloat(convertResult.width)
    let originalHeight = CGFloat(convertResult.height)
    let targetSizeF = CGFloat(CursorImageScaler.standardCursorSize)

    let scale = min(targetSizeF / originalWidth, targetSizeF / originalHeight)
    let scaledWidth = originalWidth * scale
    let scaledHeight = originalHeight * scale
    let offsetX = (targetSizeF - scaledWidth) / 2
    let offsetY = (targetSizeF - scaledHeight) / 2

    let hotspotXPixels = CGFloat(convertResult.hotspotX) * scale + offsetX
    let hotspotYPixels = CGFloat(convertResult.hotspotY) * scale + offsetY
    let hotspotX = min(max(0, hotspotXPixels / 2.0), CGFloat(MCMaxHotspotValue))
    let hotspotY = min(max(0, hotspotYPixels / 2.0), CGFloat(MCMaxHotspotValue))

    let scaledBitmap: NSBitmapImageRep?
    if convertResult.frameCount > 1 {
        scaledBitmap = CursorImageScaler.scaleSpriteSheet(
            originalBitmap, frameCount: convertResult.frameCount,
            originalFrameWidth: Int(originalWidth), originalFrameHeight: Int(originalHeight))
    } else {
        scaledBitmap = CursorImageScaler.scaleImageToStandardSize(originalBitmap)
    }

    guard let scaled = scaledBitmap, let cg = scaled.cgImage else { return nil }

    return WindowsCursorProcessingResult(
        cgImage: cg, frameCount: convertResult.frameCount,
        frameDuration: convertResult.frameDuration,
        hotspotX: hotspotX, hotspotY: hotspotY,
        originalWidth: convertResult.width, originalHeight: convertResult.height)
}

// MARK: - Cursor Preview Drop Zone (Combined preview + image drop)

struct CursorPreviewDropZone: View {
    @Bindable var cursor: Cursor
    var refreshTrigger: Int = 0
    var cape: CursorLibrary?  // Needed for simple mode alias sync
    @Environment(AppState.self) private var appState
    @AppStorage("cursorEditMode") private var editMode: Int = 0
    @State private var isTargeted = false
    @State private var showFilePicker = false
    @State private var localRefreshTrigger = 0
    @State private var isLoadingImage = false

    private let targetScale: CursorScale = .scale200  // Always use 2x HiDPI

    /// Supported image types for file picker
    private static let supportedImageTypes: [UTType] = [
        .png, .jpeg, .tiff, .gif, .windowsCursor, .windowsAnimatedCursor
    ]

    /// Check if cursor has any valid image representation
    private var hasImage: Bool {
        cursor.hasAnyRepresentation
    }

    var body: some View {
        ZStack {
            if hasImage {
                // Show cursor preview with hotspot
                AnimatingCursorView(
                    cursor: cursor,
                    showHotspot: true,
                    refreshTrigger: refreshTrigger + localRefreshTrigger,
                    scale: 3
                )
            } else {
                // Empty state - prompt to add image
                VStack(spacing: 12) {
                    Image(systemName: "cursorarrow.rays")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)

                    Text("Drag image or click to select")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Recommended: 64×64 px (HiDPI 2x)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Loading indicator overlay
            if isLoadingImage {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.clear)
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Drag overlay indicator
            if isTargeted {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .adaptiveGlassTinted(color: .accentColor, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .adaptiveGlass(in: RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .onTapGesture {
            if !isLoadingImage {
                showFilePicker = true
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard !isLoadingImage else { return false }
            handleURLDrop(urls)
            return true
        } isTargeted: { isTargeted in
            self.isTargeted = isTargeted
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: Self.supportedImageTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .help(hasImage ? String(localized:"Click or drag to replace image") : String(localized:"Click or drag to add image"))
        .accessibilityLabel("Cursor image drop zone")
        .accessibilityHint(hasImage ? "Drop an image file or click to replace" : "Drop an image file or click to select")
        .accessibilityValue(isLoadingImage ? "Loading image" : (hasImage ? "Image loaded" : "Empty"))
    }

    private func handleURLDrop(_ urls: [URL]) {
        guard let url = urls.first else { return }
        guard url.isFileURL else {
            debugLog("Ignoring non-file URL: \(url)")
            return
        }
        loadImage(from: url)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                loadImage(from: url)
            }
        case .failure(let error):
            debugLog("File import error: \(error)")
        }
    }

    private func loadImage(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            debugLog("Failed to access security scoped resource: \(url)")
            return
        }

        // Check if it's a Windows cursor file
        let ext = url.pathExtension.lowercased()
        if ext == "cur" || ext == "ani" {
            loadWindowsCursor(from: url)
            return
        }

        // Check if it's a GIF file - handle animation
        if ext == "gif" {
            loadGIFImage(from: url)
            return
        }

        // Static image (PNG/JPEG/TIFF): read data while we have security access
        guard let data = try? Data(contentsOf: url) else {
            url.stopAccessingSecurityScopedResource()
            debugLog("Failed to load image from: \(url)")
            appState.validationErrorMessage = String(localized:"Unsupported image format. Supported formats: PNG, JPEG, TIFF, GIF, CUR, ANI.")
            appState.showValidationError = true
            return
        }
        url.stopAccessingSecurityScopedResource()

        isLoadingImage = true
        Task {
            let result = await _processStaticImage(data: data)

            isLoadingImage = false
            guard let result = result else {
                debugLog("Failed to scale image")
                return
            }

            if !result.isSquare {
                appState.imageImportWarningMessage = String(format: String(localized: "Image is not square (%d×%d). It will be scaled to fit and centered."), result.originalWidth, result.originalHeight)
                appState.showImageImportWarning = true
            }

            cursor.setRepresentation(NSBitmapImageRep(cgImage: result.cgImage), for: targetScale)
            cursor.size = NSSize(width: 32, height: 32)
            appState.markAsChanged()
            localRefreshTrigger += 1
            appState.cursorListRefreshTrigger += 1
            debugLog("Image imported successfully: \(result.originalWidth)x\(result.originalHeight) → \(CursorImageScaler.standardCursorSize)x\(CursorImageScaler.standardCursorSize)")
            syncAliasesIfSimpleMode()
        }
    }

    // MARK: - Simple Mode Alias Sync

    /// Sync cursor to aliases if in simple mode
    private func syncAliasesIfSimpleMode() {
        if editMode == 0, let cape = cape {
            cape.syncCursorToAliases(cursor)
        }
    }

    // MARK: - GIF Import

    /// Load an animated GIF file and extract all frames
    private func loadGIFImage(from url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            debugLog("Failed to read GIF data from: \(url)")
            url.stopAccessingSecurityScopedResource()
            return
        }
        url.stopAccessingSecurityScopedResource()

        isLoadingImage = true
        Task {
            let result = await _processGIF(data: data)

            isLoadingImage = false
            guard let result = result else {
                debugLog("Failed to process GIF")
                return
            }

            // Warn if too many frames failed to decode
            if result.failedFrames > 0 {
                let failureRate = Double(result.failedFrames) / Double(result.totalSourceFrames)
                debugLog("GIF import: \(result.failedFrames)/\(result.totalSourceFrames) frames failed to decode (\(String(format: "%.1f%%", failureRate * 100)))")

                if failureRate > 0.2 {
                    appState.imageImportWarningMessage = String(format: String(localized:"gif_decode_warning_message"), result.failedFrames, result.totalSourceFrames)
                    appState.showImageImportWarning = true
                }
            }

            cursor.setRepresentation(NSBitmapImageRep(cgImage: result.cgImage), for: targetScale)
            cursor.size = NSSize(width: 32, height: 32)
            cursor.frameCount = result.frameCount
            cursor.frameDuration = CGFloat(result.avgFrameDuration)
            appState.markAsChanged()
            localRefreshTrigger += 1
            appState.cursorListRefreshTrigger += 1

            if result.frameCount > 1 {
                debugLog("Animated GIF imported: \(result.frameWidth)x\(result.frameHeight), \(result.frameCount) frames, \(String(format: "%.3f", result.avgFrameDuration))s/frame")
            } else {
                debugLog("Static GIF imported successfully")
            }
            syncAliasesIfSimpleMode()
        }
    }

    // MARK: - Windows Cursor Import

    /// Load a Windows cursor file (.cur or .ani)
    private func loadWindowsCursor(from url: URL) {
        // Parse and convert while we still have security access
        let convertResult: WindowsCursorResult
        do {
            convertResult = try WindowsCursorConverter.shared.convert(fileURL: url)
        } catch {
            url.stopAccessingSecurityScopedResource()
            debugLog("Failed to convert Windows cursor: \(error.localizedDescription)")
            appState.imageImportWarningMessage = String(format: String(localized: "Failed to import Windows cursor: %@"), error.localizedDescription)
            appState.showImageImportWarning = true
            return
        }
        url.stopAccessingSecurityScopedResource()

        isLoadingImage = true
        Task {
            let result = await _processWindowsCursor(convertResult: convertResult)

            isLoadingImage = false
            guard let result = result else {
                debugLog("Failed to scale Windows cursor")
                return
            }

            if result.frameCount > 1 {
                cursor.frameCount = result.frameCount
                cursor.frameDuration = result.frameDuration
            } else {
                cursor.frameCount = 1
                cursor.frameDuration = 0.0
            }

            cursor.hotSpot = NSPoint(x: result.hotspotX, y: result.hotspotY)
            cursor.size = NSSize(width: 32, height: 32)
            cursor.setRepresentation(NSBitmapImageRep(cgImage: result.cgImage), for: targetScale)

            appState.markAsChanged()
            localRefreshTrigger += 1
            appState.cursorListRefreshTrigger += 1

            let frameInfo = result.frameCount > 1 ? " (\(result.frameCount) frames)" : ""
            debugLog("Windows cursor imported: \(result.originalWidth)x\(result.originalHeight)\(frameInfo) → \(CursorImageScaler.standardCursorSize)x\(CursorImageScaler.standardCursorSize)")
            syncAliasesIfSimpleMode()
        }
    }
}

// MARK: - Preview

#Preview {
    EditOverlayView(cape: CursorLibrary(name: "Test Cape", author: "Test"))
        .environment(AppState.shared)
}
