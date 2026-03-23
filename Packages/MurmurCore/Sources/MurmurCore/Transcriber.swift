import Foundation

/// A service that converts audio to text via streaming recording.
public protocol Transcriber: Sendable {
    /// Start recording audio
    func startRecording() async throws

    /// Stop recording and return the transcript
    func stopRecording() async throws -> Transcript

    /// Cancel recording immediately without waiting for finalization
    func cancelRecording() async

    /// The live partial transcript from the current recording session
    var currentTranscript: String { get async }

    /// Whether recording is currently active
    var isRecording: Bool { get async }

    /// Whether the transcriber is available (permissions granted, etc.)
    var isAvailable: Bool { get async }
}

/// The result of a transcription.
public struct Transcript: Codable, Sendable, Equatable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}
