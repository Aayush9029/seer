import ArgumentParser
import Testing
@testable import seer

struct ArgumentParsingTests {
    @Test
    func parsesFormatAndRecognitionOptions() throws {
        let command = try SeerCLI.parse([
            "--format", "json",
            "--languages", "en-US,ja-JP",
            "--no-correction",
            "--min-confidence", "0.45",
            "--custom-words", "Seer,OCR",
            "--recursive",
            "fixtures",
        ])

        #expect(command.format == .json)
        #expect(command.languages == "en-US,ja-JP")
        #expect(command.noCorrection)
        #expect(command.minConfidence == 0.45)
        #expect(command.customWords == "Seer,OCR")
        #expect(command.recursive)
        #expect(command.paths == ["fixtures"])
    }

    @Test
    func rejectsInvalidConfidence() throws {
        #expect(throws: (any Error).self) {
            _ = try SeerCLI.parse(["--min-confidence", "2", "image.png"])
        }
    }
}
