//
//  SettingsView.swift
//  Mousecape
//
//  Settings view with left sidebar navigation
//  Integrated into main window via page switcher
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var selectedCategory: SettingsCategory = .general
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Left sidebar: Category list
            List(SettingsCategory.allCases, selection: $selectedCategory) { category in
                Label(String(localized: String.LocalizationValue(category.title)), systemImage: category.icon)
                    .tag(category)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .navigationSplitViewColumnWidth(min: 150, ideal: 180, max: 220)
        } detail: {
            // Right: Settings content based on selected category
            settingsContent
                .scrollContentBackground(.hidden)
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    appState.currentPage = .home
                }) {
                    Image(systemName: "chevron.left")
                }
                .help("Back")
            }
        }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch selectedCategory {
        case .general:
            GeneralSettingsView()
        case .appearance:
            AppearanceSettingsView()
        case .advanced:
            AdvancedSettingsView()
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("doubleClickAction") private var doubleClickAction = 0
    @State private var cursorScale: Double = 1.0
    @State private var scaleMode: ScaleMode = .global
    @State private var isLeftHanded: Bool = false
    @State private var applyTask: Task<Void, Never>?
    @State private var loginToggleError: String?
    @State private var showLoginError = false
    @Environment(AppState.self) private var appState

    /// The key used by ObjC code for cursor scale
    private static let cursorScaleKey = "MCCursorScale"
    private static let scaleModeKey = "MCScaleMode"
    private static let perCursorScalesKey = "MCPerCursorScales"
    private static let handednessKey = "MCHandedness"
    private static let globalCursorScaleKey = "MCGlobalCursorScale"
    private static let preferenceDomain = "com.sdmj76.Mousecape"

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Apply at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        // Control MousecapeHelper's launch-at-login registration only
                        let helper = SMAppService.loginItem(identifier: "com.sdmj76.MousecapeHelper")
                        do {
                            if newValue {
                                try helper.register()
                                debugLog("Helper registered for launch-at-login")
                            } else {
                                try helper.unregister()
                                debugLog("Helper unregistered from launch-at-login")
                            }
                        } catch {
                            launchAtLogin = !newValue
                            loginToggleError = error.localizedDescription
                            showLoginError = true
                            debugLog("Failed to update helper status: \(error)")
                        }
                    }
            }

            Section("Double-click Action") {
                Picker("When double-clicking a Cape", selection: $doubleClickAction) {
                    Text("Apply Cape").tag(0)
                    Text("Edit Cape").tag(1)
                    Text("Do Nothing").tag(2)
                }
            }

            Section("Cursor Scale") {
                Picker("Scale Mode", selection: $scaleMode) {
                    ForEach(ScaleMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: scaleMode) { _, newValue in
                    saveScaleMode(newValue)
                    if newValue == .global {
                        // Reload the actual global scale from preferences (may differ from stale UI state)
                        loadCursorScale()
                        // Restore global scale
                        _ = setCursorScale(Float(cursorScale))
                        saveCursorScale(cursorScale)
                        if let cape = appState.appliedCape {
                            appState.applyCape(cape)
                        }
                    } else {
                        // Apply custom scales
                        applyCustomScales()
                    }
                }

                if scaleMode == .global {
                    VStack(alignment: .leading) {
                        Text("\(String(localized:"Global Scale:")) \(cursorScale, specifier: "%.1f")x")
                        Slider(value: $cursorScale, in: 0.5...16.0, step: 0.1) {
                        } minimumValueLabel: {
                            Text("0.5x")
                        } maximumValueLabel: {
                            Text("16.0x")
                        }
                        .onChange(of: cursorScale) { _, newValue in
                            saveCursorScale(newValue)
                            _ = setCursorScale(Float(newValue))
                            // In global mode, CGSSetCursorScale already handles scaling
                            // — no need to re-register all cursors
                        }

                        Text("Scale changes are applied immediately.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    NavigationLink("Configure Per-Cursor Scales...") {
                        CustomScaleView()
                    }
                }
            }

            Section("Cursor") {
                Picker("Cursor Direction", selection: Binding(
                    get: { isLeftHanded },
                    set: { newValue in
                        isLeftHanded = newValue
                        saveHandedness(newValue)
                        if let cape = appState.appliedCape {
                            appState.applyCape(cape)
                        }
                    }
                )) {
                    Text("Right Hand").tag(false)
                    Text("Left Hand").tag(true)
                }
                .pickerStyle(.segmented)

                Text("Left-hand mode mirror cursors horizontally.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("General")
        .onAppear {
            loadScaleMode()  // This now also calls loadCursorScale()
            loadHandedness()
        }
        .alert("Login Item Error", isPresented: $showLoginError) {
            Button("OK") { }
        } message: {
            Text(loginToggleError ?? "")
        }
    }

    /// Load cursor scale from CFPreferences (same as ObjC code)
    private func loadCursorScale() {
        // In global mode, use the separate global scale preference (not MCCursorScale which custom mode overwrites)
        if scaleMode == .global {
            if let value = CFPreferencesCopyAppValue(Self.globalCursorScaleKey as CFString, Self.preferenceDomain as CFString) as? Double {
                cursorScale = value
            } else if let value = CFPreferencesCopyAppValue(Self.cursorScaleKey as CFString, Self.preferenceDomain as CFString) as? Double {
                cursorScale = value
            } else {
                cursorScale = 1.0
            }
        } else {
            // In custom mode, show the current system scale (maxScale from MCCursorScale)
            if let value = CFPreferencesCopyAppValue(Self.cursorScaleKey as CFString, Self.preferenceDomain as CFString) as? Double {
                cursorScale = value
            } else {
                cursorScale = 1.0
            }
        }
    }

    /// Save cursor scale to CFPreferences (same as ObjC code)
    private func saveCursorScale(_ value: Double) {
        // Save to separate global scale key so custom mode doesn't overwrite it
        CFPreferencesSetAppValue(
            Self.globalCursorScaleKey as CFString,
            value as CFNumber,
            Self.preferenceDomain as CFString
        )
        CFPreferencesAppSynchronize(Self.preferenceDomain as CFString)
        // Also save to MCCursorScale for applySavedCursorScale() and apply.m
        CFPreferencesSetAppValue(
            Self.cursorScaleKey as CFString,
            value as CFNumber,
            Self.preferenceDomain as CFString
        )
        CFPreferencesAppSynchronize(Self.preferenceDomain as CFString)
    }

    /// Load handedness from CFPreferences (same as ObjC MCFlag)
    private func loadHandedness() {
        if let value = CFPreferencesCopyAppValue(Self.handednessKey as CFString, Self.preferenceDomain as CFString) {
            isLeftHanded = (value as? NSNumber)?.boolValue ?? false
        } else {
            isLeftHanded = false
        }
    }

    /// Save handedness to CFPreferences and UserDefaults (for @AppStorage reactivity)
    private func saveHandedness(_ leftHanded: Bool) {
        let intValue = leftHanded ? 1 : 0
        CFPreferencesSetAppValue(
            Self.handednessKey as CFString,
            intValue as CFNumber,
            Self.preferenceDomain as CFString
        )
        CFPreferencesAppSynchronize(Self.preferenceDomain as CFString)
        // Also write to UserDefaults so @AppStorage("MCHandedness") in preview views updates reactively
        UserDefaults.standard.set(intValue, forKey: Self.handednessKey)
    }

    /// Load scale mode from CFPreferences and sync C global variable
    private func loadScaleMode() {
        if let value = CFPreferencesCopyAppValue(Self.scaleModeKey as CFString, Self.preferenceDomain as CFString) as? String,
           let mode = ScaleMode(rawValue: value) {
            scaleMode = mode
        } else {
            scaleMode = .global
        }
        // CRITICAL: Sync the C global variable so apply.m reads the correct mode
        setCustomScaleMode(scaleMode == .custom)
        // Reload cursor scale for the current mode
        loadCursorScale()
    }

    /// Save scale mode to CFPreferences
    private func saveScaleMode(_ mode: ScaleMode) {
        CFPreferencesSetAppValue(
            Self.scaleModeKey as CFString,
            mode.rawValue as CFString,
            Self.preferenceDomain as CFString
        )
        CFPreferencesAppSynchronize(Self.preferenceDomain as CFString)
        // Set direct C variable for reliable in-process communication with ObjC
        setCustomScaleMode(mode == .custom)
    }

    /// Apply custom per-cursor scales
    private func applyCustomScales() {
        guard let cape = appState.appliedCape else { return }
        appState.applyCape(cape)
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @AppStorage("showPreviewAnimations") private var showPreviewAnimations = true
    @AppStorage("showAuthorInfo") private var showAuthorInfo = true
    @AppStorage("previewGridColumns") private var previewGridColumns = 0
    @AppStorage("previewDisplayMode") private var previewDisplayMode = 0
    @State private var innerShadowEnabled: Bool = false
    @State private var outerGlowEnabled: Bool = false
    @Environment(AppState.self) private var appState

    private static let innerShadowKey = "MCInnerShadow"
    private static let outerGlowKey = "MCOuterGlow"
    private static let preferenceDomain = "com.sdmj76.Mousecape"

    var body: some View {
        Form {
            Section("List Display") {
                Toggle("Show Cursor Preview Animations", isOn: $showPreviewAnimations)
                Toggle("Show Cape Author Info", isOn: $showAuthorInfo)
            }

            Section("Preview Panel") {
                Picker("Display Mode", selection: $previewDisplayMode) {
                    Text("Simple (Windows Style)").tag(0)
                    Text("Advanced (macOS Style)").tag(1)
                }

                Picker("Preview Grid Columns", selection: $previewGridColumns) {
                    Text("Auto (based on window size)").tag(0)
                    Text("4 \(String(localized:"columns"))").tag(4)
                    Text("6 \(String(localized:"columns"))").tag(6)
                    Text("8 \(String(localized:"columns"))").tag(8)
                }
            }

            Section("Effects") {
                Toggle("Inner Shadow", isOn: $innerShadowEnabled)
                    .onChange(of: innerShadowEnabled) { _, newValue in
                        saveInnerShadow(newValue)
                        if let cape = appState.appliedCape {
                            appState.applyCape(cape)
                        }
                    }

                Text("Adds an inner shadow effect to cursor edges for better visibility.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Outer Glow", isOn: $outerGlowEnabled)
                    .onChange(of: outerGlowEnabled) { _, newValue in
                        saveOuterGlow(newValue)
                        if let cape = appState.appliedCape {
                            appState.applyCape(cape)
                        }
                    }

                Text("Adds a soft glow around the cursor for better visibility on any background.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Appearance")
        .onAppear {
            if let value = CFPreferencesCopyAppValue(Self.innerShadowKey as CFString, Self.preferenceDomain as CFString) {
                innerShadowEnabled = (value as? NSNumber)?.boolValue ?? false
            }
            if let value = CFPreferencesCopyAppValue(Self.outerGlowKey as CFString, Self.preferenceDomain as CFString) {
                outerGlowEnabled = (value as? NSNumber)?.boolValue ?? false
            }
        }
    }

    private func saveInnerShadow(_ enabled: Bool) {
        let intValue = enabled ? 1 : 0
        CFPreferencesSetAppValue(Self.innerShadowKey as CFString, intValue as CFNumber, Self.preferenceDomain as CFString)
        CFPreferencesAppSynchronize(Self.preferenceDomain as CFString)
    }

    private func saveOuterGlow(_ enabled: Bool) {
        let intValue = enabled ? 1 : 0
        CFPreferencesSetAppValue(Self.outerGlowKey as CFString, intValue as CFNumber, Self.preferenceDomain as CFString)
        CFPreferencesAppSynchronize(Self.preferenceDomain as CFString)
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @State private var showResetConfirmation = false
    @State private var isExportingLogs = false
    @State private var showResetCursorSuccess = false
    @State private var showResetOrderSuccess = false
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Storage") {
                LabeledContent("Cape Folder") {
                    Text("~/Library/Application Support/Mousecape/capes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Show in Finder") {
                    appState.openCapeFolder()
                }
            }

            Section("Reset") {
                HStack {
                    Button("Reset System Cursor") {
                        appState.resetToDefault()
                        showResetCursorSuccess = true
                    }

                    Button("Reset Sidebar Order") {
                        appState.resetCapeOrder()
                        showResetOrderSuccess = true
                    }

                    Button("Dump System Cursors") {
                        appState.dumpSystemCursors()
                    }

                    Button("Restore Default Settings", role: .destructive) {
                        showResetConfirmation = true
                    }
                }
                .confirmationDialog(
                    "Restore Default Settings",
                    isPresented: $showResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Restore Default Settings", role: .destructive) {
                        resetToDefaults()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will reset all settings to their default values. This action cannot be undone.")
                }
            }

            #if DEBUG
            Section("Debug") {
                LabeledContent("Log Folder") {
                    Text("~/Library/Logs/Mousecape")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Log Files") {
                    let files = DebugLogger.getAllLogFiles()
                    let size = DebugLogger.getTotalLogSize()
                    Text("\(files.count) files, \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Open Log Folder") {
                        NSWorkspace.shared.open(DebugLogger.logsDirectory)
                    }

                    Button("Export All Logs") {
                        exportLogs()
                    }
                    .disabled(isExportingLogs)

                    Button("Clear All Logs", role: .destructive) {
                        DebugLogger.clearAllLogs()
                    }
                }

                Text("Logs are automatically deleted after 24 hours. Logs contain debug information for troubleshooting cursor issues.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            #endif

            Section("About") {
                LabeledContent("Version") {
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        Text("Mousecape v\(version) (\(build))")
                    } else {
                        Text("Mousecape v1.1.0")
                    }
                }
                LabeledContent("System Requirements") {
                    Text("macOS 15+")
                }
                LabeledContent("Original Author") {
                    Text("\u{00A9} 2014-2025 Alex Zielenski")
                }
                LabeledContent("SwiftUI Redesign") {
                    Text("\u{00A9} 2025 sdmj76")
                }

                HStack {
                    Button("Check for Updates") {
                        checkForUpdates()
                    }
                    Button("GitHub") {
                        if let url = URL(string: "https://github.com/sdmj76/Mousecape-swiftUI") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Button("Report Issue") {
                        if let url = URL(string: "https://github.com/sdmj76/Mousecape-swiftUI/issues") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Advanced")
        .alert(
            "Reset System Cursor",
            isPresented: $showResetCursorSuccess
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("System cursor has been reset to default.")
        }
        .alert(
            "Reset Sidebar Order",
            isPresented: $showResetOrderSuccess
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Sidebar order has been reset to alphabetical.")
        }
    }

    private func resetToDefaults() {
        // Reset all settings to defaults
        let defaults = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
    }

    #if DEBUG
    private func exportLogs() {
        isExportingLogs = true

        DispatchQueue.global(qos: .userInitiated).async {
            guard let zipURL = DebugLogger.exportLogsAsZip() else {
                DispatchQueue.main.async {
                    isExportingLogs = false
                }
                return
            }

            DispatchQueue.main.async {
                isExportingLogs = false

                // Use NSSavePanel to let user choose save location
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.zip]
                savePanel.nameFieldStringValue = zipURL.lastPathComponent
                savePanel.canCreateDirectories = true
                savePanel.title = String(localized: "Export Debug Logs")

                if savePanel.runModal() == .OK, let destURL = savePanel.url {
                    do {
                        // Remove existing file if any
                        try? FileManager.default.removeItem(at: destURL)
                        try FileManager.default.copyItem(at: zipURL, to: destURL)

                        // Clean up temp file
                        try? FileManager.default.removeItem(at: zipURL)

                        // Show in Finder
                        NSWorkspace.shared.selectFile(destURL.path, inFileViewerRootedAtPath: "")
                    } catch {
                        debugLog("Failed to save logs: \(error.localizedDescription)")
                    }
                } else {
                    // Clean up temp file if user cancelled
                    try? FileManager.default.removeItem(at: zipURL)
                }
            }
        }
    }
    #endif

    private func checkForUpdates() {
        // Open GitHub releases page for manual update checking
        if let url = URL(string: "https://github.com/sdmj76/Mousecape-swiftUI/releases") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(AppState.shared)
        .frame(width: 600, height: 500)
}

// MARK: - Custom Scale View

struct CustomScaleView: View {
    @Environment(AppState.self) private var appState
    @State private var perCursorScales: [String: Double] = [:]
    @State private var selectedCursorType: CursorType? = nil
    @State private var showSetAllAlert = false
    @State private var setAllValue: Double = 1.0
    @State private var hasUnsavedScaleChanges = false

    private static let perCursorScalesKey = "MCPerCursorScales"
    private static let cursorScaleKey = "MCCursorScale"
    private static let preferenceDomain = "com.sdmj76.Mousecape"

    var body: some View {
        HStack(spacing: 0) {
            // Left column: cursor type list
            List(CursorType.allCases, selection: $selectedCursorType) { cursorType in
                HStack {
                    Text(cursorType.displayName)
                    Spacer()
                    if let scale = perCursorScales[cursorType.rawValue], scale != 1.0 {
                        Text("\(scale, specifier: "%.1f")x")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .tag(cursorType)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 220, idealWidth: 260)

            Divider()

            // Right column: scale control
            if let selected = selectedCursorType {
                VStack(alignment: .leading, spacing: 16) {
                    Text(selected.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(selected.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    let currentScale = perCursorScales[selected.rawValue] ?? 1.0
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scale: \(currentScale, specifier: "%.1f")x")
                            .font(.headline)
                        Slider(value: Binding(
                            get: { currentScale },
                            set: { newValue in
                                updateScale(for: selected, to: newValue)
                            }
                        ), in: 0.5...16.0, step: 0.1) {
                        } minimumValueLabel: {
                            Text("0.5x")
                        } maximumValueLabel: {
                            Text("16.0x")
                        }
                    }

                    HStack(spacing: 12) {
                        Button("Reset to 1.0x") {
                            updateScale(for: selected, to: 1.0)
                        }
                        .buttonStyle(.bordered)

                        Button("Set All to This") {
                            setAllValue = currentScale
                            showSetAllAlert = true
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    HStack {
                        Button("Reset All to 1.0x") {
                            resetAllScales()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack {
                    Text("Select a cursor type")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Choose a cursor from the list to configure its scale.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Custom Scales")
        .onAppear {
            loadPerCursorScales()
            hasUnsavedScaleChanges = false
        }
        .onDisappear {
            if hasUnsavedScaleChanges, let cape = appState.appliedCape {
                appState.applyCape(cape)
            }
        }
        .alert("Set All Scales", isPresented: $showSetAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Set All") {
                setAllScales(to: setAllValue)
            }
        } message: {
            Text("Set all cursor scales to \(setAllValue, specifier: "%.1f")x?")
        }
    }

    private func loadPerCursorScales() {
        if let dict = CFPreferencesCopyAppValue(Self.perCursorScalesKey as CFString, Self.preferenceDomain as CFString) as? [String: Double] {
            perCursorScales = dict
        } else {
            perCursorScales = [:]
        }
    }

    private func savePerCursorScales() {
        CFPreferencesSetAppValue(
            Self.perCursorScalesKey as CFString,
            perCursorScales as CFPropertyList,
            Self.preferenceDomain as CFString
        )
        CFPreferencesAppSynchronize(Self.preferenceDomain as CFString)
    }

    private func updateScale(for cursorType: CursorType, to value: Double) {
        perCursorScales[cursorType.rawValue] = value
        savePerCursorScales()
        recalculateMaxScaleAndApply()
    }

    private func resetAllScales() {
        perCursorScales = [:]
        savePerCursorScales()
        recalculateMaxScaleAndApply()
    }

    private func setAllScales(to value: Double) {
        for cursorType in CursorType.allCases {
            perCursorScales[cursorType.rawValue] = value
        }
        savePerCursorScales()
        recalculateMaxScaleAndApply()
    }

    private func recalculateMaxScaleAndApply() {
        let maxScale = perCursorScales.values.max() ?? 1.0
        // Save maxScale to MCCustomMaxScale (separate from global scale to prevent cross-contamination)
        CFPreferencesSetAppValue(
            "MCCustomMaxScale" as CFString,
            maxScale as CFNumber,
            Self.preferenceDomain as CFString
        )
        CFPreferencesAppSynchronize(Self.preferenceDomain as CFString)
        // Set system scale immediately for visual feedback (lightweight CGS call)
        _ = setCursorScale(Float(maxScale))
        // Mark that a full re-apply is needed on screen exit (expensive — re-registers all cursors)
        hasUnsavedScaleChanges = true
    }
}
