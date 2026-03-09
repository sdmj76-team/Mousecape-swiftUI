//
//  WindowsINFParser.swift
//  Mousecape
//
//  Parses Windows cursor install.inf files to extract cursor mappings.
//  Uses [Scheme.Reg] position-based mapping for reliable cursor type detection.
//

import Foundation
import CoreFoundation

/// Represents a parsed install.inf file with cursor mappings
struct WindowsINFMapping {
    /// Mapping from position index (0-16) to filename
    let cursorFilesByPosition: [Int: String]

    /// Scheme name from the INF
    let schemeName: String?

    /// Cursor directory from the INF
    let cursorDir: String?
}

/// INF parsing error with detailed reason
enum INFParseError: Error, LocalizedError {
    case fileNotFound(String)
    case encodingError(String)
    case noSchemeRegSection
    case noCursorPaths
    case noValidCursors

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "INF file not found: \(path)"
        case .encodingError(let path):
            return "Failed to read INF file (encoding error): \(path)"
        case .noSchemeRegSection:
            return "No [Scheme.Reg] section found in INF file"
        case .noCursorPaths:
            return "No cursor paths found in [Scheme.Reg]"
        case .noValidCursors:
            return "No valid cursor filenames could be resolved"
        }
    }

    /// Localized description for display in UI
    var localizedUIDescription: String {
        switch self {
        case .fileNotFound(let path):
            return "\(String(localized: "inf.error.noValidInf")) \(path)"
        case .encodingError(let path):
            return "\(String(localized: "inf.error.encodingFailed")) \(path)"
        case .noSchemeRegSection:
            return String(localized: "inf.error.noSchemeReg")
        case .noCursorPaths:
            return String(localized: "inf.error.noCursorPaths")
        case .noValidCursors:
            return String(localized: "inf.error.noValidFilenames")
        }
    }
}

/// Parser for Windows cursor install.inf files
struct WindowsINFParser {

    /// Windows registry fixed-order cursor type mapping (positions 0-16)
    /// Based on Windows Control Panel\Cursors\Schemes registry format
    static let schemeRegPositionMapping: [[CursorType]] = [
        [.arrow, .arrowCtx, .arrowS, .ctxMenu],                          // 0: Normal Select
        [.help],                                                           // 1: Help Select
        [.wait],                                                           // 2: Working in Background
        [.busy, .countingUp, .countingDown, .countingUpDown],             // 3: Busy
        [.crosshair, .crosshair2, .cell, .cellXOR],                      // 4: Precision Select
        [.iBeam, .iBeamXOR, .iBeamS, .iBeamH],                          // 5: Text Select
        [.open, .closed],                                                  // 6: Handwriting
        [.forbidden],                                                      // 7: Unavailable
        [.resizeNS, .windowNS, .resizeN, .resizeS, .windowN, .windowS], // 8: Vertical Resize
        [.resizeWE, .windowEW, .resizeW, .resizeE, .windowE, .windowW], // 9: Horizontal Resize
        [.windowNWSE, .windowNW, .windowSE],                              // 10: Diagonal Resize 1 (NW-SE)
        [.windowNESW, .windowNE, .windowSW],                              // 11: Diagonal Resize 2 (NE-SW)
        [.move, .resizeSquare],                                            // 12: Move
        [.alias],                                                          // 13: Alternate Select
        [.pointing, .link],                                                // 14: Link Select
        [],                                                                // 15: Location Select (no macOS equivalent)
        [],                                                                // 16: Person Select (no macOS equivalent)
    ]

    /// Parse an install.inf file
    /// - Parameter url: URL to the .inf file
    /// - Returns: Result with parsed INF mapping or error reason
    static func parse(url: URL) -> Result<WindowsINFMapping, INFParseError> {
        debugLog("=== Parsing Windows INF ===")
        debugLog("File: \(url.lastPathComponent)")

        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            debugLog("Error: INF file not found")
            return .failure(.fileNotFound(url.lastPathComponent))
        }

