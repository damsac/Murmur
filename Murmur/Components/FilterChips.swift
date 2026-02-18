import SwiftUI
import MurmurCore

struct FilterChips: View {
    let filters: [Filter]
    @Binding var selectedFilter: String?

    struct Filter: Identifiable {
        let id: String
        let label: String

        init(id: String, label: String? = nil) {
            self.id = id
            self.label = label ?? id.capitalized
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(filters) { filter in
                    FilterChip(
                        label: filter.label,
                        isSelected: selectedFilter == filter.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedFilter == filter.id {
                                selectedFilter = nil
                            } else {
                                selectedFilter = filter.id
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
        }
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.Typography.label)
                .fontWeight(.medium)
                .foregroundStyle(
                    isSelected
                        ? Theme.Colors.textPrimary
                        : Theme.Colors.textSecondary
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            isSelected
                                ? Theme.Colors.accentPurple.opacity(0.2)
                                : Theme.Colors.bgCard
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isSelected
                                        ? Theme.Colors.accentPurple
                                        : Theme.Colors.borderSubtle,
                                    lineWidth: isSelected ? 1.5 : 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 40) {
        FilterChips(
            filters: [
                FilterChips.Filter(id: "all", label: "All"),
                FilterChips.Filter(id: "todo", label: "Todo"),
                FilterChips.Filter(id: "insight", label: "Insights"),
                FilterChips.Filter(id: "idea", label: "Ideas")
            ],
            selectedFilter: .constant("todo")
        )

        FilterChips(
            filters: [
                FilterChips.Filter(id: "active", label: "Active"),
                FilterChips.Filter(id: "completed", label: "Completed"),
                FilterChips.Filter(id: "archived", label: "Archived")
            ],
            selectedFilter: .constant(nil)
        )
    }
    .padding(.vertical, 40)
    .background(Theme.Colors.bgDeep)
}
