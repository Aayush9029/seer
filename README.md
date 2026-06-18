<div align="center">

<img src="assets/icon.png" width="128" alt="seer icon">

# seer

**Extract text from anything, using Apple Vision OCR.**

[![Download](https://img.shields.io/badge/brew-aayush9029%2Ftap%2Fseer-black?logo=homebrew)](https://github.com/Aayush9029/homebrew-tap)
[![Sponsor](https://img.shields.io/badge/Sponsor-❤-db61a2?logo=github)](https://github.com/sponsors/Aayush9029)

<img src="assets/demo.gif" alt="seer demo" width="800">

</div>

## Why

On-device OCR with zero setup. Point `seer` at images, PDFs, or whole folders and get clean
text out — plain, Markdown, or JSON. Uses Apple's Vision framework, so it's fast, private, and
needs no API key or network.

## Install

```sh
brew install aayush9029/tap/seer
```

<details>
<summary>tap first</summary>

```sh
brew tap aayush9029/tap
brew install seer
```
</details>

## Usage

```sh
seer screenshot.png                  # text to stdout
seer scan.pdf -o out.md -f markdown  # OCR every page → Markdown file
seer images/ -r -f json              # recurse a folder → structured JSON
seer *.png *.heic                     # mix file types and globs
pbpaste | seer -                      # (pipe) OCR an image from stdin
seer doc.tiff --speed fast            # trade accuracy for speed
```

Defaults to the best result: accurate recognition, language correction, automatic language
detection, plain text on stdout.
