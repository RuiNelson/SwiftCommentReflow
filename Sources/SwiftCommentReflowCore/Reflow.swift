//
//
// Reflow.swift
//
//
//

import Foundation

private extension String {
    /// Returns a copy of the string with trailing whitespace removed.
    func trimmingTrailingWhitespace() -> String {
        var result = self
        while let last = result.last, last.isWhitespace {
            result.removeLast()
        }
        return result
    }
}

/// Reflows a plain text block into normalized paragraphs.
///
/// The function preserves paragraph boundaries (blank lines) and applies two spacing rules:
/// - Non-list lines in the same paragraph are joined with single spaces.
/// - Lines whose trimmed content starts with `-` are treated as list items and force a line break before the item.
///
/// - Parameter input: The source text to reflow.
/// - Returns: Reflowed text with normalized inter-line spacing.
private func reflowInternal(_ input: String, collapseParagraphBreakBeforeLists: Bool) -> String {
    typealias ParagraphLine = (text: String, forceLineBreakBefore: Bool)

    var paragraphs: [[ParagraphLine]] = []
    var currentParagraph: [ParagraphLine] = []
    var previousWasTable = false

    for rawLine in input.split(separator: "\n", omittingEmptySubsequences: false) {
        let line = String(rawLine)
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedLine.isEmpty {
            if !currentParagraph.isEmpty {
                paragraphs.append(currentParagraph)
                currentParagraph.removeAll(keepingCapacity: true)
            }
            previousWasTable = false
            continue
        }

        if currentParagraph.isEmpty {
            previousWasTable = trimmedLine.first == "|"
            currentParagraph.append((line.trimmingTrailingWhitespace(), false))
        }
        else {
            let startsWithDash = trimmedLine.first == "-"
            let startsWithOrderedList = trimmedLine.range(of: #"^\d+\."#, options: .regularExpression) != nil
            let startsWithTablePipe = trimmedLine.first == "|"
            let exitingTable = !startsWithTablePipe && previousWasTable
            let forceBreak = startsWithDash || startsWithOrderedList || startsWithTablePipe || exitingTable
            previousWasTable = startsWithTablePipe
            let normalizedLine = forceBreak
                ? line.trimmingTrailingWhitespace()
                : trimmedLine
            currentParagraph.append((normalizedLine, forceBreak))
        }
    }

    if !currentParagraph.isEmpty {
        paragraphs.append(currentParagraph)
    }

    let reflowedParagraphs = paragraphs.map { paragraph in
        guard let firstLine = paragraph.first else { return "" }

        var result = firstLine.text
        for line in paragraph.dropFirst() {
            let separator = line.forceLineBreakBefore ? "\n" : " "
            result += separator + line.text
        }
        return result
    }

    var output = ""
    for paragraph in reflowedParagraphs {
        if output.isEmpty {
            output = paragraph
            continue
        }

        let trimmedLeading = paragraph.trimmingCharacters(in: .whitespaces)
        if collapseParagraphBreakBeforeLists, trimmedLeading.first == "-" {
            output += "\n" + paragraph
        }
        else {
            output += "\n\n" + paragraph
        }
    }

    return output
}

public func reflow(_ input: String) -> String {
    reflowInternal(input, collapseParagraphBreakBeforeLists: true)
}

private func reflowDocC(_ input: String) -> String {
    reflowInternal(input, collapseParagraphBreakBeforeLists: false)
}

private enum ReflowFileBlock {
    case raw([String])
    case lineComment(prefix: String, texts: [String])
    case blockComment(startPrefix: String, texts: [String], closingLine: String)
    case docc(prefix: String, texts: [String])
}

/// Reflows comment text inside a Swift source file.
///
/// Depending on the provided switches, this function detects and reflows:
/// - `//` line comments
/// - `/* ... */` block comments
/// - `///` DocC comments
///
/// Non-comment source lines are preserved verbatim.
///
/// - Parameters:
///   - input: Full file contents to process.
///   - onComments: Enables reflow of line comments.
///   - onCommentBlocks: Enables reflow of block comments.
///   - onDocC: Enables reflow of DocC line comments (`///`).
/// - Returns: A transformed file string with selected comments reflowed.
public func reflowFile(_ input: String, onComments: Bool, onCommentBlocks: Bool, onDocC: Bool) -> String {
    let lines = input.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    var blocks: [ReflowFileBlock] = []
    var index = 0

    func commentTextPreservingIndent(_ line: String, after markerUpperBound: String.Index) -> String {
        var text = String(line[markerUpperBound...])
        if text.first == " " {
            text.removeFirst()
        }
        return text.trimmingTrailingWhitespace()
    }

    func isEscapedQuote(_ line: String, at quoteIndex: String.Index) -> Bool {
        guard quoteIndex > line.startIndex else { return false }
        var slashCount = 0
        var cursor = line.index(before: quoteIndex)
        while true {
            if line[cursor] == "\\" {
                slashCount += 1
            }
            else {
                break
            }
            if cursor == line.startIndex { break }
            cursor = line.index(before: cursor)
        }
        return slashCount % 2 == 1
    }

    func findMarker(
        _ marker: String,
        in line: String,
        requireWhitespaceBoundaryForInline: Bool,
    ) -> Range<String.Index>? {
        guard !marker.isEmpty else { return nil }
        var index = line.startIndex
        var inNormalString = false
        var inRawStringHashCount: Int?

        while index < line.endIndex {
            if let rawCount = inRawStringHashCount {
                if line[index] == "\"" {
                    var probe = line.index(after: index)
                    var matchedHashes = 0
                    while matchedHashes < rawCount, probe < line.endIndex, line[probe] == "#" {
                        matchedHashes += 1
                        probe = line.index(after: probe)
                    }
                    if matchedHashes == rawCount {
                        inRawStringHashCount = nil
                        index = probe
                        continue
                    }
                }
                index = line.index(after: index)
                continue
            }

            if inNormalString {
                if line[index] == "\"", !isEscapedQuote(line, at: index) {
                    inNormalString = false
                }
                index = line.index(after: index)
                continue
            }

            if line[index] == "\"" {
                inNormalString = true
                index = line.index(after: index)
                continue
            }

            if line[index] == "#" {
                var hashCount = 0
                var probe = index
                while probe < line.endIndex, line[probe] == "#" {
                    hashCount += 1
                    probe = line.index(after: probe)
                }
                if probe < line.endIndex, line[probe] == "\"" {
                    inRawStringHashCount = hashCount
                    index = line.index(after: probe)
                    continue
                }
            }

            if line[index...].hasPrefix(marker) {
                if requireWhitespaceBoundaryForInline, index > line.startIndex {
                    let before = line[line.index(before: index)]
                    if !before.isWhitespace {
                        index = line.index(after: index)
                        continue
                    }
                }
                let upper = line.index(index, offsetBy: marker.count)
                return index ..< upper
            }

            index = line.index(after: index)
        }

        return nil
    }

    func lineCommentOnlyPrefixAndText(_ line: String) -> (prefix: String, text: String)? {
        guard let markerRange = findMarker("//", in: line, requireWhitespaceBoundaryForInline: true) else { return nil }
        if line[markerRange.lowerBound...].hasPrefix("///") { return nil }
        let before = String(line[..<markerRange.lowerBound])
        guard before.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let prefix = before + "//"
        let text = commentTextPreservingIndent(line, after: markerRange.upperBound)
        return (prefix, text)
    }

    func anyLineCommentPrefixAndText(_ line: String) -> (prefix: String, text: String)? {
        guard let markerRange = findMarker("//", in: line, requireWhitespaceBoundaryForInline: true) else { return nil }
        if line[markerRange.lowerBound...].hasPrefix("///") { return nil }
        let prefix = String(line[..<markerRange.upperBound])
        let text = commentTextPreservingIndent(line, after: markerRange.upperBound)
        return (prefix, text)
    }

    func doccPrefixAndText(_ line: String) -> (prefix: String, text: String)? {
        guard let markerRange = findMarker("///", in: line, requireWhitespaceBoundaryForInline: true) else { return nil }
        let before = String(line[..<markerRange.lowerBound])
        guard before.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let prefix = before + "///"
        let text = commentTextPreservingIndent(line, after: markerRange.upperBound)
        return (prefix, text)
    }

    while index < lines.count {
        let line = lines[index]

        if index == 0, onComments, lineCommentOnlyPrefixAndText(line) != nil {
            var header: [String] = []
            var cursor = index
            while cursor < lines.count, lineCommentOnlyPrefixAndText(lines[cursor]) != nil {
                header.append(lines[cursor])
                cursor += 1
            }
            blocks.append(.raw(header))
            index = cursor
            continue
        }

        if onDocC, let first = doccPrefixAndText(line) {
            var texts = [first.text]
            var cursor = index + 1
            while cursor < lines.count, let next = doccPrefixAndText(lines[cursor]) {
                texts.append(next.text)
                cursor += 1
            }
            blocks.append(.docc(prefix: first.prefix, texts: texts))
            index = cursor
            continue
        }

        if onCommentBlocks, let startRange = line.range(of: "/*") {
            let startPrefix = String(line[..<startRange.upperBound])
            var texts = [String(line[startRange.upperBound...]).trimmingCharacters(in: .whitespaces)]
            var closingLine = "*/"
            var cursor = index + 1
            var foundClose = false

            while cursor < lines.count {
                let current = lines[cursor]
                if let closeRange = current.range(of: "*/") {
                    let beforeClose = String(current[..<closeRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    if !beforeClose.isEmpty {
                        texts.append(beforeClose)
                    }
                    let closePrefix = String(current[..<closeRange.lowerBound])
                    closingLine = closePrefix + "*/"
                    foundClose = true
                    cursor += 1
                    break
                }
                texts.append(current.trimmingCharacters(in: .whitespaces))
                cursor += 1
            }

            if foundClose {
                blocks.append(.blockComment(startPrefix: startPrefix, texts: texts, closingLine: closingLine))
                index = cursor
                continue
            }
        }

        if onComments, let first = anyLineCommentPrefixAndText(line) {
            var texts = [first.text]
            var cursor = index + 1
            while cursor < lines.count, let next = lineCommentOnlyPrefixAndText(lines[cursor]) {
                texts.append(next.text)
                cursor += 1
            }
            blocks.append(.lineComment(prefix: first.prefix, texts: texts))
            index = cursor
            continue
        }

        blocks.append(.raw([line]))
        index += 1
    }

    var output: [String] = []
    for block in blocks {
        switch block {
        case let .raw(rawLines):
            output.append(contentsOf: rawLines)
        case let .lineComment(prefix, texts):
            let markerRange = prefix.range(of: "//")
            let beforeMarker = markerRange.map { String(prefix[..<$0.lowerBound]) } ?? ""
            let isStandaloneLineComment = beforeMarker.trimmingCharacters(in: .whitespaces).isEmpty
            let joined = texts.joined(separator: "\n")

            if isStandaloneLineComment {
                let reflowed = reflowDocC(joined)
                let commentLines = reflowed.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                output.append(contentsOf: commentLines.map { line in
                    line.isEmpty ? prefix : prefix + " " + line
                })
            }
            else {
                output.append(prefix + " " + reflow(joined))
            }
        case let .blockComment(startPrefix, texts, closingLine):
            let reflowed = reflow(texts.joined(separator: "\n"))
            let startsWithStandaloneOpener = texts.first?.isEmpty == true

            if startsWithStandaloneOpener, let closeRange = closingLine.range(of: "*/") {
                let closePrefix = String(closingLine[..<closeRange.lowerBound])
                output.append(startPrefix)
                let blockLines = reflowed.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                output.append(contentsOf: blockLines.compactMap { line in
                    guard !line.isEmpty else { return nil }
                    return closePrefix + " " + line
                })
                output.append(closingLine)
            }
            else {
                output.append(startPrefix + " " + reflowed)
                output.append(closingLine)
            }
        case let .docc(prefix, texts):
            let reflowed = reflowDocC(texts.joined(separator: "\n"))
            let doccLines = reflowed.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            output.append(contentsOf: doccLines.map { line in
                line.isEmpty ? prefix : prefix + " " + line
            })
        }
    }

    return output.joined(separator: "\n")
}
