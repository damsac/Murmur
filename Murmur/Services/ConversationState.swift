import Foundation
import Observation
import SwiftUI
import SwiftData
import MurmurCore
import AVFAudio
import UIKit
import os.log

private let sseLog = Logger(subsystem: "com.gudnuf.murmur", category: "SSE")

/// Manages conversation thread state, input lifecycle, and agent pipeline interaction.
/// Lazy-initialized from AppState on first conversation open.
@Observable
@MainActor
final class ConversationState {
    // MARK: - Thread

    var threadItems: [ThreadItem] = []
    var inputState: ConversationInputState = .idle
    var inputText: String = ""

    // MARK: - Inline Home Screen State

    /// Latest agent response text for the stream overlay. Cleared after animation.
    var agentStreamText: String?

    /// Entry IDs created or updated in the current agent response.
    /// Views use this to apply arrival glow animation.
    var arrivedEntryIDs: Set<UUID> = []

    /// Entry IDs waiting to be revealed with stagger animation.
    /// Entries exist in SwiftData but are filtered from the view until revealed.
    var pendingRevealEntryIDs: Set<UUID> = []

    /// Transcript saved when recording stops, shown in overlay during processing.
    var displayTranscript: String?

    /// Rolling buffer of recent audio levels for waveform visualization (0.0–1.0).
    var audioLevels: [Float] = []
    private static let maxAudioLevels = 50

    // MARK: - Internal

    private var generationCounter: Int = 0
    private var processingTask: Task<Void, Never>?
    private var recordingTask: Task<Void, Never>?
    private var conversation: LLMConversation = LLMConversation()

    /// Stable ID for the ephemeral status indicator (replaced in-place, not appended)
    private let statusItemID = UUID()

    // MARK: - Dependencies (set by AppState)

    weak var appState: AppState?

    // MARK: - Computed

    var isProcessing: Bool {
        if case .processing = inputState { return true }
        return false
    }

    var isRecording: Bool {
        if case .recording = inputState { return true }
        return false
    }

    var hasItems: Bool { !threadItems.isEmpty }

    // MARK: - Text Input

    func submitText(
        entries: [Entry],
        modelContext: ModelContext,
        preferences: NotificationPreferences
    ) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard case .idle = inputState else { return }

        // Cap input length
        let cappedText = String(text.prefix(1000))
        inputText = ""

        // Add user input to thread
        threadItems.append(.userInput(text: cappedText, isCollapsed: true))

