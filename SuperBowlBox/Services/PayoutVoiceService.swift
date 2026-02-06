import Foundation
import AVFoundation
import Speech

/// Records microphone input and transcribes to text for payout rules (speak instructions).
final class PayoutVoiceService: ObservableObject {
    @Published var isRecording = false
    @Published var errorMessage: String?

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    /// Request speech and microphone authorization. Returns true if we can proceed.
    func requestAuthorization() async -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            await MainActor.run { errorMessage = "Audio session: \(error.localizedDescription)" }
            return false
        }

        let micAuthorized = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            session.requestRecordPermission { allowed in
                cont.resume(returning: allowed)
            }
        }
        guard micAuthorized else {
            await MainActor.run { errorMessage = "Microphone access is required to speak payout rules." }
            return false
        }

        let speechAuthorized = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        guard speechAuthorized else {
            await MainActor.run { errorMessage = "Speech recognition is required to turn your voice into text." }
            return false
        }

        await MainActor.run { errorMessage = nil }
        return true
    }

    /// Start recording. Call stopRecordingAndTranscribe() to get text.
    func startRecording() throws {
        errorMessage = nil
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
        isRecording = true
    }

    /// Stop recording and return transcribed text.
    func stopRecordingAndTranscribe() async throws -> String {
        guard let recorder = audioRecorder, let url = recordingURL else {
            isRecording = false
            throw PayoutVoiceError.notRecording
        }
        recorder.stop()
        audioRecorder = nil
        recordingURL = nil
        isRecording = false

        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let recognizer = recognizer else {
            try? FileManager.default.removeItem(at: url)
            throw PayoutVoiceError.recognizerUnavailable
        }

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false

            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    try? FileManager.default.removeItem(at: url)
                    cont.resume(throwing: error)
                    return
                }
                guard let result = result else {
                    try? FileManager.default.removeItem(at: url)
                    cont.resume(throwing: PayoutVoiceError.noResult)
                    return
                }
                if result.isFinal {
                    let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                    try? FileManager.default.removeItem(at: url)
                    cont.resume(returning: text.isEmpty ? "" : text)
                }
            }
        }
    }

    enum PayoutVoiceError: LocalizedError {
        case notRecording
        case recognizerUnavailable
        case noResult

        var errorDescription: String? {
            switch self {
            case .notRecording: return "Recording was not started."
            case .recognizerUnavailable: return "Speech recognition is not available."
            case .noResult: return "Could not understand audio."
            }
        }
    }
}
