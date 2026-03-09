//
//  DebugLogger.swift
//  Mousecape
//
//  Debug logging system for Mousecape GUI.
//  Only active when DEBUG configuration is used.
//

import Foundation
import AppKit

/// Debug version log manager
///
/// @unchecked Sendable is safe because:
/// 1. All mutable state (logFileHandle, logFilePath) is protected by serial DispatchQueue
/// 2. All file operations are dispatched to the queue, ensuring thread-safe access
/// 3. No concurrent access to mutable state possible
final class DebugLogger: @unchecked Sendable {
    static let shared = DebugLogger()

    private var logFileHandle: FileHandle?
    private var logFilePath: URL?
    private let dateFormatter: DateFormatter
    private let queue = DispatchQueue(label: "com.mousecape.logger", qos: .utility)
    private var shutdownObserver: Any?

    /// Log directory
    static var logsDirectory: URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return library.appendingPathComponent("Logs/Mousecape")
    }

    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"

        #if DEBUG
        initializeLogFile()
        #endif
    }

    private func initializeLogFile() {
        let logsDir = Self.logsDirectory

        // Create directory
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        // Clean old logs (keep only last 24 hours)
        Self.cleanOldLogs()

        // Generate filename
        let fileFormatter = DateFormatter()
        fileFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = fileFormatter.string(from: Date())
        let fileName = "mousecape_gui_\(timestamp).log"

        logFilePath = logsDir.appendingPathComponent(fileName)

        // Create file
        FileManager.default.createFile(atPath: logFilePath!.path, contents: nil)
        logFileHandle = try? FileHandle(forWritingTo: logFilePath!)

        // Write header
        writeHeader()

        // Register for shutdown notification
        registerForShutdown()
    }

    private func writeHeader() {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        log("=== Mousecape GUI Debug Log ===")
        log("Time: \(Date())")
        log("macOS: \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")
        log("User: \(NSUserName())")
        log("Home: \(NSHomeDirectory())")
        log("App: \(Bundle.main.bundleIdentifier ?? "unknown")")
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            log("Version: \(appVersion)")
        }
        if let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            log("Build: \(buildNumber)")
        }
        log("Log file: \(logFilePath?.path ?? "none")")

        // Log user preferences
        log("--- User Preferences ---")
        let defaults = UserDefaults.standard
        log("  launchAtLogin: \(defaults.bool(forKey: "launchAtLogin"))")
        log("  doubleClickAction: \(defaults.integer(forKey: "doubleClickAction"))")
        log("  language: \(defaults.string(forKey: "appLanguage") ?? "system")")
        log("  transparentBackground: \(defaults.bool(forKey: "transparentBackground"))")

        // Read mousecloak preferences from CFPreferences
        if let appliedCursor = CFPreferencesCopyValue(
            "MCAppliedCursor" as CFString,
            "com.sdmj76.Mousecape" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        ) as? String {
            log("  MCAppliedCursor: \(appliedCursor)")
        } else {
            log("  MCAppliedCursor: (not set)")
        }

        if let cursorScale = CFPreferencesCopyValue(
            "MCCursorScale" as CFString,
            "com.sdmj76.Mousecape" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        ) as? Double {
            log("  MCCursorScale: \(cursorScale)")
        } else {
            log("  MCCursorScale: (not set)")
        }

        log("===============================")
    }

    /// Register for system shutdown/logout notification to flush logs
    private func registerForShutdown() {
        shutdownObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.log("=== System Shutdown/Logout Detected ===")
            self?.closeLogFile()
        }
    }

    /// Write to log
    func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logLine = "[\(timestamp)] [\(fileName):\(line)] \(message)\n"

        // Output to console
        print(logLine, terminator: "")

        // Write to file
        queue.async { [weak self] in
            if let data = logLine.data(using: .utf8) {
                self?.logFileHandle?.write(data)
                try? self?.logFileHandle?.synchronize()
            }
        }
        #endif
    }

    /// Close log file and flush
    private func closeLogFile() {
        queue.sync {
            if let handle = logFileHandle {
                let endMessage = "[\(dateFormatter.string(from: Date()))] === Log End ===\n"
                if let data = endMessage.data(using: .utf8) {
                    handle.write(data)
                }
                try? handle.synchronize()
                try? handle.close()
                logFileHandle = nil
            }
        }
    }

    /// Get all log files
    static func getAllLogFiles() -> [URL] {
        let logsDir = logsDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: logsDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }
        return files.filter { $0.pathExtension == "log" }.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            return date1 > date2
        }
    }

    /// Export all logs as zip using NSFileCoordinatorReadingForUploading
    static func exportLogsAsZip() -> URL? {
        let logsDir = logsDirectory
        let logFiles = getAllLogFiles()

        guard !logFiles.isEmpty else { return nil }

        // Create temporary zip file
        let tempDir = FileManager.default.temporaryDirectory
        let fileFormatter = DateFormatter()
        fileFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = fileFormatter.string(from: Date())
        let zipPath = tempDir.appendingPathComponent("mousecape_logs_\(timestamp).zip")

        // Remove existing file
        try? FileManager.default.removeItem(at: zipPath)

        // Use NSFileCoordinator to create zip
        var error: NSError?
        var coordinatorError: NSError?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: logsDir, options: .forUploading, error: &coordinatorError) { zipURL in
            do {
                try FileManager.default.copyItem(at: zipURL, to: zipPath)
            } catch let copyError as NSError {
                error = copyError
            }
        }

        if let error = error ?? coordinatorError {
            DebugLogger.shared.log("Failed to create zip: \(error.localizedDescription)")
            return nil
        }

        return zipPath
    }

    /// Get total log files size
    static func getTotalLogSize() -> Int64 {
        let files = getAllLogFiles()
        var totalSize: Int64 = 0
        for file in files {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }
        return totalSize
    }

    /// Clean logs older than 24 hours and enforce total size limit
    static func cleanOldLogs() {
        let logsDir = logsDirectory
        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60) // 24 hours ago
        let maxTotalSize: Int64 = 100 * 1024 * 1024 // 100MB total limit

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: logsDir,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return
        }

        // Filter log files and get their metadata
        var logFiles: [(url: URL, modDate: Date, size: Int64)] = []
        for file in files {
            guard file.pathExtension == "log" else { continue }

            if let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
               let modDate = attrs.contentModificationDate,
               let size = attrs.fileSize {
                logFiles.append((url: file, modDate: modDate, size: Int64(size)))
            }
        }

        // Sort by modification date (oldest first)
        logFiles.sort { $0.modDate < $1.modDate }

        // Phase 1: Delete files older than 24 hours
        var remainingFiles: [(url: URL, modDate: Date, size: Int64)] = []
        for logFile in logFiles {
            if logFile.modDate < cutoffDate {
                try? FileManager.default.removeItem(at: logFile.url)
            } else {
                remainingFiles.append(logFile)
            }
        }

        // Phase 2: Enforce total size limit by deleting oldest files
        var totalSize: Int64 = remainingFiles.reduce(0) { $0 + $1.size }
        var filesToKeep: [(url: URL, modDate: Date, size: Int64)] = []

        // Keep files from newest to oldest until we hit the size limit
        for logFile in remainingFiles.reversed() {
            if totalSize <= maxTotalSize {
                filesToKeep.append(logFile)
            } else {
                // Would exceed limit, delete this file
                try? FileManager.default.removeItem(at: logFile.url)
                totalSize -= logFile.size
            }
        }
    }

    /// Clear all log files
    static func clearAllLogs() {
        let files = getAllLogFiles()
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    deinit {
        #if DEBUG
        closeLogFile()

        // Remove shutdown observer
        if let observer = shutdownObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        #endif
    }
}

// MARK: - Convenience global function

/// Log a debug message (only active in DEBUG builds)
func debugLog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    DebugLogger.shared.log(message, file: file, function: function, line: line)
    #endif
}
