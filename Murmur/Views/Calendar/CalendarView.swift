import SwiftUI
import SwiftData
import MurmurCore

struct CalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Entry.createdAt, order: .reverse) private var allEntries: [Entry]

    let onEntryTap: (Entry) -> Void

    @State private var displayMonth: Date = Date()
    @State private var selectedDate: Date = Date()

    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    // Active entries that have an explicit due date
    private var datedEntries: [Entry] {
        allEntries.filter { $0.dueDate != nil && $0.status == .active }
    }

    // Keyed by start-of-day for fast lookup
    private var entriesByDay: [Date: [Entry]] {
        Dictionary(grouping: datedEntries) { cal.startOfDay(for: $0.dueDate!) }
    }

    private var selectedDayEntries: [Entry] {
        let key = cal.startOfDay(for: selectedDate)
        return (entriesByDay[key] ?? []).sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    // Flat array of optional Dates — nil = leading empty cell
    private var gridDays: [Date?] {
        guard
            let monthInterval = cal.dateInterval(of: .month, for: displayMonth),
            let firstWeekday = cal.dateComponents([.weekday], from: monthInterval.start).weekday,
            let dayCount = cal.range(of: .day, in: .month, for: displayMonth)?.count
        else { return [] }

        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leading)
        for day in 1...dayCount {
            days.append(cal.date(bySetting: .day, value: day, of: displayMonth))
        }
        return days
    }

    private var monthTitle: String {
        displayMonth.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.bgDeep.ignoresSafeArea()

                VStack(spacing: 0) {
                    monthNavigator
                        .padding(.horizontal, Theme.Spacing.screenPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    dayOfWeekHeader
                        .padding(.horizontal, Theme.Spacing.screenPadding)

                    calendarGrid
                        .padding(.horizontal, Theme.Spacing.screenPadding)
                        .padding(.bottom, 16)

                    Divider()
                        .background(Theme.Colors.borderSubtle)

                    dayEntriesList
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.Colors.accentPurple)
                }
            }
        }
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayMonth = cal.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthTitle)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayMonth = cal.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Day-of-Week Header

    private var dayOfWeekHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(dayLabels.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(Theme.Typography.badge)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 6)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(gridDays.enumerated()), id: \.offset) { _, date in
                if let date {
                    CalendarDayCell(
                        date: date,
                        isSelected: cal.isDate(date, inSameDayAs: selectedDate),
                        isToday: cal.isDateInToday(date),
                        dotColors: dotColors(for: date)
                    ) {
                        selectedDate = date
                    }
                } else {
                    Color.clear.frame(height: 46)
                }
            }
        }
    }

    // MARK: - Day Entries List

    @ViewBuilder
    private var dayEntriesList: some View {
        if selectedDayEntries.isEmpty {
            VStack {
                Spacer()
                Text("No entries due")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textTertiary)
                Spacer()
            }
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(selectedDayEntries) { entry in
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                onEntryTap(entry)
                            }
                        } label: {
                            CalendarEntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .background(Theme.Colors.borderFaint)
                            .padding(.leading, Theme.Spacing.screenPadding)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    // Up to 3 distinct category colors for a given day, in category order
    private func dotColors(for date: Date) -> [Color] {
        let key = cal.startOfDay(for: date)
        guard let entries = entriesByDay[key] else { return [] }
        var seen = Set<String>()
        var colors: [Color] = []
        for entry in entries {
            if seen.insert(entry.category.rawValue).inserted {
                colors.append(Theme.categoryColor(entry.category))
            }
            if colors.count == 3 { break }
        }
        return colors
    }
}

// MARK: - Day Cell

private struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let dotColors: [Color]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.subheadline.weight(isToday || isSelected ? .semibold : .regular))
                    .foregroundStyle(dayLabelColor)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(isSelected ? Theme.Colors.accentPurple : Color.clear))

                // Dots — hidden when day is selected (circle already marks it)
                HStack(spacing: 3) {
                    ForEach(Array(dotColors.prefix(3).enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 6)
                .opacity(isSelected ? 0 : 1)
            }
            .frame(height: 46)
        }
        .buttonStyle(.plain)
    }

    private var dayLabelColor: Color {
        if isSelected { return .white }
        if isToday { return Theme.Colors.accentPurple }
        return Theme.Colors.textPrimary
    }
}

// MARK: - Entry Row

private struct CalendarEntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: entry.category, size: .small, showDotGlow: false)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.summary.isEmpty ? entry.content : entry.summary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                if let dueDate = entry.dueDate {
                    Text(timeLabel(for: dueDate))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .padding(.horizontal, Theme.Spacing.screenPadding)
        .padding(.vertical, 14)
    }

    private func timeLabel(for date: Date) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        if comps.hour == 0 && comps.minute == 0 { return "All day" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - Preview

#Preview {
    CalendarView(onEntryTap: { _ in })
}
