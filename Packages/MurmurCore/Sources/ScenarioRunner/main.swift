import Foundation
import MurmurCore

// MARK: - Scenario Definition

struct Scenario {
    let name: String
    let description: String
    let transcript: String
    /// Follow-up turns for multi-turn refinement scenarios
    let followUps: [String]

    init(_ name: String, description: String, transcript: String, followUps: [String] = []) {
        self.name = name
        self.description = description
        self.transcript = transcript
        self.followUps = followUps
    }
}

// MARK: - Scenarios

let scenarios: [Scenario] = [
    // --- Single-turn: basics ---

    Scenario(
        "01_clean_multi_item",
        description: "Clear, well-spoken transcript with distinct actionable items",
        transcript: "I need to buy groceries this afternoon, call the dentist to reschedule my appointment to next Friday, and finish writing the quarterly report by end of day tomorrow."
    ),

    Scenario(
        "02_category_diversity",
        description: "One transcript containing every category type",
        transcript: """
        OK so a few things. First I need to pick up my dry cleaning today, that's the most important. \
        Also the WiFi password at the new office is capital B raindrop seven seven four. \
        Oh and I have a dentist appointment next Wednesday at 2 PM don't let me forget. \
        I had this idea for an app that lets you scan restaurant menus and tells you calorie counts. \
        For the grocery store I need eggs milk bread peanut butter and bananas. \
        I really should start doing twenty minutes of stretching every morning. \
        What's the name of that book Sarah recommended last week? I keep forgetting. \
        I've been noticing I'm way more productive when I work from the coffee shop versus at home.
        """
    ),

    // --- Single-turn: messy speech ---

    Scenario(
        "03_filler_words_restarts",
        description: "Transcript full of um, uh, false starts, and self-corrections typical of real speech-to-text",
        transcript: """
        Um so I was thinking about uh I need to I need to go to the store and pick up like um \
        some milk and also uh what was it oh yeah I should probably also get eggs. \
        And then uh oh wait actually no not eggs I already have eggs. \
        I need to get butter. And um there was something else oh right \
        I have to I have to call the landlord about the um the leak in the bathroom. \
        That's been going on for like two weeks now it's kind of urgent.
        """
    ),

    Scenario(
        "04_garbled_transcription",
        description: "Realistic speech-to-text errors: proper nouns and technical terms garbled without explanation",
        transcript: """
        I need to send the proposal to micro Chang by end of day. \
        Also set up a meeting with the Cooper netties team about the X migration, \
        that's pretty urgent. \
        And remind me to check the fig my designs that pre a shared last week.
        """
    ),

    // --- Single-turn: time/date edge cases ---

    Scenario(
        "05_time_references",
        description: "Dense time and date references in various formats",
        transcript: """
        OK here's my schedule stuff. The report is due by end of week. \
        I have a meeting tomorrow at 3 PM. \
        Need to book flights for the conference in two weeks. \
        Remind me to take the medicine in about 45 minutes. \
        The lease renewal needs to be signed by March 15th. \
        I should start prepping for the presentation next Monday morning. \
        And at some point this weekend I need to clean the garage.
        """
    ),

    // --- Single-turn: priority signals ---

    Scenario(
        "06_priority_signals",
        description: "Items with varying urgency cues — should map to different priority levels",
        transcript: """
        This is super urgent, the client proposal needs to go out today or we lose the deal. \
        When I get a chance I should reorganize my bookshelf. \
        It's pretty important that I follow up with the recruiter by tomorrow, \
        they said the position is filling fast. \
        Low priority but eventually I want to look into getting a standing desk. \
        I absolutely must remember to pick up my prescription before the pharmacy closes at 6.
        """
    ),

    // --- Single-turn: edge cases ---

    Scenario(
        "07_long_ramble_single_idea",
        description: "One idea spread across many sentences — should consolidate into one or two entries, not fragment",
        transcript: """
        So I've been thinking about this thing where like what if we built a tool \
        that automatically summarizes your meetings and then creates action items from them \
        and it could integrate with Slack so it posts the summary right after the meeting ends \
        and then it tags the people who were assigned action items \
        and maybe it could even follow up with them if they haven't completed the items by the due date. \
        Like a smart meeting assistant basically. I think there's a real market for that.
        """
    ),

    Scenario(
        "08_rapid_fire_list",
        description: "Rapid enumeration of 10+ items in grocery-list style",
        transcript: """
        Grocery list: eggs, milk, bread, peanut butter, bananas, chicken breast, \
        rice, olive oil, garlic, onions, tomatoes, spinach, Greek yogurt, \
        almonds, and dark chocolate. Oh and we're out of dish soap and paper towels.
        """
    ),

    Scenario(
        "09_no_actionable_content",
        description: "Pure stream of consciousness with no todos, reminders, or clear action items",
        transcript: """
        I've been thinking about how weird it is that we spend so much time on our phones. \
        Like my screen time last week was something like six hours a day which is kind of insane. \
        I wonder if people in the nineties felt the same way about TV. \
        Anyway the weather has been really nice lately. \
        I noticed the cherry blossoms are starting to bloom on my street. \
        Spring always makes me feel more optimistic about things.
        """
    ),

    Scenario(
        "10_duplicate_overlapping",
        description: "Same item mentioned multiple ways — should deduplicate or merge, not create separate entries",
        transcript: """
        I need to email the team about the deadline change. \
        Oh and I should send a message to the team letting them know the deadline moved. \
        Actually yeah the main thing is just communicate to everyone that the project deadline \
        is now two weeks later than we originally planned. \
        Also separately I need to buy a birthday present for mom.
        """
    ),

    Scenario(
        "11_mixed_languages_slang",
        description: "Informal language, abbreviations, and conversational tone",
        transcript: """
        Yo I gotta hit up Target later for some stuff. \
        Also DM Jake about the BBQ this Saturday, he said he's bringing his plus one. \
        Need to RSVP to that wedding thing ASAP, it's Sara and Tom's, the one in Napa. \
        FYI my car registration expires end of month so I should handle that. \
        And tbh I should probably start studying for the cert exam, been procrastinating hard.
        """
    ),

    // --- Multi-turn: refinement scenarios ---

    Scenario(
        "12_add_items",
        description: "Multi-turn: initial extraction then add more items via voice",
        transcript: "I need to buy groceries and finish the quarterly report by Friday.",
        followUps: [
            "Oh wait I also need to call my mom tonight and book a vet appointment for the dog for sometime next week.",
        ]
    ),

    Scenario(
        "13_remove_item",
        description: "Multi-turn: initial extraction then remove one item",
        transcript: "Pick up dry cleaning, buy milk, and call the electrician about the kitchen light.",
        followUps: [
            "Actually never mind about the milk, we already have some. Remove that one.",
        ]
    ),

    Scenario(
        "14_modify_item",
        description: "Multi-turn: initial extraction then change priority and details of existing items",
        transcript: "I need to finish the budget spreadsheet and email the client about the delay.",
        followUps: [
            "Actually the client email is really urgent, make that the highest priority. And for the spreadsheet, the deadline is actually next Wednesday not this week.",
        ]
    ),

    Scenario(
        "15_replace_item",
        description: "Multi-turn: swap one item for another",
        transcript: "Buy milk, eggs, and bread from the store.",
        followUps: [
            "Change milk to oat milk. And actually instead of bread get tortillas.",
        ]
    ),

    Scenario(
        "16_garbled_refinement",
        description: "Multi-turn: follow-up instruction is poorly transcribed, model must fuzzy-match",
        transcript: "Send the proposal to Michael Chen and schedule a meeting with the design team.",
        followUps: [
            "For the thing about my cold chen make that due by Thursday and mark it high priority.",
        ]
    ),

    Scenario(
        "17_complex_multi_turn",
        description: "Multi-turn: three rounds of refinement — add, modify, and reorganize",
        transcript: "I need to prepare the investor deck, book travel for the conference, and review the Q4 numbers.",
        followUps: [
            "Add a reminder to send thank you notes after the conference. And the investor deck is the most urgent, needs to be done by Monday.",
            "Actually split the investor deck into two tasks: one for writing the narrative and one for building the financial model. The narrative is due Monday, the model is due Wednesday.",
        ]
    ),
]

