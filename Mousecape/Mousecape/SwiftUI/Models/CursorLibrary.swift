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
