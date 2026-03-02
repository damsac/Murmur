import SwiftUI
import MurmurCore

struct CategoryBadge: View {
    let category: EntryCategory
    let size: BadgeSize
    var showDotGlow: Bool = true

    enum BadgeSize {
        case small
        case medium
        case large

        var dotSize: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            case .large: return 10
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .medium: return EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
            case .large: return EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            }
        }
    }

    private var categoryColor: Color {
        Theme.categoryColor(category)
    }

    var body: some View {
        // Category indicator dot with glow
        Circle()
            .fill(categoryColor)
            .frame(width: size.dotSize, height: size.dotSize)
            .shadow(color: showDotGlow ? categoryColor.opacity(0.5) : .clear, radius: 3, x: 0, y: 0)
        .padding(size.padding)
        .background(
            Capsule()
                .fill(categoryColor.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(categoryColor.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

#Preview("All Categories") {
    ScrollView {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Small Size")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                ForEach(EntryCategory.allCases, id: \.self) { category in
                    CategoryBadge(category: category, size: .small)
                }
            }

            Divider()
                .background(Theme.Colors.borderSubtle)

            VStack(alignment: .leading, spacing: 12) {
                Text("Medium Size")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                ForEach(EntryCategory.allCases, id: \.self) { category in
                    CategoryBadge(category: category, size: .medium)
                }
            }

            Divider()
                .background(Theme.Colors.borderSubtle)

            VStack(alignment: .leading, spacing: 12) {
                Text("Large Size")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                ForEach(EntryCategory.allCases, id: \.self) { category in
                    CategoryBadge(category: category, size: .large)
                }
            }
        }
        .padding()
    }
    .background(Theme.Colors.bgDeep)
}
