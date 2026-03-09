//
//  AppState.swift
//  Mousecape
//
//  Main application state management for SwiftUI
//

import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers

/// Main application state - ObservableObject for SwiftUI
///
/// @unchecked Sendable is safe because:
/// 1. All access is @MainActor isolated (enforced by compiler)
/// 2. ObjC objects (libraryController, MCCursor, MCCursorLibrary) are accessed only from main thread
/// 3. Closures in undo/redo stacks are @MainActor closures, executed on main thread
/// 4. No concurrent access possible due to @MainActor isolation
@Observable @MainActor
final class AppState: @unchecked Sendable {

    // MARK: - Properties

    /// All loaded capes
    private(set) var capes: [CursorLibrary] = []

    /// Currently applied cape
    private(set) var appliedCape: CursorLibrary?

    /// Currently selected cape in the list
    var selectedCape: CursorLibrary?

    /// Current page (Home / Settings)
    var currentPage: AppPage = .home

    /// Edit mode state
    var isEditing: Bool = false

    /// Cape being edited
    var editingCape: CursorLibrary?

    /// Edit mode: selected cursor
    var editingSelectedCursor: Cursor?

    /// Edit mode: show cape info panel
    var showCapeInfo: Bool = false

    /// Edit mode: track if changes were made (manual tracking)
    var hasUnsavedChanges: Bool = false

    /// Refresh trigger for cursor list (increment to force refresh)
    var cursorListRefreshTrigger: Int = 0

    /// Refresh trigger for cape info (file name display)
    var capeInfoRefreshTrigger: Int = 0

    /// Refresh trigger for cape list/grid (increment to force refresh)
    var capeListRefreshTrigger: Int = 0

    /// Show add cursor sheet
    var showAddCursorSheet: Bool = false

    /// Show delete cursor confirmation
    var showDeleteCursorConfirmation: Bool = false

    /// Delete confirmation state
    var showDeleteConfirmation: Bool = false
    var capeToDelete: CursorLibrary?

    /// Discard changes confirmation state
    var showDiscardConfirmation: Bool = false

    /// Duplicate filename error state
    var showDuplicateFilenameError: Bool = false
    var duplicateFilename: String = ""

    /// Validation error state
    var showValidationError: Bool = false
    var validationErrorMessage: String = ""

    /// Image import warning state (for non-square images)
    var showImageImportWarning: Bool = false
    var imageImportWarningMessage: String = ""

    /// Loading state
    var isLoading: Bool = false
    var loadingMessage: String = ""

    /// Import result state (for Windows cursor import)
    var showImportResult: Bool = false
    var importResultMessage: String = ""
    var importResultIsSuccess: Bool = true

    /// Operation result state (for apply, import cape, export cape)
    var showOperationResult: Bool = false
    var operationResultMessage: String = ""
    var operationResultIsSuccess: Bool = true

    /// Error state
    var lastError: Error?
    var showError: Bool = false

    /// Window visibility state (for pausing animations when hidden)
    var isWindowVisible: Bool = true

    // MARK: - Undo/Redo

    /// Undo stack - stores paired closures to undo/redo changes
    private var undoStack: [(undo: () -> Void, redo: () -> Void)] = []

    /// Redo stack - stores paired closures to undo/redo changes
    private var redoStack: [(undo: () -> Void, redo: () -> Void)] = []

    /// Maximum undo history size
    private let maxUndoHistory = 20

    /// Whether undo is available
    var canUndo: Bool { !undoStack.isEmpty }

    /// Whether redo is available
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - ObjC Controller Bridge

    var libraryController: MCLibraryController?

    // MARK: - Initialization

    init() {
        setupLibraryController()
        loadCapes()
        loadPreferences()
    }

    private func setupLibraryController() {
        // Get the library URL
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        let mousecapeDir = appSupport.appendingPathComponent("Mousecape", isDirectory: true)
        let capesDir = mousecapeDir.appendingPathComponent("capes", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: capesDir, withIntermediateDirectories: true)

        // Initialize the ObjC controller
        libraryController = MCLibraryController(url: capesDir)
    }

