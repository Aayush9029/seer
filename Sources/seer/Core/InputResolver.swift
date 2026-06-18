import CoreGraphics
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum InputKind: Equatable, Sendable {
    case image
    case pdf
    case stdinImage

    static func detect(url: URL) -> InputKind? {
        if let type = UTType(filenameExtension: url.pathExtension) {
            if type.conforms(to: .pdf) {
                return .pdf
            }
            if type.conforms(to: .image) {
                return .image
            }
        }

        if CGPDFDocument(url as CFURL) != nil {
            return .pdf
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return CGImageSourceGetCount(source) > 0 ? .image : nil
    }
}

struct WorkItem: Equatable, Sendable {
    let source: String
    let kind: InputKind
    let url: URL?
    let data: Data?

    static func file(url: URL, kind: InputKind) -> WorkItem {
        WorkItem(source: url.path, kind: kind, url: url, data: nil)
    }

    static func stdin(data: Data) -> WorkItem {
        WorkItem(source: "stdin", kind: .stdinImage, url: nil, data: data)
    }
}

struct InputResolution: Sendable {
    let items: [WorkItem]
    let warnings: [String]
}

struct InputResolver {
    var fileManager: FileManager = .default

    func resolve(paths: [String], recursive: Bool) throws -> InputResolution {
        if paths.isEmpty {
            if isatty(STDIN_FILENO) == 0 {
                let data = FileHandle.standardInput.readDataToEndOfFile()
                if !data.isEmpty {
                    return InputResolution(items: [.stdin(data: data)], warnings: [])
                }
            }
            return InputResolution(items: [], warnings: [])
        }

        var items: [WorkItem] = []
        var warnings: [String] = []

        for argument in paths {
            if argument == "-" {
                let data = FileHandle.standardInput.readDataToEndOfFile()
                if data.isEmpty {
                    warnings.append("warning: no data on stdin")
                } else {
                    items.append(.stdin(data: data))
                }
                continue
            }

            let expandedPaths = expandGlob(argument)
            if expandedPaths.isEmpty {
                warnings.append("warning: no matches for \(argument)")
                continue
            }

            for path in expandedPaths {
                let url = URL(fileURLWithPath: path)
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                    warnings.append("warning: \(path) does not exist")
                    continue
                }

                if isDirectory.boolValue {
                    let resolved = resolveDirectory(url: url, recursive: recursive)
                    items.append(contentsOf: resolved.items)
                    warnings.append(contentsOf: resolved.warnings)
                } else if let kind = InputKind.detect(url: url) {
                    items.append(.file(url: url, kind: kind))
                } else {
                    warnings.append("warning: unsupported file skipped: \(url.path)")
                }
            }
        }

        return InputResolution(items: items, warnings: warnings)
    }

    private func resolveDirectory(url: URL, recursive: Bool) -> InputResolution {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
        let urls: [URL]

        if recursive {
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsPackageDescendants]
            ) else {
                return InputResolution(items: [], warnings: ["warning: unreadable directory skipped: \(url.path)"])
            }
            urls = enumerator.compactMap { $0 as? URL }.sorted { $0.path < $1.path }
        } else {
            do {
                urls = try fileManager
                    .contentsOfDirectory(at: url, includingPropertiesForKeys: keys)
                    .sorted { $0.path < $1.path }
            } catch {
                return InputResolution(items: [], warnings: ["warning: unreadable directory skipped: \(url.path)"])
            }
        }

        var items: [WorkItem] = []
        var warnings: [String] = []

        for candidate in urls {
            do {
                let values = try candidate.resourceValues(forKeys: Set(keys))
                if values.isDirectory == true {
                    continue
                }
                guard values.isRegularFile == true else {
                    continue
                }
            } catch {
                warnings.append("warning: unreadable file skipped: \(candidate.path)")
                continue
            }

            if let kind = InputKind.detect(url: candidate) {
                items.append(.file(url: candidate, kind: kind))
            } else {
                warnings.append("warning: unsupported file skipped: \(candidate.path)")
            }
        }

        return InputResolution(items: items, warnings: warnings)
    }

    private func expandGlob(_ pattern: String) -> [String] {
        guard pattern.rangeOfCharacter(from: CharacterSet(charactersIn: "*?[")) != nil else {
            return [pattern]
        }

        var result = glob_t()
        defer { globfree(&result) }

        guard glob(pattern, GLOB_TILDE, nil, &result) == 0 else {
            return []
        }

        return (0..<Int(result.gl_pathc))
            .compactMap { index in
                result.gl_pathv[index].map { String(cString: $0) }
            }
            .sorted()
    }
}
