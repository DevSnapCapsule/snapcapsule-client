//
//  ContentView.swift
//  snap capsule
//
//  Created by administrator on 25/05/2025.
//

import SwiftUI
import CoreLocation
import Photos

struct ContentView: View {
    @State private var isShowingCamera = false
    @State private var searchText = ""
    @State private var searchResults: [ImageSearchResult] = []
    @State private var selectedTab = 1
    
    var body: some View {
        NavigationView {
            ZStack {
                // Liquid glass background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color(red: 0.98, green: 0.99, blue: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Content area
                    ZStack {
                        switch selectedTab {
                        case 0:
                            // Home/Search view
                            VStack(spacing: 0) {
                                SearchBar(text: $searchText, onSearch: performSearch)
                                    .padding()
                                
                                ScrollView {
                                    if searchResults.isEmpty {
                                        EmptyStateView()
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    } else {
                                        SearchResultsList(results: searchResults)
                                    }
                                }
                            }
                        case 1:
                            // Capsule Repository
                            CapsuleRepositoryView()
                        case 2:
                            // Connect
                            ConnectView()
                        case 3:
                            // Settings
                            SettingsView()
                        default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Footer Menu with liquid glass
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            FooterMenuItem(icon: "camera.fill", title: "Snap Lens", isSelected: selectedTab == 0) {
                                isShowingCamera = true
                            }
                            
                            FooterMenuItem(icon: "photo.stack.fill", title: "Capsule Repository", isSelected: selectedTab == 1) {
                                selectedTab = 1
                            }
                            
                            FooterMenuItem(icon: "link.circle.fill", title: "Connect", isSelected: selectedTab == 2) {
                                selectedTab = 2
                            }
                            
                            FooterMenuItem(icon: "gearshape.fill", title: "Settings", isSelected: selectedTab == 3) {
                                selectedTab = 3
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .background(
                            ZStack {
                                // Glass morphism effect
                                RoundedRectangle(cornerRadius: 0)
                                    .fill(.ultraThinMaterial)
                                
                                // Subtle gradient overlay
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            }
                        )
                        .overlay(
                            // Top border with glass effect
                            VStack {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.6),
                                                Color.white.opacity(0.1)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 1)
                                    .blur(radius: 0.5)
                                Spacer()
                            }
                        )
                    }
                }
            }
            .navigationBarTitle(navigationTitle, displayMode: .inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraView()
        }
    }
    
    private var navigationTitle: String {
        switch selectedTab {
        case 0: return "SnapCapsule"
        case 1: return "Capsule Repository"
        case 2: return "Connect"
        case 3: return "Settings"
        default: return ""
        }
    }
    
    private func performSearch() {
        searchResults = MetadataManager.shared.searchImages(query: searchText)
    }
}

struct SearchBar: View {
    @Binding var text: String
    let onSearch: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 18))
            
            TextField("AI Search..", text: $text)
                .focused($isFocused)
                .autocapitalization(.none)
                .onSubmit(onSearch)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    isFocused = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(isFocused ? 0.4 : 0.2),
                                Color.white.opacity(isFocused ? 0.3 : 0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: isFocused ? 12 : 8, y: isFocused ? 6 : 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }
}