    private func loadCapes() {
        guard let controller = libraryController else { return }

        // Remember current selections by their underlying ObjC objects
        let selectedObjc = selectedCape?.underlyingLibrary
        let appliedObjc = appliedCape?.underlyingLibrary

        // Load capes from the ObjC controller
        if let objcCapes = controller.capes as? Set<MCCursorLibrary> {
            capes = objcCapes.map { CursorLibrary(objcLibrary: $0) }
            applyCapeOrder()
        }

        // Restore selections by finding wrappers for the same ObjC objects
        if let selectedObjc = selectedObjc {
            selectedCape = capes.first { $0.underlyingLibrary === selectedObjc }
        }

        // Check for applied cape (from controller or previously tracked)
        if let applied = controller.appliedCape {
            appliedCape = capes.first { $0.underlyingLibrary === applied }
        } else if let appliedObjc = appliedObjc {
            appliedCape = capes.first { $0.underlyingLibrary === appliedObjc }
        }
    }

    // MARK: - Cape Order Management

    /// Apply saved cape order or use alphabetical order as default
    private func applyCapeOrder() {
        let savedOrder = UserDefaults.standard.stringArray(forKey: "capeListOrder") ?? []

        if savedOrder.isEmpty {
            // No saved order, use alphabetical order as default
            capes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } else {
            // Sort by saved order, new capes go to end (alphabetically)
            capes.sort { cape1, cape2 in
                let index1 = savedOrder.firstIndex(of: cape1.identifier)
                let index2 = savedOrder.firstIndex(of: cape2.identifier)

                switch (index1, index2) {
                case let (i1?, i2?):
                    return i1 < i2
                case (nil, _?):
                    return false  // cape1 is new, put at end
                case (_?, nil):
                    return true   // cape2 is new, put at end
                case (nil, nil):
                    // Both are new, sort alphabetically
                    return cape1.name.localizedCaseInsensitiveCompare(cape2.name) == .orderedAscending
                }
            }
        }

        // Sync save: clean up deleted capes, add new ones
        saveCapeOrder()
    }

    /// Save current cape order to UserDefaults
    private func saveCapeOrder() {
        let order = capes.map { $0.identifier }
        UserDefaults.standard.set(order, forKey: "capeListOrder")
    }

    /// Move cape from source index to destination index (for drag and drop)
    func moveCape(from source: IndexSet, to destination: Int) {
        capes.move(fromOffsets: source, toOffset: destination)
        saveCapeOrder()
    }

    /// Reset cape order to alphabetical order
    func resetCapeOrder() {
        UserDefaults.standard.removeObject(forKey: "capeListOrder")
        capes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        saveCapeOrder()
    }

    private func loadPreferences() {
        // Load and apply cursor scale on startup
        applySavedCursorScale()
    }

    /// Load cursor scale from preferences and apply it
    private func applySavedCursorScale() {
        let preferenceDomain = "com.sdmj76.Mousecape"
        let cursorScaleKey = "MCCursorScale"

        // Read saved scale value
        if let value = CFPreferencesCopyAppValue(cursorScaleKey as CFString, preferenceDomain as CFString) as? Double {
            debugLog("Loading saved cursor scale: \(value)")
            // Apply the scale using ObjC function
            let success = setCursorScale(Float(value))
            if success {
                debugLog("Successfully applied cursor scale on startup")
            } else {
                debugLog("Failed to apply cursor scale on startup")
            }
        } else {
            debugLog("No saved cursor scale found, using default (1.0)")
            // Apply default scale
            _ = setCursorScale(1.0)
        }
    }

    // MARK: - Cape Actions

    /// Create a new empty cape
    func createNewCape() {
        let author = NSFullUserName()
        let baseName = "New Cape"

        // Find unique name by adding suffix if needed
        let uniqueName = findUniqueName(baseName: baseName, author: author)
        let newCape = CursorLibrary(name: uniqueName, author: author)

        // Set file URL before adding to library (required for save/delete)
        if let libraryURL = libraryController?.libraryURL {
            let fileURL = libraryURL.appendingPathComponent("\(newCape.identifier).cape")
            newCape.fileURL = fileURL
            // Save immediately to create the file
            newCape.underlyingLibrary.write(toFile: fileURL.path, atomically: true)
        }

        addCape(newCape)
        selectedCape = newCape
        capeInfoRefreshTrigger += 1  // Refresh file name display
        editCape(newCape)
    }

