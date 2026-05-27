# SwiftCommentReflow

[![Swift 6.1+](https://img.shields.io/badge/Swift-6.1%2B-orange.svg)](https://www.swift.org/)
[![Platform macOS 13+](https://img.shields.io/badge/platform-macOS%2013%2B-blue.svg)](https://developer.apple.com/macos/)
[![License Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/RuiNelson/SwiftCommentReflow)](https://github.com/RuiNelson/SwiftCommentReflow/releases)

`swift-comment-reflow` is a small Swift CLI utility that reformats multi-line comments into cleaner single-line or paragraph-friendly comments.

It helps keep Swift source comments consistent by reflowing:
- `//` line comments
- `/* ... */` block comments
- `///` DocC comments

## Why use it

- Keep comment formatting consistent across a codebase
- Improve readability of long wrapped comments
- Work on files, directories, and glob patterns

This tool was designed to run **before** a more complex source code formatter (like the venerable [swiftformat](https://github.com/nicklockwood/swiftformat)) runs.

## Requirements

- macOS 13+
- Swift 6.1+

## Build (Compile)

```bash
swift build -c release
```

Binary path:

```bash
.build/release/swift-comment-reflow
```

## Install locally (optional)

```bash
swift build -c release
sudo install .build/release/swift-comment-reflow /usr/local/bin/swift-comment-reflow
```

Then run:

```bash
swift-comment-reflow --help
```

## Usage

```bash
swift-comment-reflow [options] <files...>
```

At least one reflow option is required:

- `-c`, `--comments` reflow `//` line comments
- `-b`, `--blocks` reflow `/* ... */` block comments
- `-d`, `--docc` reflow `///` DocC comments

Additional options:

- `-v`, `--verbose` report on each file changed
- `-m`, `--mp <count>` maximum number of files processed concurrently (default: 10)

Inputs can be:

- File paths (`Sources/App/File.swift`)
- Directories (searched recursively for `*.swift`)
- Glob patterns (`Sources/**/*.swift`)

## Examples

Reflow normal line comments in one file:

```bash
swift-comment-reflow -c Sources/MyFile.swift
```

Reflow DocC comments recursively in a directory:

```bash
swift-comment-reflow -d Sources/
```

Reflow block comments using a glob:

```bash
swift-comment-reflow -b "Sources/**/*.swift"
```

Reflow all supported comment types across `Sources` and `Tests`:

```bash
swift-comment-reflow -cbd Sources/ Tests/
```

Use without installing (via SwiftPM):

```bash
swift run swift-comment-reflow --comments "Sources/**/*.swift"
```

## CLI Help

```text
USAGE: swift-comment-reflow-cli <files> ... [--comments] [--blocks] [--docc] [--verbose] [--mp <count>]

ARGUMENTS:
  <files>                 Files, directories, or glob patterns to reflow.
                          Directories are searched recursively for *.swift files.

OPTIONS:
  -c, --comments          Reflow // line comments.
  -b, --blocks            Reflow /* ... */ block comments.
  -d, --docc              Reflow /// DocC comments.
  -v, --verbose           Report on each file changed.
  -m, --mp <count>        Maximum number of files processed concurrently. (default: 10)
  -h, --help              Show help information.
```

## Behavior notes

- The tool edits files in place.
- Files are processed concurrently (up to 10 by default). Use `--mp` to adjust concurrency.
- By default, the tool runs silently. Use `--verbose` to see which files were changed.
- If no files match, the command exits with a validation error.
- If no `-c`, `-b`, or `-d` flag is provided, the command exits with a validation error.

## Development

Run tests:

```bash
swift test
```

## License

Apache License 2.0. See [LICENSE](LICENSE).
