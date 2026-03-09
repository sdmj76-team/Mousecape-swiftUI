//
//  CapeInfoView.swift
//  Mousecape
//
//  Cape metadata editor view.
//  Extracted from EditOverlayView.swift for better code organization.
//

import SwiftUI

// MARK: - Cape Info View (Metadata Editor)

struct CapeInfoView: View {
    @Bindable var cape: CursorLibrary
    @Environment(AppState.self) private var appState

    /// Current filename from fileURL
    private var currentFilename: String {
        cape.fileURL?.lastPathComponent ?? "\(cape.identifier).cape"
    }

    /// Check if name is valid (not empty)
    private var isNameValid: Bool {
        !cape.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Check if author is valid (not empty)
    private var isAuthorValid: Bool {
        !cape.author.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Check if version is valid (> 0)
    private var isVersionValid: Bool {
        cape.version > 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Cape metadata form
                VStack(alignment: .leading, spacing: 16) {
                    Text("Cape Information")
                        .font(.headline)

                    LabeledContent("Name") {
                        TextField("Name", text: Binding(
                            get: { cape.name },
                            set: { newValue in
                                // Filter to only allow valid filename characters
                                let filtered = AppState.filterNameOrAuthor(newValue)
                                let oldValue = cape.name
                                guard filtered != oldValue else { return }
                                cape.name = filtered
                                appState.registerUndo(
                                    undo: { [weak cape] in cape?.name = oldValue },
                                    redo: { [weak cape] in cape?.name = filtered }
                                )
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isNameValid ? Color.clear : Color.red, lineWidth: 2)
                        )
                    }

                    LabeledContent("Author") {
                        TextField("Author", text: Binding(
                            get: { cape.author },
                            set: { newValue in
                                // Filter to only allow valid filename characters
                                let filtered = AppState.filterNameOrAuthor(newValue)
                                let oldValue = cape.author
                                guard filtered != oldValue else { return }
                                cape.author = filtered
                                appState.registerUndo(
                                    undo: { [weak cape] in cape?.author = oldValue },
                                    redo: { [weak cape] in cape?.author = filtered }
                                )
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isAuthorValid ? Color.clear : Color.red, lineWidth: 2)
                        )
                    }

                    LabeledContent("Version") {
                        TextField("Version", value: Binding(
                            get: { cape.version },
                            set: { newValue in
                                let oldValue = cape.version
                                // Ensure version is at least 0.1
                                let validValue = max(0.1, newValue)
                                guard validValue != oldValue else { return }
                                cape.version = validValue
                                appState.registerUndo(
                                    undo: { [weak cape] in cape?.version = oldValue },
                                    redo: { [weak cape] in cape?.version = validValue }
                                )
                            }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isVersionValid ? Color.clear : Color.red, lineWidth: 2)
                        )
                    }

                    Divider()

                    LabeledContent("Cursors") {
                        Text("\(cape.cursorCount)")
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("File") {
                        // Show current filename (updates after save)
                        Text(currentFilename)
                            .foregroundStyle(.secondary)
                            .font(.system(.caption, design: .monospaced))
                            .id(appState.capeInfoRefreshTrigger)  // Force refresh when triggered
                    }
                }
                .padding()
                .adaptiveGlass(in: RoundedRectangle(cornerRadius: 12))

                // Cursor summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(String(localized:"Cursors")) (\(cape.cursorCount))")
                        .font(.headline)

                    if cape.cursors.isEmpty {
                        Text("No cursors yet")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                            .accessibilityLabel("No cursors in this cape")
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                        ForEach(cape.cursors) { cursor in
                            VStack(spacing: 4) {
                                if let image = cursor.previewImage(size: 48) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .frame(width: 48, height: 48)
                                } else {
                                    Image(systemName: cursor.cursorType?.previewSymbol ?? "cursorarrow")
                                        .font(.title)
                                        .frame(width: 48, height: 48)
                                }
                                Text(cursor.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding()
                .adaptiveGlass(in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }
}
