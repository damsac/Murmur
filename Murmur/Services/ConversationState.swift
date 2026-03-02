import Foundation
import Observation
import SwiftUI
import SwiftData
import MurmurCore
import AVFAudio
import UIKit

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
            if liveText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await pipeline.cancelRecording()
                inputState = .idle
                displayTranscript = nil
                removeStatusItem()
                return
            }
            // Update with final transcript
            displayTranscript = liveText

            await pipeline.cancelRecording()

            // Replace processing status with user input, then submit
            removeStatusItem()
            threadItems.append(.userInput(text: liveText, isCollapsed: true))

            submitDirect(
                text: liveText,
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
        processingTask = Task { @MainActor in
            guard let appState, let pipeline = appState.pipeline else {
                inputState = .idle
                removeStatusItem()
                return
            }

            do {
                appState.llmService?.agentMemory = appState.memoryStore?.load() ?? ""
                let agentContext = entries.filter { $0.status == .active || $0.status == .snoozed }
                    .map { $0.toAgentContext() }

                // Truncate conversation history to prevent unbounded token growth
                truncateConversationHistory()

                let result = try await pipeline.processWithAgent(
                    transcript: text,
                    existingEntries: agentContext,
                    conversation: conversation
                )
                guard !Task.isCancelled else { return }

                await appState.refreshCreditBalance()

                // Execute actions
                let ctx = AgentActionExecutor.ExecutionContext(
                    entries: entries,
                    transcript: text,
                    source: .text,
                    modelContext: modelContext,
                    preferences: preferences,
                    memoryStore: appState.memoryStore
                )
                let execResult = AgentActionExecutor.execute(
                    actions: result.response.actions,
                    context: ctx
                )
                guard !Task.isCancelled else { return }

                // Build and replace tool results
                let toolResults = ToolResultBuilder.build(
                    groups: result.response.toolCallGroups,
                    outcomes: execResult.outcomes,
                    parseFailures: result.response.parseFailures
                )
                conversation.replaceToolResults(toolResults)

                // Remove processing status
                removeStatusItem()

                // Add agent text response if present (text-only response, no actions)
                if let textResponse = result.response.textResponse,
                   !textResponse.isEmpty {
                    threadItems.append(.agentText(text: textResponse))
                    // Set stream text for inline overlay
                    self.agentStreamText = textResponse
                }

                // Add action result if there were actions
                if !execResult.applied.isEmpty || !execResult.failures.isEmpty {
                    handleActionResult(execResult: execResult, generation: gen)
                }

                inputState = .idle
            } catch {
                guard !Task.isCancelled else { return }
                removeStatusItem()

                let errorMessage = sanitizeError(error)
                let retryText = text
                threadItems.append(.error(message: errorMessage, retryText: retryText))
                inputState = .idle
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

    // MARK: - Action Result Handling

    private func handleActionResult(
        execResult: AgentActionExecutor.ExecutionResult,
        generation gen: Int
    ) {
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

        // Set agent stream text from summary if no text response
        if self.agentStreamText == nil {
            self.agentStreamText = resultData.summary
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
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
        removeStatusItem()
        inputState = .idle
    }

    // MARK: - Private Helpers

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

    private func buildActionSummary(
        applied: [AgentActionExecutor.AppliedAction],
        failures: [AgentActionExecutor.ActionFailure]
    ) -> String {
        let counts: [(String, Int)] = [
            ("Created", applied.filter { if case .create = $0.action { return true }; return false }.count),
            ("Updated", applied.filter { if case .update = $0.action { return true }; return false }.count),
            ("Completed", applied.filter { if case .complete = $0.action { return true }; return false }.count),
            ("Archived", applied.filter { if case .archive = $0.action { return true }; return false }.count)
        ]

        let parts = counts.compactMap { label, count -> String? in
            guard count > 0 else { return nil }
            return "\(label) \(count) \(count == 1 ? "entry" : "entries")"
        }

        if parts.isEmpty {
            let total = applied.count
            return total == 1 ? "1 change" : "\(total) changes"
        }
        return parts.joined(separator: ", ")
    }

    private func sanitizeError(_ error: Error) -> String {
        if case PipelineError.insufficientCredits = error {
            return "Out of credits."
        }
        if case PipelineError.emptyTranscript = error {
            return "Nothing to process."
        }
        if case PipelineError.noEntriesExtracted = error {
            return "No entries found in your input."
        }
        if case PipelineError.extractionFailed = error {
            return "Couldn't process — network error."
        }
        return "Couldn't process — try again."
    }

    /// Truncate conversation history to prevent unbounded token growth.
    /// Keeps the system prompt (first message) and the most recent turns.
    private func truncateConversationHistory() {
        let maxMessages = 20  // ~10 turns (user + assistant pairs)
        conversation.truncate(keepingLast: maxMessages)
    }
}