struct SearchResultsList: View {
    let results: [ImageSearchResult]
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(results, id: \.imageId) { result in
                VStack(alignment: .leading, spacing: 8) {
                    Text(result.matchedText)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(result.timestamp, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let address = getAddressFromLocation(result.location) {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.thinMaterial)
                        
                        RoundedRectangle(cornerRadius: 16)
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
                    RoundedRectangle(cornerRadius: 16)
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
                .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    private func getAddressFromLocation(_ location: CLLocation) -> String? {
        // In a real app, you would use CLGeocoder to get the address
        // For now, we'll just return the coordinates
        return "\(location.coordinate.latitude), \(location.coordinate.longitude)"
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.1),
                                Color.purple.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("No Photos Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Take some photos to get started!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(40)
    }
}

struct CapsuleRepositoryView: View {
    @State private var images: [ImageItem] = []
    @State private var indexedImages: [ImageItem] = []
    @State private var isLoading = true
    @State private var selectedTab = 0
    @State private var isIndexing = false
    @State private var selectedImageItem: ImageItem?
    @State private var showToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Header with liquid glass
            HStack(spacing: 0) {
                TabButton(
                    title: "Photo Collections",
                    isSelected: selectedTab == 0,
                    action: { selectedTab = 0 }
                )
                
                TabButton(
                    title: "Indexed Photos",
                    isSelected: selectedTab == 1,
                    action: { selectedTab = 1 }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(.ultraThinMaterial)
                    
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )
            .overlay(
                VStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.1)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                        .blur(radius: 0.5)
                    Spacer()
                }
            )
            
            // Content based on selected tab
            if selectedTab == 0 {
                PhotoCollectionsView(
                    images: images,
                    isLoading: isLoading,
                    isIndexing: $isIndexing,
                    selectedImageItem: $selectedImageItem,
                    onIndexImage: indexSelectedImage
                )
            } else {
                IndexedPhotosView(
                    indexedImages: indexedImages,
                    isLoading: isLoading
                )
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color(red: 0.98, green: 0.99, blue: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .overlay(
            // Loading Overlay
            Group {
                if isIndexing {
                    LoadingOverlay()
                }
            }
        )
        .overlay(
            // Toast Notification
            VStack {
                if showToast {
                    ToastView(message: toastMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1000)
                }
                Spacer()
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showToast)
        )
        .onAppear {
            loadImages()
        }
    }
    
    private func indexSelectedImage() {
        guard let selectedItem = selectedImageItem else { return }
        
        isIndexing = true
        
        // Perform actual image analysis with Google Vision API
        ImageAnalyzer.shared.analyzeImage(selectedItem.image, location: nil) { metadata in
            DispatchQueue.main.async {
                
                // Update the selected image to be indexed
                if let index = images.firstIndex(where: { $0.id == selectedItem.id }) {
                    let updatedItem = images[index]
                    var updatedMetadata = updatedItem.metadata
                    updatedMetadata["isIndexed"] = true
                    updatedMetadata["brands"] = metadata.brands
                    updatedMetadata["searchableText"] = metadata.searchableText
                    updatedMetadata["productInfo"] = metadata.productInfo.toDictionary()
                    
                    
                    let indexedItem = ImageItem(
                        id: updatedItem.id,
                        image: updatedItem.image,
                        metadata: updatedMetadata,
                        timestamp: updatedItem.timestamp
                    )
                    
                    // Update the image in the array
                    images[index] = indexedItem
                    
                    // Add to indexed images if not already there
                    if !indexedImages.contains(where: { $0.id == indexedItem.id }) {
                        indexedImages.append(indexedItem)
                    }
                    
                    // Save to Core Data
                    MetadataManager.shared.saveImageMetadata(metadata)
                }
                
                isIndexing = false
                selectedImageItem = nil
                
                // Show success toast
                toastMessage = "Selected image is indexed"
                showToast = true
                
                // Auto-hide toast after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        showToast = false
                    }
                }
            }
        }
    }
    
    private func loadImages() {
        isLoading = true
        
        // Get the workspace directory path
        let workspacePath = "/Users/administrator/Documents/snap capsule/images"
        
        let fileManager = FileManager.default
        
        do {
            // List all files in directory
            let files = try fileManager.contentsOfDirectory(atPath: workspacePath)
            
            // Filter for image files
            let imageFiles = files.filter { file in
                let fileExtension = (file as NSString).pathExtension.lowercased()
                return ["jpg", "jpeg", "png", "heic"].contains(fileExtension)
            }.filter { !$0.hasPrefix(".") }
            
            
            // Process each image file
            var newImages: [ImageItem] = []
            
            for file in imageFiles {
                let fullPath = (workspacePath as NSString).appendingPathComponent(file)
                if let image = UIImage(contentsOfFile: fullPath) {
                    
                    // Get file attributes for metadata
                    let attributes = try fileManager.attributesOfItem(atPath: fullPath)
                    let creationDate = attributes[.creationDate] as? Date ?? Date()
                    
                    // Create metadata
                    let metadata: [String: Any] = [
                        "fileName": (file as NSString).lastPathComponent,
                        "date": creationDate,
                        "fileSize": attributes[.size] as? Int64 ?? 0
                    ]
                    
                    let imageItem = ImageItem(
                        id: UUID(),
                        image: image,
                        metadata: metadata,
                        timestamp: creationDate
                    )
                    newImages.append(imageItem)
                }
            }
            
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.images = newImages.sorted(by: { $0.timestamp > $1.timestamp })
                // Separate indexed images
                self.indexedImages = newImages.filter { item in
                    item.metadata["isIndexed"] as? Bool == true
                }.sorted(by: { $0.timestamp > $1.timestamp })
                self.isLoading = false
            }
            
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Tab Components
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(
                    isSelected ?
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        gradient: Gradient(colors: [.gray, .gray]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        if isSelected {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.blue.opacity(0.15),
                                            Color.purple.opacity(0.15)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .blur(radius: 8)
                        }
                    }
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Photo Collections View
struct PhotoCollectionsView: View {
    let images: [ImageItem]
    let isLoading: Bool
    @Binding var isIndexing: Bool
    @Binding var selectedImageItem: ImageItem?
    let onIndexImage: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Index Image Button
            VStack(spacing: 16) {
                if selectedImageItem != nil {
                    Button(action: onIndexImage) {
                        HStack(spacing: 12) {
                            if isIndexing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.title2)
                            }
                            
                            Text(isIndexing ? "Indexing..." : "Index Selected Image")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.blue,
                                                Color.purple
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.2),
                                                Color.white.opacity(0.0)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.4),
                                            Color.white.opacity(0.1)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .blue.opacity(0.4), radius: 16, y: 8)
                    }
                    .disabled(isIndexing)
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // Removed the "Processing your image..." text as we now have a full-screen loader
                } else {
                    Text("Tap on a photo to select it for indexing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 16)
                }
            }
            .padding(.bottom, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(.ultraThinMaterial)
                }
            )
            
