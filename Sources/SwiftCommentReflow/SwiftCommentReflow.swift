//
//
// SwiftCommentReflow.swift
//
//
//

import ArgumentParser
import Foundation
import Glob
import SwiftCommentReflowCore

/// Command-line interface for reflowing Swift comments in files.
@main
struct SwiftCommentReflowCLI: AsyncParsableCommand {
    /// File paths, directories, or glob patterns to process.
    @Argument(
        help: "Files, directories, or glob patterns to reflow. Directories are searched recursively for *.swift files.",
    )
    var files: [String]
    
    /// Enables reflow of `//` line comments.
    @Flag(
        name: [.customShort("c"), .customLong("comments")],
        help: "Reflow // line comments.",
    ) var onComments = false
    /// Enables reflow of `/* ... */` block comments.
    @Flag(
        name: [.customShort("b"), .customLong("blocks")],
        help: "Reflow /* ... */ block comments.",
    ) var onBlockComments = false
    /// Enables reflow of `///` DocC comments.
    @Flag(
        name: [.customShort("d"), .customLong("docc")],
        help: "Reflow /// DocC comments.",
    ) var onDocC = false

    /// Executes the command using the selected comment-type flags.
    func run() async throws {
        guard onComments || onBlockComments || onDocC else {
            throw ValidationError("At least one flag must be set.")
        }
        
        let resolvedFiles = try await resolveFiles(files)
        guard !resolvedFiles.isEmpty else {
            throw ValidationError("No files matched the given patterns.")
        }
                
        var filesChanged: Int = 0
        
        for file in resolvedFiles {
            let changed = try reflowFile(file: file)
            
            filesChanged += changed ? 1 : 0
        }
        
        print("Files Changed: \(filesChanged) in \(resolvedFiles.count)")
    }
}

extension SwiftCommentReflowCLI {
    /// Resolves input paths and glob patterns into concrete file URLs.
    ///
    /// - Parameter patterns: Positional command arguments.
    /// - Returns: Matched files in discovery order.
    private func resolveFiles(_ patterns: [String]) async throws -> [URL] {
        var results: [URL] = []
        for pattern in patterns {
            if pattern.contains("*") || pattern.contains("?") || pattern.contains("[") {
                let globPattern = try Pattern(pattern)
                let stream = search(
                    directory: URL(fileURLWithPath: "."),
                    include: [globPattern],
                )
                for try await url in stream {
                    results.append(url)
                }
            }
            else {
                let url = URL(fileURLWithPath: pattern)
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                    continue
                }

                if isDirectory.boolValue {
                    let swiftPattern = try Pattern("**/*.swift")
                    let stream = search(directory: url, include: [swiftPattern])
                    for try await fileURL in stream {
                        results.append(fileURL)
                    }
                }
                else {
                    results.append(url)
                }
            }
        }
        return results
    }

    /// Reflows a single file and writes changes back to disk.
    ///
    /// - Parameter file: File URL to process.
    /// - Returns: `true` when the file was modified.
    private func reflowFile(file: URL) throws -> Bool {
        let original = try String(contentsOf: file, encoding: .utf8)
        let reflowed = SwiftCommentReflowCore.reflowFile(
            original,
            onComments: onComments,
            onCommentBlocks: onBlockComments,
            onDocC: onDocC,
        )

        let fileWasModified = original != reflowed
        if fileWasModified {
            try reflowed.write(to: file, atomically: true, encoding: String.Encoding.utf8)
        }

        print("\(file.path(percentEncoded: false)) --- \(fileWasModified ? "changed" : "intact")")

        return fileWasModified
    }
}
