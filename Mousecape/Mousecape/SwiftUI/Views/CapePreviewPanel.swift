//
//  CapePreviewPanel.swift
//  Mousecape
//
//  Preview panel showing cape details and cursor grid
//

import SwiftUI

// MARK: - Preview Scale Constants

/// Scale factor for cursor previews in the preview panel
private let previewPanelScale: CGFloat = 1.5

struct CapePreviewPanel: View {
    let cape: CursorLibrary
    @Environment(AppState.self) private var appState
    @Environment(LocalizationManager.self) private var localization
    @State private var zoomedCursor: Cursor?
    @State private var zoomTrigger: Int = 0 // Increment to force view recreation
    @State private var cachedCursors: [Cursor] = []
    @Namespace private var cursorNamespace
    @AppStorage("showAuthorInfo") private var showAuthorInfo = true

    private var isApplied: Bool {
        appState.appliedCape?.id == cape.id
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top: Cape info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(cape.name)
                                    .font(.title2.bold())
                                if isApplied {
                                    AppliedBadge()
                                }
                            }
                            if showAuthorInfo {
                                Text("\(localization.localized("by")) \(cape.author)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding()
                    .adaptiveGlassClear(in: RoundedRectangle(cornerRadius: 12))
                }
                .padding()

                // Middle: Cursor preview grid (auto-wrapping)
                ScrollView {
                    CursorFlowGrid(
                        cursors: cachedCursors,
                        zoomedCursor: zoomedCursor,
                        namespace: cursorNamespace
                    ) { cursor in
                        zoomTrigger += 1
                        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                            zoomedCursor = cursor
                        }
                    }
                    .padding()
                }

                // Bottom: Cursor count
                HStack {
                    Text("\(cape.cursorCount) \(cape.cursorCount == 1 ? localization.localized("cursor") : localization.localized("cursors"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
            }

            // Zoom overlay
            if let cursor = zoomedCursor {
                CursorZoomOverlay(
                    cursor: cursor,
                    namespace: cursorNamespace
                ) {
                    withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                        zoomedCursor = nil
                    }
                }
                .id(zoomTrigger) // Force view recreation on each tap
            }
        }
        .onAppear {
            refreshCursors()
        }
        .onChange(of: cape.id) { _, _ in
            refreshCursors()
        }
        .onChange(of: appState.capeListRefreshTrigger) { _, _ in
            refreshCursors()
        }
    }

    private func refreshCursors() {
        cape.invalidateCursorCache()
        cachedCursors = cape.cursors
    }
}

// MARK: - Applied Badge

struct AppliedBadge: View {
    @Environment(LocalizationManager.self) private var localization

    var body: some View {
        Label(localization.localized("Applied"), systemImage: "checkmark.circle.fill")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .adaptiveGlassTinted(color: .green, in: .capsule)
    }
}

// MARK: - Cursor Zoom Overlay

struct CursorZoomOverlay: View {
    let cursor: Cursor
    let namespace: Namespace.ID
    let onDismiss: () -> Void
    var showHotspot: Bool = false
    @Environment(LocalizationManager.self) private var localization

    @State private var showDetails = false
    @State private var showAnimatedCursor = false
    @State private var isVisible = false