            // Photo Grid
            ScrollView {
                if isLoading {
                    ProgressView("Loading photos...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else if images.isEmpty {
                    EmptyPhotoCollectionsState()
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 3),
                            GridItem(.flexible(), spacing: 3),
                            GridItem(.flexible(), spacing: 3)
                        ],
                        spacing: 3
                    ) {
                        ForEach(images) { item in
                            SelectableImageGridItem(
                                item: item,
                                isSelected: selectedImageItem?.id == item.id,
                                onTap: {
                                    if selectedImageItem?.id == item.id {
                                        selectedImageItem = nil
                                    } else {
                                        selectedImageItem = item
                                    }
                                }
                            )
                            .aspectRatio(1, contentMode: .fill)
                        }
                    }
                    .padding(3)
                }
            }
        }
    }
}

// MARK: - Indexed Photos View
struct IndexedPhotosView: View {
    let indexedImages: [ImageItem]
    let isLoading: Bool
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading indexed photos...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            } else if indexedImages.isEmpty {
                EmptyIndexedPhotosState()
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 3),
                        GridItem(.flexible(), spacing: 3),
                        GridItem(.flexible(), spacing: 3)
                    ],
                    spacing: 3
                ) {
                    ForEach(indexedImages) { item in
                        NavigationLink(destination: ImageDetailView(image: item)) {
                            IndexedImageGridItem(item: item)
                                .aspectRatio(1, contentMode: .fill)
                        }
                    }
                }
                .padding(3)
            }
        }
    }
}

// MARK: - Selectable Image Grid Item
struct SelectableImageGridItem: View {
    let item: ImageItem
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: item.image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .overlay(
                        Rectangle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                    )
                
                // Selection overlay with glass effect
                if isSelected {
                    ZStack {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue.opacity(0.4),
                                        Color.purple.opacity(0.4)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.2),
                                                Color.white.opacity(0.0)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                        
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .background(
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [.blue, .purple]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 36, height: 36)
                                            .shadow(color: .blue.opacity(0.5), radius: 8, y: 4)
                                    )
                                    .padding(8)
                            }
                            Spacer()
                        }
                    }
                }
                
                // Show file name and date with better formatting
                VStack(alignment: .leading, spacing: 4) {
                    if let fileName = item.metadata["fileName"] as? String {
                        Text(fileName.replacingOccurrences(of: ".JPG", with: ""))
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                    
                    Text(item.timestamp, style: .date)
                        .font(.caption2)
                        .opacity(0.9)
                        .lineLimit(1)
                }
                .foregroundColor(.white)
                .padding(8)
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Empty States
struct EmptyPhotoCollectionsState: View {
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.1),
                                Color.purple.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                Image(systemName: "photo.stack")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("No Photos Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Add some photos to get started!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 50)
    }
}

