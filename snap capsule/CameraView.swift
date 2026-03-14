import SwiftUI
import AVFoundation

class CameraViewModel: NSObject, ObservableObject {
    #if targetEnvironment(simulator)
        private let isSimulator = true
    #else
        private let isSimulator = false
    #endif
    
    @Published var session = AVCaptureSession()
    @Published var preview: AVCaptureVideoPreviewLayer!
    @Published var isTaken = false
    @Published var alert = false
    @Published var output = AVCapturePhotoOutput()
    @Published var capturedImage: UIImage?
    @Published var permissionGranted = false
    @Published var isSessionReady = false
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    private var isConfiguring = false
    private var currentInput: AVCaptureDeviceInput?
    
    // Placeholder images for simulator
    private let placeholderImages = [
        UIImage(named: "sample_photo_1"),
        UIImage(named: "sample_photo_2"),
        UIImage(named: "sample_photo_3")
    ].compactMap { $0 } // Remove any nil images
    
    private var defaultPlaceholderImage: UIImage {
        UIImage(systemName: "photo.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal) ??
        UIImage()
    }
    
    @Published var imageMetadata: [String: Any] = [:]
    
    override init() {
        super.init()
        if !isSimulator {
            checkPermissions()
        } else {
            // In simulator, grant permission by default and setup mock data
            permissionGranted = true
            isSessionReady = true
        }
    }
    
    func checkPermissions() {
        if isSimulator {
            permissionGranted = true
            isSessionReady = true
            return
        }
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] status in
                DispatchQueue.main.async {
                    self?.permissionGranted = status
                    if status {
                        self?.setupCamera()
                    } else {
                        self?.alert = true
                    }
                }
            }
        case .denied, .restricted:
            permissionGranted = false
            alert = true
        @unknown default:
            permissionGranted = false
            alert = true
        }
    }
    
    func setupCamera() {
        // Ensure session is stopped before configuration
        if session.isRunning {
            session.stopRunning()
        }
        
        // Small delay to ensure previous camera is fully released
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.performCameraSetup()
        }
    }
    
    private func performCameraSetup() {
        do {
            session.beginConfiguration()
            isConfiguring = true
            
            // Remove existing input if any
            if let existingInput = currentInput {
                session.removeInput(existingInput)
                currentInput = nil
            }
            
            // Try to get the camera device with retry and discovery logic
            var device: AVCaptureDevice?
            let cameraName = cameraPosition == .back ? "BACK" : "FRONT"
            
            // First attempt: simple default wide-angle camera
            device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                            for: .video,
                                            position: cameraPosition)
            
            // If first attempt fails, wait a bit and try again
            if device == nil {
                Thread.sleep(forTimeInterval: 0.05)
                device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                for: .video,
                                                position: cameraPosition)
            }
            
            // If still nil, use a discovery session to find any suitable camera
            if device == nil {
                let discoverySession = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [
                        .builtInWideAngleCamera,
                        .builtInDualCamera,
                        .builtInTripleCamera,
                        .builtInDualWideCamera,
                        .builtInTrueDepthCamera
                    ],
                    mediaType: .video,
                    position: cameraPosition
                )
                device = discoverySession.devices.first
            }
            
            guard let captureDevice = device else {
                print("⚠️ Failed to get \(cameraName) camera device after discovery - check hardware configuration")
                session.commitConfiguration()
                isConfiguring = false
                return
            }
            
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            if session.canAddInput(input) {
                session.addInput(input)
                currentInput = input
            }
            
            if !session.outputs.contains(output) {
                if session.canAddOutput(output) {
                    session.addOutput(output)
                }
            }
            
            session.commitConfiguration()
            isConfiguring = false
            isSessionReady = true
            
            // Ensure the capture session actually starts once configuration succeeds.
            // This prevents an initial black preview screen where the session was
            // configured but never started until the user toggled the camera.
            startSession()
            print("✅ \(cameraName) camera setup successful")
        } catch {
            print("❌ Camera setup error: \(error.localizedDescription)")
            session.commitConfiguration()
            isConfiguring = false
        }
    }
    
    func switchCamera() {
        guard !isConfiguring && !isTaken else { return }
        
        // Stop session synchronously before switching
        if session.isRunning {
            session.stopRunning()
        }
        
        // Toggle camera position
        cameraPosition = cameraPosition == .back ? .front : .back
        
        // Log which camera is now active
        let cameraName = cameraPosition == .back ? "BACK" : "FRONT"
        print("📸 Switching to \(cameraName) camera...")
        
        // Reconfigure camera with new position
        setupCamera()
        
        // Restart session after a longer delay to ensure configuration is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.startSession()
        }
    }
    
    func startSession() {
        guard !session.isRunning && isSessionReady && !isConfiguring else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stopSession() {
        guard session.isRunning && !isConfiguring else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    func takePicture() {
        if isSimulator {
            // In simulator, use either a placeholder image from assets or generate one
            DispatchQueue.main.async {
                if !self.placeholderImages.isEmpty {
                    self.capturedImage = self.placeholderImages.randomElement()
                } else {
                    // Create a test image with timestamp
                    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600))
                    let testImage = renderer.image { context in
                        // Fill background
                        UIColor.black.setFill()
                        context.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
                        
                        // Add timestamp (no location)
                        let timestamp = Date().formatted(date: .complete, time: .complete)
                        let text = "Test Photo\n\(timestamp)"
                        
                        let attributes: [NSAttributedString.Key: Any] = [
                            .foregroundColor: UIColor.white,
                            .font: UIFont.systemFont(ofSize: 24)
                        ]
                        
                        text.draw(with: CGRect(x: 50, y: 250, width: 700, height: 200),
                                options: .usesLineFragmentOrigin,
                                attributes: attributes,
                                context: nil)
                    }
                    self.capturedImage = testImage
                }
                withAnimation { self.isTaken = true }
            }
            return
        }
        
        guard session.isRunning && !isConfiguring else { return }
        
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        DispatchQueue.main.async {
            withAnimation { self.isTaken = true }
        }
    }
    
    func retake() {
        if isSimulator {
            DispatchQueue.main.async {
                withAnimation {
                    self.isTaken = false
                    self.capturedImage = nil
                }
            }
            return
        }
        
        guard isSessionReady && !isConfiguring else { return }
        
        DispatchQueue.main.async {
            withAnimation {
                self.isTaken = false
                self.capturedImage = nil
            }
        }
        
        startSession()
    }
    
    func savePicture() {
        guard let image = capturedImage else { return }
        
        if !isSimulator {
            stopSession()
        }
        
        // Get current user and albums
        guard let user = UserManager.shared.getCurrentUser() else {
            print("❌ No user logged in")
            return
        }
        
        let albums = AlbumManager.shared.getAlbums(for: user)
        guard !albums.isEmpty else {
            print("❌ No albums available")
            return
        }
        
        // Determine which album to use:
        // 1. Fill Capsule 1 until it reaches its limit.
        // 2. Then start filling Capsule 2.
        let album1 = albums.first { $0.name == "Capsule 1" }
        let album2 = albums.first { $0.name == "Capsule 2" }
        
        var targetAlbum: AlbumEntity?
        
        if let album1 = album1, AlbumManager.shared.canAddImage(to: album1) {
            targetAlbum = album1
        } else if let album2 = album2, AlbumManager.shared.canAddImage(to: album2) {
            targetAlbum = album2
        } else {
            print("⚠️ All capsules have reached their maximum image limit.")
            return
        }
        
        guard let album = targetAlbum else {
            print("❌ Could not determine target album")
            return
        }
        
        // Save image to album (no location)
        AlbumManager.shared.addImage(to: album, image: image) { success, error in
            if success {
                print("✅ Image saved to album: \(album.name ?? "Unknown")")
            } else {
                print("❌ Failed to save image: \(error ?? "Unknown error")")
            }
        }
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil { return }
        
        guard let imageData = photo.fileDataRepresentation() else { return }
        
        DispatchQueue.main.async {
            self.capturedImage = UIImage(data: imageData)
            self.session.stopRunning()
        }
    }
}

