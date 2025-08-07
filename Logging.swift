import Foundation
import os

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "IntraHabits"
    private static let logger = Logger(subsystem: subsystem, category: "general")

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    static func fault(_ message: String) {
        logger.fault("\(message, privacy: .public)")
    }
}

/// Non-fatal assertion utility to surface unrecoverable conditions during development
/// while allowing the app to continue running in production builds.
@inline(__always)
func nonFatalAssert(_ condition: @autoclosure () -> Bool, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
    #if DEBUG
    if !condition() {
        assertionFailure(message, file: file, line: line)
    }
    #else
    if !condition() {
        AppLogger.fault("Assertion failed: \(message)")
    }
    #endif
}
