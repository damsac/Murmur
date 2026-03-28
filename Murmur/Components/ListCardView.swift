import SwiftUI
import MurmurCore

struct ListCardView: View {
    let entry: Entry
    let onAction: (Entry, EntryAction) -> Void
    var onTap: (() -> Void)?
    var glowAccent: Color?
    var glowIntensity: Double = 0

    var externalExpanded: Binding<Bool>?
    @State private var localExpanded: Bool = false
    private var isExpanded: Bool { externalExpanded?.wrappedValue ?? localExpanded }
    private func toggleExpanded() {
        if let b = externalExpanded { b.wrappedValue.toggle() } else { localExpanded.toggle() }
    }

    private var accent: Color { Theme.categoryColor(entry.category) }

    // MARK: - Parsing

    private var listItems: [(text: String, checked: Bool)] {
        entry.content.components(separatedBy: "\n")
            .compactMap { line -> (String, Bool)? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("- [x] ") {
                    return (String(trimmed.dropFirst(6)), true)
                } else if trimmed.hasPrefix("- [ ] ") {
                    return (String(trimmed.dropFirst(6)), false)
                } else if trimmed.hasPrefix("- ") {
                    return (String(trimmed.dropFirst(2)), false)
                }
                return nil
            }
    }

    private var checkedCount: Int {
        listItems.filter { $0.checked }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — always visible
            headerView

            // Expanded items — always in hierarchy, height controlled
            expandedBody
                .frame(maxHeight: isExpanded ? nil : 0)
                .opacity(isExpanded ? 1 : 0)
                .clipped()
        }
        .cardStyle(accent: glowAccent, intensity: glowIntensity)
        .opacity(entry.isDone ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: entry.isCompletedToday)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.category.displayName): \(entry.summary), \(checkedCount) of \(listItems.count) checked")
    }

    // MARK: - Header (collapsed / always visible)

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            // Tappable card body — opens detail
            Button {
                onTap?()
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    Circle()
                        .fill(accent)
                        .frame(width: 8, height: 8)
                        .shadow(color: accent.opacity(0.6), radius: 4)
                        .padding(.leading, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.summary)
                            .font(.subheadline)
                            .foregroundStyle(entry.isDone ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        collapsedPreview
                    }
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expand/collapse button — right side only
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    toggleExpanded()
                }
            } label: {
                HStack(spacing: 8) {
                    // Item count badge
                    Text("\(listItems.count)")
                        .font(Theme.Typography.badge)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Theme.Colors.bgCard)
                                .overlay(Capsule().stroke(Theme.Colors.borderSubtle, lineWidth: 1))
                        )

                    // Expand chevron
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
                }
                .padding(.vertical, 8)
                .padding(.leading, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Collapsed Preview

    private var collapsedPreview: some View {
        let items = listItems
        let previewItems = Array(items.prefix(3))
        let previewText = previewItems.map { $0.text }.joined(separator: " · ")
        return Text(previewText)
            .font(.caption2)
            .foregroundStyle(Theme.Colors.textSecondary)
            .lineLimit(1)
    }

    // MARK: - Expanded Body

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Divider
            Rectangle()
                .fill(Theme.Colors.borderSubtle)
                .frame(height: 0.5)
                .padding(.top, 10)
                .padding(.bottom, 8)

            // List items with checkboxes
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(listItems.enumerated()), id: \.offset) { index, item in
                    listItemRow(index: index, text: item.text, checked: item.checked)
                }
            }

            // Progress footer
            if !listItems.isEmpty {
                HStack(spacing: 4) {
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.Colors.borderSubtle)
                                .frame(height: 3)
                            Capsule()
                                .fill(accent)
                                .frame(
                                    width: listItems.isEmpty
                                        ? 0
                                        : geo.size.width * CGFloat(checkedCount) / CGFloat(listItems.count),
                                    height: 3
                                )
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: checkedCount)
                        }
                    }
                    .frame(height: 3)
                    .frame(maxWidth: 60)

                    Text("\(checkedCount)/\(listItems.count)")
                        .font(Theme.Typography.badge)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .padding(.top, 10)
            }
        }
    }

    // MARK: - List Item Row

    private func listItemRow(index: Int, text: String, checked: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                onAction(entry, .toggleListItem(index: index))
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(checked ? accent : Theme.Colors.textTertiary)
                    .animation(.spring(response: 0.3, dampingFraction: 0.65), value: checked)

                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(checked ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                    .strikethrough(checked, color: Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("List Card — Collapsed") {
    VStack(spacing: 16) {
        ListCardView(
            entry: Entry(
                transcript: "",
                content: "- [ ] Eggs\n- [x] Milk\n- [ ] Bread\n- [ ] Butter\n- [x] Cheese\n- [ ] Tomatoes\n- [ ] Onions",
                category: .list,
                sourceText: "",
                summary: "Grocery shopping list"
            ),
            onAction: { _, action in print("Action:", action) }
        )
    }
    .padding(Theme.Spacing.screenPadding)
    .background(Theme.Colors.bgDeep)
}

#Preview("List Card — Plain Bullets") {
    VStack(spacing: 16) {
        ListCardView(
            entry: Entry(
                transcript: "",
                content: "- Pack clothes\n- Book hotel\n- Cancel mail delivery\n- Water plants",
                category: .list,
                sourceText: "",
                summary: "Trip preparation checklist"
            ),
            onAction: { _, action in print("Action:", action) }
        )
    }
    .padding(Theme.Spacing.screenPadding)
    .background(Theme.Colors.bgDeep)
}