    var body: some View {
        ZStack {
            // Dimmed background - click to dismiss
            Color.black.opacity(isVisible ? 0.6 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Centered zoomed cursor with matched geometry
            VStack(spacing: 16) {
                ZStack {
                    // Static view for transition (used for enter animation)
                    StaticCursorFrameView(cursor: cursor, scale: 3)
                        .frame(width: 128, height: 128)
                        .matchedGeometryEffect(id: cursor.id, in: namespace)
                        .opacity(showAnimatedCursor ? 0 : 1)

                    // Animated view (shown after transition completes)
                    if showAnimatedCursor {
                        AnimatingCursorView(cursor: cursor, showHotspot: showHotspot, scale: 3)
                            .frame(width: 128, height: 128)
                    }
                }

                // Details fade in after the cursor arrives
                if showDetails {
                    VStack(spacing: 4) {
                        Text(cursor.displayName)
                            .font(.title3.bold())

                        Text(cursor.identifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if cursor.frameCount > 1 {
                            Text("\(cursor.frameCount) \(localization.localized("frames"))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(24)
            .adaptiveGlass(in: RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 20)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.8)
        }
        .contentShape(Rectangle())
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onAppear {
            // Fade in on appear
            withAnimation(.easeOut(duration: 0.25)) {
                isVisible = true
            }
            // Switch to animated cursor after transition completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showAnimatedCursor = true
            }
            // Delay showing details until cursor animation completes
            withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
                showDetails = true
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// MARK: - Cursor Flow Grid (Auto-wrapping)

struct CursorFlowGrid: View {
    let cursors: [Cursor]
    let zoomedCursor: Cursor?
    let namespace: Namespace.ID
    var onCursorTap: ((Cursor) -> Void)?
    @AppStorage("previewGridColumns") private var previewGridColumns = 0

    init(
        cursors: [Cursor],
        zoomedCursor: Cursor? = nil,
        namespace: Namespace.ID,
        onCursorTap: ((Cursor) -> Void)? = nil
    ) {
        self.cursors = cursors
        self.zoomedCursor = zoomedCursor
        self.namespace = namespace
        self.onCursorTap = onCursorTap
    }

    private var columns: [GridItem] {
        if previewGridColumns > 0 {
            // Fixed number of columns
            return Array(repeating: GridItem(.flexible(), spacing: 24), count: previewGridColumns)
        } else {
            // Auto (adaptive)
            return [GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 24)]
        }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(cursors) { cursor in
                CursorPreviewCell(
                    cursor: cursor,
                    isZoomed: zoomedCursor?.id == cursor.id,
                    namespace: namespace
                ) {
                    onCursorTap?(cursor)
                }
            }
        }
    }
}

// MARK: - Cursor Preview Cell

struct CursorPreviewCell: View {
    let cursor: Cursor
    let isZoomed: Bool
    let namespace: Namespace.ID
    var onTap: (() -> Void)?
    @State private var isHovered = false

    init(
        cursor: Cursor,
        isZoomed: Bool = false,
        namespace: Namespace.ID,
        onTap: (() -> Void)? = nil
    ) {
        self.cursor = cursor
        self.isZoomed = isZoomed
        self.namespace = namespace
        self.onTap = onTap
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Animated view (always visible, does not participate in transition)
                AnimatingCursorView(
                    cursor: cursor,
                    showHotspot: false,
                    scale: previewPanelScale
                )
                .frame(width: 64, height: 64)
                .opacity(isZoomed ? 0 : 1)

                // Static view for transition (invisible but participates in matchedGeometryEffect)
                if !isZoomed {
                    StaticCursorFrameView(cursor: cursor, scale: previewPanelScale)
                        .frame(width: 64, height: 64)
                        .matchedGeometryEffect(id: cursor.id, in: namespace)
                        .opacity(0.001) // Nearly invisible but participates in layout
                }
            }

            if !isZoomed {
                Text(cursor.displayName)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(8)
        .adaptiveGlassConditional(isActive: isHovered && !isZoomed, in: RoundedRectangle(cornerRadius: 8))
        .opacity(isZoomed ? 0 : 1)
        .scaleEffect(isHovered && !isZoomed ? 1.1 : 1.0)
        .animation(.spring(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture {
            if !isZoomed {
                onTap?()
            }
        }
        .help(cursor.identifier)
    }
}

// MARK: - Preview

#Preview {
    CapePreviewPanel(cape: CursorLibrary(name: "Preview Cape", author: "Test"))
        .environment(AppState.shared)
        .environment(LocalizationManager.shared)
        .frame(width: 500, height: 400)
}
