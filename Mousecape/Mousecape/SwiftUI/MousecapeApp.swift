//
//  MousecapeApp.swift
//  Mousecape
//
//  SwiftUI App entry point for macOS 15+
//  Single window architecture with modern design
//

import SwiftUI
import ServiceManagement

@main
struct MousecapeApp: App {
    @State private var appState = AppState.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppearanceWrapper {
                ContentView()
                    .environment(appState)
            }
            .onAppear {
                configureWindowAppearance()
            }
        }
        .defaultSize(width: 900, height: 600)
        .commands {
            MousecapeCommands()
        }
        // MenuBarExtra removed - now handled by MousecapeHelper
    }

    /// Unified window appearance configuration
    private func configureWindowAppearance() {
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first(where: { $0.canBecomeMain }) else { return }

            window.backgroundColor = .windowBackgroundColor

            // Disable fullscreen (green) button
            window.collectionBehavior.remove(.fullScreenPrimary)
            if let zoomButton = window.standardWindowButton(.zoomButton) {
                zoomButton.isEnabled = false
            }

            // Set up window delegate for close confirmation
            appDelegate.setupWindowDelegate(for: window, appState: appState)

// ToolbarHider disabled - testing separate ToolbarItems
            // ToolbarHider.startMonitoring()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var windowDelegate: WindowDelegate?
    @MainActor private weak var mainWindow: NSWindow?

    @MainActor
    func setupWindowDelegate(for window: NSWindow, appState: AppState) {
        mainWindow = window
        windowDelegate?.stopObserving()
        windowDelegate = WindowDelegate(appState: appState)
        window.delegate = windowDelegate
        windowDelegate?.startObservingDirtyState()
    }

    @MainActor private(set) static var shared: AppDelegate?

    func applicationWillFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // Intercept file open events BEFORE SwiftUI creates new windows
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenDocumentEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenDocuments)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        migrateToHelper()
        migrateFromOldHelper()

        // Launch helper automatically when main app starts
        launchHelper()

        debugLog("Application finished launching")
    }

    @objc private func handleOpenDocumentEvent(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let descriptorList = event.paramDescriptor(forKeyword: keyDirectObject) else { return }

        var capeURLs: [URL] = []
        for i in 1...descriptorList.numberOfItems {
            guard let descriptor = descriptorList.atIndex(i),
                  let urlString = descriptor.stringValue,
                  let url = URL(string: urlString),
                  url.pathExtension.lowercased() == "cape" else { continue }
            capeURLs.append(url)
        }

        guard !capeURLs.isEmpty else { return }

        // Apple Event handler 在主线程执行，直接用 assumeIsolated 同步调用
        MainActor.assumeIsolated {
            AppDelegate.shared?.showMainWindow()
            let appState = AppState.shared
            appState.currentPage = .home
            for url in capeURLs {
                appState.importCape(from: url)
            }
        }
    }

    @MainActor
    func showMainWindow() {
        debugLog("Showing main window")

        // Restore state if capes were cleared
        if AppState.shared.capes.isEmpty {
            AppState.shared.restoreStateAfterReopen()
        }

        // Activate app and show window
        NSApp.activate(ignoringOtherApps: true)

        if let window = mainWindow ?? NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.setIsVisible(true)
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            windowDelegate?.startObservingDirtyState()
            AppState.shared.isWindowVisible = true
            debugLog("Main window shown")
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        debugLog("applicationShouldHandleReopen called - hasVisibleWindows: \(flag), current policy: \(NSApp.activationPolicy().rawValue)")

        // Always show main window when Dock icon is clicked, regardless of window visibility
        // This handles both cases:
        // 1. Window is hidden (accessory mode)
        // 2. Window is minimized or behind other windows
        showMainWindow()
        return false
    }

    // Quit app when window is closed (no menu bar icon in main app)
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // Close ObjC logging system on exit
    func applicationWillTerminate(_ notification: Notification) {
        #if DEBUG
        MCLoggerClose()
        #endif
    }

    private func migrateToHelper() {
        guard !UserDefaults.standard.bool(forKey: "migratedToHelper") else { return }

        // If old launch-at-login was enabled, enable helper
        if UserDefaults.standard.bool(forKey: "launchAtLogin") {
            let helper = SMAppService.loginItem(identifier: "com.sdmj76.MousecapeHelper")
            do {
                try helper.register()
                debugLog("Helper registered for launch-at-login during migration")
            } catch {
                debugLog("Failed to register helper during migration: \(error)")
            }
        }

        // Unregister old mainApp service
        do {
            try SMAppService.mainApp.unregister()
            debugLog("Unregistered old mainApp service")
        } catch {
            debugLog("Failed to unregister mainApp: \(error)")
        }

        UserDefaults.standard.set(true, forKey: "migratedToHelper")
    }

    private func migrateFromOldHelper() {
        guard !UserDefaults.standard.bool(forKey: "helperMigrated") else { return }
        UserDefaults.standard.set(true, forKey: "helperMigrated")
        DispatchQueue.global(qos: .utility).async {
            let oldService = SMAppService.loginItem(identifier: "com.sdmj76.mousecloakhelper")
            if oldService.status == .enabled {
                try? oldService.unregister()
                // launchctl bootout cleanup
                let uid = getuid()
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                process.arguments = ["bootout", "gui/\(uid)/com.sdmj76.mousecloakhelper"]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                try? process.run()
                process.waitUntilExit()
            }
        }
    }

    /// Launch MousecapeHelper when main app starts
    private func launchHelper() {
        // Helper is always launched for background session monitoring
        // Menu bar icon visibility is controlled by "Show Menu Bar Tool" toggle
        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Library")
            .appendingPathComponent("LoginItems")
            .appendingPathComponent("MousecapeHelper.app")

        // Check if helper exists
        guard FileManager.default.fileExists(atPath: helperURL.path) else {
            debugLog("Helper not found at: \(helperURL.path)")
            return
        }

        // Check if helper is already running
        let runningApps = NSWorkspace.shared.runningApplications
        let helperBundleID = "com.sdmj76.MousecapeHelper"
        if runningApps.contains(where: { $0.bundleIdentifier == helperBundleID }) {
            debugLog("Helper is already running")
            return
        }

        // Launch helper
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false // Don't activate helper (it's a background app)

        NSWorkspace.shared.openApplication(at: helperURL, configuration: configuration) { app, error in
            if let error = error {
                debugLog("Failed to launch helper: \(error.localizedDescription)")
            } else {
                debugLog("Helper launched successfully")
            }
        }
    }
}