    /// Find a unique name by adding suffix (1), (2), etc. if needed
    func findUniqueName(baseName: String, author: String) -> String {
        var name = baseName
        var counter = 1

        while isIdentifierExists(name: name, author: author) {
            name = "\(baseName) (\(counter))"
            counter += 1
        }

        return name
    }

    /// Check if a cape with the given name/author combination already exists
    private func isIdentifierExists(name: String, author: String, excludingCape: CursorLibrary? = nil) -> Bool {
        let identifier = generateIdentifier(name: name, author: author)

        // Check in-memory capes list first
        for cape in capes {
            if cape.identifier == identifier {
                if let excluding = excludingCape, excluding.identifier == identifier {
                    continue
                }
                return true
            }
        }

        // Also check existing files on disk
        if let libraryURL = libraryController?.libraryURL {
            let fileURL = libraryURL.appendingPathComponent("\(identifier).cape")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                // If we're excluding a cape and its fileURL matches, it's not a conflict
                if let excluding = excludingCape, excluding.fileURL == fileURL {
                    return false
                }
                return true
            }
        }

        return false
    }

    /// Import a cape from URL
    func importCape(from url: URL? = nil) {
        if let url = url {
            importCapeFromURL(url)
        } else {
            // Show open panel
            let panel = NSOpenPanel()
            panel.title = String(localized: "Import Cape")
            panel.allowedContentTypes = [UTType(filenameExtension: "cape")].compactMap { $0 }
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false

            panel.begin { [weak self] response in
                guard response == .OK else { return }
                for url in panel.urls {
                    self?.importCapeFromURL(url)
                }
            }
        }
    }

    private func importCapeFromURL(_ url: URL) {
        guard let libraryController = libraryController else { return }

        // Get cape name from filename (without extension)
        let capeName = url.deletingPathExtension().lastPathComponent

        let error = libraryController.importCape(at: url)
        if let error = error as NSError? {
            // Import failed due to validation
            validationErrorMessage = error.localizedDescription
            if let recoverySuggestion = error.localizedRecoverySuggestion {
                validationErrorMessage += "\n\n\(recoverySuggestion)"
            }
            showValidationError = true
        } else {
            // Import succeeded, reload the cape list
            loadCapes()

            // Show success message with cape name
            operationResultMessage = "\"\(capeName)\" \(String(localized:"has been imported."))"
            operationResultIsSuccess = true
            showOperationResult = true
        }
    }

    /// Add a cape to the library
    func addCape(_ cape: CursorLibrary) {
        libraryController?.addCape(cape.underlyingLibrary)
        loadCapes()
    }

    /// Apply a cape
    func applyCape(_ cape: CursorLibrary) {
        debugLog("=== Applying Cape ===")
        debugLog("Cape: \(cape.name) (\(cape.identifier))")
        debugLog("Cursors count: \(cape.cursors.count)")

        libraryController?.applyCape(cape.underlyingLibrary)
        appliedCape = cape

        debugLog("Apply completed, saving preferences...")

        // Save identifier for "Apply Last Cape on Launch" feature
        UserDefaults.standard.set(cape.identifier, forKey: "lastAppliedCapeIdentifier")
        // Also write MCAppliedCursor for session monitor (ObjC listen.m)
        // Uses CFPreferences to write to current user + current host domain
        CFPreferencesSetValue(
            "MCAppliedCursor" as CFString,
            cape.identifier as CFString,
            "com.sdmj76.Mousecape" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
        CFPreferencesSynchronize(
            "com.sdmj76.Mousecape" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
    }

    /// Reset to default system cursors
    func resetToDefault() {
        debugLog("=== Resetting to Default Cursors ===")

        libraryController?.restoreCape()
        appliedCape = nil

        debugLog("Reset completed, clearing preferences...")

        // Clear last applied cape identifier
        UserDefaults.standard.removeObject(forKey: "lastAppliedCapeIdentifier")
        // Also clear MCAppliedCursor for session monitor
        CFPreferencesSetValue(
            "MCAppliedCursor" as CFString,
            nil,
            "com.sdmj76.Mousecape" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
        CFPreferencesSynchronize(
            "com.sdmj76.Mousecape" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
    }

    /// Edit a cape
    func editCape(_ cape: CursorLibrary) {
        // Invalidate cursor cache to ensure fresh data when entering edit mode
        cape.invalidateCursorCache()
        editingCape = cape
        isEditing = true
        hasUnsavedChanges = false
        capeInfoRefreshTrigger += 1  // Refresh file name display
        clearUndoHistory()
    }

    /// Mark that changes have been made
    func markAsChanged() {
        hasUnsavedChanges = true
    }

    /// Register an undoable change
    /// - Parameters:
    ///   - undoAction: Closure to undo the change
    ///   - redoAction: Closure to redo the change
    func registerUndo(undo undoAction: @escaping () -> Void, redo redoAction: @escaping () -> Void) {
        // Clear redo stack when new action is registered
        redoStack.removeAll()

        // Add paired closures to undo stack
        undoStack.append((undo: undoAction, redo: redoAction))

        // Limit stack size
        if undoStack.count > maxUndoHistory {
            undoStack.removeFirst()
        }

        hasUnsavedChanges = true
    }

    /// Undo the last change
    func undo() {
        guard let entry = undoStack.popLast() else { return }
        entry.undo()
        redoStack.append(entry)
    }

    /// Redo the last undone change
    func redo() {
        guard let entry = redoStack.popLast() else { return }
        entry.redo()
        undoStack.append(entry)
        hasUnsavedChanges = true
    }

    /// Clear undo/redo history
    func clearUndoHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    /// Clear all memory caches for background mode (aggressive cleanup)
    func clearMemoryCaches() {
        let memoryBefore = reportMemoryUsage()
        debugLog("Clearing memory caches for background mode - Memory before: \(memoryBefore) MB")

        // Save essential state before clearing
        let selectedIdentifier = selectedCape?.identifier
        let appliedIdentifier = appliedCape?.identifier
        let appliedCapeName = appliedCape?.name  // Save name for menu bar display

        debugLog("Clearing \(capes.count) capes with total \(capes.reduce(0) { $0 + $1.cursorCount }) cursors")

        // Clear all cursor image caches
        for cape in capes {
            cape.invalidateCursorCache()
            for cursor in cape.cursors {
                cursor.invalidateImageCache()
            }
        }

        // Aggressively clear the entire capes array to release ObjC objects
        // This releases all MCCursorLibrary and MCCursor objects and their image data
        capes.removeAll()
        selectedCape = nil
        // Don't clear appliedCape yet - we need to recreate a lightweight version for menu bar

        // Clear ALL edit state to release view references
        isEditing = false
        editingCape = nil
        editingSelectedCursor = nil
        showCapeInfo = false
        capeToDelete = nil

        // Reset to home page to clear navigation stack
        currentPage = .home

        // Clear all dialog states
        showAddCursorSheet = false
        showDeleteCursorConfirmation = false
        showDeleteConfirmation = false
        showDiscardConfirmation = false
        showDuplicateFilenameError = false
        showValidationError = false
        showImageImportWarning = false
        showImportResult = false
        showOperationResult = false
        showError = false
        lastError = nil

        // Clear undo/redo history
        clearUndoHistory()

        // Store identifiers for restoration on window reopen
        if let selected = selectedIdentifier {
            UserDefaults.standard.set(selected, forKey: "lastSelectedCapeIdentifier")
        }
        if let applied = appliedIdentifier {
            UserDefaults.standard.set(applied, forKey: "lastAppliedCapeIdentifier")
        }

        // CRITICAL: Clear libraryController to release all ObjC cape objects
        // This is the key to releasing the 27+ MB of CFData held by MCLibraryController
        libraryController = nil
        debugLog("LibraryController released")

        // Recreate a lightweight appliedCape for menu bar display (no cursor data)
        if let appliedId = appliedIdentifier, let appliedName = appliedCapeName {
            // Create a minimal CursorLibrary with just metadata for menu bar display
            let lightweightLibrary = CursorLibrary(name: appliedName, author: "")
            lightweightLibrary.identifier = appliedId
            appliedCape = lightweightLibrary
            debugLog("Recreated lightweight appliedCape for menu bar: \(appliedName)")
        } else {
            appliedCape = nil
        }

        // Force refresh triggers to update views
        capeListRefreshTrigger += 1
        cursorListRefreshTrigger += 1
        capeInfoRefreshTrigger += 1

        // Force memory cleanup with multiple passes
        for _ in 0..<3 {
            autoreleasepool {
                // Empty pool to release autoreleased objects
            }
        }

        let memoryAfter = reportMemoryUsage()
        debugLog("Memory caches cleared - Memory after: \(memoryAfter) MB (freed: \(memoryBefore - memoryAfter) MB)")
    }

    /// Report current memory usage in MB
    private func reportMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            // Calculate correct capacity for rebinding mach_task_basic_info to integer_t array
            let capacity = MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size
            return $0.withMemoryRebound(to: integer_t.self, capacity: capacity) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            return usedMB
        }
        return 0
    }

    /// Restore state after window reopens (called from showMainWindow)
    func restoreStateAfterReopen() {
        debugLog("Restoring state after window reopen")

        // Recreate libraryController if it was cleared
        if libraryController == nil {
            setupLibraryController()
            debugLog("LibraryController recreated")
        }

        // Reload capes from disk
        loadCapes()

        // Restore selections
        if let selectedId = UserDefaults.standard.string(forKey: "lastSelectedCapeIdentifier") {
            selectedCape = capes.first { $0.identifier == selectedId }
            UserDefaults.standard.removeObject(forKey: "lastSelectedCapeIdentifier")
        }

        if let appliedId = UserDefaults.standard.string(forKey: "lastAppliedCapeIdentifier") {
            appliedCape = capes.first { $0.identifier == appliedId }
            UserDefaults.standard.removeObject(forKey: "lastAppliedCapeIdentifier")
        }

        debugLog("State restored - \(capes.count) capes loaded")
    }

    /// Request to close edit mode (may show confirmation if dirty)
    func requestCloseEdit() {
        if hasUnsavedChanges {
            showDiscardConfirmation = true
        } else {
            closeEdit()
        }
    }

    /// Close edit mode (discard changes)
    func closeEdit() {
        // Revert unsaved changes
        if hasUnsavedChanges {
            editingCape?.revertToSaved()
        }
        isEditing = false
        editingCape = nil
        editingSelectedCursor = nil
        showCapeInfo = false
        showDiscardConfirmation = false
        hasUnsavedChanges = false
        clearUndoHistory()
    }

    /// Close edit mode after saving
    func closeEditWithSave() {
        if let cape = editingCape {
            // Only close if save succeeds
            guard saveCape(cape) else { return }
            // Invalidate cursor cache to ensure fresh data on next access
            cape.invalidateCursorCache()
        }

        // Remember the cape we just edited (by its underlying ObjC object)
        let savedObjcCape = editingCape?.underlyingLibrary

        isEditing = false
        editingCape = nil
        editingSelectedCursor = nil
        showCapeInfo = false
        showDiscardConfirmation = false
        hasUnsavedChanges = false
        clearUndoHistory()

        // Reload capes to refresh the list with latest data
        // This will find the new wrapper for the same ObjC object
        loadCapes()

        // Select the cape we just saved (find its new wrapper)
        if let savedObjcCape = savedObjcCape {
            selectedCape = capes.first { $0.underlyingLibrary === savedObjcCape }
        }

        // Force UI refresh for cape list and preview panel
        capeListRefreshTrigger += 1
    }

    /// Save the currently editing cape
    /// Returns true if save was successful, false if blocked by validation or duplicate filename
    @discardableResult
    func saveCape(_ cape: CursorLibrary) -> Bool {
        // Validate all fields first
        guard validateBeforeSave() else { return false }

        // Generate new identifier based on current Name and Author
        let newIdentifier = generateIdentifier(name: cape.name, author: cape.author)

        // Check for duplicate filename (excluding current cape)
        if isIdentifierExists(name: cape.name, author: cape.author, excludingCape: cape) {
            duplicateFilename = "\(newIdentifier).cape"
            showDuplicateFilenameError = true
            return false
        }

        do {
            // Update identifier and fileURL if changed
            if let libraryURL = libraryController?.libraryURL {
                let oldFileURL = cape.fileURL
                let newFileURL = libraryURL.appendingPathComponent("\(newIdentifier).cape")

                // If filename will change, delete old file and update URL
                if oldFileURL != newFileURL {
                    // Delete old file if it exists
                    if let oldURL = oldFileURL {
                        try? FileManager.default.removeItem(at: oldURL)
                    }
                    cape.fileURL = newFileURL
                }

                // Update identifier
                cape.identifier = newIdentifier
            }

            try cape.save()
            hasUnsavedChanges = false
            capeInfoRefreshTrigger += 1  // Refresh file name display
            clearUndoHistory()  // Clear undo history after save
            // Invalidate cursor cache to ensure fresh data
            cape.invalidateCursorCache()
            return true
        } catch {
            lastError = error
            showError = true
            return false
        }
    }

    /// Generate identifier from name and author
    func generateIdentifier(name: String, author: String) -> String {
        let sanitizedAuthor = CursorLibrary.sanitizeIdentifierComponent(author.isEmpty ? "Unknown" : author)
        let sanitizedName = CursorLibrary.sanitizeIdentifierComponent(name.isEmpty ? "Untitled" : name)
        return "local.\(sanitizedAuthor).\(sanitizedName)"
    }

    /// Export a cape to file
    func exportCape(_ cape: CursorLibrary, to url: URL? = nil) {
        // Validate cape before export
        if let error = cape.underlyingLibrary.validateCape() as NSError? {
            validationErrorMessage = error.localizedDescription
            if let recoverySuggestion = error.localizedRecoverySuggestion {
                validationErrorMessage += "\n\n\(recoverySuggestion)"
            }
            showValidationError = true
            return
        }

        if let url = url {
            exportCapeToURL(cape, url: url)
        } else {
            // Show save panel
            let panel = NSSavePanel()
            panel.title = String(localized: "Export Cape")
            panel.nameFieldLabel = String(localized: "Export As:")
            panel.nameFieldStringValue = "\(cape.name).cape"
            panel.allowedContentTypes = [UTType(filenameExtension: "cape")].compactMap { $0 }
            panel.canCreateDirectories = true

            panel.begin { [weak self] response in
                guard response == .OK, let url = panel.url else { return }
                self?.exportCapeToURL(cape, url: url)
            }
        }
    }

    private func exportCapeToURL(_ cape: CursorLibrary, url: URL) {
        let success = cape.underlyingLibrary.write(toFile: url.path, atomically: true)
        if success {
            operationResultMessage = "\"\(cape.name)\" \(String(localized:"has been exported."))"
            operationResultIsSuccess = true
        } else {
            operationResultMessage = String(localized:"Failed to export cape.")
            operationResultIsSuccess = false
        }
        showOperationResult = true
    }

    /// Show cape in Finder
    func showInFinder(_ cape: CursorLibrary) {
        guard let url = libraryController?.url(forCape: cape.underlyingLibrary) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Request delete confirmation for a cape
    func confirmDeleteCape(_ cape: CursorLibrary) {
        capeToDelete = cape
        showDeleteConfirmation = true
    }

    /// Delete a cape (after confirmation)
    func deleteCape(_ cape: CursorLibrary) {
        let wasSelected = selectedCape?.id == cape.id
        let wasApplied = appliedCape?.id == cape.id

        // Clear selection first if this cape was selected (before deletion)
        if wasSelected {
            selectedCape = nil
        }

        // If this is the applied cape, reset to default
        if wasApplied {
            resetToDefault()
        }

        // Ensure cape has a file URL before attempting to delete
        if cape.fileURL == nil {
            // Try to get URL from library controller
            if let url = libraryController?.url(forCape: cape.underlyingLibrary) {
                cape.fileURL = url
            }
        }

        // Only call removeCape if fileURL exists
        if cape.fileURL != nil {
            libraryController?.removeCape(cape.underlyingLibrary)
        } else {
            // Just remove from memory if no file exists
            debugLog("Warning: Cape has no file URL, removing from list only")
        }

        loadCapes()

        capeToDelete = nil
        showDeleteConfirmation = false
    }

    /// Refresh capes list
    func refreshCapes() {
        loadCapes()
    }

    // MARK: - Cursor Actions (Edit Mode)

    /// Delete the currently selected cursor
    /// In simple mode (editMode == 0), deletes the entire cursor group
    func deleteSelectedCursor() {
        guard let cape = editingCape, let cursor = editingSelectedCursor else { return }
        let editMode = UserDefaults.standard.integer(forKey: "cursorEditMode")
        if editMode == 0, let group = WindowsCursorGroup.group(for: cursor.identifier) {
            cape.removeGroupCursors(for: group)
        } else {
            cape.removeCursor(cursor)
        }
        editingSelectedCursor = nil
        markAsChanged()
        cursorListRefreshTrigger += 1
        showDeleteCursorConfirmation = false
    }

    /// Add a cursor with the given type
    func addCursor(type: CursorType) {
        guard let cape = editingCape else { return }
        let newCursor = Cursor(identifier: type.rawValue)
        cape.addCursor(newCursor)
        editingSelectedCursor = newCursor
        markAsChanged()
        cursorListRefreshTrigger += 1
    }

    // MARK: - Preferences

    /// Open cape folder in Finder
    func openCapeFolder() {
        guard let url = libraryController?.libraryURL else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }

    // MARK: - Validation

    /// Characters allowed in Name and Author fields
    /// Allows alphanumerics, spaces, and some safe punctuation
    static let allowedNameCharacters = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: " -_()"))

    /// Check if a string is valid for Name/Author fields
    static func isValidNameOrAuthor(_ string: String) -> Bool {
        guard !string.isEmpty else { return false }
        return string.unicodeScalars.allSatisfy { allowedNameCharacters.contains($0) }
    }

    /// Filter a string to only contain valid Name/Author characters
    static func filterNameOrAuthor(_ string: String) -> String {
        String(string.unicodeScalars.filter { allowedNameCharacters.contains($0) })
    }

    /// Validate all fields before saving
    /// Returns true if valid, false if validation failed (shows error alert)
    func validateBeforeSave() -> Bool {
        guard let cape = editingCape else { return false }

        var errors: [String] = []

        // Validate cape name
        if cape.name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Name cannot be empty")
        }

        // Validate cape author
        if cape.author.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Author cannot be empty")
        }

        // Validate cape version
        if cape.version <= 0 {
            errors.append("Version must be greater than 0")
        }

        // Validate ALL cursor fields (not just selected cursor)
        for cursor in cape.cursors {
            let cursorName = cursor.displayName

            if cursor.size.width <= 0 || cursor.size.height <= 0 {
                errors.append("[\(cursorName)] Size must be greater than 0")
            }
            if cursor.frameCount <= 0 {
                errors.append("[\(cursorName)] Frame count must be at least 1")
            }
            if cursor.frameDuration < 0 {
                errors.append("[\(cursorName)] Frame duration cannot be negative")
            }
            if cursor.hotSpot.x < 0 || cursor.hotSpot.y < 0 {
                errors.append("[\(cursorName)] Hotspot cannot be negative")
            }
        }

        if !errors.isEmpty {
            validationErrorMessage = errors.joined(separator: "\n")
            showValidationError = true
            return false
        }

        return true
    }
}

// MARK: - AppState Singleton

extension AppState {
    @MainActor static let shared = AppState()
}
