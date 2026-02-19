import Foundation
import Observation
import MurmurCore

enum DisclosureLevel: Int, Codable, Comparable {
    case void = 0
    case firstLight = 1
    case gridAwakens = 2
    case viewsEmerge = 3
    case fullPower = 4

    static func < (lhs: DisclosureLevel, rhs: DisclosureLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Determine disclosure level from the number of entries the user has created.
    static func from(entryCount: Int) -> DisclosureLevel {
        switch entryCount {
        case 0:       return .void
        case 1...4:   return .firstLight
        case 5...14:  return .gridAwakens
        case 15...24: return .viewsEmerge
        default:      return .fullPower
        }
    }
}

enum RecordingState {
    case idle
    case recording
    case processing
    case confirming
}

@Observable
@MainActor
final class AppState {
    var disclosureLevel: DisclosureLevel = .void
    var devOverrideLevel: DisclosureLevel?
    var recordingState: RecordingState = .idle
    var showOnboarding: Bool = false
    var showFocusCard: Bool = false
    var isDevMode: Bool = false

    // Pipeline
    var pipeline: Pipeline?
    var pipelineError: String?

    // Shared recording state — extracted entries (not yet persisted)
    var processedEntries: [ExtractedEntry] = []
    var processedTranscript: String = ""
    var processedAudioDuration: TimeInterval?
    var processedSource: EntrySource = .voice

    var effectiveLevel: DisclosureLevel {
        devOverrideLevel ?? disclosureLevel
    }

    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    init() {}

    /// Configure the real MurmurCore pipeline — no persistence dependency.
    func configurePipeline() {
        guard let apiKey = APIKeyProvider.ppqAPIKey else {
            pipelineError = "No PPQ API key configured"
            print("⚠️ Pipeline not configured — missing PPQ_API_KEY")
            return
        }

        let transcriber = AppleSpeechTranscriber()
        let llm = PPQLLMService(apiKey: apiKey)
        pipeline = Pipeline(transcriber: transcriber, llm: llm)
    }
}
