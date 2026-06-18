import Foundation

enum OutputFormatter {
    static func render(_ results: [SourceOCRResult], format: OutputFormat) throws -> String {
        switch format {
        case .text:
            return results
                .map { source in
                    source.pages
                        .flatMap(\.lines)
                        .map(\.text)
                        .joined(separator: "\n")
                }
                .joined(separator: "\n\n")
        case .markdown:
            return results
                .map { source in
                    var chunks = ["## \(source.source)"]
                    let includePageHeaders = source.pages.count > 1
                    for page in source.pages {
                        if includePageHeaders {
                            chunks.append("### Page \(page.page)")
                        }
                        chunks.append(page.lines.map(\.text).joined(separator: "\n"))
                    }
                    return chunks.joined(separator: "\n\n")
                }
                .joined(separator: "\n\n")
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(results)
            guard let output = String(data: data, encoding: .utf8) else {
                throw CLIError(message: "Failed to encode output as UTF-8")
            }
            return output
        }
    }
}
