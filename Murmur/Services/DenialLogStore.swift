import Foundation
import MurmurCore

/// File-based store for logging denied confirmations.
/// Appends JSON lines for future learning/improvement tasks.
@MainActor
final class DenialLogStore {
    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("denial-log.jsonl")
    }

    func log(transcript: String, proposedActions: [AgentAction], message: String) {
        let entry: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "transcript": transcript,
            "message": message,
            "proposedActionCount": proposedActions.count,
            "proposedActionTypes": proposedActions.map(actionTypeName),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: entry),
              let line = String(data: data, encoding: .utf8)
        else { return }

        let lineWithNewline = line + "\n"
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write(lineWithNewline.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? lineWithNewline.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    private func actionTypeName(_ action: AgentAction) -> String {
        switch action {
        case .create: return "create"
        case .update: return "update"
        case .complete: return "complete"
        case .archive: return "archive"
        case .updateMemory: return "updateMemory"
        case .confirm: return "confirm"
        }
    }
}
