import SwiftUI

struct DevComponentGallery: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedComponent: DevComponent?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.bgDeep
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header description
                        Text("Browse all \(DevComponent.allCases.count) components in isolation with multiple states and variants.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Theme.Spacing.screenPadding)
                            .padding(.top, 8)

                        // Sections
                        ForEach(DevComponentSection.allCases) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                // Section header
                                HStack(spacing: 8) {
                                    Image(systemName: section.icon)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.Colors.accentPurple)

                                    Text(section.rawValue)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Theme.Colors.textPrimary)

                                    Text("\(section.components.count)")
                                        .font(Theme.Typography.badge)
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(Theme.Colors.bgCard)
                                        )
                                }
                                .padding(.horizontal, Theme.Spacing.screenPadding)

                                // Component rows
                                LazyVStack(spacing: 1) {
                                    ForEach(section.components) { component in
                                        ComponentRow(component: component) {
                                            selectedComponent = component
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Component Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.Colors.accentPurple)
                }
            }
            .sheet(item: $selectedComponent) { component in
                DevComponentDetailView(component: component)
            }
        }
    }
}

// MARK: - Component Row

private struct ComponentRow: View {
    let component: DevComponent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Component name
                VStack(alignment: .leading, spacing: 4) {
                    Text(component.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text(component.description)
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
            .padding(.vertical, 14)
            .background(Theme.Colors.bgCard)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Component Detail View

struct DevComponentDetailView: View {
    let component: DevComponent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.bgDeep
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        componentContent
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle(component.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.Colors.accentPurple)
                }
            }
        }
    }

    @ViewBuilder
    private var componentContent: some View {
        switch component {
        case .micButton:
            MicButtonGallery()
        case .inputBar:
            InputBarGallery()
        case .filterChips:
            FilterChipsGallery()
        case .bottomNavBar:
            BottomNavBarGallery()
        case .categoryBadge:
            CategoryBadgeGallery()
        case .tokenBalance:
            TokenBalanceGallery()
        case .toastView:
            ToastViewGallery()
        case .waveformView:
            WaveformViewGallery()
        case .pulsingMic:
            PulsingMicGallery()
        case .recordingOverlay:
            RecordingOverlayGallery()
        case .processingOverlay:
            ProcessingOverlayGallery()
        case .focusOverlay:
            FocusOverlayGallery()
        case .navHeader:
            NavHeaderGallery()
        case .settingsRow:
            SettingsRowGallery()
        case .entryCard:
            EntryCardGallery()
        case .reminderCard:
            ReminderCardGallery()
        case .confirmItemCard:
            ConfirmItemCardGallery()
        case .todoListItem:
            TodoListItemGallery()
        }
    }
}

// MARK: - Gallery Section Helper

private struct GallerySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.Typography.label)
                .foregroundStyle(Theme.Colors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.horizontal, Theme.Spacing.screenPadding)

            content()
        }
    }
}

// MARK: - MicButton Gallery

private struct MicButtonGallery: View {
    @State private var isRecording = false

