import SwiftUI
import AVFoundation

class CameraViewModel: NSObject, ObservableObject {
    #if targetEnvironment(simulator)
        private let isSimulator = true
    #else
        private let isSimulator = false
        private let deviceControlQueue = DispatchQueue(label: "camera.device.control", qos: .userInteractive)
    #endif
    
    @Published var session = AVCaptureSession()
    @Published var isTaken = false
    @Published var alert = false
    @Published var output = AVCapturePhotoOutput()
    @Published var capturedImage: UIImage?
    @Published var permissionGranted = false
    @Published var isSessionReady = false
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    @Published private(set) var flashMode: AVCaptureDevice.FlashMode = .auto
    @Published private(set) var videoZoomFactor: CGFloat = 1
    @Published private(set) var isTorchActive = false
    @Published private(set) var hasRearFlashCapability = false
    @Published private(set) var hasRearTorchCapability = false
    private var isConfiguring = false
    private var currentInput: AVCaptureDeviceInput?
    
    /// Active video device — used for pinch zoom, focus, flash, and torch.
    private(set) var captureDevice: AVCaptureDevice?
    
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
            
            DispatchQueue.main.async {
                self.captureDevice = captureDevice
                self.videoZoomFactor = captureDevice.videoZoomFactor
                self.isTorchActive = false
                let rear = captureDevice.position == .back
                self.hasRearFlashCapability = rear && captureDevice.hasFlash
                self.hasRearTorchCapability = rear && captureDevice.hasTorch
                if !rear || !captureDevice.hasFlash {
                    self.flashMode = .off
                } else if !captureDevice.isFlashModeSupported(self.flashMode) {
                    let order: [AVCaptureDevice.FlashMode] = [.auto, .on, .off]
                    self.flashMode = order.first(where: { captureDevice.isFlashModeSupported($0) }) ?? .off
                }
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
    
    #if !targetEnvironment(simulator)
    func currentDeviceZoomFactor() -> CGFloat {
        captureDevice?.videoZoomFactor ?? 1
    }
    
    func setVideoZoomFromPinch(desiredZoom: CGFloat) {
        guard let device = captureDevice else { return }
        let minZ = device.minAvailableVideoZoomFactor
        let maxZ = max(minZ, device.maxAvailableVideoZoomFactor)
        let practicalMax = min(maxZ, CGFloat(14))
        let clamped = min(max(desiredZoom, minZ), practicalMax)
        deviceControlQueue.async {
            guard device.isConnected else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.videoZoomFactor = clamped
            } catch { }
            DispatchQueue.main.async { self.videoZoomFactor = clamped }
        }
    }
    
    func focusAtCapturedPoint(ofInterest normalized: CGPoint, hostView: UIView, reticleCenterInHost: CGPoint) {
        guard let device = captureDevice else { return }
        deviceControlQueue.async {
            guard device.isConnected else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                let sx = min(max(normalized.x, 0), 1)
                let sy = min(max(normalized.y, 0), 1)
                let safe = CGPoint(x: sx, y: sy)
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = safe
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = safe
                    device.exposureMode = .continuousAutoExposure
                }
            } catch { }
        }
        
        DispatchQueue.main.async {
            CameraPreviewFocusReticle.present(at: reticleCenterInHost, in: hostView)
        }
    }
    
    func cycleFlashMode() {
        guard let device = captureDevice, device.position == .back, device.hasFlash else { return }
        let modes: [AVCaptureDevice.FlashMode] = [.off, .auto, .on].filter {
            device.isFlashModeSupported($0)
        }
        guard !modes.isEmpty else { return }
        let next: AVCaptureDevice.FlashMode
        if let idx = modes.firstIndex(of: flashMode) {
            next = modes[(idx + 1) % modes.count]
        } else {
            next = modes[0]
        }
        DispatchQueue.main.async { self.flashMode = next }
    }
    
    func toggleTorch() {
        guard let device = captureDevice, cameraPosition == .back, device.hasTorch else {
            DispatchQueue.main.async { self.isTorchActive = false }
            return
        }
        let turnOn = !isTorchActive
        deviceControlQueue.async {
            guard device.isConnected else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if turnOn && device.isTorchAvailable && device.isTorchModeSupported(.on) {
                    let level = AVCaptureDevice.maxAvailableTorchLevel
                    try device.setTorchModeOn(level: min(1.0, level))
                } else {
                    device.torchMode = .off
                }
                let nowOn = device.torchMode == .on
                DispatchQueue.main.async { self.isTorchActive = nowOn }
            } catch {
                DispatchQueue.main.async { self.isTorchActive = false }
            }
        }
    }
    #else
    func setVideoZoomFromPinch(desiredZoom: CGFloat) {}
    func currentDeviceZoomFactor() -> CGFloat { 1 }
    func cycleFlashMode() {}
    func toggleTorch() {}
    func focusAtCapturedPoint(ofInterest _: CGPoint, hostView _: UIView, reticleCenterInHost _: CGPoint) {}
    #endif
    
    func switchCamera() {
        guard !isConfiguring && !isTaken else { return }
        
        // Stop session synchronously before switching
        if session.isRunning {
            session.stopRunning()
        }
        
        DispatchQueue.main.async {
            self.isTorchActive = false
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
        
        let settings = AVCapturePhotoSettings()
        #if !targetEnvironment(simulator)
        if let d = captureDevice, d.position == .back, d.hasFlash {
            let mode = flashMode
            if d.isFlashModeSupported(mode) {
                settings.flashMode = mode
            }
        }
        #endif
        
        output.capturePhoto(with: settings, delegate: self)
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
        
        AlbumManager.shared.addImageToAvailableCapsule(image: image, importSource: .camera) { success, error in
            if success {
                print("✅ Image saved to capsule")
            } else {
                print("❌ Failed to save image: \(error ?? "Unknown error")")
            }
        }
    }
}

