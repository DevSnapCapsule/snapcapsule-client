import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                bubbleContent
            }

            if !isUser { Spacer(minLength: 48) }
        }
        .transition(.move(edge: isUser ? .trailing : .leading).combined(with: .opacity))
    }

    @ViewBuilder
    private var bubbleContent: some View {
        switch message.content {
        case .text(let text):
            Text(text)
                .font(.body)
                .foregroundStyle(isUser ? Color.white : Color.white.opacity(0.92))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        case .searchResults(let ids, let queryLabel):
            VStack(alignment: .leading, spacing: 10) {
                Text("\(ids.count) photo\(ids.count == 1 ? "" : "s") for \"\(queryLabel)\"")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))

                SearchResultGridView(imageObjectIDs: ids)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isUser {
            LinearGradient(
                colors: [Color.blue.opacity(0.95), Color.purple.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.white.opacity(0.12)
        }
    }
}
