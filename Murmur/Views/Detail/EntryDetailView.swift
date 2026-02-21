import SwiftUI
import MurmurCore

struct EntryDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationPreferences.self) private var notifPrefs
    let entry: Entry
    let onBack: () -> Void
    let onEdit: () -> Void
    let onViewTranscript: () -> Void
    let onArchive: () -> Void
    let onSnooze: () -> Void
    let onDelete: () -> Void

    @State private var showNotesSheet = false
    @State private var draftNotes: String = ""
    @State private var showDeleteConfirm = false
    @State private var showSnoozeDialog = false
    @State private var showCustomSnoozeSheet = false
    @State private var showDueDateSheet = false
    @State private var draftHasDueDate: Bool = false
    @State private var draftDueDate: Date = Date()

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav header
                NavHeader(
                    title: "Entry",
                    showBackButton: true,
                    backAction: onBack,
                    trailingButtons: [
                        NavHeader.NavButton(
                            icon: "square.and.pencil",
                            action: onEdit
                        )
                    ]
                )

                // Detail content
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Category badge
                        CategoryBadge(category: entry.category, size: .medium)
                            .padding(.bottom, 24)

                        // Content text
                        Text(entry.content.isEmpty ? entry.summary : entry.content)
                            .font(.title3)
                            .tracking(-0.01)
                            .lineSpacing(6)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(.bottom, 32)

                        // Existing notes (shown when non-empty)
                        if !entry.notes.isEmpty {
                            Text(entry.notes)
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 24)
                        }

                        // Tell me more / Edit notes button
                        Button {
                            draftNotes = entry.notes
                            showNotesSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle")
                                    .font(Theme.Typography.bodyMedium)
                                Text(entry.notes.isEmpty ? "Tell me more" : "Edit notes")
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundStyle(Theme.Colors.accentPurpleLight)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.Colors.accentPurple.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.Colors.accentPurple.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 28)

                        // Due date row (todos and reminders only)
                        if entry.category == .todo || entry.category == .reminder {
                            Button {
                                draftHasDueDate = entry.dueDate != nil
                                draftDueDate = entry.dueDate ?? Date()
                                showDueDateSheet = true
                            } label: {
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
                                        let hour = Calendar.current.component(.hour, from: dueDate)
                                        let minute = Calendar.current.component(.minute, from: dueDate)
                                        if hour != 0 || minute != 0 {
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

                        // Cadence pill row (habits only)
                        if entry.category == .habit {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Cadence")
                                    .font(Theme.Typography.label)
                                    .foregroundStyle(Theme.Colors.textSecondary)

                                HStack(spacing: 8) {
                                    ForEach(HabitCadence.allCases, id: \.self) { cadence in
                                        Button {
                                            entry.cadence = entry.cadence == cadence ? nil : cadence
                                            entry.updatedAt = Date()
                                            try? modelContext.save()
                                        } label: {
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

                        // Divider
                        Rectangle()
                            .fill(Theme.Colors.textPrimary.opacity(0.06))
                            .frame(height: 1)
                            .padding(.bottom, 20)

                        // Footer row (metadata)
                        HStack(alignment: .center) {
                            Spacer()

                            // Metadata
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

                        // View transcript link
                        Button(action: onViewTranscript) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text")
                                    .font(.subheadline.weight(.medium))
                                Text("View transcript")
                                    .font(Theme.Typography.caption)
                            }
                            .foregroundStyle(Theme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 16)
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
                    isArchived: entry.status == .archived,
                    onArchive: {
                        entry.status = .archived
                        entry.updatedAt = Date()
                        try? modelContext.save()
                        NotificationService.shared.cancel(entry)
                        onArchive()
                    },
                    onUnarchive: {
                        entry.status = .active
                        entry.updatedAt = Date()
                        try? modelContext.save()
                        NotificationService.shared.sync(entry, preferences: notifPrefs)
                        onBack()
                    },
                    onSnooze: { showSnoozeDialog = true },
                    onDelete: { showDeleteConfirm = true }
                )
            }

        }
        .sheet(isPresented: $showNotesSheet) {
            NotesEditSheet(
                notes: $draftNotes,
                onSave: {
                    entry.notes = draftNotes
                    entry.updatedAt = Date()
                    try? modelContext.save()
                    showNotesSheet = false
                },
                onDismiss: { showNotesSheet = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDueDateSheet) {
            DueDateEditSheet(
                isEnabled: $draftHasDueDate,
                date: $draftDueDate,
                onSave: {
                    entry.dueDate = draftHasDueDate ? draftDueDate : nil
                    entry.updatedAt = Date()
                    try? modelContext.save()
                    NotificationService.shared.sync(entry, preferences: notifPrefs)
                    showDueDateSheet = false
                },
                onDismiss: { showDueDateSheet = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Delete entry?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                NotificationService.shared.cancel(entry)
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        .confirmationDialog("Snooze until...", isPresented: $showSnoozeDialog) {
            Button("In 1 hour") {
                entry.snoozeUntil = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
                entry.status = .snoozed
                entry.updatedAt = Date()
                try? modelContext.save()
                NotificationService.shared.sync(entry, preferences: notifPrefs)
                onSnooze()
            }
            Button("Tomorrow morning") {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                entry.snoozeUntil = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)
                entry.status = .snoozed
                entry.updatedAt = Date()
                try? modelContext.save()
                NotificationService.shared.sync(entry, preferences: notifPrefs)
                onSnooze()
            }
            Button("Next week") {
                entry.snoozeUntil = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())
                entry.status = .snoozed
                entry.updatedAt = Date()
                try? modelContext.save()
                NotificationService.shared.sync(entry, preferences: notifPrefs)
                onSnooze()
            }
            Button("Custom time...") {
                showCustomSnoozeSheet = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showCustomSnoozeSheet) {
            CustomSnoozeSheet(
                onSave: { date in
                    entry.snoozeUntil = date
                    entry.status = .snoozed
                    entry.updatedAt = Date()
                    try? modelContext.save()
                    NotificationService.shared.sync(entry, preferences: notifPrefs)
                    showCustomSnoozeSheet = false
                    onSnooze()
                },
                onDismiss: { showCustomSnoozeSheet = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: entry.createdAt)
    }

    private var formattedDuration: String {
        guard let duration = entry.audioDuration else { return "text" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Entry Action Bar

private struct EntryActionBar: View {
    let isArchived: Bool
    let onArchive: () -> Void
    let onUnarchive: () -> Void
    let onSnooze: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if isArchived {
                ActionButton(
                    icon: "arrow.uturn.left",
                    label: "Unarchive",
                    color: Theme.Colors.accentGreen,
                    action: onUnarchive
                )
            } else {
                ActionButton(
                    icon: "archivebox",
                    label: "Archive",
                    color: Theme.Colors.textSecondary,
                    action: onArchive
                )
            }

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
    @Binding var isEnabled: Bool
    @Binding var date: Date
    let onSave: () -> Void
    let onDismiss: () -> Void

    @State private var hasTime: Bool = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Toggle("Set due date", isOn: $isEnabled)
                    .padding(Theme.Spacing.screenPadding)

                if isEnabled {
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
                }

                Spacer()
            }
            .background(Theme.Colors.bgDeep)
            .navigationTitle("Due date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isEnabled && !hasTime {
                            date = Calendar.current.startOfDay(for: date)
                        }
                        onSave()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
            }
        }
        .background(Theme.Colors.bgDeep)
        .onAppear {
            guard isEnabled else { return }
            let hour = Calendar.current.component(.hour, from: date)
            let minute = Calendar.current.component(.minute, from: date)
            hasTime = hour != 0 || minute != 0
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

// MARK: - Notes Edit Sheet

private struct NotesEditSheet: View {
    @Binding var notes: String
    let onSave: () -> Void
    let onDismiss: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            TextEditor(text: $notes)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .background(Theme.Colors.bgDeep)
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .focused($focused)
                .navigationTitle("Notes")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: onSave)
                            .fontWeight(.semibold)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onDismiss)
                    }
                }
        }
        .background(Theme.Colors.bgDeep)
        .onAppear { focused = true }
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
        onEdit: { print("Edit") },
        onViewTranscript: { print("View transcript") },
        onArchive: { print("Archive") },
        onSnooze: { print("Snooze") },
        onDelete: { print("Delete") }
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
        onEdit: { print("Edit") },
        onViewTranscript: { print("View transcript") },
        onArchive: { print("Archive") },
        onSnooze: { print("Snooze") },
        onDelete: { print("Delete") }
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
            category: .thought,
            sourceText: "",
            summary: "The best interfaces are invisible - they get out of the way and let users focus on their task without distraction."
        ),
        onBack: { print("Back") },
        onEdit: { print("Edit") },
        onViewTranscript: { print("View transcript") },
        onArchive: { print("Archive") },
        onSnooze: { print("Snooze") },
        onDelete: { print("Delete") }
    )
    .environment(appState)
    .environment(notifPrefs)
}
