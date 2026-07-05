import Foundation
import WhisperKit

// On-device streaming transcription via WhisperKit (Core ML Whisper), chosen over
// SFSpeechRecognizer for better accuracy on accents/technical vocabulary.
// Confirmed segments are typed once and never repeated; only the delta since the
// last flush is sent through InputInjector.
@MainActor
final class VoiceDictation {
    private var whisperKit: WhisperKit?
    private var streamTranscriber: AudioStreamTranscriber?
    private var streamTask: Task<Void, Never>?
    private var typedConfirmedSegmentCount = 0
    private var lastTypedUnconfirmedText = ""
    private var isStarting = false

    func start() {
        guard streamTask == nil, !isStarting else { return }
        isStarting = true
        streamTask = Task { [weak self] in
            await self?.runStreamingSession()
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        isStarting = false
        typedConfirmedSegmentCount = 0
        lastTypedUnconfirmedText = ""
        Task { [streamTranscriber] in
            await streamTranscriber?.stopStreamTranscription()
        }
        streamTranscriber = nil
        whisperKit = nil
    }

    private func runStreamingSession() async {
        do {
            if whisperKit == nil {
                // "base.en" balances accuracy and on-device speed better than "tiny.en".
                let config = WhisperKitConfig(model: "base.en", verbose: false, logLevel: .none, download: true)
                whisperKit = try await WhisperKit(config)
            }
            guard let whisperKit, let tokenizer = whisperKit.tokenizer else {
                isStarting = false
                return
            }

            let decodingOptions = DecodingOptions(task: .transcribe, language: "en", withoutTimestamps: true)

            let transcriber = AudioStreamTranscriber(
                audioEncoder: whisperKit.audioEncoder,
                featureExtractor: whisperKit.featureExtractor,
                segmentSeeker: whisperKit.segmentSeeker,
                textDecoder: whisperKit.textDecoder,
                tokenizer: tokenizer,
                audioProcessor: whisperKit.audioProcessor,
                decodingOptions: decodingOptions
            ) { [weak self] _, newState in
                Task { @MainActor [weak self] in
                    self?.handleStateUpdate(newState)
                }
            }
            streamTranscriber = transcriber
            isStarting = false
            try await transcriber.startStreamTranscription()
        } catch {
            isStarting = false
        }
    }

    private func handleStateUpdate(_ state: AudioStreamTranscriber.State) {
        let confirmed = state.confirmedSegments
        if confirmed.count > typedConfirmedSegmentCount {
            let newSegments = confirmed[typedConfirmedSegmentCount...]
            let newText = newSegments.map(\.text).joined()
            if !newText.isEmpty {
                InputInjector.typeString(newText)
            }
            typedConfirmedSegmentCount = confirmed.count
            lastTypedUnconfirmedText = ""
        }
    }
}