struct CameraView: View {
    @StateObject var camera = CameraViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    /// Optional callback invoked after a photo is successfully saved,
    /// allowing the presenting view to update its state (e.g. switch tabs).
    var onCaptureCompleted: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if camera.permissionGranted {
                // Show camera preview
                CameraPreview(camera: camera)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    HStack {
                        // Camera switch button (only show when not taken)
                        if !camera.isTaken {
                            Button(action: camera.switchCamera) {
                                Image(systemName: "camera.rotate")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18))
                                    .padding(14)
                                    .background(
                                        ZStack {
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                            
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color.white.opacity(0.3),
                                                            Color.white.opacity(0.1)
                                                        ]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        }
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color.white.opacity(0.5),
                                                        Color.white.opacity(0.2)
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                    .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
                            }
                            .padding(.top, 50)
                            .padding(.leading)
                        } else {
                            Spacer()
                        }
                        
                        Spacer()
                        
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .font(.system(size: 18))
                                .padding(14)
                                .background(
                                    ZStack {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                        
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color.white.opacity(0.3),
                                                        Color.white.opacity(0.1)
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                )
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.white.opacity(0.5),
                                                    Color.white.opacity(0.2)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
                        }
                        .padding(.top, 50)
                        .padding(.trailing)
                    }
                    
                    Spacer()
                    
                    HStack {
                        if camera.isTaken {
                                Button(action: camera.retake) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .foregroundColor(.white)
                                        .font(.system(size: 24))
                                        .padding(16)
                                        .background(
                                            ZStack {
                                                Circle()
                                                    .fill(.ultraThinMaterial)
                                                
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            gradient: Gradient(colors: [
                                                                Color.white.opacity(0.3),
                                                                Color.white.opacity(0.1)
                                                            ]),
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                            }
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color.white.opacity(0.5),
                                                            Color.white.opacity(0.2)
                                                        ]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                        .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
                                }
                                .padding(.horizontal)
                                
                                Button(action: {
                                    camera.savePicture()
                                    onCaptureCompleted?()
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                        .font(.system(size: 24))
                                        .padding(16)
                                        .background(
                                            ZStack {
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            gradient: Gradient(colors: [
                                                                Color.green,
                                                                Color.green.opacity(0.8)
                                                            ]),
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            gradient: Gradient(colors: [
                                                                Color.white.opacity(0.3),
                                                                Color.white.opacity(0.0)
                                                            ]),
                                                            startPoint: .top,
                                                            endPoint: .bottom
                                                        )
                                                    )
                                            }
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color.white.opacity(0.5),
                                                            Color.white.opacity(0.2)
                                                        ]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                        .shadow(color: Color.green.opacity(0.4), radius: 12, y: 6)
                                }
                                .padding(.horizontal)
                            } else {
                                Button(action: camera.takePicture) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color.white,
                                                        Color.white.opacity(0.9)
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 70, height: 70)
                                        
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color.white.opacity(0.8),
                                                        Color.white.opacity(0.4)
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 4
                                            )
                                            .frame(width: 76, height: 76)
                                        
                                        Image(systemName: "camera.fill")
                                            .foregroundColor(.black)
                                            .font(.system(size: 28))
                                    }
                                    .shadow(color: Color.black.opacity(0.4), radius: 20, y: 10)
                                }
                        }
                    }
                    .padding(.bottom, 40)
                }
            } else {
                VStack {
                    Text("Camera Access Required")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                    Text("Please enable camera access in Settings to use this feature.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding()
                    Button("Open Settings") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    .padding()
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .alert(isPresented: $camera.alert) {
            Alert(
                title: Text("Camera Access Required"),
                message: Text("Please enable camera access in Settings to use this feature."),
                primaryButton: .default(Text("Open Settings")) {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                },
                secondaryButton: .cancel(Text("Cancel")) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraViewModel
    
    #if targetEnvironment(simulator)
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        // Add a label to indicate simulator mode
        let label = UILabel()
        label.text = "📸 Camera Preview (Simulator)"
        label.textColor = .white
        label.textAlignment = .center
        label.frame = CGRect(x: 0, y: view.bounds.height/2 - 50, width: view.bounds.width, height: 100)
        view.addSubview(label)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    #else
    class Coordinator {
        let parent: CameraPreview
        var previewLayer: AVCaptureVideoPreviewLayer?
        
        init(_ parent: CameraPreview) {
            self.parent = parent
        }
        
        func setupPreviewLayer(for view: UIView) {
            if previewLayer == nil {
                let layer = AVCaptureVideoPreviewLayer(session: parent.camera.session)
                layer.frame = view.frame
                layer.videoGravity = .resizeAspectFill
                view.layer.addSublayer(layer)
                previewLayer = layer
            }
            previewLayer?.frame = view.frame
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        context.coordinator.setupPreviewLayer(for: view)
        
        if camera.isSessionReady {
            camera.startSession()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.frame
    }
    #endif
}
