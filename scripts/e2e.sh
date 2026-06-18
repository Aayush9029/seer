#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "build: swift build -c release"
swift build -c release

cat > "$tmpdir/generate.swift" <<'SWIFT'
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

func draw(_ text: String, in context: CGContext, x: CGFloat, y: CGFloat, fontSize: CGFloat) {
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
    let attributes: [NSAttributedString.Key: Any] = [
        kCTFontAttributeName as NSAttributedString.Key: font,
        kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(gray: 0, alpha: 1),
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    context.textMatrix = .identity
    context.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, context)
}

func writePNG(_ text: String, to url: URL) throws {
    let width = 1400
    let height = 360
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "fixture", code: 1)
    }
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(CGColor(gray: 0, alpha: 1))
    draw(text, in: context, x: 70, y: 135, fontSize: 82)
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "fixture", code: 2)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "fixture", code: 3)
    }
}

func writePDF(_ pages: [String], to url: URL) throws {
    var mediaBox = CGRect(x: 0, y: 0, width: 900, height: 360)
    guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
        throw NSError(domain: "fixture", code: 4)
    }
    for page in pages {
        context.beginPDFPage(nil)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(mediaBox)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        draw(page, in: context, x: 60, y: 145, fontSize: 64)
        context.endPDFPage()
    }
    context.closePDF()
}

let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try writePNG("HELLO SEER 12345", to: out.appendingPathComponent("hello.png"))
try writePDF(["PAGE ONE SEER", "PAGE TWO 67890"], to: out.appendingPathComponent("pages.pdf"))
SWIFT

swift "$tmpdir/generate.swift" "$tmpdir"

bin=".build/release/seer"
png="$tmpdir/hello.png"
pdf="$tmpdir/pages.pdf"

"$bin" "$png" "$pdf" > "$tmpdir/text.txt"
grep -qi "HELLO" "$tmpdir/text.txt" || fail "text output missing HELLO"
grep -qi "SEER" "$tmpdir/text.txt" || fail "text output missing SEER"
grep -qi "PAGE ONE" "$tmpdir/text.txt" || fail "text output missing PAGE ONE"

"$bin" --format markdown "$png" "$pdf" > "$tmpdir/markdown.md"
grep -q "## $png" "$tmpdir/markdown.md" || fail "markdown output missing PNG header"
grep -q "## $pdf" "$tmpdir/markdown.md" || fail "markdown output missing PDF header"
grep -q "### Page 1" "$tmpdir/markdown.md" || fail "markdown output missing page header"
grep -qi "PAGE TWO" "$tmpdir/markdown.md" || fail "markdown output missing PAGE TWO"

"$bin" --format json "$png" "$pdf" > "$tmpdir/output.json"
python3 - "$tmpdir/output.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)

text = " ".join(
    line["text"]
    for source in payload
    for page in source["pages"]
    for line in page["lines"]
).upper()

required = ["HELLO", "SEER", "PAGE ONE", "PAGE TWO", "67890"]
missing = [item for item in required if item not in text]
if missing:
    raise SystemExit(f"missing JSON OCR text: {missing}")
PY

echo "PASS"
