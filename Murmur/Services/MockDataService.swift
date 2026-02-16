import Foundation
import SwiftData

enum MockDataService {
    // MARK: - Level 0: Empty (The Void)
    static func entriesForLevel0() -> [Entry] {
        []
    }

    // MARK: - Level 1: First Light (3 entries)
    static func entriesForLevel1() -> [Entry] {
        [
            Entry(
                summary: "Follow up with Sarah about the design mockups",
                category: .todo,
                createdAt: Date().addingTimeInterval(-7200),
                priority: 2
            ),
            Entry(
                summary: "The best ideas come when you're not actively searching for them",
                category: .insight,
                createdAt: Date().addingTimeInterval(-3600),
                priority: 1
            ),
            Entry(
                summary: "Research voice-first UI patterns for mobile apps",
                category: .idea,
                createdAt: Date().addingTimeInterval(-1800),
                priority: 1
            )
        ]
    }

    // MARK: - Level 2: Grid Awakens (15 entries, 3+ categories)
    static func entriesForLevel2() -> [Entry] {
        [
            // TODOs
            Entry(
                summary: "Review PR #234 for the authentication flow",
                category: .todo,
                createdAt: Date().addingTimeInterval(-86400),
                priority: 2
            ),
            Entry(
                summary: "Update project README with new setup instructions",
                category: .todo,
                createdAt: Date().addingTimeInterval(-72000),
                priority: 1
            ),
            Entry(
                summary: "Schedule team sync for next week",
                category: .todo,
                createdAt: Date().addingTimeInterval(-64800),
                priority: 1
            ),

            // Insights
            Entry(
                summary: "Progressive disclosure reduces cognitive load in complex interfaces",
                category: .insight,
                createdAt: Date().addingTimeInterval(-57600),
                priority: 1
            ),
            Entry(
                summary: "Voice input is faster than typing for capturing quick thoughts",
                category: .insight,
                createdAt: Date().addingTimeInterval(-50400),
                priority: 1
            ),

            // Ideas
            Entry(
                summary: "Build a browser extension for quick voice capture",
                category: .idea,
                createdAt: Date().addingTimeInterval(-43200),
                priority: 1
            ),
            Entry(
                summary: "Explore using AI to automatically categorize entries",
                category: .idea,
                createdAt: Date().addingTimeInterval(-36000),
                priority: 1
            ),
            Entry(
                summary: "Add collaborative features for team brainstorming",
                category: .idea,
                createdAt: Date().addingTimeInterval(-28800),
                priority: 0
            ),

            // Reminders
            Entry(
                summary: "Call mom this weekend",
                category: .reminder,
                createdAt: Date().addingTimeInterval(-21600),
                dueDate: Date().addingTimeInterval(172800),
                priority: 2
            ),
            Entry(
                summary: "Pay electricity bill by Friday",
                category: .reminder,
                createdAt: Date().addingTimeInterval(-14400),
                dueDate: Date().addingTimeInterval(259200),
                priority: 2
            ),

            // Questions
            Entry(
                summary: "What's the best approach for handling offline sync?",
                category: .question,
                createdAt: Date().addingTimeInterval(-10800),
                priority: 1
            ),
            Entry(
                summary: "Should we use CloudKit or build custom backend?",
                category: .question,
                createdAt: Date().addingTimeInterval(-7200),
                priority: 1
            ),

            // Notes
            Entry(
                summary: "Meeting notes: Discussed Q1 roadmap, focusing on core features first",
                category: .note,
                createdAt: Date().addingTimeInterval(-5400),
                priority: 0
            ),

            // Decisions
            Entry(
                summary: "Going with SwiftUI for faster iteration speed",
                category: .decision,
                createdAt: Date().addingTimeInterval(-3600),
                priority: 1
            ),

            // Learning
            Entry(
                summary: "Learned about SwiftData model containers and configurations",
                category: .learning,
                createdAt: Date().addingTimeInterval(-1800),
                priority: 0
            )
        ]
    }

