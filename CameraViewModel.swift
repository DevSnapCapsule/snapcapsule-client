class CameraViewModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isTaken = false
    @Published var alert = false
    @Published var output = AVCapturePhotoOutput()
    @Published var capturedImage: UIImage?
    @Published var permissionGranted = false
    @Published var isSessionReady = false
    private var isConfiguring = false
    
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    
    @Published var imageMetadata: [String: Any] = [:]
    @Published var isShowingRandomImage = false
    
    override init() {
        super.init()
        checkPermissions()
        setupLocation()
    }
    
    func checkPermissions() {
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
        guard !isConfiguring else { return }
        isConfiguring = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Stop session if running
                if self.session.isRunning {
                    self.session.stopRunning()
                }
                
                self.session.beginConfiguration()
                
                // Remove any existing inputs and outputs
                for input in self.session.inputs {
                    self.session.removeInput(input)
                }
                for output in self.session.outputs {
                    self.session.removeOutput(output)
                }
                
                // Add new input
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                          for: .video,
                                                          position: .back) else {
                    print("Failed to get camera device")
                    self.session.commitConfiguration()
                    self.isConfiguring = false
                    return
                }
                
                let input = try AVCaptureDeviceInput(device: device)
                
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                
                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }
                
                self.session.commitConfiguration()
                self.isConfiguring = false
                
                DispatchQueue.main.async {
                    self.isSessionReady = true
                    self.startSession()
                }
            } catch {
                print("Camera setup error: \(error.localizedDescription)")
                self.session.commitConfiguration()
                self.isConfiguring = false
                DispatchQueue.main.async {
                    self.alert = true
                }
            }
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
        guard session.isRunning && !isConfiguring else { return }
        
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        DispatchQueue.main.async {
            withAnimation { self.isTaken = true }
        }
    }
    
    func retake() {
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
        
        stopSession()
        
        // Save to photo library
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        // Process image metadata and AI analysis
        ImageAnalyzer.shared.analyzeImage(image, location: currentLocation) { metadata in
            // Save metadata to CoreData
            MetadataManager.shared.saveImageMetadata(metadata)
        }
    }
    
    func selectRandomImage() {
        let fileManager = FileManager.default
        let imagesPath = (Bundle.main.bundlePath as NSString).appendingPathComponent("images")
        
        do {
            let imageFiles = try fileManager.contentsOfDirectory(atPath: imagesPath)
                .filter { $0.lowercased().hasSuffix(".jpg") || $0.lowercased().hasSuffix(".jpeg") }
            
            guard let randomImage = imageFiles.randomElement() else {
                print("No images found in the directory")
                return
            }
            
            let imagePath = (imagesPath as NSString).appendingPathComponent(randomImage)
            guard let image = UIImage(contentsOfFile: imagePath) else {
                print("Failed to load image")
                return
            }
            
            // Extract metadata using ImageIO
            guard let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: imagePath) as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
                print("Failed to extract metadata")
                return
            }
            
            DispatchQueue.main.async {
                self.capturedImage = image
                self.imageMetadata = properties
                self.isTaken = true
                self.isShowingRandomImage = true
                self.stopSession()
            }
            
        } catch {
            print("Error accessing images directory: \(error)")
        }
    }
    
    // ... rest of the existing code ...
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraViewModel
    
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
} 