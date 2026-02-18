import Foundation
import MurmurCore

// MARK: - REPL

@MainActor
func main() async {
    // Setup
    guard let apiKey = ProcessInfo.processInfo.environment["PPQ_API_KEY"], !apiKey.isEmpty else {
        print("Error: PPQ_API_KEY environment variable not set")
        print("Usage: PPQ_API_KEY=your-key-here .build/debug/TranscriptionTest")
        exit(1)
    }

    let transcriber = AppleSpeechTranscriber()
    let llm = PPQLLMService(apiKey: apiKey)
    let pipeline = Pipeline(transcriber: transcriber, llm: llm)

    print("MurmurKit REPL (extraction-only)")
    print("=================================")
    print("Type 'help' for commands.\n")

    // REPL loop
    while true {
        print("murmur> ", terminator: "")
        fflush(stdout)

        guard let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty else {
            continue
        }

        let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let command = parts[0].lowercased()
        let args = Array(parts.dropFirst())

        switch command {
        case "record", "rec", "r":
            await handleRecord(pipeline: pipeline, args: args)
        case "text", "t":
            await handleText(pipeline: pipeline)
        case "refine", "ref":
            await handleRefine(pipeline: pipeline, args: args)
        case "help", "h", "?":
            printHelp()
        case "quit", "exit", "q":
            print("Bye!")
            exit(0)
        default:
            print("Unknown command: \(command). Type 'help' for commands.")
        }

        print()
    }
}

// MARK: - Command Handlers

@MainActor
func handleRecord(pipeline: Pipeline, args: [String]) async {
    let seconds = Int(args.first ?? "") ?? 10

    do {
        print("Recording \(seconds)s — speak now!")
        try await pipeline.startRecording()
        await printCountdown(seconds)
        print("Processing...")
        let result = try await pipeline.stopRecording()

        print("Transcript: \"\(result.transcript.text)\"\n")
        printExtracted(result.entries)
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

@MainActor
func handleText(pipeline: Pipeline) async {
    print("Enter text (empty line to finish):")
    var lines: [String] = []
    while let line = readLine() {
        if line.isEmpty { break }
        lines.append(line)
    }

    let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else {
        print("No text entered.")
        return
    }

    do {
        print("Extracting...")
        let result = try await pipeline.extractFromText(text)
        printExtracted(result.entries)
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

@MainActor
func handleRefine(pipeline: Pipeline, args: [String]) async {
    guard pipeline.currentConversation != nil else {
        print("No active session. Run 'record' or 'text' first.")
        return
    }

    let mode = args.first?.lowercased() ?? "text"

    if mode == "voice" || mode == "v" {
        let seconds = Int(args.dropFirst().first ?? "") ?? 10
        do {
            print("Recording \(seconds)s — tell me what to change, add, or remove.")
            try await pipeline.startRecording()
            await printCountdown(seconds)
            print("Processing...")
            let result = try await pipeline.refineFromRecording()
            print("Transcript: \"\(result.transcript.text)\"\n")
            printExtracted(result.entries)
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    } else {
        print("Enter refinement text (empty line to finish):")
        var lines: [String] = []
        while let line = readLine() {
            if line.isEmpty { break }
            lines.append(line)
        }

        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            print("No text entered.")
            return
        }

        do {
            print("Refining...")
            let result = try await pipeline.refineFromText(newInput: text)
            printExtracted(result.entries)
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
}

func printExtracted(_ entries: [ExtractedEntry]) {
    print("Extracted \(entries.count) entries:\n")
    for (i, entry) in entries.enumerated() {
        let pri = entry.priority.map { "P\($0)" } ?? "--"
        let due = entry.dueDateDescription ?? "--"
        print("  \(i + 1). [\(entry.category.displayName)] \(entry.summary.isEmpty ? entry.content : entry.summary)")
        print("     Priority: \(pri)  Due: \(due)")
    }
}

func printHelp() {
    print("""
    Commands:
      record [secs]       rec, r      Record voice (default 10s) -> extract
      text                t           Multi-line text input -> extract
      refine [voice [s]]  ref         Refine last extraction (text or voice)
      help                h, ?        This help
      quit                exit, q     Exit

    After record/text, use 'refine' to modify the extracted entries
    using the multi-turn conversation context.
    """)
}

// MARK: - Countdown

func printCountdown(_ seconds: Int) async {
    for i in (1...seconds).reversed() {
        print("\(i) ", terminator: "")
        fflush(stdout)
        try? await Task.sleep(for: .seconds(1))
    }
    print()
}

await main()
