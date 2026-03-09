//
//  CursorLibrary.swift
//  Mousecape
//
//  Swift wrapper for MCCursorLibrary (Cape)
//

import Foundation
import AppKit

/// Swift wrapper around MCCursorLibrary for SwiftUI usage
@Observable
final class CursorLibrary: Identifiable, Hashable {
    /// Stable ID based on the underlying ObjC object's memory address
    /// This ensures the same ObjC library always has the same wrapper ID
    var id: ObjectIdentifier {
        ObjectIdentifier(objcLibrary)
    }

    private let objcLibrary: MCCursorLibrary

    // Cached cursors for SwiftUI
    private var _cursors: [Cursor]?

    /// Invalidate cursor cache (call after modifications)
    func invalidateCursorCache() {
        _cursors = nil
    }

    // MARK: - Properties (bridged from ObjC)

    var name: String {
        get { objcLibrary.name }
        set { objcLibrary.name = newValue }
    }

    var author: String {
        get { objcLibrary.author }
        set { objcLibrary.author = newValue }
    }

    var identifier: String {
        get { objcLibrary.identifier }
        set { objcLibrary.identifier = newValue }
    }

    var version: Double {
        get { objcLibrary.version.doubleValue }
        set { objcLibrary.version = NSNumber(value: newValue) }
    }

    var fileURL: URL? {
        get { objcLibrary.fileURL }
        set { objcLibrary.fileURL = newValue }
    }

    var isDirty: Bool {
        objcLibrary.isDirty
    }

    var isHiDPI: Bool {
        get { objcLibrary.isHiDPI }
        set { objcLibrary.setValue(newValue, forKey: "hiDPI") }
    }

    var isInCloud: Bool {
        get { objcLibrary.isInCloud }
        set { objcLibrary.isInCloud = newValue }
    }

    // MARK: - Cursors

    var cursors: [Cursor] {
        if let cached = _cursors {
            return cached
        }

        let objcCursors = objcLibrary.cursors as? Set<MCCursor> ?? []
        let swiftCursors = objcCursors.map { Cursor(objcCursor: $0) }
        // Sort by identifier for consistent ordering
        let sorted = swiftCursors.sorted { $0.identifier < $1.identifier }
        _cursors = sorted
        return sorted
    }

    var cursorCount: Int {
        objcLibrary.cursors.count
    }

    /// Get the first cursor (preferring Arrow) for preview
    var previewCursor: Cursor? {
        // Prefer Arrow cursor for preview
        if let arrow = cursors.first(where: { $0.identifier.contains("Arrow") && !$0.identifier.contains("Ctx") }) {
            return arrow
        }
        return cursors.first
    }

    // MARK: - Cursor Management

    func addCursor(_ cursor: Cursor) {
        objcLibrary.addCursor(cursor.underlyingCursor)
        _cursors = nil // Invalidate cache
    }

    func removeCursor(_ cursor: Cursor) {
        objcLibrary.removeCursor(cursor.underlyingCursor)
        _cursors = nil // Invalidate cache
    }

    func cursor(withIdentifier identifier: String) -> Cursor? {
        cursors.first { $0.identifier == identifier }
    }

    /// 将光标的所有属性同步到同组别名（覆盖已有）
    func syncCursorToAliases(_ cursor: Cursor) {
        guard let group = WindowsCursorGroup.group(for: cursor.identifier) else { return }
        for cursorType in group.cursorTypes where cursorType.rawValue != cursor.identifier {
            let aliasCursor = cursor.copy(withIdentifier: cursorType.rawValue)
            // 直接操作底层 ObjC 对象，避免多次缓存失效
            if let existing = objcLibrary.cursors.first(where: { ($0 as? MCCursor)?.identifier == cursorType.rawValue }) as? MCCursor {
                objcLibrary.removeCursor(existing)
            }
            objcLibrary.addCursor(aliasCursor.underlyingCursor)
        }
        _cursors = nil  // 只在最后失效一次
    }

