//
//  UserPreferences.swift
//  Mousecape
//
//  User preferences management using CFPreferences API
//  Compatible with mousecloak CLI preferences
//

import Foundation

/// User preferences manager for Mousecape
/// Uses CFPreferences to maintain compatibility with mousecloak CLI tool
final class UserPreferences {
    @MainActor static let shared = UserPreferences()

    // MARK: - Constants

    private let domain = "com.sdmj76.Mousecape" as CFString

    /// Preference keys
    struct Keys {
        static let appliedCursor = "MCAppliedCursor"
        static let cursorScale = "MCCursorScale"
        static let handedness = "MCHandedness"
    }

    private init() {}

    // MARK: - Read Preferences

    /// Get a preference value for current user and host
    func getValue(forKey key: String) -> Any? {
        let value = CFPreferencesCopyValue(
            key as CFString,
            domain,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )

        #if DEBUG
        if let value = value {
            debugLog("UserPreferences.getValue: key=\(key), value=\(value)")
        } else {
            debugLog("UserPreferences.getValue: key=\(key), value=(null)")
        }
        #endif

        return value as? Any
    }

    /// Get a preference value from app-wide preferences
    func getAppValue(forKey key: String) -> Any? {
        let value = CFPreferencesCopyAppValue(key as CFString, domain)

        #if DEBUG
        if let value = value {
            debugLog("UserPreferences.getAppValue: key=\(key), value=\(value)")
        } else {
            debugLog("UserPreferences.getAppValue: key=\(key), value=(null)")
        }
        #endif

        return value as? Any
    }

    /// Get a string preference
    func getString(forKey key: String) -> String? {
        return getValue(forKey: key) as? String
    }

    /// Get a boolean preference
    func getBool(forKey key: String) -> Bool {
        return (getValue(forKey: key) as? Bool) ?? false
    }

    /// Get a double preference
    func getDouble(forKey key: String) -> Double? {
        return getValue(forKey: key) as? Double
    }

    // MARK: - Write Preferences

    /// Set a preference value for current user and host
    func setValue(_ value: Any?, forKey key: String) {
        #if DEBUG
        if let value = value {
            debugLog("UserPreferences.setValue: key=\(key), value=\(value)")
        } else {
            debugLog("UserPreferences.setValue: key=\(key), value=(null)")
        }
        #endif

        CFPreferencesSetValue(
            key as CFString,
            value as CFPropertyList?,
            domain,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
    }

    /// Synchronize preferences to disk
    func synchronize() -> Bool {
        return CFPreferencesSynchronize(
            domain,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
    }

    // MARK: - Convenience Methods for Mousecape Preferences

    /// Get the currently applied cursor identifier
    var appliedCursor: String? {
        get { getString(forKey: Keys.appliedCursor) }
        set { setValue(newValue, forKey: Keys.appliedCursor) }
    }

    /// Get the cursor scale factor
    var cursorScale: Double? {
        get { getDouble(forKey: Keys.cursorScale) }
        set { setValue(newValue, forKey: Keys.cursorScale) }
    }

    /// Get the handedness setting
    var handedness: String? {
        get { getString(forKey: Keys.handedness) }
        set { setValue(newValue, forKey: Keys.handedness) }
    }
}

// MARK: - Objective-C Bridge Functions

/// Bridge function for Objective-C compatibility
/// Get a preference value (equivalent to MCDefault)
@_cdecl("SwiftGetPreference")
public func SwiftGetPreference(_ key: UnsafePointer<CChar>) -> Unmanaged<AnyObject>? {
    let keyString = String(cString: key)
    guard let value = UserPreferences.shared.getValue(forKey: keyString) else {
        return nil
    }
    return Unmanaged.passRetained(value as AnyObject)
}

/// Bridge function for Objective-C compatibility
/// Set a preference value (equivalent to MCSetDefault)
@_cdecl("SwiftSetPreference")
public func SwiftSetPreference(_ value: UnsafeRawPointer?, _ key: UnsafePointer<CChar>) {
    let keyString = String(cString: key)
    if let value = value {
        let objcValue = Unmanaged<AnyObject>.fromOpaque(value).takeUnretainedValue()
        UserPreferences.shared.setValue(objcValue, forKey: keyString)
    } else {
        UserPreferences.shared.setValue(nil, forKey: keyString)
    }
}

