import ArgumentParser
import Foundation

enum RecognitionSpeed: String, CaseIterable, ExpressibleByArgument, Sendable {
    case accurate
    case fast
}

struct RecognitionOptions: Sendable {
    var speed: RecognitionSpeed = .accurate
    var languages: [String] = []
    var usesLanguageCorrection = true
    var minimumConfidence: Float = 0
    var customWords: [String] = []

    var automaticallyDetectsLanguage: Bool {
        languages.isEmpty
    }
}
