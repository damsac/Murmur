import Foundation
import Speech
import AVFoundation

/// Transcriber implementation using Apple's Speech framework
@MainActor
public final class AppleSpeechTranscriber: NSObject, Transcriber {
    private let speechRecognizer: SFSpeechRecognizer
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var _isRecording = false
    private var currentTranscript = ""

    public override init() {
        // Use device locale or fallback to US English
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) ?? SFSpeechRecognizer(locale: Locale.current)!
        super.init()
    }

    // MARK: - Transcriber Protocol

    public var isRecording: Bool {
        get async { _isRecording }
    }

    public var isAvailable: Bool {
        get async {
            // Check if speech recognition is available and authorized
            guard speechRecognizer.isAvailable else { return false }

            let authStatus = SFSpeechRecognizer.authorizationStatus()
            return authStatus == .authorized
        }
    }

    public func startRecording() async throws {
        // Request permissions if needed
        try await requestPermissions()

        guard speechRecognizer.isAvailable else {
            throw TranscriberError.speechRecognitionUnavailable
        }

        // Cancel any ongoing recognition
        recognitionTask?.cancel()
        recognitionTask = nil

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw TranscriberError.unableToCreateRequest
        }

        recognitionRequest.shouldReportPartialResults = true

        // Configure audio session before accessing audio engine
        #if !os(macOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        // Configure audio engine input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        // Start recognition
        currentTranscript = ""
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                Task { @MainActor in
                    self.currentTranscript = result.bestTranscription.formattedString
                }
            }

            if error != nil || result?.isFinal == true {
                Task { @MainActor in
                    self.audioEngine.stop()
                    self.audioEngine.inputNode.removeTap(onBus: 0)
                }
            }
        }

        _isRecording = true
    }

    public func stopRecording() async throws -> Transcript {
        guard _isRecording else {
            throw TranscriberError.notRecording
        }

        // Stop audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()

        _isRecording = false

        // Wait briefly for final transcription results
        try await Task.sleep(for: .milliseconds(500))

        // Return transcript
        let text = currentTranscript.isEmpty ? "" : currentTranscript
        return Transcript(text: text)
    }

    // MARK: - Permissions

    private func requestPermissions() async throws {
        // Request speech recognition permission
        let speechStatus = await requestSpeechAuthorization()
        guard speechStatus == .authorized else {
            throw TranscriberError.speechRecognitionNotAuthorized
        }

        // Request microphone permission
        let micStatus = await requestMicrophoneAuthorization()
        guard micStatus else {
            throw TranscriberError.microphoneNotAuthorized
        }
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        #if os(macOS)
        // On macOS, use AVCaptureDevice for microphone permission
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
        #else
        // On iOS, use AVAudioSession
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        #endif
    }
}

// MARK: - Errors

public enum TranscriberError: LocalizedError {
    case speechRecognitionUnavailable
    case speechRecognitionNotAuthorized
    case microphoneNotAuthorized
    case unableToCreateRequest
    case notRecording

    public var errorDescription: String? {
        switch self {
        case .speechRecognitionUnavailable:
            return "Speech recognition is not available on this device"
        case .speechRecognitionNotAuthorized:
            return "Speech recognition permission not granted. Please enable in Settings."
        case .microphoneNotAuthorized:
            return "Microphone permission not granted. Please enable in Settings."
        case .unableToCreateRequest:
            return "Unable to create speech recognition request"
        case .notRecording:
            return "Not currently recording"
        }
    }
}