        submit(
            text: cappedText,
            entries: entries,
            modelContext: modelContext,
            preferences: preferences
        )
    }

    // MARK: - Voice Input

    func startRecording() {
        guard case .idle = inputState else { return }
        guard let pipeline = appState?.pipeline else { return }

        arrivedEntryIDs.removeAll()
        pendingRevealEntryIDs.removeAll()

        withAnimation(.easeInOut(duration: 0.35)) {
            inputState = .recording(transcript: "")
        }
        // Add status indicator
        removeStatusItem()
        threadItems.append(.status(id: statusItemID, kind: .recording(transcript: "")))

        recordingTask?.cancel()
        recordingTask = Task { @MainActor in
            guard await ensureMicPermission() else { return }

            do {
                try await pipeline.startRecording()
            } catch {
                inputState = .idle
                removeStatusItem()
                return
            }

            await consumeRecordingStreams(from: pipeline)
        }
    }

    private func ensureMicPermission() async -> Bool {
        let recordPermission = AVAudioApplication.shared.recordPermission
        if recordPermission == .undetermined {
            let granted = await AVAudioApplication.requestRecordPermission()
            if !granted {
                inputState = .idle
                removeStatusItem()
                return false
            }
        } else if recordPermission == .denied {
            inputState = .idle
            removeStatusItem()
            return false
        }
        return true
    }

    private func consumeRecordingStreams(from pipeline: Pipeline) async {
        guard let transcriber = pipeline.transcriber as? AppleSpeechTranscriber else { return }

        let audioTask = Task { @MainActor in
            for await level in transcriber.audioLevelStream {
                guard !Task.isCancelled else { break }
                self.audioLevels.append(level)
                if self.audioLevels.count > Self.maxAudioLevels {
                    self.audioLevels.removeFirst(self.audioLevels.count - Self.maxAudioLevels)
                }
            }
        }

        for await transcript in transcriber.transcriptStream {
            guard !Task.isCancelled else { break }
            inputState = .recording(transcript: transcript)
            updateStatusItem(kind: .recording(transcript: transcript))
        }

        audioTask.cancel()
    }

    func stopRecording(
        entries: [Entry],
        modelContext: ModelContext,
        preferences: NotificationPreferences
    ) {
        guard case .recording(let currentTranscript) = inputState else { return }
        guard let pipeline = appState?.pipeline else { return }

        recordingTask?.cancel()
        recordingTask = nil
        audioLevels = []

        // Save transcript for overlay display during processing
        displayTranscript = currentTranscript

        // Grab transcript synchronously before any awaits to avoid idle flash
        let gen = nextGeneration()
        withAnimation(.easeInOut(duration: 0.35)) {
            inputState = .processing(generation: gen)
        }
        removeStatusItem()
        threadItems.append(.status(id: statusItemID, kind: .processing))

        Task { @MainActor in
            let liveText = await pipeline.currentTranscript
            // Fall back to the last stream transcript if the pipeline transcript is empty
            let finalText = liveText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? currentTranscript
                : liveText
            if finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await pipeline.cancelRecording()
                inputState = .idle
                displayTranscript = nil
                removeStatusItem()
                return
            }
            // Update with final transcript
            displayTranscript = finalText

            await pipeline.cancelRecording()

            // Replace processing status with user input, then submit
            removeStatusItem()
            threadItems.append(.userInput(text: finalText, isCollapsed: true))

            submitDirect(
                text: finalText,
                generation: gen,
                entries: entries,
                modelContext: modelContext,
                preferences: preferences
            )
        }
    }

    func cancelRecording() {
        guard case .recording = inputState else { return }
        guard let pipeline = appState?.pipeline else { return }

        recordingTask?.cancel()
        recordingTask = nil
        audioLevels = []
        Task { @MainActor in
            await pipeline.cancelRecording()
            inputState = .idle
            removeStatusItem()
        }
    }

    // MARK: - Processing

    private func submit(
        text: String,
        entries: [Entry],
        modelContext: ModelContext,
        preferences: NotificationPreferences
    ) {
        processingTask?.cancel()
        let gen = nextGeneration()
        inputState = .processing(generation: gen)

        // Show processing status
        removeStatusItem()
        threadItems.append(.status(id: statusItemID, kind: .processing))

        submitDirect(
            text: text,
            generation: gen,
            entries: entries,
            modelContext: modelContext,
            preferences: preferences
        )
    }

    /// Submit with a pre-allocated generation (used by stopRecording to avoid idle flash).
    private func submitDirect(
        text: String,
        generation gen: Int,
        entries: [Entry],
        modelContext: ModelContext,
        preferences: NotificationPreferences
    ) {
        processingTask?.cancel()
        arrivedEntryIDs.removeAll()
        pendingRevealEntryIDs.removeAll()

        processingTask = Task { @MainActor in
            guard let appState, let pipeline = appState.pipeline else {
                inputState = .idle
                removeStatusItem()
                return
            }

            do {
                sseLog.info("[SSE] submitDirect — streaming agent call, gen=\(gen)")
                appState.llmService?.agentMemory = appState.memoryStore?.load() ?? ""
                let agentContext = entries.filter { $0.status == .active || $0.status == .snoozed }
                    .map { $0.toAgentContext() }
                truncateConversationHistory()

                let stream = try await pipeline.processWithAgentStreaming(
                    transcript: text,
                    existingEntries: agentContext,
                    conversation: conversation
                )

                let execCtx = AgentActionExecutor.ExecutionContext(
                    entries: entries, transcript: text, source: .text,
                    modelContext: modelContext, preferences: preferences,
                    memoryStore: appState.memoryStore
                )
                try await consumeAgentStream(stream, generation: gen, context: execCtx, appState: appState)
                inputState = .idle
            } catch {
                guard !Task.isCancelled else { return }
                removeStatusItem()
                sseLog.error("[SSE] streaming agent call failed: \(error.localizedDescription)")
                threadItems.append(.error(message: sanitizeError(error), retryText: text))
                inputState = .idle
            }
        }
    }

    private func consumeAgentStream(
        _ stream: AsyncThrowingStream<AgentStreamEvent, Error>,
        generation gen: Int,
        context execCtx: AgentActionExecutor.ExecutionContext,
        appState: AppState
    ) async throws {
        var allApplied: [AgentActionExecutor.AppliedAction] = []
        var allFailures: [AgentActionExecutor.ActionFailure] = []
        var allUndoItems: [UndoItem] = []
        var allOutcomes: [AgentActionExecutor.ActionOutcome] = []
        var allGroups: [ToolCallGroup] = []
        var allParseFailures: [ParseFailure] = []
        var streamedText = ""

        for try await event in stream {
            guard !Task.isCancelled else { break }

            switch event {
            case .textDelta(let delta):
                streamedText += delta
                self.agentStreamText = streamedText

            case .toolCallStarted:
                break

            case .toolCallCompleted(let result):
                sseLog.info("[SSE] tool call completed: \(result.toolName) — executing")
                allGroups.append(result.group)
                let execResult = AgentActionExecutor.execute(actions: result.actions, context: execCtx)
                allApplied.append(contentsOf: execResult.applied)
                allFailures.append(contentsOf: execResult.failures)
                allUndoItems.append(contentsOf: execResult.undo.items)
                allOutcomes.append(contentsOf: execResult.outcomes)
                trackArrivedEntries(execResult.applied)

            case .toolCallFailed(let failure):
                allParseFailures.append(failure)

            case .completed:
                await appState.refreshCreditBalance()
                let toolResults = ToolResultBuilder.build(
                    groups: allGroups, outcomes: allOutcomes, parseFailures: allParseFailures
                )
                conversation.replaceToolResults(toolResults)
                removeStatusItem()

                if !streamedText.isEmpty, allApplied.isEmpty {
                    threadItems.append(.agentText(text: streamedText))
                }

                let combined = AgentActionExecutor.ExecutionResult(
                    applied: allApplied, failures: allFailures,
                    undo: UndoTransaction(items: allUndoItems), outcomes: allOutcomes
                )
                recordActionResult(execResult: combined, generation: gen)
            }
        }
    }

    // MARK: - Undo

    func undoActionResult(
        _ resultData: ActionResultData,
        entries: [Entry],
        modelContext: ModelContext,
        preferences: NotificationPreferences
    ) {
        // Only allow undo if generation hasn't advanced
        guard resultData.generation == generationCounter else { return }
        resultData.undo.execute(entries: entries, context: modelContext, preferences: preferences)

        // Remove the action result from thread
        threadItems.removeAll { $0.id == threadItems.last(where: {
            if case .actionResult(_, let data) = $0 {
                return data.generation == resultData.generation
            }
            return false
        })?.id }
    }

    // MARK: - Retry

    func retryError(
        _ item: ThreadItem,
        entries: [Entry],
        modelContext: ModelContext,
        preferences: NotificationPreferences
    ) {
        guard case .error(_, _, let retryText) = item,
              let text = retryText else { return }

        // Remove the error item
        threadItems.removeAll { $0.id == item.id }

        submit(
            text: text,
            entries: entries,
            modelContext: modelContext,
            preferences: preferences
        )
    }

    // MARK: - Reset

    func reset() {
        processingTask?.cancel()
        processingTask = nil
        recordingTask?.cancel()
        recordingTask = nil
        threadItems.removeAll()
        inputState = .idle
        inputText = ""
        generationCounter = 0
        conversation = LLMConversation()
        agentStreamText = nil
        arrivedEntryIDs.removeAll()
        pendingRevealEntryIDs.removeAll()
        displayTranscript = nil
        audioLevels = []

        // Cancel any ongoing recording
        if let pipeline = appState?.pipeline {
            Task { @MainActor in
                await pipeline.cancelRecording()
            }
        }
    }

    // MARK: - Lifecycle

    func cancelProcessing() {
        processingTask?.cancel()
        processingTask = nil
        pendingRevealEntryIDs.removeAll()
        removeStatusItem()
        inputState = .idle
    }

    // MARK: - Private Helpers

    /// Track which entries just arrived and stagger their reveal.
    /// First entry appears immediately; rest appear with 150ms delays.
    private func trackArrivedEntries(_ applied: [AgentActionExecutor.AppliedAction]) {
        let entries = applied.map { $0.entry }
        guard !entries.isEmpty else { return }

        // Hide all entries initially
        for entry in entries {
            pendingRevealEntryIDs.insert(entry.id)
        }

        // Stagger reveals: first immediately, rest with 150ms gaps
        for (index, entry) in entries.enumerated() {
            let delay = Double(index) * 0.15
            Task { @MainActor in
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                guard !Task.isCancelled else { return }
                withAnimation(Animations.cardAppear) {
                    pendingRevealEntryIDs.remove(entry.id)
                    arrivedEntryIDs.insert(entry.id)
                }
                // Safety TTL: clear glow after 5s per entry
                try? await Task.sleep(for: .seconds(5))
                arrivedEntryIDs.remove(entry.id)
            }
        }
    }

    /// Record completed actions to the thread and fire haptic.
    private func recordActionResult(
        execResult: AgentActionExecutor.ExecutionResult,
        generation gen: Int
    ) {
        guard !execResult.applied.isEmpty || !execResult.failures.isEmpty else { return }

        let appliedInfos = execResult.applied.map { applied -> AppliedActionInfo in
            let actionType = AppliedActionInfo.ActionType.from(applied.action)
            return AppliedActionInfo(id: applied.entry.id, entry: applied.entry, actionType: actionType)
        }

        let summary = buildActionSummary(applied: execResult.applied, failures: execResult.failures)
        let resultData = ActionResultData(
            summary: summary,
            applied: appliedInfos,
            failures: execResult.failures.map { $0.reason },
            undo: execResult.undo,
            generation: gen
        )
        threadItems.append(.actionResult(result: resultData))
        displayTranscript = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func nextGeneration() -> Int {
        generationCounter += 1
        return generationCounter
    }

    private func removeStatusItem() {
        threadItems.removeAll { $0.id == statusItemID }
    }

    private func updateStatusItem(kind: StatusKind) {
        if let index = threadItems.firstIndex(where: { $0.id == statusItemID }) {
            threadItems[index] = .status(id: statusItemID, kind: kind)
        }
    }

    private func truncateConversationHistory() {
        conversation.truncate(keepingLast: 20)
    }
}

