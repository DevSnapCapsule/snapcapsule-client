import Foundation
import CoreData

// MARK: - Chat

enum ChatMessageRole: String, Codable {
    case user
    case assistant
}

enum ChatMessageContent: Equatable {
    case text(String)
    case searchResults([NSManagedObjectID], queryLabel: String)

    static func == (lhs: ChatMessageContent, rhs: ChatMessageContent) -> Bool {
        switch (lhs, rhs) {
        case let (.text(a), .text(b)):
            return a == b
        case let (.searchResults(a, labelA), .searchResults(b, labelB)):
            let aKeys = a.map { $0.uriRepresentation().absoluteString }
            let bKeys = b.map { $0.uriRepresentation().absoluteString }
            return labelA == labelB && aKeys == bKeys
        default:
            return false
        }
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: ChatMessageRole
    let content: ChatMessageContent
    let timestamp: Date

    init(
        id: UUID = UUID(),
        role: ChatMessageRole,
        content: ChatMessageContent,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - AI intent

/// Structured search intent extracted by Gemini from natural language.
struct SearchIntent: Codable, Equatable {
    let searchQuery: String
    let brand: String?
    let object: String?
    let product: String?
    let scene: String?
    let personContext: String?

    /// Non-empty, deduplicated terms used for Core Data `searchableText` matching.
    var searchableTerms: [String] {
        let candidates = [
            searchQuery,
            brand,
            object,
            product,
            scene
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        var seen = Set<String>()
        return candidates.filter { term in
            let key = term.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }
}

/// Full Gemini JSON payload including the conversational reply.
struct AssistantResponse: Codable, Equatable {
    let searchQuery: String
    let brand: String?
    let object: String?
    let product: String?
    let scene: String?
    let personContext: String?
    let assistantMessage: String

    var searchIntent: SearchIntent {
        SearchIntent(
            searchQuery: searchQuery,
            brand: brand,
            object: object,
            product: product,
            scene: scene,
            personContext: personContext
        )
    }
}

// MARK: - Errors

enum VoiceSearchError: LocalizedError, Equatable {
    case microphoneDenied
    case speechRecognitionDenied
    case speechRecognizerUnavailable
    case emptyTranscript
    case networkUnavailable
    case missingAPIKey
    case geminiFailed(String)
    case invalidJSON
    case noMatchingImages

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "Microphone access is required for voice search. Enable it in Settings."
        case .speechRecognitionDenied:
            return "Speech recognition is required for voice search. Enable it in Settings."
        case .speechRecognizerUnavailable:
            return "Speech recognition is not available on this device right now."
        case .emptyTranscript:
            return "I didn't catch that. Try speaking again."
        case .networkUnavailable:
            return "An internet connection is required for AI search."
        case .missingAPIKey:
            return "Gemini API key is not configured. Add Secrets.plist, Config.plist, .env, or set GEMINI_API_KEY."
        case .geminiFailed(let message):
            return message
        case .invalidJSON:
            return "Received an unexpected response from the AI service."
        case .noMatchingImages:
            return "No matching photos were found in your library."
        }
    }
}
