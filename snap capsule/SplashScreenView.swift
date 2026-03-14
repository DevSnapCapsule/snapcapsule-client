import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var opacity = 0.0
    
    var body: some View {
        ZStack {
            // White background
            Color.white
                .ignoresSafeArea()
            
            // Logo centered with text below
            VStack(spacing: 32) {
                Image("SnapCapsuleLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 280, maxHeight: 280)
                    .opacity(opacity)
                
                VStack(spacing: 12) {
                    // Big text - AI-Powered Photo Management with gradient
                    Text("AI-Powered Photo Management")
                        .font(.system(size: 28, weight: .semibold, design: .default))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.2, green: 0.4, blue: 0.8),   // Metallic blue
                                    Color(red: 0.4, green: 0.6, blue: 1.0),   // Bright blue
                                    Color(red: 0.6, green: 0.4, blue: 0.9),   // Purple-blue
                                    Color(red: 0.8, green: 0.4, blue: 0.7)    // Pink-purple
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)
                        .opacity(opacity)
                    
                    // Small text - Description with dark gray
                    Text("Transform how you organize, share and experience your digital memories")
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 40)
                        .opacity(opacity)
                }
            }
        }
        .onAppear {
            // Auto-login a default local user so that Capsule 1 / Capsule 2
            // and the Capsule Repository work without authentication.
            autoLoginDefaultUser()
            
            // Reset state to ensure splash always shows
            isActive = false
            opacity = 0.0
            
            // Fade in animation
            withAnimation(.easeIn(duration: 0.8)) {
                opacity = 1.0
            }
            
            // Wait briefly then transition to the main app
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    opacity = 0.0
                }
                
                // Small delay before transitioning
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isActive = true
                }
            }
        }
        .fullScreenCover(isPresented: $isActive) {
            // Go straight into the main app UI (ContentView),
            // which in turn shows the Capsule Repository tab.
            ContentView()
        }
    }
    
    private func autoLoginDefaultUser() {
        let defaultEmail = "demo@snapcapsule.local"
        
        UserManager.shared.loginUser(email: defaultEmail) { success, error in
            if !success {
                print("⚠️ [SplashScreen] Failed to auto-login default user: \(error ?? "unknown error")")
            } else {
                print("✅ [SplashScreen] Auto-logged in default user: \(defaultEmail)")
            }
        }
    }
}

