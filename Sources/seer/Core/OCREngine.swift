import CoreGraphics
import Foundation
import Vision

struct OCREngine: Sendable {
    func recognize(image: CGImage, options: RecognitionOptions) async throws -> [RecognizedLine] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = options.usesLanguageCorrection
        request.automaticallyDetectsLanguage = options.automaticallyDetectsLanguage
        request.recognitionLanguages = options.languages.map { Locale.Language(identifier: $0) }
        request.customWords = options.customWords

        let observations = try await request.perform(on: image)
        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else {
                return nil
            }
            guard candidate.confidence >= options.minimumConfidence else {
                return nil
            }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return nil
            }

            return RecognizedLine(
                text: text,
                confidence: candidate.confidence,
                boundingBox: boundingBox(for: observation),
                detectedLanguage: detectedLanguage(for: observation)
            )
        }
    }

    private func boundingBox(for observation: RecognizedTextObservation) -> BoundingBox {
        let xs = [
            observation.topLeft.x,
            observation.topRight.x,
            observation.bottomRight.x,
            observation.bottomLeft.x,
        ]
        let ys = [
            observation.topLeft.y,
            observation.topRight.y,
            observation.bottomRight.y,
            observation.bottomLeft.y,
        ]
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0
        return BoundingBox(
            x: Double(minX),
            y: Double(minY),
            width: Double(maxX - minX),
            height: Double(maxY - minY)
        )
    }

    private func detectedLanguage(for observation: RecognizedTextObservation) -> String? {
        if #available(macOS 26.0, *) {
            return observation.recognitionLanguages.first?.minimalIdentifier
        }
        return nil
    }
}
