import SwiftUI
import SwiftData
import MurmurCore
import os.log

private let entryDetailLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "murmur", category: "Entries")

struct EntryDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationPreferences.self) private var notifPrefs
    let entry: Entry
    let onBack: () -> Void
    let onAction: (EntryAction) -> Void

    @Query(sort: \Entry.createdAt, order: .reverse) private var allEntries: [Entry]

    // Inline draft state — seeded on appear, saved on every change
    @State private var draftSummary: String = ""
    @State private var draftNotes: String = ""
    @State private var draftCategory: EntryCategory = .note
    @State private var draftPriority: Int?

    // Sheets that remain separate (date/time pickers, snooze)
    @State private var showSnoozeDialog = false
    @State private var showCustomSnoozeSheet = false
    @State private var showDueDateSheet = false
    @State private var draftDueDate: Date = Date()

    // Note dictation state
    @State private var isRecordingNote = false
    @State private var noteRecordingTask: Task<Void, Never>?

    @FocusState private var summaryFocused: Bool
    @FocusState private var notesFocused: Bool

    private static let editableCategories: [EntryCategory] = [
        .todo, .reminder, .idea, .habit, .note, .question, .list
    ]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav header — no edit button; editing is inline
                NavHeader(
                    title: "Entry",
                    showBackButton: true,
                    backAction: onBack,
                    trailingButtons: []
                )

                // Detail + edit content
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // MARK: Category picker (inline, always visible)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Self.editableCategories, id: \.self) { cat in
                                    let color = Theme.categoryColor(cat)
                                    let isSelected = draftCategory == cat
                                    Button {
                                        draftCategory = cat
                                        entry.category = cat
                                        entry.updatedAt = Date()
                                        save()
                                        NotificationService.shared.sync(entry, preferences: notifPrefs)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 7, height: 7)
                                            Text(cat.displayName)
                                                .font(Theme.Typography.label)
                                                .fontWeight(.medium)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(isSelected ? color.opacity(0.15) : Theme.Colors.bgCard)
                                        .foregroundStyle(isSelected ? color : Theme.Colors.textSecondary)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().stroke(
                                                isSelected ? color.opacity(0.4) : Theme.Colors.borderFaint,
                                                lineWidth: 1
                                            )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.bottom, 20)

                        // MARK: Summary / title (inline TextEditor)
                        Text("Summary")
                            .font(Theme.Typography.label)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(.bottom, 6)

                        TextEditor(text: $draftSummary)
                            .font(.title3)
                            .tracking(-0.01)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 72)
                            .focused($summaryFocused)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(summaryFocused
                                        ? Theme.Colors.bgCard
                                        : Theme.Colors.bgCard.opacity(0.5))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                summaryFocused
                                                    ? Theme.Colors.accentPurple.opacity(0.3)
                                                    : Theme.Colors.borderFaint,
                                                lineWidth: 1
                                            )
                                    )
                            )
                            .onChange(of: draftSummary) { _, newValue in
                                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                entry.summary = trimmed
                                entry.updatedAt = Date()
                                save()
                                NotificationService.shared.sync(entry, preferences: notifPrefs)
                            }
                            .padding(.bottom, 24)

                        // MARK: Notes (inline TextEditor, always visible)
                        HStack {
                            Text("Notes")
                                .font(Theme.Typography.label)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Spacer()
                            noteDictationButton
                        }
                        .padding(.bottom, 6)

                        ZStack(alignment: .topLeading) {
                            if draftNotes.isEmpty && !notesFocused {
                                Text("Add a note…")
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Colors.textMuted)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $draftNotes)
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 80)
                                .focused($notesFocused)
                                .padding(12)
                                .onChange(of: draftNotes) { _, newValue in
                                    if entry.category == .list {
                                        entry.content = newValue
                                    } else {
                                        entry.notes = newValue
                                    }
                                    entry.updatedAt = Date()
                                    save()
                                }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(notesFocused
                                    ? Theme.Colors.bgCard
                                    : Theme.Colors.bgCard.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            notesFocused
                                                ? Theme.Colors.accentPurple.opacity(0.3)
                                                : Theme.Colors.borderFaint,
                                            lineWidth: 1
                                        )
                                )
                        )
                        .padding(.bottom, 24)

                        // MARK: Priority picker (inline, always visible)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Priority")
                                    .font(Theme.Typography.label)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                Spacer()
                                Text("1 = highest")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textMuted)
                            }

                            HStack(spacing: 8) {
                                priorityPill(label: "None", value: nil)
                                ForEach(1...5, id: \.self) { p in
                                    priorityPill(label: "\(p)", value: p)
                                }
                            }
                        }
                        .padding(.bottom, 28)

                        // MARK: Due date row (todos and reminders only)
                        if draftCategory == .todo || draftCategory == .reminder {
                            DueDateRow(entry: entry) {
                                draftDueDate = entry.dueDate ?? Date()
                                showDueDateSheet = true
                            }
                        }

                        // MARK: Cadence pill row (habits only)
                        if draftCategory == .habit {
                            CadencePicker(entry: entry) { cadence in
                                entry.cadence = entry.cadence == cadence ? nil : cadence
                                entry.updatedAt = Date()
                                save()
                            }
                            if entry.currentStreak > 0 {
                                HabitStreakRow(
                                    current: entry.currentStreak,
                                    longest: entry.longestStreak,
                                    cadence: entry.cadence ?? .daily
                                )
                            }
                        }

                        // Divider
                        Rectangle()
                            .fill(Theme.Colors.textPrimary.opacity(0.06))
                            .frame(height: 1)
                            .padding(.bottom, 20)

                        // Footer row (metadata)
                        HStack(alignment: .center) {
                            Spacer()
                            HStack(spacing: 6) {
                                Text(formattedDate)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textMuted)

                                Circle()
                                    .fill(Theme.Colors.textMuted)
                                    .frame(width: 3, height: 3)

                                Text(formattedDuration)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textMuted)
                            }
                        }

                    }
                    .padding(.horizontal, Theme.Spacing.screenPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 110) // Space for action bar
                }
            }

            // Action bar at bottom
            VStack {
                Spacer()
                EntryActionBar(
                    isDone: entry.status == .completed || entry.status == .archived,
                    onDone: { onAction(.complete) },
                    onSnooze: { showSnoozeDialog = true },
                    onDelete: { onAction(.delete) }
                )
            }
        }
        .onAppear {
            draftSummary = entry.summary
            draftNotes = entry.category == .list ? entry.content : entry.notes
            draftCategory = entry.category
            draftPriority = entry.priority
        }
        .sheet(isPresented: $showDueDateSheet) {
            DueDateEditSheet(
                date: $draftDueDate,
                isRemovable: entry.dueDate != nil,
                onSave: {
                    entry.dueDate = draftDueDate
                    entry.updatedAt = Date()
                    save()
                    NotificationService.shared.sync(entry, preferences: notifPrefs)
                    showDueDateSheet = false
                },
                onRemove: {
                    entry.dueDate = nil
                    entry.updatedAt = Date()
                    save()
                    NotificationService.shared.cancel(entry)
                    showDueDateSheet = false
                },
                onDismiss: { showDueDateSheet = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Snooze until...", isPresented: $showSnoozeDialog) {
            Button("In 1 hour") {
                snooze(until: Calendar.current.date(byAdding: .hour, value: 1, to: Date()))
            }
            Button("Tomorrow morning") {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                snooze(until: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow))
            }
            Button("Next week") {
                snooze(until: Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()))
            }
            Button("Custom time...") {
                showCustomSnoozeSheet = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showCustomSnoozeSheet) {
            CustomSnoozeSheet(
                onSave: { date in
                    snooze(until: date)
                    showCustomSnoozeSheet = false
                },
                onDismiss: { showCustomSnoozeSheet = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Priority Pill

    @ViewBuilder
    private func priorityPill(label: String, value: Int?) -> some View {
        let isSelected = draftPriority == value
        Button {
            draftPriority = value
            entry.priority = value
            entry.updatedAt = Date()
            save()
        } label: {
            Text(label)
                .font(Theme.Typography.label)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Theme.Colors.accentPurple.opacity(0.15) : Theme.Colors.bgCard)
                .foregroundStyle(isSelected ? Theme.Colors.accentPurple : Theme.Colors.textSecondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        isSelected ? Theme.Colors.accentPurple.opacity(0.4) : Theme.Colors.borderFaint,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func save() {
        do {
            try modelContext.save()
        } catch {
            entryDetailLog.error("Failed to save entry: \(error.localizedDescription)")
        }
    }

    private func snooze(until date: Date?) {
        onAction(.snooze(until: date))
    }

    private var formattedDate: String {
        Self.dateFormatter.string(from: entry.createdAt)
    }

    private var formattedDuration: String {
        guard let duration = entry.audioDuration else { return "text" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Note Dictation

extension EntryDetailView {
    @ViewBuilder
    var noteDictationButton: some View {
        let conversation = appState.conversation
        let isGloballyBusy = conversation.isRecording || conversation.isProcessing

        Button {
            if isRecordingNote {
                stopNoteDictation()
            } else {
                startNoteDictation()
            }
        } label: {
            Image(systemName: isRecordingNote ? "stop.circle.fill" : "mic.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    isRecordingNote
                        ? Theme.Colors.accentRed
                        : Theme.Colors.accentPurple.opacity(0.7)
                )
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .disabled(!isRecordingNote && isGloballyBusy)
        .opacity(!isRecordingNote && isGloballyBusy ? 0.3 : 1.0)
        .accessibilityLabel(isRecordingNote ? "Stop note dictation" : "Dictate notes")
    }

    func startNoteDictation() {
        let conversation = appState.conversation
        guard !conversation.isRecording, !conversation.isProcessing else { return }

        isRecordingNote = true
        conversation.startRecording()

        // Watch for recording failure — if the conversation drops back to idle
        // (e.g. no mic hardware, permission denied), reset our local state.
        noteRecordingTask?.cancel()
        noteRecordingTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            if case .idle = conversation.inputState {
                isRecordingNote = false
            }
        }
    }

    func stopNoteDictation() {
        let conversation = appState.conversation
        guard isRecordingNote else { return }

        let transcript: String
        if case .recording(let t) = conversation.inputState {
            transcript = t
        } else {
            transcript = ""
        }

        isRecordingNote = false
        conversation.cancelRecording()

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let prefixedText = "[Dictating notes for entry \(entry.shortID) — \"\(entry.summary)\"]: \(trimmed)"

        noteRecordingTask?.cancel()
        noteRecordingTask = Task { @MainActor in
            for _ in 0..<40 {
                if case .idle = conversation.inputState { break }
                try? await Task.sleep(for: .milliseconds(50))
            }
            guard !Task.isCancelled else { return }

            conversation.inputText = prefixedText
            conversation.submitText(
                entries: allEntries,
                modelContext: modelContext,
                preferences: notifPrefs
            )
        }
    }
}

// MARK: - Due Date Row

private struct DueDateRow: View {
    let entry: Entry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundStyle(entry.dueDate != nil
                        ? Theme.Colors.accentYellow
                        : Theme.Colors.textSecondary)
                if let dueDate = entry.dueDate {
                    Text(dueDate, style: .date)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.accentYellow)
                    if dueDate.hasTimeComponent {
                        Text(dueDate, style: .time)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.accentYellow)
                    }
                } else {
                    Text("Add due date")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(.bottom, 24)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cadence Picker

private struct CadencePicker: View {
    let entry: Entry
    let onSelect: (HabitCadence) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cadence")
                .font(Theme.Typography.label)
                .foregroundStyle(Theme.Colors.textSecondary)

            HStack(spacing: 8) {
                ForEach(HabitCadence.allCases, id: \.self) { cadence in
                    Button { onSelect(cadence) } label: {
                        Text(cadence.displayName)
                            .font(Theme.Typography.label)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                entry.cadence == cadence
                                    ? Theme.Colors.accentGreen.opacity(0.15)
                                    : Theme.Colors.bgCard
                            )
                            .foregroundStyle(
                                entry.cadence == cadence
                                    ? Theme.Colors.accentGreen
                                    : Theme.Colors.textSecondary
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(
                                    entry.cadence == cadence
                                        ? Theme.Colors.accentGreen.opacity(0.4)
                                        : Theme.Colors.borderFaint,
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 24)
    }
}

// MARK: - Habit Streak Row

private struct HabitStreakRow: View {
    let current: Int
    let longest: Int
    let cadence: HabitCadence

    private var periodLabel: String {
        switch cadence {
        case .daily, .weekdays: return current == 1 ? "day" : "days"
        case .weekly: return current == 1 ? "week" : "weeks"
        case .monthly: return current == 1 ? "month" : "months"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("\(current) \(periodLabel) streak")
                .font(Theme.Typography.label)
                .foregroundStyle(Theme.Colors.accentGreen)

            if longest > current {
                Text("·")
                    .foregroundStyle(Theme.Colors.textMuted)
                Text("Best: \(longest)")
                    .font(Theme.Typography.label)
                    .foregroundStyle(Theme.Colors.textMuted)
            }
        }
        .padding(.bottom, 24)
    }
}

// MARK: - Entry Action Bar

private struct EntryActionBar: View {
    let isDone: Bool
    let onDone: () -> Void
    let onSnooze: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ActionButton(
                icon: isDone ? "checkmark.circle.fill" : "checkmark.circle",
                label: "Done",
                color: Theme.Colors.accentGreen,
                action: onDone
            )

            ActionButton(
                icon: "clock",
                label: "Snooze",
                color: Theme.Colors.accentYellow,
                action: onSnooze
            )

            ActionButton(
                icon: "trash",
                label: "Delete",
                color: Theme.Colors.accentRed,
                action: onDelete
            )
        }
        .padding(.top, 14)
        .padding(.bottom, 26)
        .background(
            Rectangle()
                .fill(Theme.Colors.bgDeep.opacity(0.95))
                .background(.ultraThinMaterial.opacity(0.5))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.Colors.textPrimary.opacity(0.06))
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

private struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(color)
            }
            .frame(minWidth: 80)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Due Date Edit Sheet

private struct DueDateEditSheet: View {
    @Binding var date: Date
    let isRemovable: Bool
    let onSave: () -> Void
    let onRemove: () -> Void
    let onDismiss: () -> Void

    @State private var hasTime: Bool = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                DatePicker(
                    "",
                    selection: $date,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, Theme.Spacing.screenPadding)

                Divider()
                    .padding(.horizontal, Theme.Spacing.screenPadding)

                Toggle("Add time", isOn: $hasTime)
                    .padding(Theme.Spacing.screenPadding)

                if hasTime {
                    DatePicker(
                        "",
                        selection: $date,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding(.horizontal, Theme.Spacing.screenPadding)
                }

                Spacer()
            }
            .background(Theme.Colors.bgDeep)
            .navigationTitle("Due date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !hasTime {
                            date = Calendar.current.startOfDay(for: date)
                        }
                        onSave()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
                if isRemovable {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Remove Date", role: .destructive, action: onRemove)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .background(Theme.Colors.bgDeep)
        .onAppear {
            hasTime = date.hasTimeComponent
        }
    }
}

// MARK: - Custom Snooze Sheet

private struct CustomSnoozeSheet: View {
    @State private var date: Date = Date().addingTimeInterval(3600)
    let onSave: (Date) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                DatePicker(
                    "",
                    selection: $date,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, Theme.Spacing.screenPadding)

                Spacer()
            }
            .background(Theme.Colors.bgDeep)
            .navigationTitle("Snooze until")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Snooze") { onSave(date) }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
            }
        }
        .background(Theme.Colors.bgDeep)
    }
}

// MARK: - Date Extension

private extension Date {
    var hasTimeComponent: Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self)
        let minute = calendar.component(.minute, from: self)
        return hour != 0 || minute != 0
    }
}

#Preview("Entry Detail - Idea") {
    @Previewable @State var appState = AppState()
    @Previewable @State var notifPrefs = NotificationPreferences()

    EntryDetailView(
        entry: Entry(
            transcript: "",
            content: "An app that scans your grocery receipt and suggests meals based on what you actually bought.",
            category: .idea,
            sourceText: "",
            summary: "An app that scans your grocery receipt and suggests meals based on what you actually bought."
        ),
        onBack: { print("Back") },
        onAction: { action in print("Action: \(action)") }
    )
    .environment(appState)
    .environment(notifPrefs)
}

#Preview("Entry Detail - Todo") {
    @Previewable @State var appState = AppState()
    @Previewable @State var notifPrefs = NotificationPreferences()

    EntryDetailView(
        entry: Entry(
            transcript: "",
            content: "Review the new design system and provide detailed feedback to the team by end of week",
            category: .todo,
            sourceText: "",
            summary: "Review the new design system and provide detailed feedback to the team by end of week",
            priority: 1
        ),
        onBack: { print("Back") },
        onAction: { action in print("Action: \(action)") }
    )
    .environment(appState)
    .environment(notifPrefs)
}

#Preview("Entry Detail - Insight") {
    @Previewable @State var appState = AppState()
    @Previewable @State var notifPrefs = NotificationPreferences()

    EntryDetailView(
        entry: Entry(
            transcript: "",
            content: "The best interfaces are invisible - they get out of the way and let users focus on their task without distraction.",
            category: .note,
            sourceText: "",
            summary: "The best interfaces are invisible - they get out of the way and let users focus on their task without distraction."
        ),
        onBack: { print("Back") },
        onAction: { action in print("Action: \(action)") }
    )
    .environment(appState)
    .environment(notifPrefs)
}