struct EmptyIndexedPhotosState: View {
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.1),
                                Color.purple.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("No Indexed Photos")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Index some photos to see them here!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 50)
    }
}

// MARK: - Indexed Image Grid Item
struct IndexedImageGridItem: View {
    let item: ImageItem
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(uiImage: item.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .overlay(
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                )
            
            // Indexed badge and brand info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("INDEXED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                }
                
                // Show detected brands if available
                if let brands = item.metadata["brands"] as? [BrandDetectionResult], !brands.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "tag.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text(brands.first?.brandName ?? "")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                }
                
                if let fileName = item.metadata["fileName"] as? String {
                    Text(fileName.replacingOccurrences(of: ".JPG", with: ""))
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                
                Text(item.timestamp, style: .date)
                    .font(.caption2)
                    .opacity(0.9)
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .padding(8)
            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
        }
    }
}


struct ImageGridItem: View {
    let item: ImageItem
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(uiImage: item.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .overlay(
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                )
            
            // Show file name and date with better formatting
            VStack(alignment: .leading, spacing: 4) {
                if let fileName = item.metadata["fileName"] as? String {
                    Text(fileName.replacingOccurrences(of: ".JPG", with: ""))
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                
                Text(item.timestamp, style: .date)
                    .font(.caption2)
                    .opacity(0.9)
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .padding(8)
            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
        }
    }
}


struct ImageItem: Identifiable, Equatable {
    let id: UUID
    let image: UIImage
    let metadata: [String: Any]
    let timestamp: Date
    
    static func == (lhs: ImageItem, rhs: ImageItem) -> Bool {
        return lhs.id == rhs.id
    }
}

struct ImageDetailView: View {
    let image: ImageItem
    @State private var detectedBrands: [BrandDetectionResult] = []
    @State private var isLoadingBrands = false
    @State private var productInfo: ProductInfo?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(uiImage: image.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                
                // Brand Detection Section
                if image.metadata["isIndexed"] as? Bool == true {
                    BrandDetectionView(brands: detectedBrands, productInfo: productInfo)
                        .padding(.horizontal)
                        .onAppear {
                            loadBrandInformation()
                        }
                }
                
                ImageMetadataContent(image: image.image, metadata: image.metadata)
                    .padding()
                    .background(Color(red: 0.95, green: 0.93, blue: 0.90))
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func loadBrandInformation() {
        // Check if brands are already stored in metadata
        if let brandsData = image.metadata["brands"] as? [BrandDetectionResult] {
            detectedBrands = brandsData
            print("✅ Loaded \(brandsData.count) brands from metadata")
        }
        
        // Extract product info from metadata
        if let productInfoDict = image.metadata["productInfo"] as? [String: Any] {
            productInfo = ProductInfo.fromDictionary(productInfoDict)
            print("✅ Loaded productInfo from metadata: gender=\(productInfo?.gender ?? "nil"), brand=\(productInfo?.brand ?? "nil"), product=\(productInfo?.product ?? "nil")")
            print("✅ ProductInfo isValid: \(productInfo?.isValid ?? false)")
        } else {
            print("⚠️ No productInfo found in metadata - attempting on-the-fly extraction")
            
            // Try to extract productInfo on-the-fly from metadata
            var labels: [String] = []
            if let labelsData = image.metadata["labels"] as? [String] {
                labels = labelsData
            }
            
            // Get brands from metadata
            var brandsData: [BrandDetectionResult] = []
            if let brandsArray = image.metadata["brands"] as? [BrandDetectionResult] {
                brandsData = brandsArray
            }
            
            // If no brands but we have labels, try to extract from labels
            if brandsData.isEmpty && !labels.isEmpty {
                print("⚠️ No brands in metadata, but labels available: \(labels)")
            }
            
            // Try to extract product info even if we don't have brands
            let extractedProductInfo = ProductAnalyzer.shared.extractProductInfo(
                from: labels,
                objects: image.metadata["objects"] as? [String] ?? [],
                brands: brandsData,
                faces: image.metadata["faces"] as? [String] ?? []
            )
            
            if extractedProductInfo.isValid {
                productInfo = extractedProductInfo
                print("✅ Extracted productInfo on-the-fly: gender=\(productInfo?.gender ?? "nil"), brand=\(productInfo?.brand ?? "nil"), product=\(productInfo?.product ?? "nil")")
            } else {
                print("⚠️ On-the-fly extraction failed - Brand: \(extractedProductInfo.brand ?? "nil"), Product: \(extractedProductInfo.product ?? "nil")")
            }
        }
        
        // If brands not stored, detect brands using Google Vision API
        if detectedBrands.isEmpty {
            isLoadingBrands = true
            GoogleVisionService.shared.detectLogos(in: image.image) { result in
                DispatchQueue.main.async {
                    isLoadingBrands = false
                    switch result {
                    case .success(let brands):
                        detectedBrands = brands
                    case .failure(let error):
                        // Handle error silently in production
                        detectedBrands = []
                    }
                }
            }
        }
    }
}

struct FooterMenuItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue.opacity(0.2),
                                        Color.purple.opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                            .blur(radius: 8)
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: isSelected ? 26 : 24, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(
                            isSelected ?
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                gradient: Gradient(colors: [.gray, .gray]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
    }
}

struct PeopleSearchBar: View {
    @Binding var text: String
    let onSearch: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18))
                
