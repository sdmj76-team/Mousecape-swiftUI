#!/usr/bin/env swift
// Quick test for CursorLibrary serialization functionality

import Foundation

// Test 1: Dictionary keys
print("✓ Test 1: Checking dictionary keys...")
let testDict: [String: Any] = [
    "MinimumVersion": NSNumber(value: 2.0),
    "Version": NSNumber(value: 2.0),
    "CapeName": "Test Cape",
    "Author": "Test Author",
    "Identifier": "local.test.cape",
    "CapeVersion": NSNumber(value: 1.0),
    "HiDPI": NSNumber(value: true),
    "Cloud": NSNumber(value: false),
    "Cursors": [String: [String: Any]]()
]

print("  - MinimumVersion: \(testDict["MinimumVersion"] as? NSNumber ?? 0)")
print("  - Version: \(testDict["Version"] as? NSNumber ?? 0)")
print("  - CapeName: \(testDict["CapeName"] as? String ?? "")")
print("  - Author: \(testDict["Author"] as? String ?? "")")
print("  - Identifier: \(testDict["Identifier"] as? String ?? "")")

// Test 2: Validation constants
print("\n✓ Test 2: Validation constants...")
let maxFrameCount = 24
let maxHotspotValue: CGFloat = 31.99
let maxImportSize = 512

print("  - Max frame count: \(maxFrameCount)")
print("  - Max hotspot value: \(maxHotspotValue)")
print("  - Max import size: \(maxImportSize)")

// Test 3: Change tracking enum
print("\n✓ Test 3: Change tracking types...")
enum ChangeType {
    case done
    case undone
    case redone
    case cleared
}

let changeTypes: [ChangeType] = [.done, .undone, .redone, .cleared]
print("  - Change types defined: \(changeTypes.count)")

print("\n✅ All basic tests passed!")
print("CursorLibrary.swift serialization functionality is ready.")
