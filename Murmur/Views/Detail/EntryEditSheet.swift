import SwiftUI
import MurmurCore

struct EntryEditSheet: View {
    @Binding var summary: String
    @Binding var category: EntryCategory
    @Binding var priority: Int?
    let onSave: () -> Void
    let onDismiss: () -> Void

    @FocusState private var summaryFocused: Bool

    private static let editableCategories: [EntryCategory] = [
        .todo, .reminder, .idea, .habit
    ]

    private var orderedCategories: [EntryCategory] {
        var cats = Self.editableCategories
        if let idx = cats.firstIndex(of: category) {
            cats.remove(at: idx)
        }
        cats.insert(category, at: 0)
        return cats
    }

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
                                ForEach(orderedCategories, id: \.self) { cat in
                                    let color = Theme.categoryColor(cat)
                                    let isSelected = category == cat
                                    Button { category = cat } label: {
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
                    }

                    // Priority
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