                TextField("Search people...", text: $text)
                    .focused($isFocused)
                    .autocapitalization(.none)
                    .onSubmit(onSearch)
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                        isFocused = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 18))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(isFocused ? 0.4 : 0.2),
                                    Color.white.opacity(isFocused ? 0.3 : 0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
            .shadow(color: Color.black.opacity(0.05), radius: isFocused ? 12 : 8, y: isFocused ? 6 : 4)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        }
    }
}

struct ConnectView: View {
    @State private var searchText = ""
    @State private var selectedSegment = 0
    @State private var friends: [Friend] = [
        Friend(id: "1", name: "Sarah Parker", username: "@sarah_p", avatar: "person.circle.fill", isOnline: true),
        Friend(id: "2", name: "Mike Johnson", username: "@mike_j", avatar: "person.circle.fill", isOnline: false),
        Friend(id: "3", name: "Emma Wilson", username: "@emma_w", avatar: "person.circle.fill", isOnline: true)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar for finding friends
            PeopleSearchBar(text: $searchText, onSearch: searchFriends)
                .padding()
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(.ultraThinMaterial)
                    }
                )
            
            // Segment control
            Picker("View", selection: $selectedSegment) {
                Text("Friends").tag(0)
                Text("Requests").tag(1)
                Text("Discover").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Content based on selected segment
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedSegment {
                    case 0:
                        if !searchText.isEmpty {
                            // Show search results
                            let filteredFriends = friends.filter {
                                $0.name.lowercased().contains(searchText.lowercased()) ||
                                $0.username.lowercased().contains(searchText.lowercased())
                            }
                            if filteredFriends.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "person.slash")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray)
                                    Text("No results found")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 50)
                            } else {
                                FriendsListView(friends: filteredFriends)
                            }
                        } else {
                            FriendsListView(friends: friends)
                        }
                    case 1:
                        FriendRequestsView()
                    case 2:
                        DiscoverView()
                    default:
                        EmptyView()
                    }
                }
                .padding()
            }
        }
    }
    
    private func searchFriends() {
        // Real-time search is already implemented in the view
    }
}

struct Friend: Identifiable {
    let id: String
    let name: String
    let username: String
    let avatar: String
    let isOnline: Bool
}

struct FriendsListView: View {
    let friends: [Friend]
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(friends) { friend in
                FriendRow(friend: friend)
            }
        }
    }
}

struct FriendRow: View {
    let friend: Friend
    @State private var isShowingShareSheet = false
    
    var body: some View {
        HStack {
            // Avatar
            ZStack {
                Image(systemName: friend.avatar)
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                
                // Online indicator
                if friend.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .offset(x: 15, y: 15)
                }
            }
            
            // Name and username
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.headline)
                Text(friend.username)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Share button
            Button(action: { isShowingShareSheet = true }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.thinMaterial)
                
                RoundedRectangle(cornerRadius: 16)
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
            RoundedRectangle(cornerRadius: 16)
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
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
        .sheet(isPresented: $isShowingShareSheet) {
            ShareSheet(friend: friend)
        }
    }
}

struct ShareSheet: View {
    let friend: Friend
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedAlbums: Set<String> = []
    
