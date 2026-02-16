import Foundation
import Observation

enum RecordingState {
    case idle
    case recording
    case processing
    case confirming
}

@Observable
final class AppState {
    var disclosureLevel: DisclosureLevel = .void
    var devOverrideLevel: DisclosureLevel?
    var recordingState: RecordingState = .idle
    var creditBalance: Int = 1000
    var showOnboarding: Bool = false
    var showFocusCard: Bool = false
    var isDevMode: Bool = false

    var effectiveLevel: DisclosureLevel {
        devOverrideLevel ?? disclosureLevel
    }

    init() {}
}
