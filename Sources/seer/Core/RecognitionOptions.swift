import Foundation

struct RecognitionOptions: Sendable {
    var languages: [String] = []
    var usesLanguageCorrection = true
    var minimumConfidence: Float = 0
    var customWords: [String] = []

    var automaticallyDetectsLanguage: Bool {
        languages.isEmpty
    }
}
