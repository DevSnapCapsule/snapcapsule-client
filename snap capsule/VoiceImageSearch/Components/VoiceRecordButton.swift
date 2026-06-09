import SwiftUI

struct VoiceRecordButton: View {
    let isRecording: Bool
    let isDisabled: Bool
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.35), lineWidth: 3)
                        .frame(width: 78, height: 78)
                        .scaleEffect(pulse ? 1.12 : 0.92)
                        .opacity(pulse ? 0.2 : 0.55)
                        .animation(
                            .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                            value: pulse
                        )
                }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: isRecording
                                ? [Color.red.opacity(0.95), Color.orange.opacity(0.85)]
                                : [Color.blue.opacity(0.95), Color.purple.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: (isRecording ? Color.red : Color.blue).opacity(0.35), radius: 12, y: 4)

                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
        .accessibilityLabel(isRecording ? "Stop recording" : "Start voice search")
        .onChange(of: isRecording) { _, recording in
            pulse = recording
        }
        .onAppear {
            pulse = isRecording
        }
    }
}