// MARK: - Helpers (outside class body for swiftlint type_body_length)

private func buildActionSummary(
    applied: [AgentActionExecutor.AppliedAction],
    failures: [AgentActionExecutor.ActionFailure]
) -> String {
    let labels: [(String, (AgentAction) -> Bool)] = [
        ("Created", { if case .create = $0 { return true }; return false }),
        ("Updated", { if case .update = $0 { return true }; return false }),
        ("Completed", { if case .complete = $0 { return true }; return false }),
        ("Archived", { if case .archive = $0 { return true }; return false }),
    ]
    let parts = labels.compactMap { label, pred -> String? in
        let n = applied.filter { pred($0.action) }.count
        return n > 0 ? "\(label) \(n) \(n == 1 ? "entry" : "entries")" : nil
    }
    if parts.isEmpty {
        return applied.count == 1 ? "1 change" : "\(applied.count) changes"
    }
    return parts.joined(separator: ", ")
}

private func sanitizeError(_ error: Error) -> String {
    switch error {
    case PipelineError.insufficientCredits: return "Out of credits."
    case PipelineError.emptyTranscript: return "Nothing to process."
    case PipelineError.noEntriesExtracted: return "No entries found in your input."
    case PipelineError.extractionFailed: return "Couldn't process — network error."
    default: return "Couldn't process — try again."
    }
}
