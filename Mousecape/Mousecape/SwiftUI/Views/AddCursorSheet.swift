//
//  AddCursorSheet.swift
//  Mousecape
//
//  Sheet view for adding new cursor types to a cape.
//  Extracted from EditOverlayView.swift for better code organization.
//

import SwiftUI

// MARK: - Add Cursor Sheet

struct AddCursorSheet: View {
    let cape: CursorLibrary
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @AppStorage("cursorEditMode") private var editMode: Int = 0
    @State private var selectedType: CursorType?
    @State private var selectedGroup: WindowsCursorGroup?

    // Filter out cursor types that already exist in the cape
    private var availableTypes: [CursorType] {
        let existingIdentifiers = Set(cape.cursors.map { $0.identifier })
        return CursorType.allCases.filter { !existingIdentifiers.contains($0.rawValue) }
    }

    // Filter out groups where any cursor type already exists
    private var availableGroups: [WindowsCursorGroup] {
        return WindowsCursorGroup.allCases.filter { group in
            !group.cursorTypes.contains { cursorType in
                cape.cursor(withIdentifier: cursorType.rawValue) != nil
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Cursor")
                .font(.headline)

            if editMode == 0 {
                groupList
            } else {
                cursorTypeList
            }

            buttonBar
        }
        .padding()
        .frame(width: 350, height: 420)
        .onAppear {
            if editMode == 0 {
                selectedGroup = availableGroups.first
            } else {
                selectedType = availableTypes.first
            }
        }
    }

    // MARK: - Simple Mode: Group List

    @ViewBuilder
    private var groupList: some View {
        if availableGroups.isEmpty {
            ContentUnavailableView(
                "All Cursor Groups Added",
                systemImage: "checkmark.circle",
                description: Text("This cape already contains all cursor groups.")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(availableGroups) { group in
                        GroupRow(
                            group: group,
                            isSelected: selectedGroup == group,
                            onSelect: { selectedGroup = group }
                        )
                    }
                }
                .padding(8)
            }
            .frame(height: 300)
            .adaptiveGlassClear(in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Advanced Mode: Cursor Type List

    @ViewBuilder
    private var cursorTypeList: some View {
        if availableTypes.isEmpty {
            ContentUnavailableView(
                "All Cursor Types Added",
                systemImage: "checkmark.circle",
                description: Text("This cape already contains all standard cursor types.")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(availableTypes) { type in
                        CursorTypeRow(
                            type: type,
                            isSelected: selectedType == type,
                            onSelect: { selectedType = type }
                        )
                    }
                }
                .padding(8)
            }
            .frame(height: 300)
            .adaptiveGlassClear(in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var buttonBar: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Add") {
                if editMode == 0 {
                    addSelectedGroup()
                } else {
                    addSelectedCursor()
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(editMode == 0
                ? (selectedGroup == nil || availableGroups.isEmpty)
                : (selectedType == nil || availableTypes.isEmpty))
        }
    }

    // MARK: - Actions

    private func addSelectedCursor() {
        guard let type = selectedType else { return }

        let newCursor = Cursor(identifier: type.rawValue)
        cape.addCursor(newCursor)
        appState.markAsChanged()
        appState.cursorListRefreshTrigger += 1
        appState.editingSelectedCursor = newCursor

        dismiss()
    }

    private func addSelectedGroup() {
        guard let group = selectedGroup,
              let primaryType = group.primaryType else { return }

        let newCursor = Cursor(identifier: primaryType.rawValue)
        cape.addCursorWithAliases(newCursor)
        appState.markAsChanged()
        appState.cursorListRefreshTrigger += 1
        appState.editingSelectedCursor = newCursor

        dismiss()
    }
}

// MARK: - Group Row (Simple Mode)

private struct GroupRow: View {
    let group: WindowsCursorGroup
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack {
            Image(systemName: group.previewSymbol)
                .frame(width: 24)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.displayName)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Text("\(group.cursorTypes.count) types")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.15))
            }
        }
        .onTapGesture {
            onSelect()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(group.displayName)
    }
}

// MARK: - Cursor Type Row (Advanced Mode)

private struct CursorTypeRow: View {
    let type: CursorType
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack {
            Image(systemName: type.previewSymbol)
                .frame(width: 24)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            Text(type.displayName)
                .foregroundStyle(isSelected ? .primary : .secondary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.15))
            }
        }
        .onTapGesture {
            onSelect()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(type.displayName)
    }
}
