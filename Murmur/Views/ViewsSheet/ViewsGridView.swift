import SwiftUI
import MurmurCore

struct ViewsGridView: View {
    @Environment(AppState.self) private var appState
    let onViewSelected: (ViewType) -> Void
    let onCreateView: () -> Void
    let onDismiss: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Sheet handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(white: 0.23))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            // Title
            Text("Your Views")
                .font(Theme.Typography.navTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.bottom, 24)

            // Views grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(ViewType.allCases, id: \.self) { viewType in
                        ViewCard(viewType: viewType)
                            .onTapGesture {
                                onViewSelected(viewType)
                            }
                    }

                    // Create view card
                    CreateViewCard()
                        .onTapGesture {
                            onCreateView()
                        }
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Theme.Colors.bgCard
                .ignoresSafeArea()
        )
    }
}

// MARK: - View Types

enum ViewType: CaseIterable {
    case todo
    case ideas
    case dontForget
    case habits
    case allEntries

    var title: String {
        switch self {
        case .todo: return "Todo"
        case .ideas: return "Ideas"
        case .dontForget: return "Don't Forget"
        case .habits: return "Habits"
        case .allEntries: return "All Entries"
        }
    }

    var icon: String {
        switch self {
        case .todo: return "checkmark"
        case .ideas: return "lightbulb.fill"
        case .dontForget: return "clock.fill"
        case .habits: return "checkmark.circle.fill"
        case .allEntries: return "doc.text.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .todo: return Theme.Colors.accentPurple
        case .ideas: return Theme.Colors.accentYellow
        case .dontForget: return Color(red: 251/255, green: 146/255, blue: 60/255) // Orange
        case .habits: return Theme.Colors.accentGreen
        case .allEntries: return Theme.Colors.accentBlue
        }
    }

    var category: EntryCategory? {
        switch self {
        case .todo: return .todo
        case .ideas: return .idea
        case .dontForget: return .reminder
        case .habits: return .habit
        case .allEntries: return nil
        }
    }
}

// MARK: - View Card

private struct ViewCard: View {
    let viewType: ViewType

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(viewType.iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: viewType.icon)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(viewType.iconColor)
            }

            // Name
            Text(viewType.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 110)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.145, green: 0.145, blue: 0.196)) // #252533
        )
    }
}

// MARK: - Create View Card

private struct CreateViewCard: View {
    var body: some View {
        VStack(spacing: 10) {
            // Plus icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)
                    .frame(width: 44, height: 44)

                Image(systemName: "plus")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            // Label
            Text("Create View")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 110)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    Color(white: 0.23),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
        )
    }
}

#Preview("Views Grid") {
    @Previewable @State var appState = AppState()

    ZStack {
        // Background content (dimmed)
        Theme.Colors.bgDeep
            .ignoresSafeArea()

        // Dimming overlay
        Color.black.opacity(0.5)
            .ignoresSafeArea()

        // Bottom sheet
        VStack {
            Spacer()
            ViewsGridView(
                onViewSelected: { print("View selected:", $0.title) },
                onCreateView: { print("Create view") },
                onDismiss: { print("Dismiss") }
            )
            .frame(height: 520)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .ignoresSafeArea(edges: .bottom)
    }
    .environment(appState)
}