    let albums = [
        Album(id: "1", name: "Summer 2024", count: 45),
        Album(id: "2", name: "Family Trip", count: 128),
        Album(id: "3", name: "Birthday Party", count: 67)
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Share Capsules with \(friend.name)")) {
                    ForEach(albums) { album in
                        AlbumRow(
                            album: album,
                            isSelected: selectedAlbums.contains(album.id)
                        ) {
                            if selectedAlbums.contains(album.id) {
                                selectedAlbums.remove(album.id)
                            } else {
                                selectedAlbums.insert(album.id)
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("Share Capsules", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Share") {
                    shareAlbums()
                }
                .disabled(selectedAlbums.isEmpty)
            )
        }
    }
    
    private func shareAlbums() {
        // Implement sharing functionality
        presentationMode.wrappedValue.dismiss()
    }
}

struct Album: Identifiable {
    let id: String
    let name: String
    let count: Int
}

struct AlbumRow: View {
    let album: Album
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(album.name)
                        .font(.headline)
                    Text("\(album.count) photos")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                }
            }
        }
        .foregroundColor(.primary)
    }
}

struct FriendRequestsView: View {
    var body: some View {
        VStack(spacing: 16) {
            RequestRow(name: "John Smith", username: "@john_s", mutualFriends: 3)
            RequestRow(name: "Lisa Brown", username: "@lisa_b", mutualFriends: 5)
        }
    }
}

struct RequestRow: View {
    let name: String
    let username: String
    let mutualFriends: Int
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                    Text(username)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("\(mutualFriends) mutual friends")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button(action: { /* Accept friend request */ }) {
                    Text("Accept")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.blue,
                                                Color.purple
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.2),
                                                Color.white.opacity(0.0)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.4),
                                            Color.white.opacity(0.1)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                }
                
                Button(action: { /* Decline friend request */ }) {
                    Text("Decline")
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.blue.opacity(0.15),
                                                Color.blue.opacity(0.05)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.blue.opacity(0.4),
                                            Color.blue.opacity(0.2)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                }
            }
        }
        .padding()
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.thinMaterial)
                
                RoundedRectangle(cornerRadius: 16)
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
            RoundedRectangle(cornerRadius: 16)
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
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }
}

struct DiscoverView: View {
    let suggestions = [
        Friend(id: "4", name: "Alex Turner", username: "@alex_t", avatar: "person.circle.fill", isOnline: true),
        Friend(id: "5", name: "Rachel Green", username: "@rachel_g", avatar: "person.circle.fill", isOnline: false)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Suggested Friends")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(suggestions) { suggestion in
                SuggestionRow(friend: suggestion)
            }
        }
    }
}

struct SuggestionRow: View {
    let friend: Friend
    
    var body: some View {
        HStack {
            Image(systemName: friend.avatar)
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.headline)
                Text(friend.username)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: { /* Add friend */ }) {
                Text("Add Friend")
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                            
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.blue.opacity(0.15),
                                            Color.blue.opacity(0.05)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue.opacity(0.4),
                                        Color.blue.opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            }
        }
        .padding()
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.thinMaterial)
                
                RoundedRectangle(cornerRadius: 16)
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
            RoundedRectangle(cornerRadius: 16)
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
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }
}

struct SettingsView: View {
    @State private var locationPermission = false
    @State private var mediaPermission = false
    @State private var showingSubscriptionSheet = false
    @State private var showingHelpSheet = false
    @State private var showingContactSheet = false
    @State private var showingAboutSheet = false
    