// MARK: - Window Delegate (handles close confirmation)

@MainActor
class WindowDelegate: NSObject, NSWindowDelegate {
    private let appState: AppState
    private var timer: Timer?

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    func startObservingDirtyState() {
        // Prevent duplicate timers
        guard timer == nil else { return }
        // Use a timer to periodically check dirty state
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDocumentEdited()
            }
        }
    }

    func stopObserving() {
        timer?.invalidate()
        timer = nil
    }

    private func updateDocumentEdited() {
        guard let window = NSApp.windows.first(where: { $0.canBecomeMain }) else { return }
        // Use manual hasUnsavedChanges instead of ObjC isDirty
        let isDirty = appState.isEditing && appState.hasUnsavedChanges
        if window.isDocumentEdited != isDirty {
            window.isDocumentEdited = isDirty
        }
    }

    nonisolated func windowShouldClose(_ sender: NSWindow) -> Bool {
        let shouldBlock = MainActor.assumeIsolated {
            appState.isEditing && appState.hasUnsavedChanges
        }

        if shouldBlock {
            Task { @MainActor in
                appState.showDiscardConfirmation = true
            }
            return false
        }

        // Main app has no menu bar icon, so closing window should quit the app
        return true
    }
}

// MARK: - Toolbar Platter Hider

/// Hides NSToolbarPlatterView (toolbar background) in macOS 15+
enum ToolbarHider {
    @MainActor private static var timer: Timer?
    @MainActor private static var checkCount = 0

    @MainActor
    static func startMonitoring() {
        // Initial hide
        hideToolbarPlatter()

        // Monitor for view changes - check frequently at first, then less often
        checkCount = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                hideToolbarPlatter()
                checkCount += 1

                // After 20 checks (2 seconds), slow down to every 0.5s
                if checkCount >= 20 {
                    timer?.invalidate()
                    timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                        Task { @MainActor in
                            hideToolbarPlatter()
                        }
                    }
                }
            }
        }
    }

    @MainActor
    static func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    private static func hideToolbarPlatter() {
        guard let window = NSApp.windows.first(where: { $0.canBecomeMain }) else { return }
        hideToolbarPlatterInView(window.contentView?.superview)
    }

    @MainActor
    private static func hideToolbarPlatterInView(_ view: NSView?) {
        guard let view = view else { return }

        let className = String(describing: type(of: view))

        // Resize NSToolbarPlatterView to fit toolbar items
        if className == "NSToolbarPlatterView" {
            // Option 1: Hide it completely
            // view.isHidden = true

            // Option 2: Resize to fit toolbar items
            if let superview = view.superview {
                // Find the toolbar item viewers to calculate proper width
                var minX: CGFloat = .greatestFiniteMagnitude
                var maxX: CGFloat = 0
                findToolbarItemBounds(in: superview, minX: &minX, maxX: &maxX)
                if minX < maxX {
                    let padding: CGFloat = 8
                    view.frame = NSRect(
                        x: minX - padding,
                        y: view.frame.origin.y,
                        width: (maxX - minX) + padding * 2,
                        height: view.frame.height
                    )
                }
            }
        }

        for subview in view.subviews {
            hideToolbarPlatterInView(subview)
        }
    }

    @MainActor
    private static func findToolbarItemBounds(in view: NSView, minX: inout CGFloat, maxX: inout CGFloat) {
        let className = String(describing: type(of: view))
        if className == "NSToolbarItemViewer" {
            let frame = view.convert(view.bounds, to: nil)
            minX = min(minX, frame.minX)
            maxX = max(maxX, frame.maxX)
        }
        for subview in view.subviews {
            findToolbarItemBounds(in: subview, minX: &minX, maxX: &maxX)
        }
    }
}

// MARK: - Appearance Wrapper

/// 窗口外观容器
struct AppearanceWrapper<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
    }
}

// MARK: - Content View (Root)

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        MainView()
            // Error alert
            .alert("Error", isPresented: $appState.showError) {
                Button("OK") {
                    appState.showError = false
                }
            } message: {
                if let error = appState.lastError {
                    Text(error.localizedDescription)
                }
            }
    }
}

// MARK: - FocusedValues for Menu Commands

extension FocusedValues {
    struct SelectedCapeKey: FocusedValueKey {
        typealias Value = Binding<CursorLibrary?>
    }

    var selectedCape: Binding<CursorLibrary?>? {
        get { self[SelectedCapeKey.self] }
        set { self[SelectedCapeKey.self] = newValue }
    }
}
