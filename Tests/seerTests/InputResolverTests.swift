import Foundation
import Testing
@testable import seer

struct InputResolverTests {
    @Test
    func detectsSupportedTypesByExtension() {
        #expect(InputKind.detect(url: URL(fileURLWithPath: "/tmp/sample.pdf")) == .pdf)
        #expect(InputKind.detect(url: URL(fileURLWithPath: "/tmp/sample.png")) == .image)
        #expect(InputKind.detect(url: URL(fileURLWithPath: "/tmp/sample.jpg")) == .image)
        #expect(InputKind.detect(url: URL(fileURLWithPath: "/tmp/sample.heic")) == .image)
        #expect(InputKind.detect(url: URL(fileURLWithPath: "/tmp/sample.tiff")) == .image)
        #expect(InputKind.detect(url: URL(fileURLWithPath: "/tmp/sample.bmp")) == .image)
        #expect(InputKind.detect(url: URL(fileURLWithPath: "/tmp/sample.gif")) == .image)
        #expect(InputKind.detect(url: URL(fileURLWithPath: "/tmp/sample.webp")) == .image)
        #expect(InputKind.detect(url: URL(fileURLWithPath: "/tmp/sample.txt")) == nil)
    }

    @Test
    func resolvesDirectoryNonRecursivelyInStableOrder() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let nested = root.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try FixtureFactory.writePNG(text: "FIRST", to: root.appendingPathComponent("b.png"))
        try FixtureFactory.writePDF(pages: ["SECOND"], to: root.appendingPathComponent("a.pdf"))
        try FixtureFactory.writePNG(text: "NESTED", to: nested.appendingPathComponent("c.png"))
        defer { try? FileManager.default.removeItem(at: root) }

        let resolution = try InputResolver().resolve(paths: [root.path], recursive: false)

        #expect(resolution.items.map { URL(fileURLWithPath: $0.source).lastPathComponent } == ["a.pdf", "b.png"])
    }
}