// MARK: - Runner

@MainActor
func run() async {
    guard let apiKey = ProcessInfo.processInfo.environment["PPQ_API_KEY"], !apiKey.isEmpty else {
        print("Error: PPQ_API_KEY environment variable not set")
        exit(1)
    }

    let outputDir = "ScenarioResults"

    // Check output directory exists
    let fm = FileManager.default
    if !fm.fileExists(atPath: outputDir) {
        // swiftlint:disable:next force_try
        try! fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
    }

    let llm = PPQLLMService(apiKey: apiKey)

    print("Running \(scenarios.count) scenarios...\n")

    for scenario in scenarios {
        print("[\(scenario.name)] \(scenario.description)")
        var output = ""
        output += "# Scenario: \(scenario.name)\n"
        output += "\(scenario.description)\n"
        output += String(repeating: "=", count: 72) + "\n\n"

        let conversation = LLMConversation()

        // Turn 1: initial extraction
        output += "## Turn 1 — Initial Extraction\n\n"
        output += "### Input Transcript\n"
        output += scenario.transcript + "\n\n"

        do {
            let entries = try await llm.extractEntries(from: scenario.transcript, conversation: conversation)
            output += formatEntries(entries, turn: 1)
        } catch {
            output += "### ERROR\n\(error.localizedDescription)\n\n"
            print("  ERROR on turn 1: \(error.localizedDescription)")
        }

        // Follow-up turns
        for (i, followUp) in scenario.followUps.enumerated() {
            let turnNum = i + 2
            output += "## Turn \(turnNum) — Refinement\n\n"
            output += "### Input Transcript\n"
            output += followUp + "\n\n"

            do {
                let entries = try await llm.extractEntries(from: followUp, conversation: conversation)
                output += formatEntries(entries, turn: turnNum)
            } catch {
                output += "### ERROR\n\(error.localizedDescription)\n\n"
                print("  ERROR on turn \(turnNum): \(error.localizedDescription)")
            }
        }

        // Write output file
        let filePath = "\(outputDir)/\(scenario.name).md"
        // swiftlint:disable:next force_try
        try! output.write(toFile: filePath, atomically: true, encoding: .utf8)
        print("  -> \(filePath)")

        // Small delay between scenarios to avoid rate limiting
        try? await Task.sleep(for: .milliseconds(500))
    }

    print("\nDone. Results written to \(outputDir)/")
}

func formatEntries(_ entries: [ExtractedEntry], turn: Int) -> String {
    var out = "### Extracted Entries (\(entries.count))\n\n"

    if entries.isEmpty {
        out += "_No entries extracted._\n\n"
        return out
    }

    for (i, entry) in entries.enumerated() {
        out += "**\(i + 1). [\(entry.category.rawValue.uppercased())]** \(entry.content)\n"
        if !entry.summary.isEmpty {
            out += "- Summary: \(entry.summary)\n"
        }
        if let p = entry.priority {
            out += "- Priority: P\(p)\n"
        }
        if let d = entry.dueDateDescription {
            out += "- Due: \(d)\n"
        }
        out += "- Source text: \"\(entry.sourceText)\"\n"
        out += "\n"
    }

    return out
}

await run()
