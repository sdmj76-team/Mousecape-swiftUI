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