private func flashModeSystemImage(for mode: AVCaptureDevice.FlashMode) -> String {
    switch mode {
    case .off: return "bolt.slash.fill"
    case .auto: return "bolt.badge.automatic.fill"
    case .on: return "bolt.fill"
    @unknown default: return "bolt.slash.fill"
    }
}

private func flashAccessibilityLabel(for mode: AVCaptureDevice.FlashMode) -> String {
    switch mode {
    case .off: return "Photo flash off, tap to change"
    case .auto: return "Photo flash automatic, tap to change"
    case .on: return "Photo flash on, tap to change"
    @unknown default: return "Photo flash, tap to change"
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil { return }
        
        guard let imageData = photo.fileDataRepresentation(),
              let raw = UIImage(data: imageData) else { return }
        
        DispatchQueue.main.async {
            self.capturedImage = raw.normalizedForImageProcessing()
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
                            
                            #if !targetEnvironment(simulator)
                            if !camera.isTaken && camera.cameraPosition == .back {
                                if camera.hasRearFlashCapability {
                                    Button(action: { camera.cycleFlashMode() }) {
                                        Image(systemName: flashModeSystemImage(for: camera.flashMode))
                                            .foregroundColor(.white)
                                            .font(.system(size: 18))
                                            .padding(14)
                                            .background(
                                                Circle()
                                                    .fill(.ultraThinMaterial)
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                            )
                                            .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(flashAccessibilityLabel(for: camera.flashMode))
                                    .padding(.top, 50)
                                } else if camera.hasRearTorchCapability {
                                    Button(action: { camera.toggleTorch() }) {
                                        Image(systemName: camera.isTorchActive ? "flashlight.on.fill" : "flashlight.off.fill")
                                            .foregroundStyle(camera.isTorchActive ? Color.yellow : Color.white)
                                            .font(.system(size: 18))
                                            .padding(14)
                                            .background(
                                                Circle()
                                                    .fill(.ultraThinMaterial)
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                            )
                                            .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(camera.isTorchActive ? "Turn flashlight off" : "Turn flashlight on")
                                    .padding(.top, 50)
                                }
                            }
                            #endif
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
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let parent: CameraPreview
        var previewLayer: AVCaptureVideoPreviewLayer?
        private var pinchBaseZoom: CGFloat = 1
        
        init(parent: CameraPreview) {
            self.parent = parent
        }
        
        func bind(to view: UIView) {
            if previewLayer == nil {
                let layer = AVCaptureVideoPreviewLayer(session: parent.camera.session)
                layer.videoGravity = .resizeAspectFill
                view.layer.insertSublayer(layer, at: 0)
                previewLayer = layer
                
                view.isMultipleTouchEnabled = true
                let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
                pinch.delegate = self
                view.addGestureRecognizer(pinch)
                let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
                view.addGestureRecognizer(tap)
            }
            previewLayer?.frame = view.bounds
        }
        
        @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
            guard g.view != nil else { return }
            switch g.state {
            case .began:
                pinchBaseZoom = parent.camera.currentDeviceZoomFactor()
            case .changed, .ended, .cancelled:
                parent.camera.setVideoZoomFromPinch(desiredZoom: pinchBaseZoom * g.scale)
            default:
                break
            }
        }
        
        @objc private func handleTap(_ g: UITapGestureRecognizer) {
            guard g.state == .ended, let view = g.view, let layer = previewLayer else { return }
            let p = g.location(in: view)
            let devicePoint = layer.captureDevicePointConverted(fromLayerPoint: p)
            parent.camera.focusAtCapturedPoint(ofInterest: devicePoint, hostView: view, reticleCenterInHost: p)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        context.coordinator.bind(to: view)
        if camera.isSessionReady {
            camera.startSession()
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.bind(to: uiView)
    }
    #endif
}

#if !targetEnvironment(simulator)
private enum CameraPreviewFocusReticle {
    private static let viewTag = 9_876_541
    
    static func present(at center: CGPoint, in container: UIView) {
        container.subviews.filter { $0.tag == viewTag }.forEach { $0.removeFromSuperview() }
        let side: CGFloat = 72
        let box = UIView(
            frame: CGRect(
                x: center.x - side / 2,
                y: center.y - side / 2,
                width: side,
                height: side
            )
        )
        box.tag = viewTag
        box.layer.borderColor = UIColor.systemYellow.cgColor
        box.layer.borderWidth = 1.5
        box.backgroundColor = .clear
        box.alpha = 1
        box.transform = .identity
        container.addSubview(box)
        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.curveEaseOut]
        ) {
            box.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        } completion: { _ in
            UIView.animate(withDuration: 0.45, delay: 0.2, options: [.curveEaseIn]) {
                box.alpha = 0
            } completion: { _ in
                box.removeFromSuperview()
            }
        }
    }
}
#endif
