//
//  HelperDebugLog.swift
//  MousecapeHelper
//
//  Simple debug logging wrapper for MousecapeHelper
//

import Foundation

/// Debug logging function for MousecapeHelper
/// Only logs in DEBUG builds
func debugLog(_ message: String) {
    #if DEBUG
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    let logMessage = "[\(timestamp)] [MousecapeHelper] \(message)"
    HelperLog(logMessage)
    #endif
}
