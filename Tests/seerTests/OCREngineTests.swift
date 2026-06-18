import Testing
@testable import seer

struct OCREngineTests {
    @Test
    func recognizesGeneratedImageText() async throws {
        let image = try FixtureFactory.makeTextImage("HELLO SEER 12345")
        let lines = try await OCREngine().recognize(image: image, options: RecognitionOptions())
        let text = lines.map(\.text).joined(separator: " ").uppercased()

        #expect(text.contains("HELLO"))
        #expect(text.contains("SEER"))
        #expect(text.contains("12345"))
    }
}
