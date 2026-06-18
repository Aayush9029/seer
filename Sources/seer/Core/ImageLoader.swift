import CoreGraphics
import Foundation
import ImageIO

enum ImageLoader {
    static func load(url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw CLIError(message: "Could not read image: \(url.path)")
        }
        return try load(source: source, description: url.path)
    }

    static func load(data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw CLIError(message: "Could not read image from stdin")
        }
        return try load(source: source, description: "stdin")
    }

    private static func load(source: CGImageSource, description: String) throws -> CGImage {
        guard CGImageSourceGetCount(source) > 0,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CLIError(message: "Could not decode image: \(description)")
        }
        return image
    }
}