    // MARK: - Level 3: Views Emerge (25 entries)
    static func entriesForLevel3() -> [Entry] {
        var entries = entriesForLevel2()

        // Add 10 more entries
        entries.append(contentsOf: [
            Entry(
                summary: "Refactor the recording state machine",
                category: .todo,
                createdAt: Date().addingTimeInterval(-90000),
                priority: 2
            ),
            Entry(
                summary: "Write unit tests for entry categorization",
                category: .todo,
                createdAt: Date().addingTimeInterval(-82800),
                priority: 1
            ),
            Entry(
                summary: "The constraint of limited tokens makes every word count",
                category: .insight,
                createdAt: Date().addingTimeInterval(-75600),
                priority: 1
            ),
            Entry(
                summary: "Add dark mode support (oh wait, it's dark-only!)",
                category: .idea,
                createdAt: Date().addingTimeInterval(-68400),
                priority: 0
            ),
            Entry(
                summary: "Doctor appointment on Thursday at 3pm",
                category: .reminder,
                createdAt: Date().addingTimeInterval(-61200),
                dueDate: Date().addingTimeInterval(172800),
                priority: 2
            ),
            Entry(
                summary: "How to handle really long voice inputs that exceed token limits?",
                category: .question,
                createdAt: Date().addingTimeInterval(-54000),
                priority: 1
            ),
            Entry(
                summary: "Lunch with Alex: Discussed new project ideas and potential collaboration",
                category: .note,
                createdAt: Date().addingTimeInterval(-46800),
                priority: 0
            ),
            Entry(
                summary: "Using Nix for reproducible development environments",
                category: .decision,
                createdAt: Date().addingTimeInterval(-39600),
                priority: 1
            ),
            Entry(
                summary: "Discovered XcodeGen for managing project configurations",
                category: .learning,
                createdAt: Date().addingTimeInterval(-32400),
                priority: 0
            ),
            Entry(
                summary: "Build a prototype for gesture-based voice recording",
                category: .idea,
                createdAt: Date().addingTimeInterval(-25200),
                priority: 1
            )
        ])

        return entries
    }

    // MARK: - Level 4: Full Power (60 entries)
    static func entriesForLevel4() -> [Entry] {
        var entries = entriesForLevel3()

        // Add many more varied entries
        let additionalSummaries = [
            ("Fix the waveform animation stuttering on older devices", EntryCategory.todo, 2),
            ("Implement swipe actions for entry cards", EntryCategory.todo, 1),
            ("Add haptic feedback for recording start/stop", EntryCategory.todo, 1),
            ("Test voice recognition accuracy in noisy environments", EntryCategory.todo, 1),
            ("Optimize SwiftData queries for better performance", EntryCategory.todo, 2),

            ("Simplicity is the ultimate sophistication", EntryCategory.insight, 1),
            ("Users judge interfaces in milliseconds, not minutes", EntryCategory.insight, 1),
            ("The best interface is no interface", EntryCategory.insight, 0),
            ("Constraints breed creativity", EntryCategory.insight, 1),

            ("Explore using machine learning for priority suggestions", EntryCategory.idea, 1),
            ("Create a watch app for quick voice capture", EntryCategory.idea, 1),
            ("Add support for multiple languages", EntryCategory.idea, 0),
            ("Build integration with calendar apps", EntryCategory.idea, 1),
            ("Create custom views for different entry types", EntryCategory.idea, 1),

            ("Submit tax documents by end of month", EntryCategory.reminder, 2),
            ("Renew gym membership", EntryCategory.reminder, 1),
            ("Buy groceries for the week", EntryCategory.reminder, 2),
            ("Water the plants", EntryCategory.reminder, 1),
            ("Return library books", EntryCategory.reminder, 1),

            ("What's the best way to handle error states?", EntryCategory.question, 1),
            ("Should entries be automatically archived after completion?", EntryCategory.question, 1),
            ("How to balance between features and simplicity?", EntryCategory.question, 1),
            ("What metrics matter most for voice interfaces?", EntryCategory.question, 1),

            ("Team standup: Everyone on track for sprint goals", EntryCategory.note, 0),
            ("Podcast notes: Interview with design leader about AI", EntryCategory.note, 0),
            ("Book notes: Make It Stick - learning requires effort", EntryCategory.note, 0),
            ("Conference takeaway: Voice is the next UI frontier", EntryCategory.note, 0),

            ("Choosing quality over speed for initial launch", EntryCategory.decision, 1),
            ("Decided to use progressive disclosure for feature reveal", EntryCategory.decision, 1),
            ("Going with token-based pricing model", EntryCategory.decision, 1),

            ("Understanding SwiftUI's new Observable macro", EntryCategory.learning, 0),
            ("Learned about proper git commit message conventions", EntryCategory.learning, 0),
            ("Discovered the power of keyboard shortcuts in Xcode", EntryCategory.learning, 0),
            ("Understanding the difference between @State and @Environment", EntryCategory.learning, 0),
            ("How to properly structure SwiftUI previews", EntryCategory.learning, 0)
        ]

        for (i, (summary, category, priority)) in additionalSummaries.enumerated() {
            entries.append(
                Entry(
                    summary: summary,
                    category: category,
                    createdAt: Date().addingTimeInterval(-Double((i + 1) * 3600)),
                    priority: priority
                )
            )
        }

        return entries
    }

    // MARK: - Get Entries for Level
    static func entries(for level: DisclosureLevel) -> [Entry] {
        switch level {
        case .void:
            return entriesForLevel0()
        case .firstLight:
            return entriesForLevel1()
        case .gridAwakens:
            return entriesForLevel2()
        case .viewsEmerge:
            return entriesForLevel3()
        case .fullPower:
            return entriesForLevel4()
        }
    }
}