    // Mock user data
    let user = UserProfile(
        name: "Raj",
        photo: "person.circle.fill",
        accountType: .bronze,
        isSubscribed: false
    )
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Section
                VStack(spacing: 16) {
                    Image(systemName: user.photo)
                        .font(.system(size: 80))
                        .foregroundColor(.gray)
                        .frame(width: 120, height: 120)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                    
                    Text(user.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    AccountTypeView(type: user.accountType)
                }
                .padding(.vertical)
                
                // Permissions Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("Permissions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        Toggle(isOn: $locationPermission) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.blue, .purple]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text("Location Access")
                            }
                        }
                        .padding()
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 0)
                                    .fill(.ultraThinMaterial)
                            }
                        )
                        
                        Divider()
                            .padding(.horizontal)
                            .background(Color.white.opacity(0.3))
                        
                        Toggle(isOn: $mediaPermission) {
                            HStack {
                                Image(systemName: "photo.fill")
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.blue, .purple]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text("Media Access")
                            }
                        }
                        .padding()
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 0)
                                    .fill(.ultraThinMaterial)
                            }
                        )
                    }
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.thinMaterial)
                            
                            RoundedRectangle(cornerRadius: 16)
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
                        RoundedRectangle(cornerRadius: 16)
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
                    .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
                }
                
                // Subscription Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subscription")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Button(action: { showingSubscriptionSheet = true }) {
                        HStack {
                            Image(systemName: "star.circle.fill")
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.yellow, .orange]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text("Upgrade to Premium")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.thinMaterial)
                                
                                RoundedRectangle(cornerRadius: 16)
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
                            RoundedRectangle(cornerRadius: 16)
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
                        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
                    }
                }
                
                // Support Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("Support")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        Button(action: { showingHelpSheet = true }) {
                            HStack {
                                Image(systemName: "questionmark.circle.fill")
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.blue, .purple]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text("Help & Support")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 0)
                                        .fill(.ultraThinMaterial)
                                }
                            )
                        }
                        
                        Divider()
                            .padding(.horizontal)
                            .background(Color.white.opacity(0.3))
                        
                        Button(action: { showingContactSheet = true }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.blue, .purple]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text("Contact Us")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 0)
                                        .fill(.ultraThinMaterial)
                                }
                            )
                        }
                        
                        Divider()
                            .padding(.horizontal)
                            .background(Color.white.opacity(0.3))
                        
                        Button(action: { showingAboutSheet = true }) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.blue, .purple]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text("About Us")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 0)
                                        .fill(.ultraThinMaterial)
                                }
                            )
                        }
                    }
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.thinMaterial)
                            
                            RoundedRectangle(cornerRadius: 16)
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
                        RoundedRectangle(cornerRadius: 16)
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
                    .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
                }
                
                // Version info
                Text("Version 1.0.0")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.top)
            }
            .padding()
        }
        .sheet(isPresented: $showingSubscriptionSheet) {
            SubscriptionView()
        }
        .sheet(isPresented: $showingHelpSheet) {
            HelpSupportView()
        }
        .sheet(isPresented: $showingContactSheet) {
            ContactView()
        }
        .sheet(isPresented: $showingAboutSheet) {
            AboutUsView()
        }
    }
}

struct UserProfile {
    let name: String
    let photo: String
    let accountType: AccountType
    let isSubscribed: Bool
}

enum AccountType {
    case bronze
    case silver
    case gold
    
    var title: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        }
    }
    
    var color: Color {
        switch self {
        case .bronze: return .brown
        case .silver: return .gray
        case .gold: return .yellow
        }
    }
}

struct AccountTypeView: View {
    let type: AccountType
    
    var body: some View {
        HStack {
            Image(systemName: "medal.fill")
                .foregroundColor(type.color)
            Text("\(type.title) User")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(type.color.opacity(0.1))
        .cornerRadius(20)
    }
}

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Choose Your Plan")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    // Bronze Plan
                    PlanCard(
                        type: .bronze,
                        price: "Free",
                        features: [
                            "5 AI Search requests per day",
                            "Basic photo storage",
                            "No sharing capabilities",
                            "Standard support"
                        ],
                        isRecommended: false
                    )
                    
                    // Silver Plan
                    PlanCard(
                        type: .silver,
                        price: "$20",
                        features: [
                            "50 AI Search requests per day",
                            "Enhanced photo storage",
                            "Share capsules with up to 5 members",
                            "Priority support"
                        ],
                        isRecommended: true
                    )
                    
                    // Gold Plan
                    PlanCard(
                        type: .gold,
                        price: "$50",
                        features: [
                            "Unlimited AI Search requests",
                            "Premium photo storage",
                            "Share capsules with unlimited members",
                            "24/7 Premium support"
                        ],
                        isRecommended: false
                    )
                    
