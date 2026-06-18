import Foundation

struct BoundingBox: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct RecognizedLine: Codable, Equatable, Sendable {
    let text: String
    let confidence: Float
    let boundingBox: BoundingBox
    let detectedLanguage: String?
}

struct PageOCRResult: Codable, Equatable, Sendable {
    let page: Int
    let lines: [RecognizedLine]
}

struct SourceOCRResult: Codable, Equatable, Sendable {
    let source: String
    let pages: [PageOCRResult]
}