        // 针对中文 Windows 光标主题优化的编码检测顺序
        // 使用 CFStringConvertEncodingToNSStringEncoding 支持 Swift 原生不支持的编码
        guard let data = try? Data(contentsOf: url) else {
            debugLog("Error: Failed to read INF file (I/O error)")
            return .failure(.encodingError(url.lastPathComponent))
        }

        let encodings: [(CFStringEncoding, String)] = [
            (0x08000100, "UTF-8"),              // kCFStringEncodingUTF8
            (0x0C000101, "UTF-16 LE"),          // kCFStringEncodingUTF16LE
            (0x0C000102, "UTF-16 BE"),          // kCFStringEncodingUTF16BE
            (0x0631, "GBK"),                    // kCFStringEncodingGBK_95 (corrected: was 0x0636)
            (0x01000931, "GB18030"),            // kCFStringEncodingGB_18030_2000
            (0x0A03, "Big5"),                  // kCFStringEncodingBig5
            (0x0621, "Shift_JIS"),             // kCFStringEncodingShiftJIS
            (0x0628, "EUC-KR"),                // kCFStringEncodingEUC_KR
            (0x0201, "ISO-8859-1"),            // kCFStringEncodingISOLatin1
        ]

        for (cfEncoding, name) in encodings {
            // 尝试使用 CFString 解码（支持非 Unicode 编码如 GBK）
            var content: String?

            data.withUnsafeBytes { bytes in
                guard let baseAddress = bytes.baseAddress else { return }

                if let cfString = CFStringCreateWithBytes(
                    kCFAllocatorDefault,
                    baseAddress.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    cfEncoding,
                    false
                ) {
                    content = cfString as String
                }
            }

            if let validContent = content {
                debugLog("Trying \(name): decoded \(validContent.count) chars")
                // 验证解码质量
                if isValidDecodedContent(validContent) {
                    debugLog("✓ Read INF with \(name) encoding (\(data.count) bytes)")
                    return parseContent(validContent)
                }
                debugLog("✗ \(name) failed validation, trying next encoding...")
            } else {
                debugLog("✗ \(name) failed to decode (CFStringCreateWithBytes returned nil)")
            }
        }

