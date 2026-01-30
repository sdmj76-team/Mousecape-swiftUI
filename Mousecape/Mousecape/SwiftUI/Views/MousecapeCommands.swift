//
//  MousecapeCommands.swift
//  Mousecape
//
//  System menu bar commands
//

import SwiftUI

struct MousecapeCommands: Commands {
    @FocusedValue(\.selectedCape) var selectedCapeBinding: Binding<CursorLibrary?>?

    private var selectedCape: CursorLibrary? {
        selectedCapeBinding?.wrappedValue
    }

    private func L(_ key: String) -> String {
        LocalizationManager.shared.localized(key)
    }

    var body: some Commands {
        // MARK: - Mousecape menu (App menu)
        CommandGroup(after: .appSettings) {
            Button(L("Settings...")) {
                Task { @MainActor in
                    AppState.shared.currentPage = .settings
                }
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button(L("Reset to Default")) {
                Task { @MainActor in
                    AppState.shared.resetToDefault()
                }
            }
            .keyboardShortcut("r", modifiers: .command)
        }

        // MARK: - File menu
        CommandGroup(replacing: .newItem) {
            Button(L("New Cape")) {
                Task { @MainActor in
                    AppState.shared.createNewCape()
                }
            }
            .keyboardShortcut("n", modifiers: .command)

            Button(L("Import from Windows...")) {
                Task { @MainActor in
                    AppState.shared.importWindowsCursorFolder()
                }
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])

            Divider()

            Button(L("Import Cape...")) {
                Task { @MainActor in
                    AppState.shared.importCape()
                }
            }
            .keyboardShortcut("i", modifiers: .command)

            Button(L("Export Cape...")) {
                if let cape = selectedCape {
                    Task { @MainActor in
                        AppState.shared.exportCape(cape)
                    }
                }
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(selectedCape == nil)

            Divider()

            Button(L("Delete Cape")) {
                if let cape = selectedCape {
                    Task { @MainActor in
                        AppState.shared.confirmDeleteCape(cape)
                    }
                }
            }
            .keyboardShortcut(.delete)
            .disabled(selectedCape == nil)
        }

        // Hide Save item (moved to Edit menu)
        CommandGroup(replacing: .saveItem) { }

        // MARK: - Edit menu
        CommandGroup(replacing: .undoRedo) {
            Button(L("Undo")) {
                Task { @MainActor in
                    AppState.shared.undo()
                }
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!AppState.shared.canUndo || !AppState.shared.isEditing)

            Button(L("Redo")) {
                Task { @MainActor in
                    AppState.shared.redo()
                }
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!AppState.shared.canRedo || !AppState.shared.isEditing)

            Divider()

            Button(L("Save Cape")) {
                Task { @MainActor in
                    if AppState.shared.isEditing, let cape = AppState.shared.editingCape {
                        AppState.shared.saveCape(cape)
                    }
                }
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!AppState.shared.isEditing)
        }

        // Hide system View menu (toolbar options)
        CommandGroup(replacing: .toolbar) { }

        // MARK: - Help menu (clear custom items, keep system default)
        CommandGroup(replacing: .help) { }
    }
}
