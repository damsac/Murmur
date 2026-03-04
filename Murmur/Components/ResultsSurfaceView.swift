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
    let onConfirm: ([AgentAction]) -> Void
    let onDeny: () -> Void

    /// Max fraction of screen height the surface can occupy
    private let maxHeightFraction: CGFloat = 0.5

    /// Bottom padding to clear the nav bar
    private let bottomPad = Theme.Spacing.micButtonSize + 24

    @State private var autoDismissTask: Task<Void, Never>?

    /// Per-index action type overrides from user tapping to cycle
    @State private var actionOverrides: [Int: ProposedActionKind] = [:]

    /// Per-index create action edits from user tapping a create row
    @State private var createOverrides: [Int: CreateAction] = [:]

    /// Index of the create action currently being edited (nil = no sheet)
    @State private var editingIndex: Int?

    /// Draft state for the create-action edit sheet
    @State private var draftSummary: String = ""
    @State private var draftCategory: EntryCategory = .note
    @State private var draftPriority: Int?

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

                // Solid background behind cards + gradient fade above
                VStack(spacing: 0) {
                    Spacer()
                    // Short gradient transition
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Theme.Colors.bgDeep.opacity(0.85),
                            Theme.Colors.bgDeep,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 60)
                    // Solid region under the cards
                    Theme.Colors.bgDeep
                }
                .allowsHitTesting(false)

                // Content
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    if let confirmation {
                        confirmationContent(confirmation)
                    } else if let results {
                        resultsContent(results)
                    }

                    // Extra padding for confirmation so buttons clear the mic
                    Spacer()
                        .frame(height: confirmation != nil ? bottomPad + 48 : bottomPad)
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
    private func resultsContent(_ data: ResultsSurfaceData) -> some View {
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
    private func confirmationContent(_ data: ConfirmationData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Proposed action previews
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Array(data.proposedActions.enumerated()), id: \.offset) { index, action in
                        let currentKind = actionOverrides[index] ?? ProposedActionKind.from(action)
                        let isCreate = if case .create = action { true } else { false }
                        // Use edited version of create actions for display
                        let displayAction: AgentAction = {
                            if case .create = action, let override = createOverrides[index] {
                                return .create(override)
                            }
                            return action
                        }()
                        ProposedActionRow(
                            action: displayAction,
                            entries: entries,
                            currentKind: currentKind,
                            onCycle: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    actionOverrides[index] = currentKind.next
                                }
                            },
                            onEdit: isCreate ? {
                                let base: CreateAction
                                if let override = createOverrides[index] {
                                    base = override
                                } else if case .create(let a) = action {
                                    base = a
                                } else { return }
                                draftSummary = base.summary
                                draftCategory = base.category
                                draftPriority = base.priority
                                editingIndex = index
                            } : nil
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
            }
            .sheet(isPresented: Binding(
                get: { editingIndex != nil },
                set: { if !$0 { editingIndex = nil } }
            )) {
                if let idx = editingIndex {
                    EntryEditSheet(
                        summary: $draftSummary,
                        category: $draftCategory,
                        priority: $draftPriority,
                        onSave: {
                            if let original = data.proposedActions.enumerated().first(where: { $0.offset == idx }),
                               case .create(let a) = original.element {
                                createOverrides[idx] = CreateAction(
                                    content: a.content,
                                    category: draftCategory,
                                    sourceText: a.sourceText,
                                    summary: draftSummary,
                                    priority: draftPriority,
                                    dueDateDescription: a.dueDateDescription,
                                    cadence: a.cadence
                                )
                            }
                            editingIndex = nil
                        },
                        onDismiss: { editingIndex = nil }
                    )
                }
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
                    let finalActions = buildFinalActions(from: data)
                    onConfirm(finalActions)
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

    // MARK: - Build Final Actions

    /// Rebuild the action list applying any user overrides from cycling or editing.
    private func buildFinalActions(from data: ConfirmationData) -> [AgentAction] {
        data.proposedActions.enumerated().map { index, action in
            if let kindOverride = actionOverrides[index] {
                return kindOverride.applied(to: action)
            }
            if case .create = action, let createOverride = createOverrides[index] {
                return .create(createOverride)
            }
            return action
        }
    }
}

// MARK: - Action Kind Cycling

/// The mutation types a user can cycle through on a proposed action row.
enum ProposedActionKind {
    case complete
    case archive
    case create

    static func from(_ action: AgentAction) -> ProposedActionKind {
        switch action {
        case .complete: return .complete
        case .archive: return .archive
        case .create: return .create
        default: return .complete
        }
    }

    /// Cycle: complete ↔ archive. Creates don't cycle.
    var next: ProposedActionKind {
        switch self {
        case .complete: return .archive
        case .archive: return .complete
        case .create: return .create
        }
    }

    var isCyclable: Bool {
        self == .complete || self == .archive
    }

    var label: String {
        switch self {
        case .complete: return "Complete"
        case .archive: return "Archive"
        case .create: return "Create"
        }
    }

    var icon: String {
        switch self {
        case .complete: return "checkmark.circle.fill"
        case .archive: return "archivebox.fill"
        case .create: return "plus.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .complete: return Theme.Colors.accentGreen
        case .archive: return Theme.Colors.accentYellow
        case .create: return Theme.Colors.accentPurple
        }
    }

    /// Convert the original action to this kind, preserving the entry ID.
    func applied(to original: AgentAction) -> AgentAction {
        switch (self, original) {
        case (.archive, .complete(let a)):
            return .archive(ArchiveAction(id: a.id, reason: a.reason))
        case (.complete, .archive(let a)):
            return .complete(CompleteAction(id: a.id, reason: a.reason))
        default:
            return original
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
    let currentKind: ProposedActionKind
    let onCycle: () -> Void
    var onEdit: (() -> Void)?

    /// Resolve the entry referenced by this action
    private var resolvedEntry: Entry? {
        guard let shortID = actionEntryID else { return nil }
        return Entry.resolve(shortID: shortID, in: entries)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: currentKind.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(currentKind.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)

                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Action badge — tappable for cycling; pencil for editable creates
            if currentKind.isCyclable {
                Button(action: onCycle) {
                    Text(currentKind.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(currentKind.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(currentKind.color.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else if onEdit != nil {
                Image(systemName: "pencil")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(currentKind.color)
                    .padding(7)
                    .background(currentKind.color.opacity(0.12))
                    .clipShape(Circle())
            } else {
                Text(currentKind.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(currentKind.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(currentKind.color.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(Theme.Colors.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(currentKind.color.opacity(0.2), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { onEdit?() }
    }

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
}
