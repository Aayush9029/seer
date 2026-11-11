# seer

`seer` is a Swift CLI that extracts text from images and PDFs on the Mac with the Apple Vision framework. It prints plain text, Markdown, or JSON, and needs no network or API key. It ships through the Homebrew tap `aayush9029/tap` as a prebuilt arm64 binary. Status: shipped.

## Commands

| Task | Command |
|------|---------|
| Build | `swift build -c release` |
| Test | `swift test` |
| End-to-end test | `scripts/e2e.sh` |
| Run | `swift run seer scan.pdf -f markdown` |
| Package a release | `scripts/package.sh v0.1.0` |
| Release | Load the `oss-cli-release` skill |

## Architecture

- `Sources/seer/seerCLI.swift`: the `swift-argument-parser` command.
- `Sources/seer/Core`: `InputResolver` (files, folders, globs, `-` for stdin), `ImageLoader`, `PDFRasterizer`, `OCREngine` (Vision), `OutputFormatter`, `AppVersion`.
- `Tests/seerTests`: unit tests. `FixtureFactory` draws test images in code.
- `scripts/e2e.sh` draws a PNG and a two-page PDF, runs the release binary, and checks the text, Markdown, and JSON output.

## Rules

- Always use the Vision `.accurate` recognition level. Language correction is on by default (`--no-correction` turns it off). The fast mode gave bad results, and recent work removed it. Do not add it back.
- The package targets macOS 15 (`.macOS(.v15)`). The tap formula needs `macos: :sequoia` and `arm64`.
- Release flow: run `scripts/package.sh <tag>`, upload `dist/seer-<version>-arm64-macos.tar.gz` to the GitHub release, then put the printed SHA256 into `../../homebrew-tap/Formula/seer.rb`.
- Keep `AppVersion` the same as the git tag. The formula test runs `seer --version`.
