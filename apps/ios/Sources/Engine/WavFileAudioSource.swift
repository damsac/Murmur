import Foundation
import AVFoundation

// Mic-free scripted-audio path (Plan 08 D7): reads a bundled 16 kHz mono WAV (a
// short scripted jobsite utterance) and pushes its f32 PCM in ~200 ms chunks
// through the SAME `pushSamples` closure `AudioCaptureSource` uses — so the real
// whisper path can be exercised end-to-end on sim/device WITHOUT a live mic.
// Selected with the `wavwalk=1` launch arg. The text demo path (ScriptedSource)
// stays the default screenshot/CI flow and does not depend on whisper at all.
@MainActor
final class WavFileAudioSource: PCMAudioSource {
    private let pushSamples: @Sendable ([Float]) -> Void
    private let fixtureName: String
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )!
    /// ~200 ms of 16 kHz audio per push — realistic frame cadence (D1).
    private let chunkFrames = 3_200
    private var task: Task<Void, Never>?
    private var paused = false

    /// `fixtureName` is a bundled resource base name (default: a committed
    /// jobsite fixture). Resolution happens at `start()` so a missing fixture
    /// degrades to a no-op rather than trapping at init.
    init(fixtureName: String = "jobsite-16k", pushSamples: @escaping @Sendable ([Float]) -> Void) {
        self.fixtureName = fixtureName
        self.pushSamples = pushSamples
    }

    func start() {
        guard let samples = Self.loadFixture(named: fixtureName, target: targetFormat) else { return }
        let push = pushSamples
        let frames = chunkFrames
        task = Task { [weak self] in
            var offset = 0
            while offset < samples.count {
                if self?.paused == true {
                    try? await Task.sleep(for: .milliseconds(100))
                    continue
                }
                let end = min(offset + frames, samples.count)
                push(Array(samples[offset..<end]))
                offset = end
                // Pace roughly to real time so the pump sees a live cadence.
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    func pause() { paused = true }
    func resume() { paused = false }

    func stop() {
        task?.cancel()
        task = nil
    }

    /// Load the bundled WAV and return 16 kHz mono f32 samples (converting if
    /// the file's format differs). Returns nil if the resource is absent.
    private static func loadFixture(named name: String, target: AVAudioFormat) -> [Float]? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let file = try? AVAudioFile(forReading: url) else { return nil }
        let srcFormat = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let srcBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: frameCount),
              (try? file.read(into: srcBuffer)) != nil else { return nil }

        // Already 16 kHz mono f32 — read directly.
        if srcFormat.sampleRate == target.sampleRate,
           srcFormat.channelCount == 1,
           srcFormat.commonFormat == .pcmFormatFloat32,
           let channel = srcBuffer.floatChannelData {
            return Array(UnsafeBufferPointer(start: channel[0], count: Int(srcBuffer.frameLength)))
        }

        // Otherwise convert to the target format.
        guard let converter = AVAudioConverter(from: srcFormat, to: target) else { return nil }
        let ratio = target.sampleRate / srcFormat.sampleRate
        let outCapacity = AVAudioFrameCount(Double(srcBuffer.frameLength) * ratio) + 1024
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: outCapacity) else { return nil }
        var supplied = false
        var convError: NSError?
        converter.convert(to: out, error: &convError) { _, status in
            if supplied {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return srcBuffer
        }
        guard convError == nil, let channel = out.floatChannelData, out.frameLength > 0 else { return nil }
        return Array(UnsafeBufferPointer(start: channel[0], count: Int(out.frameLength)))
    }
}
