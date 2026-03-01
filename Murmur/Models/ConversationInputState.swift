import Foundation

/// State machine for conversation input lifecycle.
/// Prevents race conditions from concurrent recording/processing.
enum ConversationInputState: Equatable {
    case idle
    case recording(transcript: String)
    case processing(generation: Int)
}
