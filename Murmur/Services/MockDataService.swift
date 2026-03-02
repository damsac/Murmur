import Foundation
import SwiftData
import MurmurCore

enum MockDataService {
    // MARK: - Level 0: Empty (The Void)
    static func entriesForLevel0() -> [Entry] {
        []
    }

    // MARK: - Level 1: First Light (3 entries)
    static func entriesForLevel1() -> [Entry] {
        [
            Entry(
                transcript: "",
                content: "Follow up with Sarah about the design mockups",
                category: .todo,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-7200),
                summary: "Follow up with Sarah about the design mockups",
                priority: 1
            ),
            Entry(
                transcript: "",
                content: "The best ideas come when you're not actively searching for them",
                category: .note,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-3600),
                summary: "The best ideas come when you're not actively searching for them",
                priority: 3
            ),
            Entry(
                transcript: "",
                content: "Research voice-first UI patterns for mobile apps",
                category: .idea,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-1800),
                summary: "Research voice-first UI patterns for mobile apps",
                priority: 3
            )
        ]
    }

    // MARK: - Level 2: Grid Awakens (15 entries, 3+ categories)
    // swiftlint:disable:next function_body_length
    static func entriesForLevel2() -> [Entry] {
        [
            // TODOs
            Entry(
                transcript: "",
                content: "Review PR #234 for the authentication flow",
                category: .todo,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-86400),
                summary: "Review PR #234 for the authentication flow",
                priority: 1
            ),
            Entry(
                transcript: "",
                content: "Update project README with new setup instructions",
                category: .todo,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-72000),
                summary: "Update project README with new setup instructions",
                priority: 3
            ),
            Entry(
                transcript: "",
                content: "Schedule team sync for next week",
                category: .todo,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-64800),
                summary: "Schedule team sync for next week",
                priority: 3
            ),

            // Thoughts (was Insights)
            Entry(
                transcript: "",
                content: "Progressive disclosure reduces cognitive load in complex interfaces",
                category: .note,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-57600),
                summary: "Progressive disclosure reduces cognitive load in complex interfaces",
                priority: 3
            ),
            Entry(
                transcript: "",
                content: "Voice input is faster than typing for capturing quick thoughts",
                category: .note,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-50400),
                summary: "Voice input is faster than typing for capturing quick thoughts",
                priority: 3
            ),

            // Ideas
            Entry(
                transcript: "",
                content: "Build a browser extension for quick voice capture",
                category: .idea,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-43200),
                summary: "Build a browser extension for quick voice capture",
                priority: 3
            ),
            Entry(
                transcript: "",
                content: "Explore using AI to automatically categorize entries",
                category: .idea,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-36000),
                summary: "Explore using AI to automatically categorize entries",
                priority: 3
            ),
            Entry(
                transcript: "",
                content: "Add collaborative features for team brainstorming",
                category: .idea,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-28800),
                summary: "Add collaborative features for team brainstorming",
                priority: 5
            ),

            // Reminders
            Entry(
                transcript: "",
                content: "Call mom this weekend",
                category: .reminder,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-21600),
                summary: "Call mom this weekend",
                priority: 1,
                dueDate: Date().addingTimeInterval(172800)
            ),
            Entry(
                transcript: "",
                content: "Pay electricity bill by Friday",
                category: .reminder,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-14400),
                summary: "Pay electricity bill by Friday",
                priority: 1,
                dueDate: Date().addingTimeInterval(259200)
            ),

            // Questions
            Entry(
                transcript: "",
                content: "What's the best approach for handling offline sync?",
                category: .question,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-10800),
                summary: "What's the best approach for handling offline sync?",
                priority: 3
            ),
            Entry(
                transcript: "",
                content: "Should we use CloudKit or build custom backend?",
                category: .question,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-7200),
                summary: "Should we use CloudKit or build custom backend?",
                priority: 3
            ),

            // Notes
            Entry(
                transcript: "",
                content: "Meeting notes: Discussed Q1 roadmap, focusing on core features first",
                category: .note,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-5400),
                summary: "Meeting notes: Discussed Q1 roadmap, focusing on core features first",
                priority: 5
            ),

            // Notes (was Decisions)
            Entry(
                transcript: "",
                content: "Going with SwiftUI for faster iteration speed",
                category: .note,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-3600),
                summary: "Going with SwiftUI for faster iteration speed",
                priority: 3
            ),

            // Habits (was Learning)
            Entry(
                transcript: "",
                content: "Learned about SwiftData model containers and configurations",
                category: .habit,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-1800),
                summary: "Learned about SwiftData model containers and configurations",
                priority: 5
            )
        ]
    }

    // MARK: - Level 3: Views Emerge (25 entries)
    static func entriesForLevel3() -> [Entry] {
        var entries = entriesForLevel2()

        // Add 10 more entries
        entries.append(contentsOf: [
            Entry(
                transcript: "",
                content: "Refactor the recording state machine",
                category: .todo,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-90000),
                summary: "Refactor the recording state machine",
                priority: 1
            ),
            Entry(
                transcript: "",
                content: "Write unit tests for entry categorization",
                category: .todo,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-82800),
                summary: "Write unit tests for entry categorization",
                priority: 3
            ),
            Entry(
                transcript: "",
                content: "The constraint of limited tokens makes every word count",
                category: .note,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-75600),
                summary: "The constraint of limited tokens makes every word count",
                priority: 3
            ),
            Entry(
                transcript: "",
                content: "Add dark mode support (oh wait, it's dark-only!)",
                category: .idea,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-68400),
                summary: "Add dark mode support (oh wait, it's dark-only!)",
                priority: 5
            ),
            Entry(
                transcript: "",
                content: "Doctor appointment on Thursday at 3pm",
                category: .reminder,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-61200),
                summary: "Doctor appointment on Thursday at 3pm",
                priority: 1,
                dueDate: Date().addingTimeInterval(172800)
            ),
            Entry(
                transcript: "",
                content: "How to handle really long voice inputs that exceed token limits?",
                category: .question,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-54000),
                summary: "How to handle really long voice inputs that exceed token limits?",
                priority: 3
            ),
            Entry(
                transcript: "",
                content: "Lunch with Alex: Discussed new project ideas and potential collaboration",
                category: .note,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-46800),
                summary: "Lunch with Alex: Discussed new project ideas and potential collaboration",
                priority: 5
            ),
            Entry(
                transcript: "",
                content: "Using Nix for reproducible development environments",
                category: .note,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-39600),
                summary: "Using Nix for reproducible development environments",
                priority: 3
            ),
            Entry(
                transcript: "",
                content: "Discovered XcodeGen for managing project configurations",
                category: .habit,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-32400),
                summary: "Discovered XcodeGen for managing project configurations",
                priority: 5
            ),
            Entry(
                transcript: "",
                content: "Build a prototype for gesture-based voice recording",
                category: .idea,
                sourceText: "",
                createdAt: Date().addingTimeInterval(-25200),
                summary: "Build a prototype for gesture-based voice recording",
                priority: 3
            )
        ])

        return entries
    }

    // MARK: - Level 4: Full Power (60 entries)
    static func entriesForLevel4() -> [Entry] {
        var entries = entriesForLevel3()

        // Add many more varied entries
        let additionalEntries: [(String, EntryCategory, Int?)] = [
            ("Fix the waveform animation stuttering on older devices", .todo, 1),
            ("Implement swipe actions for entry cards", .todo, 3),
            ("Add haptic feedback for recording start/stop", .todo, 3),
            ("Test voice recognition accuracy in noisy environments", .todo, 3),
            ("Optimize SwiftData queries for better performance", .todo, 1),

            ("Simplicity is the ultimate sophistication", .note, 3),
            ("Users judge interfaces in milliseconds, not minutes", .note, 3),
            ("The best interface is no interface", .note, 5),
            ("Constraints breed creativity", .note, 3),

            ("Explore using machine learning for priority suggestions", .idea, 3),
            ("Create a watch app for quick voice capture", .idea, 3),
            ("Add support for multiple languages", .idea, 5),
            ("Build integration with calendar apps", .idea, 3),
            ("Create custom views for different entry types", .idea, 3),

            ("Submit tax documents by end of month", .reminder, 1),
            ("Renew gym membership", .reminder, 3),
            ("Buy groceries for the week", .reminder, 1),
            ("Water the plants", .reminder, 3),
            ("Return library books", .reminder, 3),

            ("What's the best way to handle error states?", .question, 3),
            ("Should entries be automatically archived after completion?", .question, 3),
            ("How to balance between features and simplicity?", .question, 3),
            ("What metrics matter most for voice interfaces?", .question, 3),

            ("Team standup: Everyone on track for sprint goals", .note, 5),
            ("Podcast notes: Interview with design leader about AI", .note, 5),
            ("Book notes: Make It Stick - learning requires effort", .note, 5),
            ("Conference takeaway: Voice is the next UI frontier", .note, 5),

            ("Choosing quality over speed for initial launch", .note, 3),
            ("Decided to use progressive disclosure for feature reveal", .note, 3),
            ("Going with token-based pricing model", .note, 3),

            ("Understanding SwiftUI's new Observable macro", .habit, 5),
            ("Learned about proper git commit message conventions", .habit, 5),
            ("Discovered the power of keyboard shortcuts in Xcode", .habit, 5),
            ("Understanding the difference between @State and @Environment", .habit, 5),
            ("How to properly structure SwiftUI previews", .habit, 5)
        ]

        for (i, (text, category, priority)) in additionalEntries.enumerated() {
            entries.append(
                Entry(
                    transcript: "",
                    content: text,
                    category: category,
                    sourceText: "",
                    createdAt: Date().addingTimeInterval(-Double((i + 1) * 3600)),
                    summary: text,
                    priority: priority
                )
            )
        }

        return entries
    }

}
