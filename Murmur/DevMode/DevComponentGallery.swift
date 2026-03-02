import SwiftUI
import MurmurCore

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
        case .navHeader:
            NavHeaderGallery()
        case .settingsRow:
            SettingsRowGallery()
        case .entryCard:
            EntryCardGallery()
        case .reminderCard:
            ReminderCardGallery()
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
    @State private var tab2: BottomNavBar.Tab = .settings

    var body: some View {
        GallerySection(title: "With Mic + Keyboard") {
            BottomNavBar(
                selectedTab: $tab1,
                onMicTap: {},
                onKeyboardTap: {}
            )
        }

        GallerySection(title: "Recording State") {
            BottomNavBar(
                selectedTab: $tab2,
                isRecording: true,
                onMicTap: {},
                onKeyboardTap: {}
            )
        }

        GallerySection(title: "All Tab States") {
            VStack(spacing: 8) {
                ForEach(BottomNavBar.Tab.allCases, id: \.self) { tab in
                    BottomNavBar(selectedTab: .constant(tab), onMicTap: {})
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
                ToastView(message: "Entry saved successfully", type: .success)
                ToastView(message: "Low token balance", type: .warning)
                ToastView(message: "Failed to process entry", type: .error)
                ToastView(message: "New feature available", type: .info)
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
        GallerySection(title: "Default") {
            ProcessingOverlay(
                transcript: "I need to pick up dry cleaning, and I had this thought about interfaces"
            )
            .frame(height: 500)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, Theme.Spacing.screenPadding)
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
            SettingsGroup {
                SettingsToggleRow(
                    icon: "moon",
                    iconColor: Theme.Colors.accentPurple,
                    label: "Auto-categorize entries",
                    isOn: $toggle1
                )

                SettingsGroupDivider()

                SettingsToggleRow(
                    icon: "waveform",
                    iconColor: Theme.Colors.accentBlue,
                    label: "Haptic feedback",
                    isOn: $toggle2
                )
            }
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
                        transcript: "",
                        content: "Review the new design system and provide feedback to the team",
                        category: .todo,
                        sourceText: "",
                        summary: "Review the new design system and provide feedback to the team",
                        priority: 1
                    )
                )

                EntryCard(
                    entry: Entry(
                        transcript: "",
                        content: "The best interfaces are invisible - they get out of the way and let users focus",
                        category: .note,
                        sourceText: "",
                        createdAt: Date().addingTimeInterval(-3600),
                        summary: "The best interfaces are invisible - they get out of the way and let users focus"
                    )
                )

                EntryCard(
                    entry: Entry(
                        transcript: "",
                        content: "Build a browser extension for quick voice notes",
                        category: .idea,
                        sourceText: "",
                        createdAt: Date().addingTimeInterval(-7200),
                        summary: "Build a browser extension for quick voice notes"
                    )
                )

                EntryCard(
                    entry: Entry(
                        transcript: "",
                        content: "What's the best way to implement real-time collaboration?",
                        category: .question,
                        sourceText: "",
                        createdAt: Date().addingTimeInterval(-86400),
                        summary: "What's the best way to implement real-time collaboration?"
                    )
                )
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
        }

        GallerySection(title: "Without Category Badge") {
            EntryCard(
                entry: Entry(
                    transcript: "",
                    content: "This card hides its category badge",
                    category: .note,
                    sourceText: "",
                    summary: "This card hides its category badge"
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
                        transcript: "",
                        content: "Submit quarterly report to management",
                        category: .reminder,
                        sourceText: "",
                        summary: "Submit quarterly report to management",
                        priority: 1,
                        dueDate: Calendar.current.startOfDay(for: Date())
                    ),
                    onTap: nil
                )

                ReminderEntryCard(
                    entry: Entry(
                        transcript: "",
                        content: "Schedule dentist appointment",
                        category: .reminder,
                        sourceText: "",
                        summary: "Schedule dentist appointment",
                        dueDate: Date().addingTimeInterval(86400)
                    ),
                    onTap: nil
                )

                ReminderEntryCard(
                    entry: Entry(
                        transcript: "",
                        content: "Renew gym membership",
                        category: .reminder,
                        sourceText: "",
                        summary: "Renew gym membership",
                        dueDate: Date().addingTimeInterval(86400 * 5)
                    ),
                    onTap: nil
                )

                ReminderEntryCard(
                    entry: Entry(
                        transcript: "",
                        content: "This reminder is overdue",
                        category: .reminder,
                        sourceText: "",
                        summary: "This reminder is overdue",
                        priority: 1,
                        dueDate: Date().addingTimeInterval(-86400)
                    ),
                    onTap: nil
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
                        transcript: "",
                        content: "Review design system documentation",
                        category: .todo,
                        sourceText: "",
                        summary: "Review design system documentation",
                        priority: 1
                    ),
                    isCompleted: $completed1,
                    onTap: {},
                    onComplete: {},
                    onSnooze: {},
                    onDelete: {}
                )

                TodoListItem(
                    entry: Entry(
                        transcript: "",
                        content: "Schedule team meeting for next week",
                        category: .todo,
                        sourceText: "",
                        summary: "Schedule team meeting for next week",
                        priority: 3
                    ),
                    isCompleted: $completed2,
                    onTap: {},
                    onComplete: {},
                    onSnooze: {},
                    onDelete: {}
                )

                TodoListItem(
                    entry: Entry(
                        transcript: "",
                        content: "Update project README with installation instructions and getting started guide",
                        category: .todo,
                        sourceText: "",
                        createdAt: Date().addingTimeInterval(-7200),
                        summary: "Update project README with installation instructions and getting started guide",
                        priority: 5
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
