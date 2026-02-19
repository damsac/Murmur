import Foundation

/// A service that converts audio to text via streaming recording.
public protocol Transcriber: Sendable {
    /// Start recording audio
    func startRecording() async throws

    /// Stop recording and return the transcript
    func stopRecording() async throws -> Transcript

    /// Whether recording is currently active
    var isRecording: Bool { get async }

    /// Whether the transcriber is available (permissions granted, etc.)
    var isAvailable: Bool { get async }
}

/// The result of a transcription, containing the full text and optional segments.
public struct Transcript: Codable, Sendable, Equatable {
    public let text: String
    public let segments: [Segment]

    public init(text: String, segments: [Segment]? = nil) {
        self.text = text
        self.segments = segments ?? [Segment(text: text)]
    }

    /// Total duration derived from the last segment's endTime, if available
    public var duration: TimeInterval? {
        segments.last?.endTime
    }

    public struct Segment: Codable, Sendable, Equatable {
        public let text: String
        public let startTime: TimeInterval?
        public let endTime: TimeInterval?

        public init(text: String, startTime: TimeInterval? = nil, endTime: TimeInterval? = nil) {
            self.text = text
            self.startTime = startTime
            self.endTime = endTime
        }
    }
}
