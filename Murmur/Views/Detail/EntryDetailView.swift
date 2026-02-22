import SwiftUI
import MurmurCore

struct EntryDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationPreferences.self) private var notifPrefs
    let entry: Entry
    let onBack: () -> Void
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
    @State private var draftDueDate: Date = Date()
    @State private var showEditSheet = false
    @State private var draftSummary: String = ""
    @State private var draftCategory: EntryCategory = .note
    @State private var draftPriority: Int?

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
                // Nav header
                NavHeader(
                    title: "Entry",
                    showBackButton: true,
                    backAction: onBack,
                    trailingButtons: [
                        NavHeader.NavButton(
                            icon: "square.and.pencil",
                            action: {
                                draftSummary = entry.summary
                                draftCategory = entry.category
                                draftPriority = entry.priority
                                showEditSheet = true
                            }
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
                            DueDateRow(entry: entry) {
                                draftDueDate = entry.dueDate ?? Date()
                                showDueDateSheet = true
                            }
                        }

                        // Cadence pill row (habits only)
                        if entry.category == .habit {
                            CadencePicker(entry: entry) { cadence in
                                entry.cadence = entry.cadence == cadence ? nil : cadence
                                entry.updatedAt = Date()
                                save()
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
                        entry.perform(.archive, in: modelContext, preferences: notifPrefs)
                        onArchive()
                    },
                    onUnarchive: {
                        entry.perform(.unarchive, in: modelContext, preferences: notifPrefs)
                        onBack()
                    },
                    onSnooze: { showSnoozeDialog = true },
                    onDelete: { showDeleteConfirm = true }
                )
            }

        }
        .sheet(isPresented: $showEditSheet) {
            EntryEditSheet(
                summary: $draftSummary,
                category: $draftCategory,
                priority: $draftPriority,
                onSave: {
                    let trimmed = draftSummary.trimmingCharacters(in: .whitespacesAndNewlines)
                    entry.summary = trimmed
                    entry.content = trimmed
                    entry.category = draftCategory
                    entry.priority = draftPriority
                    entry.updatedAt = Date()
                    save()
                    NotificationService.shared.sync(entry, preferences: notifPrefs)
                    showEditSheet = false
                },
                onDismiss: { showEditSheet = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showNotesSheet) {
            NotesEditSheet(
                notes: $draftNotes,
                onSave: {
                    entry.notes = draftNotes
                    entry.updatedAt = Date()
                    save()
                    showNotesSheet = false
                },
                onDismiss: { showNotesSheet = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
        .alert("Delete entry?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                entry.perform(.delete, in: modelContext, preferences: notifPrefs)
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
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

    // MARK: - Helpers

    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save entry: \(error.localizedDescription)")
        }
    }

    private func snooze(until date: Date?) {
        entry.perform(.snooze(until: date), in: modelContext, preferences: notifPrefs)
        onSnooze()
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

// MARK: - Entry Edit Sheet

private struct EntryEditSheet: View {
    @Binding var summary: String
    @Binding var category: EntryCategory
    @Binding var priority: Int?
    let onSave: () -> Void
    let onDismiss: () -> Void

    @FocusState private var summaryFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(Theme.Typography.label)
                            .foregroundStyle(Theme.Colors.textSecondary)

                        TextEditor(text: $summary)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 80)
                            .focused($summaryFocused)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.Colors.bgCard)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                                    )
                            )
                    }

                    // Category
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(Theme.Typography.label)
                            .foregroundStyle(Theme.Colors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(EntryCategory.allCases, id: \.self) { cat in
                                    let color = Theme.categoryColor(cat)
                                    let isSelected = category == cat
                                    Button { category = cat } label: {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 7, height: 7)
                                            Text(cat.rawValue)
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
                    }

                    // Priority
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Priority")
                            .font(Theme.Typography.label)
                            .foregroundStyle(Theme.Colors.textSecondary)

                        HStack(spacing: 8) {
                            priorityPill(label: "None", value: nil)
                            ForEach(1...5, id: \.self) { p in
                                priorityPill(label: "\(p)", value: p)
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.screenPadding)
            }
            .background(Theme.Colors.bgDeep)
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .fontWeight(.semibold)
                        .disabled(summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
            }
        }
        .background(Theme.Colors.bgDeep)
        .onAppear { summaryFocused = true }
    }

    @ViewBuilder
    private func priorityPill(label: String, value: Int?) -> some View {
        let isSelected = priority == value
        Button {
            priority = value
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
        onViewTranscript: { print("View transcript") },
        onArchive: { print("Archive") },
        onSnooze: { print("Snooze") },
        onDelete: { print("Delete") }
    )
    .environment(appState)
    .environment(notifPrefs)
}
