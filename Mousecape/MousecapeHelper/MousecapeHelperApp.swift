//
//  MousecapeHelperApp.swift
//  MousecapeHelper
//
//  Created by Claude Code on 2026-03-06.
//

import SwiftUI
import ServiceManagement

// MARK: - Menu Bar Visibility State

/// Shared state for menu bar icon visibility, controlled by main app via CFPreferences + DistributedNotification
@Observable
@MainActor
class MenuBarState {
    static let shared = MenuBarState()
    var isVisible: Bool = true

    init() {
        isVisible = Self.readFromPreferences()
    }

    func updateFromPreferences() {
        isVisible = Self.readFromPreferences()
    }

    private static func readFromPreferences() -> Bool {
        // Synchronize to flush latest values from disk
        CFPreferencesSynchronize(
            "com.sdmj76.Mousecape" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        let value = CFPreferencesCopyValue(
            "launchHelperWithApp" as CFString,
            "com.sdmj76.Mousecape" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        let result = (value as? NSNumber)?.boolValue ?? true
        debugLog("Menu bar visibility read: \(result)")
        return result
    }
}

// MARK: - App

@main
struct MousecapeHelperApp: App {
    @NSApplicationDelegateAdaptor(HelperAppDelegate.self) var appDelegate
    @StateObject private var cursorState = CursorState()
    @State private var menuBarState = MenuBarState.shared

    var body: some Scene {
        @Bindable var state = menuBarState
        MenuBarExtra("Mousecape", image: "MenuBarIcon", isInserted: $state.isVisible) {
            MenuBarContentView()
                .environmentObject(cursorState)
                .onAppear {
                    // Refresh state when menu opens
                    cursorState.refresh()
                }
        }
    }
}

// MARK: - App Delegate

class HelperAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize logging
        #if DEBUG
        MCLoggerInit()
        #endif
        debugLog("MousecapeHelper started")

        // Single instance check — exit if another Helper is already running
        let myPID = ProcessInfo.processInfo.processIdentifier
        let myBundleID = Bundle.main.bundleIdentifier ?? "com.sdmj76.MousecapeHelper"
        let runningApps = NSWorkspace.shared.runningApplications
        let duplicate = runningApps.contains { app in
            app.bundleIdentifier == myBundleID && app.processIdentifier != myPID
        }
        if duplicate {
            debugLog("Another Helper instance is already running, exiting")
            NSApp.terminate(nil)
            return
        }

        // Start session monitoring to keep cursors persistent
        startSessionMonitor()
        debugLog("Session monitor started")

        // Listen for menu bar visibility changes from main app
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleMenuBarVisibilityChanged),
            name: NSNotification.Name("com.sdmj76.Mousecape.menuBarVisibilityChanged"),
            object: nil
        )
    }

    @objc private func handleMenuBarVisibilityChanged() {
        DispatchQueue.main.async {
            MenuBarState.shared.updateFromPreferences()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        debugLog("MousecapeHelper terminating")
        #if DEBUG
        MCLoggerClose()
        #endif
    }
}
