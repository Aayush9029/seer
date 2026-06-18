import Foundation
import Testing
@testable import seer

struct OutputFormatterTests {
    @Test
    func rendersJSONShape() throws {
        let results = [
            SourceOCRResult(
                source: "fixture.png",
                pages: [
                    PageOCRResult(
                        page: 1,
                        lines: [
                            RecognizedLine(
                                text: "HELLO SEER",
                                confidence: 0.98,
                                boundingBox: BoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
                                detectedLanguage: "en"
                            ),
                        ]
                    ),
                ]
            ),
        ]

        let output = try OutputFormatter.render(results, format: .json)
        let data = try #require(output.data(using: .utf8))
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        let source = try #require(json?.first)
        let pages = try #require(source["pages"] as? [[String: Any]])
        let page = try #require(pages.first)
        let lines = try #require(page["lines"] as? [[String: Any]])
        let line = try #require(lines.first)
        let box = try #require(line["boundingBox"] as? [String: Any])

        #expect(source["source"] as? String == "fixture.png")
        #expect(page["page"] as? Int == 1)
        #expect(line["text"] as? String == "HELLO SEER")
        #expect(line["detectedLanguage"] as? String == "en")
        #expect(box["width"] as? Double == 0.3)
    }

    @Test
    func rendersMarkdownWithPageHeadersForPDFs() throws {
        let results = [
            SourceOCRResult(
                source: "doc.pdf",
                pages: [
                    PageOCRResult(page: 1, lines: [RecognizedLine(text: "ONE", confidence: 1, boundingBox: BoundingBox(x: 0, y: 0, width: 1, height: 1), detectedLanguage: nil)]),
                    PageOCRResult(page: 2, lines: [RecognizedLine(text: "TWO", confidence: 1, boundingBox: BoundingBox(x: 0, y: 0, width: 1, height: 1), detectedLanguage: nil)]),
                ]
            ),
        ]

        let output = try OutputFormatter.render(results, format: .markdown)

        #expect(output.contains("## doc.pdf"))
        #expect(output.contains("### Page 1"))
        #expect(output.contains("### Page 2"))
        #expect(output.contains("ONE"))
        #expect(output.contains("TWO"))
    }
}