                    // Terms and conditions
                    Text("Prices are in USD and billed monthly. Cancel anytime.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            }
            .navigationBarTitle("Premium Subscription", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

struct PlanCard: View {
    let type: AccountType
    let price: String
    let features: [String]
    let isRecommended: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if isRecommended {
                Text("RECOMMENDED")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            
            HStack {
                Image(systemName: "medal.fill")
                    .foregroundColor(type.color)
                Text(type.title)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            
            Text(price)
                .font(.system(size: 32, weight: .bold))
            + Text("/month")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(features, id: \.self) { feature in
                    HStack(alignment: .top) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 16))
                        Text(feature)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical)
            
            Button(action: {
                // Handle subscription
            }) {
                Text(type == .bronze ? "Current Plan" : "Upgrade")
                    .fontWeight(.semibold)
                    .foregroundColor(type == .bronze ? .gray : .white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(type == .bronze ? Color.gray.opacity(0.1) : Color.blue)
                    .cornerRadius(12)
            }
            .disabled(type == .bronze)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: isRecommended ? Color.blue.opacity(0.1) : Color.black.opacity(0.05), radius: 8, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isRecommended ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
}

struct HelpSupportView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Frequently Asked Questions")) {
                    // Add FAQ items here
                }
                
                Section(header: Text("Guides")) {
                    // Add guide items here
                }
            }
            .navigationBarTitle("Help & Support", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

struct ContactView: View {
    @Environment(\.dismiss) var dismiss
    @State private var subject = ""
    @State private var message = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Message")) {
                    TextField("Subject", text: $subject)
                    TextEditor(text: $message)
                        .frame(height: 150)
                }
                
                Section {
                    Button(action: {
                        // Handle sending message here
                        dismiss()
                    }) {
                        Text("Send Message")
                    }
                }
            }
            .navigationBarTitle("Contact Us", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
}

struct AboutUsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App Logo
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .padding(.top, 20)
                    
                    // App Name and Version
                    VStack(spacing: 4) {
                        Text("SnapCapsule")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Version 1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    // Description
                    VStack(spacing: 16) {
                        descriptionSection(
                            title: "Our Mission",
                            content: "SnapCapsule is dedicated to revolutionizing the way people capture, organize, and share their precious moments. We believe every photo tells a story worth preserving."
                        )
                        
                        descriptionSection(
                            title: "What We Do",
                            content: "We combine cutting-edge AI technology with intuitive design to help you organize and discover your photos in ways never before possible. Our smart search and sharing features make managing your photo collection effortless."
                        )
                        
                        descriptionSection(
                            title: "Privacy First",
                            content: "Your privacy is our top priority. We employ industry-leading security measures to ensure your memories remain private and secure."
                        )
                    }
                    .padding(.horizontal)
                    
                    // Social Links
                    VStack(spacing: 8) {
                        Text("Connect With Us")
                            .font(.headline)
                            .padding(.top)
                        
                        HStack(spacing: 20) {
                            socialButton(icon: "link.circle.fill", url: "www.snapcapsule.com")
                            socialButton(icon: "envelope.circle.fill", url: "support@snapcapsule.com")
                            socialButton(icon: "message.circle.fill", url: "@snapcapsule")
                        }
                        .font(.system(size: 30))
                    }
                    
                    // Copyright
                    Text("© 2024 SnapCapsule. All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top)
                }
                .padding()
            }
            .navigationBarTitle("About Us", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
    
    private func descriptionSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func socialButton(icon: String, url: String) -> some View {
        Button(action: {
            // Handle social link tap
        }) {
            Image(systemName: icon)
                .foregroundColor(.blue)
        }
    }
}

// MARK: - Loading Overlay
struct LoadingOverlay: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            // Loading card
            VStack(spacing: 24) {
                // Animated spinner
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .blue.opacity(0.6)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(rotation))
                }
                
                // Loading text
                VStack(spacing: 8) {
                    Text("Indexing Image...")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Please wait while we analyze your image")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.regularMaterial)
                    
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.3)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.black.opacity(0.25), radius: 30, y: 15)
            )
            .padding(40)
        }
        .onAppear {
            startRotation()
        }
    }
    
    private func startRotation() {
        rotation = 0
        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
}

// MARK: - Toast Notification
struct ToastView: View {
    let message: String
    @State private var opacity: Double = 0
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.white)
            
            Text(message)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            ZStack {
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.green, .green.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Capsule()
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
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.2)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.green.opacity(0.4), radius: 16, y: 8)
        )
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                opacity = 1
            }
        }
    }
}

#Preview {
    ContentView()
}
