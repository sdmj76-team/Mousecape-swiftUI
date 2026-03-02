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

        MenuBarExtra("Mousecape", image: "MenuBarIcon") {
            MenuBarContentView()
                .environment(appState)
        }
    }

    private func configureWindowAppearance() {
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first(where: { $0.canBecomeMain }) else { return }

            // Make titlebar transparent for cleaner look
            window.titlebarAppearsTransparent = true

            // Configure window background based on user's transparentWindow setting
            let transparentWindow = UserDefaults.standard.bool(forKey: "transparentWindow")
            if transparentWindow {
                window.isOpaque = false
                // 检测当前是否为深色模式
                let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                if isDarkMode {
                    // 深色模式：使用深灰色背景，避免与桌面混合时泛白
                    window.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 0.95)
                } else {
                    // 浅色模式：使用系统窗口背景色
                    window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9)
                }
            } else {
                window.isOpaque = true
                window.backgroundColor = NSColor.windowBackgroundColor
            }

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

// MARK: - Menu Bar Content

struct MenuBarContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if let cape = appState.appliedCape {
            Text(String(localized: "Current Cursor: \(cape.name)"))
        } else {
            Text(String(localized: "Current Cursor: None"))
        }

        Divider()

        Button(String(localized: "Open Mousecape")) {
            AppDelegate.shared?.showMainWindow()
        }

        Button(String(localized: "Reset Cursors")) {
            appState.resetToDefault()
        }

        Button(String(localized: "Settings")) {
            AppDelegate.shared?.showMainWindow()
            appState.currentPage = .settings
        }

        Divider()

        Button(String(localized: "Quit Mousecape")) {
            NSApp.terminate(nil)
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

        // If launched at login, start hidden (menu bar only)
        // Detect background launch: check if app was activated by user or system
        let launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        let isBackgroundLaunch = !NSRunningApplication.current.isActive

        if launchAtLogin && isBackgroundLaunch {
            NSApp.setActivationPolicy(.accessory)
            debugLog("Launched at login - starting in accessory mode")
        } else {
            debugLog("Launched manually - will show main window")
        }

        // Intercept file open events BEFORE SwiftUI creates new windows
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenDocumentEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenDocuments)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        startSessionMonitor()
        migrateFromOldHelper()
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
        debugLog("Exiting accessory mode - showing main window")

        // Restore state if capes were cleared (window was destroyed)
        if AppState.shared.capes.isEmpty {
            AppState.shared.restoreStateAfterReopen()
        }

        // 优先用保存的引用，fallback 到 NSApp.windows 搜索
        let window = mainWindow ?? NSApp.windows.first(where: { $0.canBecomeMain })
        if let window = window {
            // 先显示窗口（在 accessory 模式下）
            window.orderFrontRegardless()
            window.makeKey()
        }

        // 然后异步切换 policy（延迟到下一个 RunLoop 周期）
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            debugLog("Policy switched to regular, window activated")
        }

        // Resume timer polling and animations when window is shown
        windowDelegate?.startObservingDirtyState()
        AppState.shared.isWindowVisible = true
        debugLog("Main window shown, animations resumed")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return false
    }

    // Keep app running when window is closed (menu bar stays active)
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // Close ObjC logging system on exit
    func applicationWillTerminate(_ notification: Notification) {
        #if DEBUG
        MCLoggerClose()
        #endif
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

        // Hide window and clear memory, but don't actually close it
        // This prevents SwiftUI from keeping the view tree alive
        MainActor.assumeIsolated {
            debugLog("Entering accessory mode - hiding main window")
            // Stop timer polling before window hides
            AppDelegate.shared?.windowDelegate?.stopObserving()
            appState.isWindowVisible = false

            // Clear all memory caches aggressively
            appState.clearMemoryCaches()

            // Hide the window
            sender.orderOut(nil)

            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.accessory)
                debugLog("Accessory mode active - window hidden, memory cleared")
            }
        }
        return false  // Don't close, just hide
    }
}

// MARK: - Toolbar Platter Hider

/// Hides NSToolbarPlatterView (toolbar background) in macOS 15+
enum ToolbarHider {
    @MainActor private static var timer: Timer?

    @MainActor
    static func startMonitoring() {
        // Initial hide
        hideToolbarPlatter()

        // Monitor for view changes - check frequently at first, then less often
        var checkCount = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                hideToolbarPlatter()
                checkCount += 1

                // After 20 checks (2 seconds), slow down to every 0.5s
                if checkCount >= 20 {
                    timer?.invalidate()
                    timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                        DispatchQueue.main.async {
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

struct AppearanceWrapper<Content: View>: View {
    /// appearanceMode: 1 = Light, 2 = Dark (默认 1 = Light)
    @AppStorage("appearanceMode") private var appearanceMode = 1
    @AppStorage("transparentWindow") private var transparentWindow = false
    @ViewBuilder let content: Content

    private var isDarkMode: Bool {
        appearanceMode == 2
    }

    var body: some View {
        content
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .onChange(of: appearanceMode, initial: true) { _, newValue in
                updateAppAppearance(newValue)
            }
    }

    private func updateAppAppearance(_ mode: Int) {
        // 直接设置 NSApplication 的外观以确保实时生效
        if mode == 2 {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        } else {
            NSApp.appearance = NSAppearance(named: .aqua)
        }

        // 更新窗口背景色
        DispatchQueue.main.async {
            updateWindowOpacity(isDark: mode == 2)
        }
    }

    private func updateWindowOpacity(isDark: Bool) {
        guard let window = NSApp.windows.first(where: { $0.canBecomeMain }) else { return }

        if transparentWindow {
            window.isOpaque = false
            if isDark {
                // 深色模式：使用深灰色背景，避免与桌面混合时泛白
                window.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 0.95)
            } else {
                // 浅色模式：使用系统窗口背景色
                window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9)
            }
        } else {
            window.isOpaque = true
            window.backgroundColor = NSColor.windowBackgroundColor
        }
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
