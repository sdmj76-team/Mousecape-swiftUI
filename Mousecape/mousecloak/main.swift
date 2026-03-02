//
//  main.swift
//  mousecloak
//
//  Created by Swift Migration on 2026-03-02.
//  Copyright (c) 2013-2025 Sdmj76. All rights reserved.
//

import Foundation
import ArgumentParser

// MARK: - Main CLI Structure

@main
struct MousecloakCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mousecloak",
        abstract: "A command-line tool for managing macOS cursor themes",
        version: "2.0",
        subcommands: [
            Apply.self,
            Reset.self,
            Create.self,
            Dump.self,
            Convert.self,
            Export.self,
            Scale.self,
            Listen.self
        ],
        defaultSubcommand: nil
    )

    struct Options: ParsableArguments {
        @Flag(name: .long, help: "Suppress copyright info")
        var suppressCopyright = false
    }
}

// MARK: - Apply Command

extension MousecloakCLI {
    struct Apply: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Apply a cape"
        )

        @Argument(help: "Path to the cape file")
        var capePath: String

        @OptionGroup var options: MousecloakCLI.Options

        func run() throws {
            printHeader(suppressCopyright: options.suppressCopyright)
            applyCapeAtPath(capePath)
            printFooter(suppressCopyright: options.suppressCopyright)
        }
    }
}

// MARK: - Reset Command

extension MousecloakCLI {
    struct Reset: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Reset to the default OSX cursors"
        )

        @OptionGroup var options: MousecloakCLI.Options

        func run() throws {
            printHeader(suppressCopyright: options.suppressCopyright)
            resetAllCursors()
            printFooter(suppressCopyright: options.suppressCopyright)
        }
    }
}

// MARK: - Create Command

extension MousecloakCLI {
    struct Create: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: """
            Create a cursor from a folder. Default output is to a new file of the same name. Directory must use the format:
            \t\t├── com.apple.coregraphics.Arrow
            \t\t│   ├── 0.png
            \t\t│   ├── 1.png
            \t\t│   ├── 2.png
            \t\t│   └── 3.png
            \t\t├── com.apple.coregraphics.Wait
            \t\t│   ├── 0.png
            \t\t│   ├── 1.png
            \t\t│   └── 2.png
            \t\t├── com.apple.cursor.3
            \t\t│   ├── 0.png
            \t\t│   ├── 1.png
            \t\t│   ├── 2.png
            \t\t│   └── 3.png
            \t\t└── com.apple.cursor.5
            \t\t    ├── 0.png
            \t\t    ├── 1.png
            \t\t    ├── 2.png
            \t\t    └── 3.png
            """
        )

        @Argument(help: "Input directory path")
        var inputPath: String

        @Option(name: .shortAndLong, help: "Output file path")
        var output: String?

        @OptionGroup var options: MousecloakCLI.Options

        func run() throws {
            printHeader(suppressCopyright: options.suppressCopyright)

            let outputPath = output ?? (inputPath as NSString).deletingLastPathComponent
            let error = createCape(inputPath, outputPath, false)

            if let error = error {
                printError(error.localizedDescription)
            } else {
                printSuccess("Cape successfully written to \(outputPath)")
            }

            printFooter(suppressCopyright: options.suppressCopyright)
        }
    }
}

// MARK: - Dump Command

extension MousecloakCLI {
    struct Dump: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Dumps the currently applied cursors to a file"
        )

        @Argument(help: "Output file path")
        var outputPath: String

        @OptionGroup var options: MousecloakCLI.Options

        func run() throws {
            printHeader(suppressCopyright: options.suppressCopyright)

            dumpCursorsToFile(outputPath) { progress, total in
                print("Dumped \(progress) of \(total)")
                return true
            }

            printFooter(suppressCopyright: options.suppressCopyright)
        }
    }
}

// MARK: - Convert Command

extension MousecloakCLI {
    struct Convert: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Convert a .MightyMouse file to cape. Default output is to a new file of the same name"
        )

        @Argument(help: "Input .MightyMouse file path")
        var inputPath: String

        @Option(name: .shortAndLong, help: "Output file path")
        var output: String?

        @OptionGroup var options: MousecloakCLI.Options

        func run() throws {
            printHeader(suppressCopyright: options.suppressCopyright)

            let outputPath = output ?? (inputPath as NSString).deletingLastPathComponent
            let error = createCape(inputPath, outputPath, true)

            if let error = error {
                printError(error.localizedDescription)
            } else {
                printSuccess("Cape successfully written to \(outputPath)")
            }

            printFooter(suppressCopyright: options.suppressCopyright)
        }
    }
}

// MARK: - Export Command

extension MousecloakCLI {
    struct Export: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Export a cape to a directory"
        )

        @Argument(help: "Input cape file path")
        var inputPath: String

        @Option(name: .shortAndLong, help: "Output directory path", required: true)
        var output: String

        @OptionGroup var options: MousecloakCLI.Options

        func run() throws {
            printHeader(suppressCopyright: options.suppressCopyright)

            guard let cape = NSDictionary(contentsOfFile: inputPath) else {
                printError("Failed to read cape file at \(inputPath)")
                printFooter(suppressCopyright: options.suppressCopyright)
                return
            }

            exportCape(cape as! [AnyHashable: Any], output)

            printFooter(suppressCopyright: options.suppressCopyright)
        }
    }
}

// MARK: - Scale Command

extension MousecloakCLI {
    struct Scale: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Scale the cursor to obscene multipliers or get the current scale"
        )

        @Argument(help: "Scale value (optional, omit to get current scale)")
        var scaleValue: Float?

        @OptionGroup var options: MousecloakCLI.Options

        func run() throws {
            printHeader(suppressCopyright: options.suppressCopyright)

            if let scale = scaleValue {
                setCursorScale(scale)
            } else {
                print("\(cursorScale())")
            }

            printFooter(suppressCopyright: options.suppressCopyright)
        }
    }
}

// MARK: - Listen Command

extension MousecloakCLI {
    struct Listen: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Keep mousecloak alive to apply the current Cape every user switch"
        )

        @OptionGroup var options: MousecloakCLI.Options

        func run() throws {
            printHeader(suppressCopyright: options.suppressCopyright)
            listener()
            printFooter(suppressCopyright: options.suppressCopyright)
        }
    }
}

// MARK: - Helper Functions

private func printHeader(suppressCopyright: Bool) {
    #if DEBUG
    MCLoggerInit()
    MCLoggerWrite("=== mousecloak CLI Started ===")
    #endif

    if !suppressCopyright {
        print("\u{001B}[1m\u{001B}[37mmousecloak v2.0\u{001B}[0m")
    }
}

private func printFooter(suppressCopyright: Bool) {
    if !suppressCopyright {
        print("\u{001B}[1m\u{001B}[37mCopyright © 2013-2025 Sdmj76\u{001B}[0m")
    }
}

private func printError(_ message: String) {
    print("\u{001B}[1m\u{001B}[31m\(message)\u{001B}[0m")
}

private func printSuccess(_ message: String) {
    print("\u{001B}[1m\u{001B}[32m\(message)\u{001B}[0m")
}
