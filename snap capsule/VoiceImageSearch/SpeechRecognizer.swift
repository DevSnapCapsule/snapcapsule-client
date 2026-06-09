import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechRecognizer: ObservableObject {
    enum AuthorizationState: Equatable {
        case notDetermined
        case authorized
        case microphoneDenied
        case speechRecognitionDenied
        case unavailable
    }

    /// Latest partial or final transcription for the current session.
    @Published private(set) var transcript = ""
    @Published private(set) var isRecording = false
    @Published private(set) var authorizationState: AuthorizationState = .notDetermined
    @Published private(set) var errorMessage: String?

    /// Set when a recording session ends with text ready to send (one shot per session).
    @Published private(set) var sessionTranscript: String?

    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var finalizeWorkItem: DispatchWorkItem?
    private var hasDeliveredSession = false
    private var receivedFinalResult = false

    init(locale: Locale = Locale(identifier: "en-US")) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        authorizationState = speechRecognizer?.isAvailable == true ? .notDetermined : .unavailable
    }

    func requestAuthorizationIfNeeded() async {
        guard authorizationState == .notDetermined else { return }

        let microphoneGranted = await requestMicrophonePermission()
        guard microphoneGranted else {
            authorizationState = .microphoneDenied
            return
        }

        let speechStatus = await requestSpeechAuthorization()
        switch speechStatus {
        case .authorized:
            authorizationState = speechRecognizer?.isAvailable == true ? .authorized : .unavailable
        case .denied, .restricted:
            authorizationState = .speechRecognitionDenied
        case .notDetermined:
            authorizationState = .notDetermined
        @unknown default:
            authorizationState = .unavailable
        }
    }

    func startRecording() async throws {
        errorMessage = nil
        cancelFinalizeWorkItem()

        if authorizationState == .notDetermined {
            await requestAuthorizationIfNeeded()
        }

        switch authorizationState {
        case .microphoneDenied:
            throw VoiceSearchError.microphoneDenied
        case .speechRecognitionDenied:
            throw VoiceSearchError.speechRecognitionDenied
        case .unavailable:
            throw VoiceSearchError.speechRecognizerUnavailable
        case .notDetermined:
            throw VoiceSearchError.speechRecognitionDenied
        case .authorized:
            break
        }

        if isRecording {
            await finishRecording()
        }

        // Fresh session — replace prior live text entirely.
        transcript = ""
        sessionTranscript = nil
        hasDeliveredSession = false
        receivedFinalResult = false

        try configureAudioSession()
        try beginRecognition()
        isRecording = true
    }

    /// Clears the pending session payload after the view model accepts it (prevents duplicate API calls).
    func acknowledgeSessionDelivery() {
        sessionTranscript = nil
    }

    /// User released the mic — wait for Apple's final transcript instead of cancelling immediately.
    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        recognitionRequest?.endAudio()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, !self.receivedFinalResult else { return }
                self.completeSessionUsingBestTranscript()
            }
        }
        finalizeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    // MARK: - Private

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func beginRecognition() throws {
        tearDownAudioPipeline(cancelTask: true)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw VoiceSearchError.speechRecognizerUnavailable
        }
        recognitionRequest.shouldReportPartialResults = true
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceSearchError.speechRecognizerUnavailable
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    // Always replace the full phrase — never append to a previous session.
                    self.transcript = result.bestTranscription.formattedString

                    if result.isFinal {
                        self.receivedFinalResult = true
                        self.cancelFinalizeWorkItem()
                        self.completeSession(with: self.transcript)
                    }
                }

                if let error, !self.isBenignSpeechError(error) {
                    self.errorMessage = error.localizedDescription
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func finishRecording() async {
        stopRecording()
        try? await Task.sleep(nanoseconds: 1_600_000_000)
    }

    private func completeSessionUsingBestTranscript() {
        completeSession(with: transcript)
    }

    private func completeSession(with text: String) {
        guard !hasDeliveredSession else { return }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        hasDeliveredSession = true
        cancelFinalizeWorkItem()
        tearDownAudioPipeline(cancelTask: true)

        transcript = trimmed
        sessionTranscript = trimmed

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func tearDownAudioPipeline(cancelTask: Bool) {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)

        if cancelTask {
            recognitionTask?.cancel()
        }

        recognitionRequest = nil
        recognitionTask = nil
    }

    private func cancelFinalizeWorkItem() {
        finalizeWorkItem?.cancel()
        finalizeWorkItem = nil
    }

    private func isBenignSpeechError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == "kAFAssistantErrorDomain", nsError.code == 1110 {
            return true
        }
        if nsError.domain == "kLSRErrorDomain", nsError.code == 301 {
            return true
        }
        if nsError.code == 216 {
            return true
        }
        let message = nsError.localizedDescription.lowercased()
        return message.contains("cancel") || message.contains("no speech")
    }
}
