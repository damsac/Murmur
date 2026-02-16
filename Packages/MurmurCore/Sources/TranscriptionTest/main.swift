import Foundation
import MurmurCore

// MARK: - REPL

@MainActor
// swiftlint:disable:next cyclomatic_complexity
func main() async {
    let inMemory = CommandLine.arguments.contains("--memory")

    // Setup
    guard let apiKey = ProcessInfo.processInfo.environment["PPQ_API_KEY"], !apiKey.isEmpty else {
        print("Error: PPQ_API_KEY environment variable not set")
        print("Usage: PPQ_API_KEY=your-key-here .build/debug/TranscriptionTest")
        exit(1)
    }

    let transcriber = AppleSpeechTranscriber()
    let llm = PPQLLMService(apiKey: apiKey)

    let store: EntryStore
    do {
        store = try EntryStore(inMemory: inMemory)
    } catch {
        print("Error creating store: \(error.localizedDescription)")
        exit(1)
    }

    let pipeline = Pipeline(transcriber: transcriber, llm: llm, store: store)
    var lastListedEntries: [Entry] = []

    print("MurmurKit REPL")
    print("==============")
    if inMemory {
        print("Mode: in-memory (entries will not persist)")
    } else {
        print("Mode: persistent storage")
        if let count = try? store.count(), count > 0 {
            print("Loaded \(count) existing entries")
        }
    }
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
            await handleRecord(pipeline: pipeline, args: args, lastListed: &lastListedEntries)
        case "text", "t":
            await handleText(pipeline: pipeline, lastListed: &lastListedEntries)
        case "list", "ls", "l":
            handleList(store: store, args: args, lastListed: &lastListedEntries)
        case "show", "s":
            handleShow(args: args, lastListed: lastListedEntries)
        case "status", "st":
            handleStatus(store: store, args: args, lastListed: lastListedEntries)
        case "delete", "del", "rm":
            handleDelete(store: store, args: args, lastListed: &lastListedEntries)
        case "clear":
            handleClear(store: store, lastListed: &lastListedEntries)
        case "stats":
            handleStats(store: store)
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
func handleRecord(pipeline: Pipeline, args: [String], lastListed: inout [Entry]) async {
    let seconds = Int(args.first ?? "") ?? 10

    do {
        print("Recording \(seconds)s — speak now!")
        try await pipeline.startRecording()
        await printCountdown(seconds)
        print("Processing...")
        let result = try await pipeline.stopRecording()

        print("Transcript: \"\(result.transcript.text)\"\n")
        await confirmAndSave(pipeline: pipeline, entries: result.entries, lastListed: &lastListed)
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

@MainActor
func handleText(pipeline: Pipeline, lastListed: inout [Entry]) async {
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
        await confirmAndSave(pipeline: pipeline, entries: result.entries, lastListed: &lastListed)
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

@MainActor
func confirmAndSave(pipeline: Pipeline, entries: [Entry], lastListed: inout [Entry]) async {
    var entries = entries

    func printExtracted() {
        print("Extracted \(entries.count) entries:\n")
        for (i, entry) in entries.enumerated() {
            let pri = entry.priority.map { "P\($0)" } ?? "--"
            let due = entry.dueDate.map { formatShortDate($0) }
                ?? entry.dueDateDescription
                ?? "--"
            print("  \(i + 1). [\(entry.category.displayName)] \(entry.summary.isEmpty ? entry.content : entry.summary)")
            print("     Priority: \(pri)  Due: \(due)")
        }
    }

    printExtracted()

    while true {
        print("\nSave? [y]es all / [n]o / [e]dit # / [e] to re-record / numbers (e.g. 1,3): ", terminator: "")
        fflush(stdout)

        let response = (readLine() ?? "y").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if response.isEmpty || response == "y" || response == "yes" {
            do {
                try pipeline.save(entries: entries)
                print("Saved \(entries.count) entries.")
                lastListed = entries
            } catch {
                print("Error saving: \(error.localizedDescription)")
            }
            return
        } else if response == "n" || response == "no" {
            print("Discarded.")
            return
        } else if response == "e" || response == "edit" {
            // Bare 'e' — re-record with existing entries as context
            await refineViaRecording(pipeline: pipeline, entries: &entries)
            printExtracted()
            continue
        } else if response.hasPrefix("e") {
            // 'e 2' — edit a specific entry field by field
            let editParts = response.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            let numStr = editParts.count > 1 ? editParts[1] : String(response.dropFirst().trimmingCharacters(in: .whitespaces))
            guard let num = Int(numStr), num >= 1, num <= entries.count else {
                print("Usage: e <#> to edit one, or just e to re-record")
                continue
            }
            editEntry(entries[num - 1], number: num)
            printExtracted()
            continue
        } else {
            // Parse comma-separated numbers
            let indices = response
                .components(separatedBy: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                .filter { $0 >= 1 && $0 <= entries.count }
                .map { $0 - 1 }

            if indices.isEmpty {
                print("No valid numbers. Discarded.")
                return
            }

            let selected = indices.map { entries[$0] }
            do {
                try pipeline.save(entries: selected)
                print("Saved \(selected.count) entries.")
                lastListed = selected
            } catch {
                print("Error saving: \(error.localizedDescription)")
            }
            return
        }
    }
}

@MainActor
func refineViaRecording(pipeline: Pipeline, entries: inout [Entry]) async {
    print("\nHow many seconds? [10]: ", terminator: "")
    fflush(stdout)
    let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let seconds = Int(input) ?? 10

    do {
        print("Recording \(seconds)s — tell me what to change, add, or remove.")
        try await pipeline.startRecording()
        await printCountdown(seconds)
        print("Processing...")
        let result = try await pipeline.refineFromRecording()
        print("Transcript: \"\(result.transcript.text)\"\n")
        entries = result.entries
    } catch {
        print("Error: \(error.localizedDescription)")
        print("Keeping current entries.")
    }
}

func editEntry(_ entry: Entry, number: Int) {
    print("\nEditing entry #\(number) — press Enter to keep current value\n")

    print("  Content [\(entry.content)]: ", terminator: "")
    fflush(stdout)
    if let val = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !val.isEmpty {
        entry.content = val
    }

    print("  Summary [\(entry.summary)]: ", terminator: "")
    fflush(stdout)
    if let val = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !val.isEmpty {
        entry.summary = val
    }

    let categories = EntryCategory.allCases.map(\.rawValue).joined(separator: ", ")
    print("  Category [\(entry.category.rawValue)] (\(categories)): ", terminator: "")
    fflush(stdout)
    if let val = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !val.isEmpty {
        if let cat = EntryCategory(rawValue: val.lowercased()) {
            entry.category = cat
        } else {
            print("  (unknown category, keeping \(entry.category.rawValue))")
        }
    }

    print("  Priority [\(entry.priority.map { "\($0)" } ?? "none")] (1-5 or 'none'): ", terminator: "")
    fflush(stdout)
    if let val = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !val.isEmpty {
        if val == "none" || val == "-" {
            entry.priority = nil
        } else if let p = Int(val), (1...5).contains(p) {
            entry.priority = p
        } else {
            print("  (invalid, keeping current)")
        }
    }

    print("  Due date [\(entry.dueDateDescription ?? "none")]: ", terminator: "")
    fflush(stdout)
    if let val = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !val.isEmpty {
        if val == "none" || val == "-" {
            entry.dueDateDescription = nil
            entry.dueDate = nil
        } else {
            entry.dueDateDescription = val
            entry.dueDate = Entry.resolveDate(from: val)
        }
    }

    print("  Updated entry #\(number).")
}

@MainActor
func handleList(store: EntryStore, args: [String], lastListed: inout [Entry]) {
    do {
        let entries: [Entry]
        let filter = args.first?.lowercased()

        if let filter {
            // Try as category
            if let cat = EntryCategory(rawValue: filter) {
                entries = try store.fetch(category: cat)
            } else if let status = EntryStatus(rawValue: filter) {
                entries = try store.fetch(status: status)
            } else {
                print("Unknown filter: \(filter)")
                print("Categories: \(EntryCategory.allCases.map(\.rawValue).joined(separator: ", "))")
                print("Statuses: \(EntryStatus.allCases.map(\.rawValue).joined(separator: ", "))")
                return
            }
        } else {
            entries = try store.fetchAll()
        }

        if entries.isEmpty {
            print("No entries\(filter.map { " matching '\($0)'" } ?? "").")
            lastListed = []
            return
        }

        lastListed = entries
        printEntryTable(entries)
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

@MainActor
func handleShow(args: [String], lastListed: [Entry]) {
    guard let numStr = args.first, let num = Int(numStr),
          num >= 1, num <= lastListed.count else {
        print("Usage: show <#>  (run 'list' first)")
        return
    }

    let entry = lastListed[num - 1]
    print("Entry #\(num)")
    print("─────────────────────────────────")
    print("  Content:    \(entry.content)")
    print("  Summary:    \(entry.summary)")
    print("  Category:   \(entry.category.displayName)")
    print("  Status:     \(entry.status.displayName)")
    print("  Priority:   \(entry.priority.map { "P\($0)" } ?? "--")")
    print("  Due:        \(entry.dueDate.map { formatLongDate($0) } ?? "--")")
    if let desc = entry.dueDateDescription {
        print("  Due (raw):  \(desc)")
    }
    print("  Source:     \(entry.source.displayName)")
    if let dur = entry.audioDuration {
        print("  Duration:   \(String(format: "%.1fs", dur))")
    }
    print("  Created:    \(formatLongDate(entry.createdAt))")
    print("  Updated:    \(formatLongDate(entry.updatedAt))")
    if let completed = entry.completedAt {
        print("  Completed:  \(formatLongDate(completed))")
    }
    print("  Transcript: \(entry.transcript)")
    print("  Source text: \(entry.sourceText)")
}

@MainActor
func handleStatus(store: EntryStore, args: [String], lastListed: [Entry]) {
    guard args.count >= 2,
          let num = Int(args[0]),
          num >= 1, num <= lastListed.count else {
        print("Usage: status <#> <active|completed|archived|snoozed>")
        return
    }

    let statusStr = args[1].lowercased()
    guard let newStatus = EntryStatus(rawValue: statusStr) else {
        print("Unknown status: \(statusStr)")
        print("Options: \(EntryStatus.allCases.map(\.rawValue).joined(separator: ", "))")
        return
    }

    let entry = lastListed[num - 1]
    do {
        try store.updateStatus(entry, to: newStatus)
        print("#\(num) \"\(entry.summary.isEmpty ? entry.content : entry.summary)\" -> \(newStatus.displayName)")
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

@MainActor
func handleDelete(store: EntryStore, args: [String], lastListed: inout [Entry]) {
    guard let numStr = args.first, let num = Int(numStr),
          num >= 1, num <= lastListed.count else {
        print("Usage: delete <#>  (run 'list' first)")
        return
    }

    let entry = lastListed[num - 1]
    print("Delete \"\(entry.summary.isEmpty ? entry.content : entry.summary)\"? [y/n]: ", terminator: "")
    fflush(stdout)

    let response = (readLine() ?? "n").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard response == "y" || response == "yes" else {
        print("Cancelled.")
        return
    }

    do {
        try store.delete(entry)
        lastListed.remove(at: num - 1)
        print("Deleted.")
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

@MainActor
func handleClear(store: EntryStore, lastListed: inout [Entry]) {
    do {
        let count = try store.count()
        if count == 0 {
            print("No entries to delete.")
            return
        }

        print("Delete all \(count) entries? [y/n]: ", terminator: "")
        fflush(stdout)

        let response = (readLine() ?? "n").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard response == "y" || response == "yes" else {
            print("Cancelled.")
            return
        }

        try store.deleteAll()
        lastListed = []
        print("Deleted \(count) entries.")
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

@MainActor
func handleStats(store: EntryStore) {
    do {
        let total = try store.count()
        if total == 0 {
            print("No entries.")
            return
        }

        print("Total: \(total) entries\n")

        print("By category:")
        for cat in EntryCategory.allCases {
            let n = try store.count(category: cat)
            if n > 0 { print("  \(cat.displayName.padding(toLength: 12, withPad: " ", startingAt: 0)) \(n)") }
        }

        print("\nBy status:")
        for status in EntryStatus.allCases {
            let n = try store.count(status: status)
            if n > 0 { print("  \(status.displayName.padding(toLength: 12, withPad: " ", startingAt: 0)) \(n)") }
        }

        print("\nBy source:")
        for source in EntrySource.allCases {
            let n = try store.count(source: source)
            if n > 0 { print("  \(source.displayName.padding(toLength: 12, withPad: " ", startingAt: 0)) \(n)") }
        }
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

func printHelp() {
    print("""
    Commands:
      record [secs]       rec, r    Record voice (default 10s) -> extract -> confirm
      text                t         Multi-line text input -> extract -> confirm
      list [filter]       ls, l     List entries. Filter: category or status name
      show <#>            s         Show entry details
      status <#> <status> st        Change entry status
      delete <#>          del, rm   Delete an entry
      clear                         Delete all entries
      stats                         Counts by category and status
      help                h, ?      This help
      quit                exit, q   Exit

    After record/text, confirm prompt:
      y / Enter = save all, n = discard, 1,3 = save selected
      e = re-record to refine entries, e <#> = edit one entry by field
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

// MARK: - Formatting

func printEntryTable(_ entries: [Entry]) {
    func pad(_ s: String, _ width: Int, left: Bool = false) -> String {
        if left { return s.padding(toLength: width, withPad: " ", startingAt: 0) }
        let padding = max(0, width - s.count)
        return String(repeating: " ", count: padding) + s
    }

    print("\(pad("#", 4))  \(pad("Status", 10, left: true))  \(pad("Category", 10, left: true))  \(pad("Pri", 3))  \(pad("Content", 34, left: true))  Due")
    print("\(pad("---", 4))  \(pad("----------", 10, left: true))  \(pad("----------", 10, left: true))  \(pad("---", 3))  \(pad(String(repeating: "-", count: 34), 34, left: true))  ----------")

    for (i, entry) in entries.enumerated() {
        let pri = entry.priority.map { "P\($0)" } ?? "--"
        let due = entry.dueDate.map { formatShortDate($0) }
            ?? entry.dueDateDescription
            ?? "--"
        let content = entry.summary.isEmpty ? entry.content : entry.summary
        let truncated = content.count > 34 ? String(content.prefix(31)) + "..." : content
        print("\(pad("\(i + 1)", 4))  \(pad(entry.status.rawValue, 10, left: true))  \(pad(entry.category.rawValue, 10, left: true))  \(pad(pri, 3))  \(pad(truncated, 34, left: true))  \(due)")
    }
}

private let shortDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEE MMM d"
    return f
}()

private let longDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
}()

func formatShortDate(_ date: Date) -> String {
    shortDateFormatter.string(from: date)
}

func formatLongDate(_ date: Date) -> String {
    longDateFormatter.string(from: date)
}

await main()
