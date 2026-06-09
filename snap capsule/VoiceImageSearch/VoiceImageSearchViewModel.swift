import Combine
import CoreData
import Foundation

@MainActor
final class VoiceImageSearchViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isProcessing = false
    @Published private(set) var isTyping = false
    @Published private(set) var liveTranscript = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var showErrorAlert = false

    let speechRecognizer = SpeechRecognizer()

    private let geminiService: GeminiSearchIntentService
    private let searchService: ImageMetadataSearchService
    private let networkMonitor: NetworkMonitor
    private var cancellables = Set<AnyCancellable>()
    private var lastProcessedTranscript: String?
    private var lastProcessedAt: Date?

    init(
        geminiService: GeminiSearchIntentService = .shared,
        searchService: ImageMetadataSearchService = ImageMetadataSearchService(),
        networkMonitor: NetworkMonitor = .shared
    ) {
        self.geminiService = geminiService
        self.searchService = searchService
        self.networkMonitor = networkMonitor

        speechRecognizer.$transcript
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transcript in
                guard let self, self.speechRecognizer.isRecording else { return }
                self.liveTranscript = transcript
            }
            .store(in: &cancellables)

        speechRecognizer.$sessionTranscript
            .compactMap { $0 }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transcript in
                self?.enqueueTranscript(transcript, source: .voice)
            }
            .store(in: &cancellables)

        appendWelcomeMessageIfNeeded()
    }

    var isRecording: Bool {
        speechRecognizer.isRecording
    }

    func onAppear() {
        Task {
            await speechRecognizer.requestAuthorizationIfNeeded()
        }
    }

    func toggleRecording() {
        Task {
            if speechRecognizer.isRecording {
                speechRecognizer.stopRecording()
            } else {
                errorMessage = nil
                liveTranscript = ""
                do {
                    try await speechRecognizer.startRecording()
                } catch {
                    present(error)
                }
            }
        }
    }

    func submitTypedQuery(_ text: String) {
        enqueueTranscript(text, source: .typed)
    }

    func dismissError() {
        showErrorAlert = false
        errorMessage = nil
    }

    // MARK: - Private

    private enum TranscriptSource {
        case voice
        case typed
    }

    /// Single entry point for voice and typed queries — claims processing before any async work.
    private func enqueueTranscript(_ transcript: String, source: TranscriptSource) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if source == .voice {
                speechRecognizer.acknowledgeSessionDelivery()
            }
            present(VoiceSearchError.emptyTranscript)
            return
        }

        if isProcessing {
            if source == .voice {
                speechRecognizer.acknowledgeSessionDelivery()
            }
            return
        }

        let now = Date()
        if trimmed == lastProcessedTranscript,
           let lastProcessedAt,
           now.timeIntervalSince(lastProcessedAt) < 5 {
            if source == .voice {
                speechRecognizer.acknowledgeSessionDelivery()
            }
            return
        }

        isProcessing = true
        liveTranscript = ""
        if source == .voice {
            speechRecognizer.acknowledgeSessionDelivery()
        }

        Task {
            await processTranscript(trimmed)
        }
    }

    private func appendWelcomeMessageIfNeeded() {
        guard messages.isEmpty else { return }
        messages.append(
            ChatMessage(
                role: .assistant,
                content: .text("Hi! Tap the mic, speak your search, then tap again when done. Each recording starts fresh.")
            )
        )
    }

    private func processTranscript(_ transcript: String) async {
        defer { isProcessing = false }

        guard networkMonitor.isConnected else {
            present(VoiceSearchError.networkUnavailable)
            return
        }

        errorMessage = nil
        messages.append(ChatMessage(role: .user, content: .text(transcript)))
        isTyping = true

        do {
            let response = try await geminiService.parseSearchIntent(from: transcript)
            lastProcessedTranscript = transcript
            lastProcessedAt = Date()
            isTyping = false

            messages.append(
                ChatMessage(
                    role: .assistant,
                    content: .text(response.assistantMessage)
                )
            )

            let results = try searchService.search(with: response.searchIntent)
            if results.isEmpty {
                messages.append(
                    ChatMessage(
                        role: .assistant,
                        content: .text("I couldn't find any indexed photos matching \"\(response.searchQuery)\". Try another phrase or check that your photos are indexed.")
                    )
                )
            } else {
                let ids = results.map(\.objectID)
                messages.append(
                    ChatMessage(
                        role: .assistant,
                        content: .searchResults(ids, queryLabel: response.searchQuery)
                    )
                )
            }
        } catch let error as VoiceSearchError {
            isTyping = false
            present(error)
        } catch let error as GeminiServiceError {
            isTyping = false
            present(VoiceSearchError.geminiFailed(error.localizedDescription))
        } catch {
            isTyping = false
            present(VoiceSearchError.geminiFailed(error.localizedDescription))
        }
    }

    private func present(_ error: VoiceSearchError) {
        errorMessage = error.errorDescription
        showErrorAlert = true
    }

    private func present(_ error: Error) {
        if let voiceError = error as? VoiceSearchError {
            present(voiceError)
        } else {
            present(VoiceSearchError.geminiFailed(error.localizedDescription))
        }
    }
}
