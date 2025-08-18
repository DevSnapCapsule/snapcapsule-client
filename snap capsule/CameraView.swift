import SwiftUI
import AVFoundation
import CoreLocation

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
    private var isConfiguring = false
    
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    
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
    @Published var isShowingRandomImage = false
    
    override init() {
        super.init()
        if !isSimulator {
            checkPermissions()
        } else {
            // In simulator, grant permission by default and setup mock data
            permissionGranted = true
            isSessionReady = true
            // Set a mock location for simulator testing
            currentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // Example: San Francisco
        }
        setupLocation()
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
        do {
            session.beginConfiguration()
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                      for: .video,
                                                      position: .back) else {
                print("Failed to get camera device")
                return
            }
            
            let input = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
            isSessionReady = true
        } catch {
            print("Camera setup error: \(error.localizedDescription)")
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
    
    func setupLocation() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
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
                        
                        // Add timestamp and location
                        let timestamp = Date().formatted(date: .complete, time: .complete)
                        let location = "📍 \(self.currentLocation?.coordinate.latitude ?? 0), \(self.currentLocation?.coordinate.longitude ?? 0)"
                        let text = "Test Photo\n\(timestamp)\n\(location)"
                        
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
        
        // Save to photo library
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        // Create metadata with current timestamp and location
        let timestamp = Date()
        let location = currentLocation ?? CLLocation(latitude: 0, longitude: 0)
        
        // Process image metadata and AI analysis
        ImageAnalyzer.shared.analyzeImage(image, location: location) { [weak self] metadata in
            guard let self = self else { return }
            
            // Save metadata to CoreData
            DispatchQueue.main.async {
                MetadataManager.shared.saveImageMetadata(metadata)
                print("✅ Saved image metadata: \(metadata.imageId)")
                print("📍 Location: \(metadata.location?.coordinate.latitude ?? 0), \(metadata.location?.coordinate.longitude ?? 0)")
                print("🏷️ Labels: \(metadata.labels)")
                print("🎨 Colors: \(metadata.colors)")
                print("📦 Objects: \(metadata.objects)")
                print("🖼️ Scenes: \(metadata.scenes)")
            }
        }
    }
    
    func selectRandomImage() {
        let fileManager = FileManager.default
        let imagesPath = "/Users/administrator/Documents/snap capsule/images"
        
        do {
            let imageFiles = try fileManager.contentsOfDirectory(atPath: imagesPath)
                .filter { $0.lowercased().hasSuffix(".jpg") || $0.lowercased().hasSuffix(".jpeg") }
            
            guard let randomImage = imageFiles.randomElement() else {
                print("No images found in the directory")
                return
            }
            
            print("Selected image: \(randomImage)")
            
            let imagePath = (imagesPath as NSString).appendingPathComponent(randomImage)
            guard let image = UIImage(contentsOfFile: imagePath) else {
                print("Failed to load image")
                return
            }
            
            // Extract metadata using ImageIO
            guard let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: imagePath) as CFURL, nil) else {
                print("Failed to create image source")
                return
            }
            
            let options = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, options) as? [String: Any] else {
                print("Failed to extract metadata")
                return
            }
            
            var metadata: [String: Any] = [:]
            
            // Extract EXIF data
            if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                metadata["{Exif}"] = exif
            }
            
            // Extract GPS data
            if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
                metadata["{GPS}"] = gps
            }
            
            // Extract TIFF data
            if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                metadata["{TIFF}"] = tiff
            }
            
            // Add basic image properties
            if let width = properties[kCGImagePropertyPixelWidth as String] as? Int {
                metadata["PixelWidth"] = width
            }
            if let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
                metadata["PixelHeight"] = height
            }
            if let orientation = properties[kCGImagePropertyOrientation as String] as? Int {
                metadata["Orientation"] = orientation
            }
            if let colorModel = properties[kCGImagePropertyColorModel as String] as? String {
                metadata["ColorModel"] = colorModel
            }
            if let profileName = properties[kCGImagePropertyProfileName as String] as? String {
                metadata["ColorProfile"] = profileName
            }
            
            DispatchQueue.main.async {
                self.capturedImage = image
                self.imageMetadata = metadata
                self.isTaken = true
                self.isShowingRandomImage = true
                self.stopSession()
            }
            
        } catch {
            print("Error accessing images directory: \(error)")
            print("Attempted path: \(imagesPath)")
        }
    }
}

extension CameraViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
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
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if camera.permissionGranted {
                if camera.isShowingRandomImage {
                    // Show selected image with metadata
                    if let image = camera.capturedImage {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .padding(.bottom)
                                
                                ImageMetadataContent(image: image, metadata: camera.imageMetadata)
                                    .padding(.horizontal)
                                    .padding(.vertical)
                                    .background(Color(red: 0.95, green: 0.93, blue: 0.90)) // Biscuit color
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                            }
                        }
                        .background(Color.black)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            VStack {
                                HStack {
                                    Button(action: {
                                        camera.isShowingRandomImage = false
                                        camera.isTaken = false
                                        camera.startSession()
                                    }) {
                                        Image(systemName: "arrow.left")
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color.black.opacity(0.75))
                                            .clipShape(Circle())
                                    }
                                    .padding(.top, 50)
                                    .padding(.leading)
                                    
                                    Spacer()
                                    
                                    Button(action: camera.selectRandomImage) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color.black.opacity(0.75))
                                            .clipShape(Circle())
                                    }
                                    .padding(.top, 50)
                                    
                                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                                        Image(systemName: "xmark")
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color.black.opacity(0.75))
                                            .clipShape(Circle())
                                    }
                                    .padding(.top, 50)
                                    .padding(.trailing)
                                }
                                Spacer()
                            }
                        )
                    }
                } else {
                    // Show camera preview
                    CameraPreview(camera: camera)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        HStack {
                            Button(action: camera.selectRandomImage) {
                                Image(systemName: "photo.stack")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.75))
                                    .clipShape(Circle())
                            }
                            .padding(.top, 50)
                            .padding(.leading)
                            
                            Spacer()
                            
                            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.75))
                                    .clipShape(Circle())
                            }
                            .padding(.top, 50)
                            .padding(.trailing)
                        }
                        
                        Spacer()
                        
                        HStack {
                            if camera.isTaken {
                                Button(action: camera.retake) {
                                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.black.opacity(0.75))
                                        .clipShape(Circle())
                                }
                                .padding(.horizontal)
                                
                                Button(action: {
                                    camera.savePicture()
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.black.opacity(0.75))
                                        .clipShape(Circle())
                                }
                                .padding(.horizontal)
                            } else {
                                Button(action: camera.takePicture) {
                                    Image(systemName: "camera")
                                        .foregroundColor(.white)
                                        .padding(30)
                                        .background(Color.black.opacity(0.75))
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(.bottom, 30)
                    }
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
