import SwiftUI

struct VoiceImageSearchView: View {
    @StateObject private var viewModel = VoiceImageSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var typedQuery = ""

    var body: some View {
        NavigationStack {
            ZStack {
                VoiceImageSearchBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    conversationList
                    inputBar
                }
            }
            .navigationTitle("Voice Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.onAppear()
        }
        .alert("Voice Search", isPresented: Binding(
            get: { viewModel.showErrorAlert },
            set: { isPresented in
                if !isPresented { viewModel.dismissError() }
            }
        )) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }
    }

    // MARK: - Conversation

    private var conversationList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if viewModel.messages.isEmpty {
                        emptyState
                    }

                    ForEach(viewModel.messages) { message in
                        ChatBubbleView(message: message)
                            .id(message.id)
                    }

                    if viewModel.isTyping {
                        HStack {
                            TypingIndicatorView()
                            Spacer()
                        }
                        .id("typing-indicator")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isTyping) { _, isTyping in
                if isTyping {
                    scrollToBottom(proxy: proxy, anchor: "typing-indicator")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.95), Color.purple.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Search photos with your voice")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Try: \"find me Nike related pics\" or \"show photos with my backpack\"")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Input

    private var inputBar: some View {
        VStack(spacing: 12) {
            if viewModel.isRecording || !viewModel.liveTranscript.isEmpty {
                liveTranscriptBar
            }

            HStack(spacing: 14) {
                TextField("Or type a search…", text: $typedQuery)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .disabled(viewModel.isProcessing || viewModel.isRecording)
                    .onSubmit(submitTypedQuery)

                VoiceRecordButton(
                    isRecording: viewModel.isRecording,
                    isDisabled: viewModel.isProcessing
                ) {
                    viewModel.toggleRecording()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .padding(.top, 8)
            .background(.ultraThinMaterial)
        }
    }

    private var liveTranscriptBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(viewModel.isRecording ? 1 : 0.35)

            Text(viewModel.liveTranscript.isEmpty ? "Listening…" : viewModel.liveTranscript)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeOut(duration: 0.15), value: viewModel.liveTranscript)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private func submitTypedQuery() {
        let trimmed = typedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        typedQuery = ""
        viewModel.submitTypedQuery(trimmed)
    }

    private func scrollToBottom(proxy: ScrollViewProxy, anchor: String? = nil) {
        withAnimation(.easeOut(duration: 0.25)) {
            if let anchor {
                proxy.scrollTo(anchor, anchor: .bottom)
            } else if let last = viewModel.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

private struct VoiceImageSearchBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.09, blue: 0.14),
                Color(red: 0.04, green: 0.05, blue: 0.1),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
