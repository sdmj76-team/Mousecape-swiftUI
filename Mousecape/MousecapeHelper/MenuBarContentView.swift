//
//  MenuBarContentView.swift
//  MousecapeHelper
//
//  Created by Claude Code on 2026-03-06.
//

import SwiftUI
import AppKit
import Combine

// Observable state manager for cursor name
@MainActor
class CursorState: ObservableObject {
    @Published var currentCapeName: String = ""
    private var observer: NSObjectProtocol?

    init() {
        // Initial refresh
        refresh()

        // Listen for preference changes from main app
        observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.sdmj76.Mousecape.cursorChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }

        // Also listen for CFPreferences changes
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let state = Unmanaged<CursorState>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    state.refresh()
                }
            },
            "com.sdmj76.Mousecape.preferencesChanged" as CFString,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        if let observer = observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    func refresh() {
        // Use CFPreferences API (same as main app)
        let value = CFPreferencesCopyValue(
            "MCAppliedCursor" as CFString,
            "com.sdmj76.Mousecape" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )

        if let capeIdentifier = value as? String {
            // Extract cape name from identifier
            let components = capeIdentifier.split(separator: ".")
            if let lastName = components.last {
                currentCapeName = String(lastName)
            } else {
                currentCapeName = capeIdentifier
            }
        } else {
            currentCapeName = ""
        }
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject var cursorState: CursorState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Display current cape name if available
            if !cursorState.currentCapeName.isEmpty {
                Text(String(localized: "Current Cursor: \(cursorState.currentCapeName)"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                Divider()
            }

            Button(String(localized: "Open Mousecape")) {
                openMainApp()
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            Button(String(localized: "Reset Cursors")) {
                resetCursors()
            }

            Divider()

            Button(String(localized: "Quit Mousecape")) {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    private func openMainApp() {
        // Helper is located at: Mousecape.app/Contents/Library/LoginItems/MousecapeHelper.app
        // Navigate up to find main app: MousecapeHelper.app -> LoginItems -> Library -> Contents -> Mousecape.app
        let helperURL = Bundle.main.bundleURL
        let mainAppURL = helperURL
            .deletingLastPathComponent() // Remove MousecapeHelper.app -> LoginItems/
            .deletingLastPathComponent() // Remove LoginItems/ -> Library/
            .deletingLastPathComponent() // Remove Library/ -> Contents/
            .deletingLastPathComponent() // Remove Contents/ -> Mousecape.app/

        NSWorkspace.shared.open(mainAppURL)
    }

    private func resetCursors() {
        ResetCursorsToDefault()
        cursorState.currentCapeName = "" // Clear display
        cursorState.refresh() // Refresh after reset
    }
}

#Preview {
    MenuBarContentView()
}