    /// 只同步元数据到别名（不深拷贝图像），用于 hotspot/fps/frameCount 变化时的快速同步
    func syncMetadataToAliases(_ cursor: Cursor) {
        guard let group = WindowsCursorGroup.group(for: cursor.identifier) else { return }
        for cursorType in group.cursorTypes where cursorType.rawValue != cursor.identifier {
            let aliasCursor = cursor.copyMetadata(withIdentifier: cursorType.rawValue)
            // 直接操作底层 ObjC 对象，避免多次缓存失效
            if let existing = objcLibrary.cursors.first(where: { ($0 as? MCCursor)?.identifier == cursorType.rawValue }) as? MCCursor {
                objcLibrary.removeCursor(existing)
            }
            objcLibrary.addCursor(aliasCursor.underlyingCursor)
        }
        _cursors = nil  // 只在最后失效一次
    }

    /// 删除分组中所有光标（简易模式下删除整个分组用）
    func removeGroupCursors(for group: WindowsCursorGroup) {
        for cursorType in group.cursorTypes {
            if let existing = self.cursor(withIdentifier: cursorType.rawValue) {
                removeCursor(existing)
            }
        }
    }

    /// 添加光标并自动创建同组别名
    func addCursorWithAliases(_ cursor: Cursor) {
        if let existing = self.cursor(withIdentifier: cursor.identifier) {
            removeCursor(existing)
        }
        addCursor(cursor)
        syncCursorToAliases(cursor)
    }

    // MARK: - Save & Load

    func save() throws {
        if let error = objcLibrary.save() {
            throw error
        }
    }

    func revertToSaved() {
        objcLibrary.revertToSaved()
        _cursors = nil // Invalidate cache
    }

    /// Clear the dirty flag (mark as saved)
    func clearChangeCount() {
        objcLibrary.updateChangeCount(.changeCleared)
    }

    // MARK: - Initialization

    init(objcLibrary: MCCursorLibrary) {
        self.objcLibrary = objcLibrary
    }

    /// Create a new empty library
    convenience init(name: String, author: String = "") {
        let library = MCCursorLibrary(cursors: Set())
        library.name = name
        library.author = author
        // Generate identifier in format: local.Author.Name
        let sanitizedAuthor = Self.sanitizeIdentifierComponent(author.isEmpty ? "Unknown" : author)
        let sanitizedName = Self.sanitizeIdentifierComponent(name.isEmpty ? "Untitled" : name)
        library.identifier = "local.\(sanitizedAuthor).\(sanitizedName)"
        library.version = NSNumber(value: 1.0)
        self.init(objcLibrary: library)
    }

    /// Sanitize a string for use in identifier (remove spaces and special characters)
    static func sanitizeIdentifierComponent(_ string: String) -> String {
        // Replace spaces with nothing, keep only alphanumeric and some punctuation
        let allowed = CharacterSet.alphanumerics
        let components = string.unicodeScalars.filter { allowed.contains($0) }
        let result = String(String.UnicodeScalarView(components))
        return result.isEmpty ? "Unknown" : result
    }

    /// Load from URL
    convenience init?(contentsOf url: URL) {
        guard let library = MCCursorLibrary(contentsOf: url) else {
            return nil
        }
        self.init(objcLibrary: library)
    }

