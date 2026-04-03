//
//  MousecapeHelperApp.swift
//  MousecapeHelper
//
//  Created by Claude Code on 2026-03-06.
//

import SwiftUI
import ServiceManagement

@main
struct MousecapeHelperApp: App {
    @NSApplicationDelegateAdaptor(HelperAppDelegate.self) var appDelegate
    @StateObject private var cursorState = CursorState()

    var body: some Scene {
        MenuBarExtra("Mousecape", image: "MenuBarIcon") {
            MenuBarContentView()
                .environmentObject(cursorState)
                .onAppear {
                    // Refresh state when menu opens
                    cursorState.refresh()
                }
        }
    }
}

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
    }

    func applicationWillTerminate(_ notification: Notification) {
        debugLog("MousecapeHelper terminating")
        #if DEBUG
        MCLoggerClose()
        #endif
    }
}