    var body: some View {
        GallerySection(title: "Sizes") {
            HStack(spacing: 40) {
                VStack(spacing: 12) {
                    MicButton(size: .small, isRecording: false) {}
                    Text("Small (52pt)")
                        .font(Theme.Typography.badge)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                VStack(spacing: 12) {
                    MicButton(size: .large, isRecording: false) {}
                    Text("Large (64pt)")
                        .font(Theme.Typography.badge)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }

        GallerySection(title: "Recording States") {
            HStack(spacing: 40) {
                VStack(spacing: 12) {
                    MicButton(size: .large, isRecording: false) {}
                    Text("Idle")
                        .font(Theme.Typography.badge)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                VStack(spacing: 12) {
                    MicButton(size: .large, isRecording: true) {}
                    Text("Recording")
                        .font(Theme.Typography.badge)
                        .foregroundStyle(Theme.Colors.accentRed)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }

        GallerySection(title: "Interactive") {
            VStack(spacing: 12) {
                MicButton(size: .large, isRecording: isRecording) {
                    isRecording.toggle()
                }

                Text("Tap to toggle recording")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }
}

// MARK: - InputBar Gallery

private struct InputBarGallery: View {
    @State private var emptyText = ""
    @State private var filledText = "Review design system"
    @State private var longText = "This is a much longer message that spans multiple lines to test the text field expansion behavior and see how it handles wrapping"

    var body: some View {
        GallerySection(title: "Empty") {
            InputBar(
                text: $emptyText,
                placeholder: "Type or speak...",
                isRecording: false,
                onMicTap: {},
                onSubmit: {}
            )
        }

        GallerySection(title: "With Text") {
            InputBar(
                text: $filledText,
                placeholder: "Type or speak...",
                isRecording: false,
                onMicTap: {},
                onSubmit: {}
            )
        }

        GallerySection(title: "Recording") {
            InputBar(
                text: .constant(""),
                placeholder: "Type or speak...",
                isRecording: true,
                onMicTap: {},
                onSubmit: {}
            )
        }

        GallerySection(title: "Multiline") {
            InputBar(
                text: $longText,
                placeholder: "Type or speak...",
                isRecording: false,
                onMicTap: {},
                onSubmit: {}
            )
        }
    }
}

// MARK: - FilterChips Gallery

private struct FilterChipsGallery: View {
    @State private var selected1: String? = "todo"
    @State private var selected2: String?

    var body: some View {
        GallerySection(title: "With Selection") {
            FilterChips(
                filters: [
                    FilterChips.Filter(id: "all", label: "All"),
                    FilterChips.Filter(id: "todo", label: "Todo"),
                    FilterChips.Filter(id: "insight", label: "Insights"),
                    FilterChips.Filter(id: "idea", label: "Ideas"),
                    FilterChips.Filter(id: "reminder", label: "Reminders"),
                ],
                selectedFilter: $selected1
            )
        }

        GallerySection(title: "No Selection") {
            FilterChips(
                filters: [
                    FilterChips.Filter(id: "active", label: "Active"),
                    FilterChips.Filter(id: "completed", label: "Completed"),
                    FilterChips.Filter(id: "archived", label: "Archived"),
                ],
                selectedFilter: $selected2
            )
        }
    }
}

// MARK: - BottomNavBar Gallery

private struct BottomNavBarGallery: View {
    @State private var tab1: BottomNavBar.Tab = .home
    @State private var tab2: BottomNavBar.Tab = .views

    var body: some View {
        GallerySection(title: "With Mic Spacer") {
            ZStack(alignment: .bottom) {
                BottomNavBar(selectedTab: $tab1, showMicButton: true)
                MicButton(size: .large, isRecording: false) {}
                    .offset(y: -30)
            }
            .frame(height: Theme.Spacing.bottomNavHeight + 20)
        }

        GallerySection(title: "Without Mic Button") {
            BottomNavBar(selectedTab: $tab2, showMicButton: false)
        }

        GallerySection(title: "All Tab States") {
            VStack(spacing: 8) {
                ForEach(BottomNavBar.Tab.allCases, id: \.self) { tab in
                    BottomNavBar(selectedTab: .constant(tab), showMicButton: false)
                }
            }
        }
    }
}

// MARK: - CategoryBadge Gallery

private struct CategoryBadgeGallery: View {
    var body: some View {
        GallerySection(title: "All Categories (Small)") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 12) {
                ForEach(EntryCategory.allCases, id: \.self) { category in
                    CategoryBadge(category: category, size: .small)
                }
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
        }

        GallerySection(title: "All Categories (Medium)") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 12) {
                ForEach(EntryCategory.allCases, id: \.self) { category in
                    CategoryBadge(category: category, size: .medium)
                }
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
        }

        GallerySection(title: "All Categories (Large)") {
            VStack(spacing: 12) {
                ForEach(EntryCategory.allCases, id: \.self) { category in
                    CategoryBadge(category: category, size: .large)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.screenPadding)
        }
    }
}

// MARK: - TokenBalance Gallery

private struct TokenBalanceGallery: View {
    @State private var balance: Int = 1000

    var body: some View {
        GallerySection(title: "States") {
            VStack(spacing: 16) {
                HStack {
                    Text("Normal")
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Spacer()
                    TokenBalanceLabel(balance: 1247, showWarning: false)
                }

                HStack {
                    Text("Warning")
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Spacer()
                    TokenBalanceLabel(balance: 150, showWarning: true)
                }

                HStack {
                    Text("Critical")
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Spacer()
                    TokenBalanceLabel(balance: 23, showWarning: true)
                }

                HStack {
                    Text("Empty")
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Spacer()
                    TokenBalanceLabel(balance: 0, showWarning: true)
                }
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
        }

        GallerySection(title: "Interactive") {
            VStack(spacing: 12) {
                TokenBalanceLabel(
                    balance: balance,
                    showWarning: balance < 200
                )

                Stepper("Balance: \(balance)", value: $balance, in: 0...5000, step: 50)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
        }
    }
}

// MARK: - ToastView Gallery

private struct ToastViewGallery: View {
    var body: some View {
        GallerySection(title: "All Types") {
            VStack(spacing: 12) {
                ToastView(message: "Entry saved successfully", type: .success, isShowing: .constant(true))
                ToastView(message: "Low token balance", type: .warning, isShowing: .constant(true))
                ToastView(message: "Failed to process entry", type: .error, isShowing: .constant(true))
                ToastView(message: "New feature available", type: .info, isShowing: .constant(true))
            }
        }
    }
}

// MARK: - WaveformView Gallery

private struct WaveformViewGallery: View {
    @State private var isAnimating = true

    var body: some View {
        GallerySection(title: "Animating (Recording)") {
            WaveformView(isAnimating: true)
                .frame(height: 60)
                .padding(.horizontal, 60)
        }

        GallerySection(title: "Frozen (Processing)") {
            WaveformView(isAnimating: false)
                .frame(height: 60)
                .padding(.horizontal, 60)
                .opacity(0.6)
        }

        GallerySection(title: "Interactive") {
            VStack(spacing: 16) {
                WaveformView(isAnimating: isAnimating)
                    .frame(height: 60)
                    .padding(.horizontal, 60)

                Button(isAnimating ? "Freeze" : "Animate") {
                    isAnimating.toggle()
                }
                .font(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.Colors.accentPurple)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Theme.Colors.accentPurple.opacity(0.12))
                )
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - PulsingMic Gallery

private struct PulsingMicGallery: View {
    var body: some View {
        GallerySection(title: "Default") {
            PulsingMicView()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
        }
    }
}

// MARK: - RecordingOverlay Gallery

private struct RecordingOverlayGallery: View {
    @State private var variant = 0

    private let variants: [(String, String, Int)] = [
        ("Empty", "", 1250),
        ("With Transcript", "Review the new design system and provide feedback to the team by end of week", 850),
        ("Long Transcript", "Review the new design system and provide feedback to the team. Check typography, colors, and spacing.", 450),
        ("Low Balance", "This is a recording with low token balance", 75),
        ("Zero Balance", "Running out of tokens during recording", 0),
    ]

    var body: some View {
        GallerySection(title: "Variant") {
            Picker("Variant", selection: $variant) {
                ForEach(0..<variants.count, id: \.self) { i in
                    Text(variants[i].0).tag(i)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Spacing.screenPadding)
        }

        RecordingOverlay(
            transcript: variants[variant].1,
            tokenBalance: variants[variant].2,
            onStopRecording: {}
        )
        .frame(height: 500)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, Theme.Spacing.screenPadding)
    }
}

// MARK: - ProcessingOverlay Gallery

private struct ProcessingOverlayGallery: View {
    var body: some View {
        GallerySection(title: "With Cards") {
            ProcessingOverlay(
                entries: [
                    Entry(summary: "Pick up dry cleaning before 6pm", category: .todo, priority: 2, aiGenerated: true),
                    Entry(summary: "The best interfaces are invisible", category: .insight, aiGenerated: true),
                ],
                transcript: "I need to pick up dry cleaning, and I had this thought about interfaces"
            )
            .frame(height: 500)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, Theme.Spacing.screenPadding)
        }
    }
}

// MARK: - FocusOverlay Gallery

private struct FocusOverlayGallery: View {
    @State private var category: EntryCategory = .todo

    var body: some View {
        GallerySection(title: "Category") {
            Picker("Category", selection: $category) {
                Text("Todo").tag(EntryCategory.todo)
                Text("Insight").tag(EntryCategory.insight)
                Text("Idea").tag(EntryCategory.idea)
                Text("Reminder").tag(EntryCategory.reminder)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Spacing.screenPadding)
        }

        FocusOverlay(
            entry: Entry(
                summary: focusSummary(for: category),
                category: category,
                priority: category == .todo ? 2 : 1,
                tags: ["sample"],
                aiGenerated: true
            ),
            onMarkDone: (category == .todo || category == .reminder) ? {} : nil,
            onSnooze: (category == .todo || category == .reminder) ? {} : nil,
            onDismiss: {}
        )
        .frame(height: 500)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, Theme.Spacing.screenPadding)
    }

    private func focusSummary(for category: EntryCategory) -> String {
        switch category {
        case .todo: return "Review design mockups and provide feedback"
        case .insight: return "The best interfaces are invisible"
        case .idea: return "Build a browser extension for quick voice notes"
        case .reminder: return "Team standup at 10am tomorrow"
        default: return "Sample entry for \(category.displayName)"
        }
    }
}

// MARK: - NavHeader Gallery

private struct NavHeaderGallery: View {
    var body: some View {
        GallerySection(title: "Simple Title") {
            NavHeader(title: "Settings")
        }

        GallerySection(title: "With Back Button") {
            NavHeader(
                title: "Entry Details",
                showBackButton: true,
                backAction: {},
                trailingButtons: [
                    NavHeader.NavButton(icon: "ellipsis", action: {})
                ]
            )
        }

        GallerySection(title: "Multiple Actions") {
            NavHeader(
                title: "Todo View",
                showBackButton: true,
                backAction: {},
                trailingButtons: [
                    NavHeader.NavButton(icon: "plus", action: {}),
                    NavHeader.NavButton(icon: "slider.horizontal.3", action: {})
                ]
            )
        }
    }
}

// MARK: - SettingsRow Gallery

private struct SettingsRowGallery: View {
    @State private var toggle1 = true
    @State private var toggle2 = false

    var body: some View {
        GallerySection(title: "Standard Rows") {
            VStack(spacing: 8) {
                SettingsRow(
                    icon: "person.circle",
                    iconColor: Theme.Colors.accentBlue,
                    label: "Account"
                )

                SettingsRow(
                    icon: "bell",
                    iconColor: Theme.Colors.accentYellow,
                    label: "Notifications",
                    value: "Enabled"
                )

                SettingsRow(
                    icon: "creditcard",
                    iconColor: Theme.Colors.accentGreen,
                    label: "Top Up Credits"
                )

                SettingsRow(
                    icon: "info.circle",
                    iconColor: Theme.Colors.textSecondary,
                    label: "About",
                    value: "v1.0.0"
                )
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
        }

        GallerySection(title: "Toggle Rows") {
            VStack(spacing: 8) {
                SettingsToggleRow(
                    icon: "moon",
                    iconColor: Theme.Colors.accentPurple,
                    label: "Auto-categorize entries",
                    isOn: $toggle1
                )

                SettingsToggleRow(
                    icon: "waveform",
                    iconColor: Theme.Colors.accentBlue,
                    label: "Haptic feedback",
                    isOn: $toggle2
                )
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
        }
    }
}

// MARK: - EntryCard Gallery

private struct EntryCardGallery: View {
    var body: some View {
        GallerySection(title: "Categories") {
            VStack(spacing: 16) {
                EntryCard(
                    entry: Entry(
                        summary: "Review the new design system and provide feedback to the team",
                        category: .todo,
                        priority: 2,
                        tags: ["design", "urgent"],
                        aiGenerated: true
                    )
                )

                EntryCard(
                    entry: Entry(
                        summary: "The best interfaces are invisible - they get out of the way and let users focus",
                        category: .insight,
                        createdAt: Date().addingTimeInterval(-3600),
                        aiGenerated: false
                    )
                )

                EntryCard(
                    entry: Entry(
                        summary: "Build a browser extension for quick voice notes",
                        category: .idea,
                        createdAt: Date().addingTimeInterval(-7200),
                        tags: ["extension"],
                        aiGenerated: true
                    )
                )

                EntryCard(
                    entry: Entry(
                        summary: "What's the best way to implement real-time collaboration?",
                        category: .question,
                        createdAt: Date().addingTimeInterval(-86400),
                        aiGenerated: true
                    )
                )
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
        }

        GallerySection(title: "Without Category Badge") {
            EntryCard(
                entry: Entry(
                    summary: "This card hides its category badge",
                    category: .note,
                    aiGenerated: true
                ),
                showCategory: false
            )
            .padding(.horizontal, Theme.Spacing.screenPadding)
        }
    }
}

// MARK: - ReminderCard Gallery

private struct ReminderCardGallery: View {
    var body: some View {
        GallerySection(title: "Due Date Variants") {
            VStack(spacing: 16) {
                ReminderEntryCard(
                    entry: Entry(
                        summary: "Submit quarterly report to management",
                        category: .reminder,
                        dueDate: Calendar.current.startOfDay(for: Date()),
                        priority: 2,
                        aiGenerated: true
                    ),
                    onTap: nil
                )

                ReminderEntryCard(
                    entry: Entry(
                        summary: "Schedule dentist appointment",
                        category: .reminder,
                        dueDate: Date().addingTimeInterval(86400),
                        aiGenerated: true
                    ),
                    onTap: nil
                )

                ReminderEntryCard(
                    entry: Entry(
                        summary: "Renew gym membership",
                        category: .reminder,
                        dueDate: Date().addingTimeInterval(86400 * 5),
                        aiGenerated: true
                    ),
                    onTap: nil
                )

                ReminderEntryCard(
                    entry: Entry(
                        summary: "This reminder is overdue",
                        category: .reminder,
                        dueDate: Date().addingTimeInterval(-86400),
                        priority: 2,
                        aiGenerated: true
                    ),
                    onTap: nil
                )
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
        }
    }
}

// MARK: - ConfirmItemCard Gallery

private struct ConfirmItemCardGallery: View {
    var body: some View {
        GallerySection(title: "Categories") {
            VStack(spacing: 16) {
                ConfirmItemCard(
                    entry: Entry(
                        summary: "Review the new design system and provide feedback to the team by end of week",
                        category: .todo,
                        priority: 2,
                        aiGenerated: true
                    ),
                    onVoiceCorrect: {},
                    onDiscard: {}
                )

                ConfirmItemCard(
                    entry: Entry(
                        summary: "The best interfaces are invisible - they get out of the way",
                        category: .insight,
                        aiGenerated: true
                    ),
                    onVoiceCorrect: {},
                    onDiscard: {}
                )

                ConfirmItemCard(
                    entry: Entry(
                        summary: "Build a browser extension for quick voice notes",
                        category: .idea,
                        priority: 1,
                        aiGenerated: true
                    ),
                    onVoiceCorrect: {},
                    onDiscard: {}
                )
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
        }
    }
}

// MARK: - TodoListItem Gallery

private struct TodoListItemGallery: View {
    @State private var completed1 = false
    @State private var completed2 = true
    @State private var completed3 = false

    var body: some View {
        GallerySection(title: "States (swipe left for actions)") {
            VStack(spacing: 12) {
                TodoListItem(
                    entry: Entry(
                        summary: "Review design system documentation",
                        category: .todo,
                        priority: 2
                    ),
                    isCompleted: $completed1,
                    onTap: {},
                    onComplete: {},
                    onSnooze: {},
                    onDelete: {}
                )

                TodoListItem(
                    entry: Entry(
                        summary: "Schedule team meeting for next week",
                        category: .todo,
                        priority: 1
                    ),
                    isCompleted: $completed2,
                    onTap: {},
                    onComplete: {},
                    onSnooze: {},
                    onDelete: {}
                )

                TodoListItem(
                    entry: Entry(
                        summary: "Update project README with installation instructions and getting started guide",
                        category: .todo,
                        createdAt: Date().addingTimeInterval(-7200),
                        priority: 0
                    ),
                    isCompleted: $completed3,
                    onTap: {},
                    onComplete: {},
                    onSnooze: {},
                    onDelete: {}
                )
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
        }
    }
}

#Preview {
    DevComponentGallery()
}