    /// Initialize from dictionary (for .cape file deserialization)
    /// - Parameter dictionary: Dictionary containing cape data
    /// - Returns: nil if dictionary is invalid or version is unsupported
    convenience init?(dictionary: [String: Any]) {
        // Extract version information
        guard let minimumVersion = dictionary["MinimumVersion"] as? NSNumber,
              let version = dictionary["Version"] as? NSNumber else {
            return nil
        }

        // Check minimum version compatibility
        let parserVersion: CGFloat = 2.0  // MCCursorParserVersion
        if minimumVersion.doubleValue > parserVersion {
            return nil
        }

        // Extract metadata
        guard let capeName = dictionary["CapeName"] as? String,
              let author = dictionary["Author"] as? String,
              let identifier = dictionary["Identifier"] as? String,
              let capeVersion = dictionary["CapeVersion"] as? NSNumber,
              let cursorsDict = dictionary["Cursors"] as? [String: [String: Any]] else {
            return nil
        }

        // Create empty library
        let library = MCCursorLibrary(cursors: Set())
        library.name = capeName
        library.author = author
        library.identifier = identifier
        library.version = capeVersion

        // Optional metadata
        if let hiDPI = dictionary["HiDPI"] as? NSNumber {
            library.isHiDPI = hiDPI.boolValue
        }
        if let cloud = dictionary["Cloud"] as? NSNumber {
            library.isInCloud = cloud.boolValue
        }

        // Parse cursors
        let doubleVersion = version.doubleValue
        for (cursorIdentifier, cursorDict) in cursorsDict {
            guard let cursor = Cursor(dictionary: cursorDict, version: doubleVersion) else {
                continue
            }
            cursor.identifier = cursorIdentifier
            library.addCursor(cursor.underlyingCursor)
        }

        self.init(objcLibrary: library)
    }

    // MARK: - ObjC Bridge

    /// Get the underlying ObjC library object
    var underlyingLibrary: MCCursorLibrary {
        objcLibrary
    }

    // MARK: - Hashable & Equatable

    static func == (lhs: CursorLibrary, rhs: CursorLibrary) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - CursorLibrary Preview Helper

extension CursorLibrary {
    /// Get a summary string for display
    var summary: String {
        let count = cursorCount
        return count == 1 ? "1 cursor" : "\(count) cursors"
    }

    /// Check if this is likely a complete cape (has standard cursors)
    var isComplete: Bool {
        let standardCursors = ["Arrow", "IBeam", "Wait", "PointingHand", "OpenHand", "ClosedHand"]
        let identifiers = Set(cursors.map { $0.identifier })
        return standardCursors.allSatisfy { standard in
            identifiers.contains { $0.contains(standard) }
        }
    }
}

// MARK: - Serialization

extension CursorLibrary {
    /// Convert library to dictionary representation (for .cape file serialization)
    /// - Returns: Dictionary compatible with ObjC MCCursorLibrary format
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]

        // Version information
        dict["MinimumVersion"] = NSNumber(value: 2.0)
        dict["Version"] = NSNumber(value: 2.0)

        // Metadata
        dict["CapeName"] = name
        dict["CapeVersion"] = NSNumber(value: version)
        dict["Cloud"] = NSNumber(value: isInCloud)
        dict["Author"] = author
        dict["HiDPI"] = NSNumber(value: isHiDPI)
        dict["Identifier"] = identifier

        // Cursors dictionary
        var cursorsDict: [String: [String: Any]] = [:]
        for cursor in cursors {
            cursorsDict[cursor.identifier] = cursor.toDictionary()
        }
        dict["Cursors"] = cursorsDict

        return dict
    }

    /// Write library to file as binary plist
    /// - Parameter url: Target file URL
    /// - Throws: Error if write fails
    func write(to url: URL) throws {
        let dict = toDictionary() as NSDictionary
        let success = dict.write(to: url, atomically: true)
        if !success {
            throw NSError(
                domain: "com.sdmj76.mousecape.error",
                code: -2,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to save cape",
                    NSLocalizedFailureReasonErrorKey: "Could not write to file"
                ]
            )
        }
    }
}

// MARK: - Validation

extension CursorLibrary {
    /// Validation error types
    enum ValidationError: LocalizedError {
        case frameCountExceeded(cursorName: String, count: Int, max: Int)
        case hotspotOutOfBounds(cursorName: String, details: String)
        case imageTooLarge(cursorName: String, width: Int, height: Int, max: Int)
        case multipleErrors(errors: [ValidationError])

