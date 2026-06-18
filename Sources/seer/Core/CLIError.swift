import Foundation

struct CLIError: LocalizedError, Sendable {
    let message: String

    var errorDescription: String? { message }
}

struct TimeoutError: LocalizedError, Sendable {
    let seconds: Double

    var errorDescription: String? {
        "Timed out after \(seconds) seconds"
    }
}
