import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum FixtureFactory {
    static func makeTextImage(_ text: String, width: Int = 1400, height: Int = 360) throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw FixtureError("Could not create image context")
        }

        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        draw(text, in: context, x: 70, y: 135, fontSize: 82)

        guard let image = context.makeImage() else {
            throw FixtureError("Could not create image")
        }
        return image
    }

    static func writePNG(text: String, to url: URL) throws {
        let image = try makeTextImage(text)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw FixtureError("Could not create PNG destination")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw FixtureError("Could not write PNG")
        }
    }

    static func writePDF(pages: [String], to url: URL) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: 900, height: 360)
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw FixtureError("Could not create PDF context")
        }

        for pageText in pages {
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(mediaBox)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            draw(pageText, in: context, x: 60, y: 145, fontSize: 64)
            context.endPDFPage()
        }
        context.closePDF()
    }

    private static func draw(_ text: String, in context: CGContext, x: CGFloat, y: CGFloat, fontSize: CGFloat) {
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            kCTFontAttributeName as NSAttributedString.Key: font,
            kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(gray: 0, alpha: 1),
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributed)
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
    }
}

struct FixtureError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
