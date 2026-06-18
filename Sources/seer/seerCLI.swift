import ArgumentParser
import Darwin
import Foundation

@main
struct SeerCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "seer",
        abstract: "Extract text from images and PDFs using Apple Vision OCR.",
        version: AppVersion.current
    )

    @Argument(help: "Files, directories, or glob patterns to OCR. Reads image bytes from stdin when omitted.")
    var paths: [String] = []

    @Option(name: [.short, .long], help: "Write output to a file instead of stdout.")
    var output: String?

    @Option(name: [.short, .long], help: "Output format: text, markdown, or json.")
    var format: OutputFormat = .text

    @Option(help: "Comma or space separated BCP-47 language codes, such as en-US,ja-JP.")
    var languages: String?

    @Flag(help: "Disable Vision language correction.")
    var noCorrection = false

    @Option(help: "Drop lines below this confidence, from 0 to 1.")
    var minConfidence: Float = 0

    @Option(help: "Comma or space separated custom words to bias recognition.")
    var customWords: String?

    @Flag(name: [.short, .long], help: "Recurse into directories.")
    var recursive = false

    @Flag(name: [.short, .long], help: "Suppress warnings on stderr.")
    var quiet = false

    func validate() throws {
        guard (0...1).contains(minConfidence) else {
            throw ValidationError("--min-confidence must be between 0 and 1")
        }
    }

    mutating func run() async throws {
        let recognitionOptions = RecognitionOptions(
            languages: splitList(languages),
            usesLanguageCorrection: !noCorrection,
            minimumConfidence: minConfidence,
            customWords: splitList(customWords)
        )

        let resolution = try InputResolver().resolve(paths: paths, recursive: recursive)
        if !quiet {
            resolution.warnings.forEach { FileHandle.standardError.writeLine($0) }
        }

        guard !resolution.items.isEmpty else {
            throw CLIError(message: "No processable input files found")
        }

        let stdoutSuppression = try StdoutSuppression.redirectToDevNull()
        do {
            let outcomes = await processItems(resolution.items, options: recognitionOptions)
            var results = Array<SourceOCRResult?>(repeating: nil, count: resolution.items.count)
            var processedCount = 0

            for outcome in outcomes {
                switch outcome {
                case let .success(index, result):
                    results[index] = result
                    processedCount += 1
                case let .failure(_, warning):
                    if !quiet {
                        FileHandle.standardError.writeLine("warning: \(warning)")
                    }
                }
            }

            guard processedCount > 0 else {
                stdoutSuppression.restore()
                throw CLIError(message: "No input could be processed")
            }

            let rendered = try OutputFormatter.render(results.compactMap { $0 }, format: format)
            try writeOutput(rendered, standardOutputFileDescriptor: stdoutSuppression.originalFileDescriptor)
            stdoutSuppression.closeOriginal()
        } catch {
            stdoutSuppression.restore()
            throw error
        }
    }

    private func processItems(_ items: [WorkItem], options: RecognitionOptions) async -> [ProcessingOutcome] {
        let limit = max(1, min(ProcessInfo.processInfo.activeProcessorCount, items.count))
        let engine = OCREngine()

        return await withTaskGroup(of: ProcessingOutcome.self) { group in
            var nextIndex = 0
            var outcomes: [ProcessingOutcome] = []

            func submit(_ index: Int) {
                let item = items[index]
                group.addTask {
                    do {
                        let result = try await withTimeout(seconds: 60) {
                            try await process(item: item, engine: engine, options: options)
                        }
                        return .success(index: index, result: result)
                    } catch {
                        return .failure(index: index, warning: "\(item.source): \(error.localizedDescription)")
                    }
                }
            }

            while nextIndex < limit {
                submit(nextIndex)
                nextIndex += 1
            }

            while let outcome = await group.next() {
                outcomes.append(outcome)
                if nextIndex < items.count {
                    submit(nextIndex)
                    nextIndex += 1
                }
            }

            return outcomes
        }
    }

    private func process(item: WorkItem, engine: OCREngine, options: RecognitionOptions) async throws -> SourceOCRResult {
        switch item.kind {
        case .image:
            guard let url = item.url else {
                throw CLIError(message: "Missing file URL")
            }
            let image = try ImageLoader.load(url: url)
            let lines = try await engine.recognize(image: image, options: options)
            return SourceOCRResult(source: item.source, pages: [PageOCRResult(page: 1, lines: lines)])
        case .stdinImage:
            guard let data = item.data else {
                throw CLIError(message: "Missing stdin data")
            }
            let image = try ImageLoader.load(data: data)
            let lines = try await engine.recognize(image: image, options: options)
            return SourceOCRResult(source: item.source, pages: [PageOCRResult(page: 1, lines: lines)])
        case .pdf:
            guard let url = item.url else {
                throw CLIError(message: "Missing file URL")
            }
            let pages = try PDFRasterizer.rasterize(url: url)
            var pageResults: [PageOCRResult] = []
            for page in pages {
                let lines = try await engine.recognize(image: page.image, options: options)
                pageResults.append(PageOCRResult(page: page.pageNumber, lines: lines))
            }
            return SourceOCRResult(source: item.source, pages: pageResults)
        }
    }

    private func writeOutput(_ string: String, standardOutputFileDescriptor: Int32) throws {
        let outputString = string.hasSuffix("\n") ? string : string + "\n"
        if let output {
            try outputString.write(to: URL(fileURLWithPath: output), atomically: true, encoding: .utf8)
        } else if let data = outputString.data(using: .utf8) {
            let handle = FileHandle(fileDescriptor: standardOutputFileDescriptor, closeOnDealloc: false)
            handle.write(data)
        } else {
            throw CLIError(message: "Failed to encode output as UTF-8")
        }
    }

    private func splitList(_ value: String?) -> [String] {
        guard let value else {
            return []
        }
        return value
            .split { $0 == "," || $0 == " " || $0 == "\n" || $0 == "\t" }
            .map(String.init)
    }
}

private enum ProcessingOutcome: Sendable {
    case success(index: Int, result: SourceOCRResult)
    case failure(index: Int, warning: String)
}

private final class StdoutSuppression {
    let originalFileDescriptor: Int32
    private var restored = false

    private init(originalFileDescriptor: Int32) {
        self.originalFileDescriptor = originalFileDescriptor
    }

    static func redirectToDevNull() throws -> StdoutSuppression {
        let original = dup(STDOUT_FILENO)
        guard original >= 0 else {
            throw CLIError(message: "Could not duplicate stdout")
        }

        let nullDescriptor = open("/dev/null", O_WRONLY)
        guard nullDescriptor >= 0 else {
            close(original)
            throw CLIError(message: "Could not open /dev/null")
        }
        defer { close(nullDescriptor) }

        guard dup2(nullDescriptor, STDOUT_FILENO) >= 0 else {
            close(original)
            throw CLIError(message: "Could not redirect stdout")
        }

        return StdoutSuppression(originalFileDescriptor: original)
    }

    func restore() {
        guard !restored else {
            return
        }
        dup2(originalFileDescriptor, STDOUT_FILENO)
        closeOriginal()
    }

    func closeOriginal() {
        guard !restored else {
            return
        }
        close(originalFileDescriptor)
        restored = true
    }
}

private func withTimeout<T: Sendable>(
    seconds: Double,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError(seconds: seconds)
        }

        guard let result = try await group.next() else {
            throw TimeoutError(seconds: seconds)
        }
        group.cancelAll()
        return result
    }
}

private extension FileHandle {
    func writeLine(_ line: String) {
        if let data = (line + "\n").data(using: .utf8) {
            write(data)
        }
    }
}
