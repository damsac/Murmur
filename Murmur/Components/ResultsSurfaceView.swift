import SwiftUI
import MurmurCore

/// Bottom-anchored overlay showing agent results as entry cards or confirmation previews.
/// Two modes: results (after actions execute) and confirmation (awaiting user confirm/deny).
struct ResultsSurfaceView: View {
    let results: ResultsSurfaceData?
    let confirmation: ConfirmationData?
    let entries: [Entry]
    let onDismiss: () -> Void
    let onUndo: (ResultsSurfaceData) -> Void
    let onConfirm: () -> Void
    let onDeny: () -> Void

    /// Max fraction of screen height the surface can occupy
    private let maxHeightFraction: CGFloat = 0.5

    /// Bottom padding to clear the nav bar
    private let bottomPad = Theme.Spacing.micButtonSize + 24

    @State private var autoDismissTask: Task<Void, Never>?

    /// Auto-dismiss duration for results mode. Scales with entry count: 3s base + 1s per entry, capped at 8s.
    private var autoDismissDuration: TimeInterval {
        let count = results?.applied.count ?? 0
        return min(max(3.0, 3.0 + Double(count)), 8.0)
    }

    var body: some View {
        GeometryReader { screen in
            ZStack(alignment: .bottom) {
                // Tap-to-dismiss background (only for results mode)
                if results != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onDismiss() }
                }

                // Dark gradient fade behind content
                VStack(spacing: 0) {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Theme.Colors.bgDeep.opacity(0.6),
                            Theme.Colors.bgDeep.opacity(0.95),
                            Theme.Colors.bgDeep,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(
                        height: screen.size.height * maxHeightFraction + bottomPad + 60
                    )
                }
                .allowsHitTesting(false)

                // Content
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    if let confirmation {
                        confirmationContent(confirmation, maxWidth: screen.size.width)
                    } else if let results {
                        resultsContent(results, maxWidth: screen.size.width)
                    }

                    Spacer()
                        .frame(height: bottomPad)
                }
                .frame(
                    maxHeight: screen.size.height * maxHeightFraction + bottomPad,
                    alignment: .bottom
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .onAppear {
            // Auto-dismiss only in results mode (not confirmation)
            guard confirmation == nil, results != nil else { return }
            autoDismissTask = Task {
                try? await Task.sleep(for: .seconds(autoDismissDuration))
                guard !Task.isCancelled else { return }
                onDismiss()
            }
        }
        .onDisappear {
            autoDismissTask?.cancel()
        }
    }

    // MARK: - Results Mode

    @ViewBuilder
    private func resultsContent(_ data: ResultsSurfaceData, maxWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Summary text
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.accentPurple)

                Text(data.summary)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)

                Spacer()

                // Undo button
                if !data.undo.isEmpty {
                    Button {
                        onUndo(data)
                    } label: {
                        Text("Undo")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Colors.accentPurple)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.accentPurple.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)

            // Entry cards
            if !data.applied.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(data.applied) { info in
                            ResultEntryRow(entry: info.entry, actionType: info.actionType)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.screenPadding)
                }
            }
        }
    }

    // MARK: - Confirmation Mode

    @ViewBuilder
    private func confirmationContent(_ data: ConfirmationData, maxWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Message
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.accentYellow)

                Text(data.message)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(3)
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)

            // Proposed action previews
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Array(data.proposedActions.enumerated()), id: \.offset) { _, action in
                        ProposedActionRow(action: action, entries: entries)
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
            }

            // Confirm / Deny buttons
            HStack(spacing: 12) {
                Button {
                    onDeny()
                } label: {
                    Text("Dismiss")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    onConfirm()
                } label: {
                    Text("Confirm")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.accentPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
        }
    }
}

// MARK: - Result Entry Row

private struct ResultEntryRow: View {
    let entry: Entry
    let actionType: AppliedActionInfo.ActionType

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: entry.category, size: .small)

            Text(entry.summary)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            actionBadge
        }
        .padding(12)
        .background(Theme.Colors.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var actionBadge: some View {
        Text(actionType.rawValue)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(badgeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var badgeColor: Color {
        switch actionType {
        case .created: return Theme.Colors.accentPurple
        case .updated: return Theme.Colors.accentBlue
        case .completed: return Theme.Colors.accentGreen
        case .archived: return Theme.Colors.accentYellow
        }
    }
}

// MARK: - Proposed Action Row

private struct ProposedActionRow: View {
    let action: AgentAction
    let entries: [Entry]

    /// Resolve the entry referenced by this action
    private var resolvedEntry: Entry? {
        guard let shortID = actionEntryID else { return nil }
        return Entry.resolve(shortID: shortID, in: entries)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: actionIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(actionColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                // Primary: entry title or create summary
                Text(title)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)

                // Secondary: reason or category for creates
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(actionTypeName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(actionColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(actionColor.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(12)
        .background(Theme.Colors.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(actionColor.opacity(0.2), lineWidth: 1)
        )
    }

    /// Primary text — entry name for mutations, summary for creates
    private var title: String {
        switch action {
        case .create(let a):
            return a.summary.isEmpty ? a.content : a.summary
        case .update(let a):
            return resolvedEntry?.summary ?? "Entry \(a.id)"
        case .complete(let a):
            return resolvedEntry?.summary ?? "Entry \(a.id)"
        case .archive(let a):
            return resolvedEntry?.summary ?? "Entry \(a.id)"
        case .updateMemory:
            return "Memory update"
        case .confirm(let r):
            return r.message
        }
    }

    /// Secondary text — reason for mutations, category for creates
    private var subtitle: String? {
        switch action {
        case .create(let a):
            return a.category.rawValue.capitalized
        case .update(let a):
            return a.reason
        case .complete(let a):
            return a.reason
        case .archive(let a):
            return a.reason
        default:
            return nil
        }
    }

    private var actionEntryID: String? {
        switch action {
        case .update(let a): return a.id
        case .complete(let a): return a.id
        case .archive(let a): return a.id
        default: return nil
        }
    }

    private var actionIcon: String {
        switch action {
        case .create: return "plus.circle.fill"
        case .update: return "pencil.circle.fill"
        case .complete: return "checkmark.circle.fill"
        case .archive: return "archivebox.fill"
        case .updateMemory: return "brain"
        case .confirm: return "questionmark.circle"
        }
    }

    private var actionColor: Color {
        switch action {
        case .create: return Theme.Colors.accentPurple
        case .update: return Theme.Colors.accentBlue
        case .complete: return Theme.Colors.accentGreen
        case .archive: return Theme.Colors.accentYellow
        case .updateMemory: return Theme.Colors.accentBlue
        case .confirm: return Theme.Colors.accentYellow
        }
    }

    private var actionTypeName: String {
        switch action {
        case .create: return "Create"
        case .update: return "Update"
        case .complete: return "Complete"
        case .archive: return "Archive"
        case .updateMemory: return "Memory"
        case .confirm: return "Confirm"
        }
    }
}
