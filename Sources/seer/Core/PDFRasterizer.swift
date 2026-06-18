import CoreGraphics
import Foundation

struct RasterizedPDFPage: Sendable {
    let pageNumber: Int
    let image: CGImage
}

enum PDFRasterizer {
    static func rasterize(url: URL, scale: CGFloat = 2.0) throws -> [RasterizedPDFPage] {
        guard let document = CGPDFDocument(url as CFURL) else {
            throw CLIError(message: "Could not read PDF: \(url.path)")
        }

        let pageCount = document.numberOfPages
        guard pageCount > 0 else {
            throw CLIError(message: "PDF has no pages: \(url.path)")
        }

        return try (1...pageCount).map { pageNumber in
            guard let page = document.page(at: pageNumber) else {
                throw CLIError(message: "Could not read page \(pageNumber): \(url.path)")
            }
            return RasterizedPDFPage(
                pageNumber: pageNumber,
                image: try rasterize(page: page, scale: scale)
            )
        }
    }

    private static func rasterize(page: CGPDFPage, scale: CGFloat) throws -> CGImage {
        let box = page.getBoxRect(.mediaBox)
        let width = max(Int((box.width * scale).rounded(.up)), 1)
        let height = max(Int((box.height * scale).rounded(.up)), 1)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw CLIError(message: "Could not create PDF render context")
        }

        let targetRect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(targetRect)
        context.concatenate(page.getDrawingTransform(.mediaBox, rect: targetRect, rotate: 0, preserveAspectRatio: true))
        context.drawPDFPage(page)

        guard let image = context.makeImage() else {
            throw CLIError(message: "Could not render PDF page")
        }
        return image
    }
}