        var errorDescription: String? {
            switch self {
            case .frameCountExceeded(let name, let count, let max):
                return "Frame count exceeded for \(name): \(count) frames (max: \(max))"
            case .hotspotOutOfBounds(let name, let details):
                return "Hotspot out of bounds for \(name): \(details)"
            case .imageTooLarge(let name, let width, let height, let max):
                return "Image too large for \(name): \(width)×\(height) (max: \(max)×\(max))"
            case .multipleErrors(let errors):
                let messages = errors.map { $0.errorDescription ?? "Unknown error" }
                return "Multiple validation errors:\n" + messages.joined(separator: "\n")
            }
        }
    }

    /// Validate the cape for system compatibility
    /// - Throws: ValidationError if validation fails
    func validate() throws {
        let maxFrameCount = 24  // MCMaxFrameCount
        let maxHotspotValue: CGFloat = 31.99  // MCMaxHotspotValue
        let maxImportSize = 512  // MCMaxImportSize

        var errors: [ValidationError] = []

        for cursor in cursors {
            let cursorName = cursor.displayName

            // Check frame count
            if cursor.frameCount > maxFrameCount {
                errors.append(.frameCountExceeded(
                    cursorName: cursorName,
                    count: cursor.frameCount,
                    max: maxFrameCount
                ))
            }

            // Check hotspot bounds
            var hotspotDetails: [String] = []
            if cursor.hotSpot.x < 0 {
                hotspotDetails.append("X is negative (\(cursor.hotSpot.x))")
            } else if cursor.hotSpot.x > maxHotspotValue {
                hotspotDetails.append("X exceeds maximum (\(cursor.hotSpot.x) > \(maxHotspotValue))")
            }

            if cursor.hotSpot.y < 0 {
                hotspotDetails.append("Y is negative (\(cursor.hotSpot.y))")
            } else if cursor.hotSpot.y > maxHotspotValue {
                hotspotDetails.append("Y exceeds maximum (\(cursor.hotSpot.y) > \(maxHotspotValue))")
            }

            if !hotspotDetails.isEmpty {
                errors.append(.hotspotOutOfBounds(
                    cursorName: cursorName,
                    details: hotspotDetails.joined(separator: ", ")
                ))
            }

            // Check image size (check all representations)
            for scale in CursorScale.allCases {
                if let rep = cursor.representation(for: scale) {
                    let width = rep.pixelsWide
                    let height = rep.pixelsHigh / cursor.frameCount  // Per-frame height
                    if width > maxImportSize || height > maxImportSize {
                        errors.append(.imageTooLarge(
                            cursorName: cursorName,
                            width: width,
                            height: height,
                            max: maxImportSize
                        ))
                        break  // Only report once per cursor
                    }
                }
            }
        }

        if !errors.isEmpty {
            if errors.count == 1 {
                throw errors[0]
            } else {
                throw ValidationError.multipleErrors(errors: errors)
            }
        }
    }
}

// MARK: - Change Tracking

extension CursorLibrary {
    /// Document change type
    enum ChangeType {
        case done
        case undone
        case redone
        case cleared
    }

    /// Current change count
    var changeCount: Int {
        (objcLibrary.value(forKey: "changeCount") as? NSNumber)?.intValue ?? 0
    }

    /// Last saved change count
    var lastChangeCount: Int {
        (objcLibrary.value(forKey: "lastChangeCount") as? NSNumber)?.intValue ?? 0
    }

    /// Update change count
    /// - Parameter type: Type of change
    func updateChangeCount(_ type: ChangeType) {
        let nsType: NSDocument.ChangeType
        switch type {
        case .done:
            nsType = .changeDone
        case .undone:
            nsType = .changeUndone
        case .redone:
            nsType = .changeRedone
        case .cleared:
            nsType = .changeCleared
        }
        objcLibrary.updateChangeCount(nsType)
    }
}