        debugLog("Error: Failed to decode INF file (tried: \(encodings.map { $0.1 }.joined(separator: ", ")))")
        return .failure(.encodingError(url.lastPathComponent))
    }

    /// Parse INF content string
    private static func parseContent(_ content: String) -> Result<WindowsINFMapping, INFParseError> {
        debugLog("Parsing INF content (\(content.count) chars)")

        let lines = content.components(separatedBy: .newlines)

        // Step 1: Parse [Scheme.Reg] section to get cursor paths
        guard let schemeRegLine = findSchemeRegLine(lines) else {
            debugLog("Error: No [Scheme.Reg] section found")
            return .failure(.noSchemeRegSection)
        }

        // Step 2: Extract cursor paths from Scheme.Reg
        let cursorPaths = extractCursorPaths(from: schemeRegLine)
        guard !cursorPaths.isEmpty else {
            debugLog("Error: No cursor paths found in [Scheme.Reg]")
            return .failure(.noCursorPaths)
        }

        // Step 3: Parse [Strings] section (optional, for variable resolution)
        let strings = parseStringsSection(lines)

        // Step 4: Build position-to-filename mapping
        var cursorFilesByPosition: [Int: String] = [:]
        for (position, path) in cursorPaths.enumerated() {
            if let filename = resolveFilename(from: path, strings: strings) {
                cursorFilesByPosition[position] = filename
            }
            // Skip invalid paths silently
        }

        guard !cursorFilesByPosition.isEmpty else {
            debugLog("Error: No valid cursor filenames could be resolved")
            return .failure(.noValidCursors)
        }

        debugLog("INF parse result: \(cursorFilesByPosition.count) cursor mappings")
        for (position, filename) in cursorFilesByPosition.sorted(by: { $0.key < $1.key }) {
            debugLog("  Position \(position) -> \(filename)")
        }
        if let scheme = strings["scheme_name"] {
            debugLog("Scheme name: \(scheme)")
        }

        return .success(WindowsINFMapping(
            cursorFilesByPosition: cursorFilesByPosition,
            schemeName: strings["scheme_name"],
            cursorDir: strings["cur_dir"]
        ))
    }

    /// Find the HKCU,"Control Panel\Cursors\Schemes" line in [Scheme.Reg] section
    private static func findSchemeRegLine(_ lines: [String]) -> String? {
        var inSchemeRegSection = false

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Check for section headers
            if trimmedLine.hasPrefix("[") && trimmedLine.hasSuffix("]") {
                inSchemeRegSection = trimmedLine.lowercased() == "[scheme.reg]"
                continue
            }

            // Look for the Cursors\Schemes line
            if inSchemeRegSection && !trimmedLine.isEmpty && !trimmedLine.hasPrefix(";") {
                let lowercased = trimmedLine.lowercased()
                if lowercased.contains("control panel\\cursors\\schemes") ||
                   lowercased.contains("control panel\\\\cursors\\\\schemes") {
                    return trimmedLine
                }
            }
        }

        return nil
    }

    /// Extract cursor paths from Scheme.Reg line
    /// Input: HKCU,"Control Panel\Cursors\Schemes","%SCHEME_NAME%",,"%10%\%CUR_DIR%\%pointer%,%10%\%CUR_DIR%\Normal.ani,..."
    /// Output: ["%10%\%CUR_DIR%\%pointer%", "%10%\%CUR_DIR%\Normal.ani", ...]
    private static func extractCursorPaths(from schemeRegLine: String) -> [String] {
        // Split by ",," to find the cursor list part (after the empty field)
        let parts = schemeRegLine.components(separatedBy: ",,")
        guard parts.count >= 2 else { return [] }

        // Get the cursor list part (everything after ",,")
        let cursorListPart = parts.dropFirst().joined(separator: ",,")

        // Remove surrounding quotes if present
        var cursorList = cursorListPart.trimmingCharacters(in: .whitespaces)
        if cursorList.hasPrefix("\"") && cursorList.hasSuffix("\"") && cursorList.count >= 2 {
            cursorList = String(cursorList.dropFirst().dropLast())
        }

        // Split by comma to get individual cursor paths
        return cursorList.components(separatedBy: ",")
    }

    /// Resolve filename from a cursor path
    /// - If path ends with %variable%, look up in strings
    /// - If path ends with filename.ext, use directly
    private static func resolveFilename(from path: String, strings: [String: String]) -> String? {
        let trimmedPath = path.trimmingCharacters(in: .whitespaces)
        guard !trimmedPath.isEmpty else { return nil }

        // Get the last component (after last \ or /)
        let lastComponent: String
        if let lastBackslash = trimmedPath.lastIndex(of: "\\") {
            lastComponent = String(trimmedPath[trimmedPath.index(after: lastBackslash)...])
        } else if let lastSlash = trimmedPath.lastIndex(of: "/") {
            lastComponent = String(trimmedPath[trimmedPath.index(after: lastSlash)...])
        } else {
            lastComponent = trimmedPath
        }

        // Check if it's a variable reference like %pointer%
        if lastComponent.hasPrefix("%") && lastComponent.hasSuffix("%") && lastComponent.count > 2 {
            // Extract variable name and look up in strings
            let varName = String(lastComponent.dropFirst().dropLast()).lowercased()
            return strings[varName]
        }

        // Otherwise, it's a direct filename - just clean it up
        let filename = lastComponent
        // Remove any remaining % markers that might be path variables
        if filename.contains("%") {
            return nil // Invalid format
        }
        return filename.isEmpty ? nil : filename
    }

    /// Parse [Strings] section to get all variable definitions (optional)
    private static func parseStringsSection(_ lines: [String]) -> [String: String] {
        var strings: [String: String] = [:]
        var inStringsSection = false

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Check for section headers
            if trimmedLine.hasPrefix("[") && trimmedLine.hasSuffix("]") {
                inStringsSection = trimmedLine.lowercased() == "[strings]"
                continue
            }

            // Parse lines in [Strings] section
            if inStringsSection && !trimmedLine.isEmpty && !trimmedLine.hasPrefix(";") {
                if let (key, value) = parseKeyValue(trimmedLine) {
                    strings[key.lowercased()] = value
                }
            }
        }

        return strings
    }

    /// Parse a key = value line
    private static func parseKeyValue(_ line: String) -> (key: String, value: String)? {
        // Split on first = sign
        guard let equalsIndex = line.firstIndex(of: "=") else { return nil }

        let key = String(line[..<equalsIndex]).trimmingCharacters(in: .whitespaces)
        var value = String(line[line.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)

        // Remove quotes
        if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
            value = String(value.dropFirst().dropLast())
        }

        guard !key.isEmpty && !value.isEmpty else { return nil }

        return (key, value)
    }

    /// 验证解码后的内容是否有效
    /// - Parameter content: 解码后的 INF 文件内容
    /// - Returns: 如果内容有效返回 true，否则返回 false
    private static func isValidDecodedContent(_ content: String) -> Bool {
        // 1. 检查替换字符（说明解码失败）
        if content.contains("�") {
            return false
        }

        // 2. 检查控制字符比例（除 \r\n\t 外）
        let controlChars = content.unicodeScalars.filter {
            CharacterCategory($0.value) == .control &&
            $0.value != 13 && $0.value != 10 && $0.value != 9
        }
        if controlChars.count > content.count / 4 {
            return false  // 超过25%是控制字符，说明解码错误
        }

        // 3. 验证包含必需的 [Scheme.Reg] 段
        guard content.contains("[Scheme.Reg]") || content.contains("[scheme.reg]") else {
            return false
        }

        // 4. 检查中文字符（使用 Unicode 范围）
        let hasChineseChars = content.unicodeScalars.contains {
            $0.value >= 0x4E00 && $0.value <= 0x9FFF  // CJK 统一汉字
        }

        // 5. 对于 ISO-8859-1 编码，检查是否有大量高位字节字符（0x80-0xFF）
        // 这些通常是多字节编码（如 GBK）的误解析
        let highByteChars = content.unicodeScalars.filter {
            $0.value >= 0x80 && $0.value <= 0xFF  // Latin-1 补充范围
        }

        debugLog("  Validation: chinese=\(hasChineseChars), highByte=\(highByteChars.count)/\(content.count) (\(highByteChars.count * 100 / content.count)%)")

        // 如果有大量高位字节字符（>10%）且没有中文字符，可能是错误的编码
        if highByteChars.count > content.count / 10 && !hasChineseChars {
            return false  // 可能是 GBK 等多字节编码被错误解析为 ISO-8859-1
        }

        // 如果包含中文，说明可能是正确的中文字符集
        // 如果不包含中文，也可能是纯英文 INF 文件

        return true
    }

    /// Character category helper for validation
    private enum CharacterCategory {
        case control
        case other

        init(_ unicodeValue: UInt32) {
            // Control characters are in the range 0-31 and 127
            if (unicodeValue <= 31 || unicodeValue == 127) {
                self = .control
            } else {
                self = .other
            }
        }
    }

    /// Get macOS cursor types for a position index
    /// - Parameter position: Position index (0-16) from Scheme.Reg
    /// - Returns: Array of matching CursorType
    static func cursorTypes(forPosition position: Int) -> [CursorType] {
        guard position >= 0 && position < schemeRegPositionMapping.count else {
            return []
        }
        return schemeRegPositionMapping[position]
    }

    /// Find and parse a valid INF file in a folder
    /// Searches for all *.inf files and returns the first one with valid [Scheme.Reg]
    /// - Parameter folderURL: Folder to search in
    /// - Returns: Result with parsed INF mapping or last error encountered
    static func findValidINF(in folderURL: URL) -> Result<WindowsINFMapping, INFParseError> {
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return .failure(.fileNotFound(folderURL.lastPathComponent))
        }

        // Find all .inf files
        let infFiles = contents.filter { $0.pathExtension.lowercased() == "inf" }

        guard !infFiles.isEmpty else {
            return .failure(.fileNotFound("*.inf"))
        }

        // Try each INF file until we find a valid one
        var lastError: INFParseError = .noSchemeRegSection
        for infURL in infFiles {
            switch parse(url: infURL) {
            case .success(let mapping):
                return .success(mapping)
            case .failure(let error):
                lastError = error
            }
        }

        return .failure(lastError)
    }
}
