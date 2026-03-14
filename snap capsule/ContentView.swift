//
//  ContentView.swift
//  snap capsule
//
//  Created by administrator on 25/05/2025.
//

import SwiftUI
 
struct ContentView: View {
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @State private var isShowingCamera = false
    @State private var searchText = ""
    @State private var searchResults: [ImageSearchResult] = []
    @State private var selectedTab = 1
    @State private var showNetworkAlert = false
    @State private var networkAlertMessage: String = "SnapCapsule needs an internet connection to analyze photos. Please check your connection and try again."
    
    var body: some View {
        NavigationView {
            ZStack {
                // Match overall background to the footer/menu background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.80),
                        Color.black.opacity(0.90)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
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
                                    .padding(.horizontal)
                                    .padding(.top)
                                
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
                            // About
                            SettingsView()
                        default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Footer Menu with higher contrast
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            FooterMenuItem(icon: "camera.fill", title: "Snap Lens", isSelected: selectedTab == 0) {
                                isShowingCamera = true
                            }
                            
                            FooterMenuItem(icon: "photo.stack.fill", title: "Capsule Repository", isSelected: selectedTab == 1) {
                                selectedTab = 1
                            }
                            
                            FooterMenuItem(icon: "info.circle.fill", title: "About", isSelected: selectedTab == 2) {
                                selectedTab = 2
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .background(
                            ZStack {
                                // Dark glass morphism effect for strong contrast
                                RoundedRectangle(cornerRadius: 0)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.black.opacity(0.65),
                                                Color.black.opacity(0.75)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                
                                // Subtle blue highlight
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue.opacity(0.20),
                                        Color.purple.opacity(0.15)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        )
                        .overlay(
                            // Top border glow
                            VStack {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.25),
                                                Color.white.opacity(0.05)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 1)
                                    .blur(radius: 1.0)
                                Spacer()
                            }
                        )
                    }
                }
            }
            .navigationBarTitle(navigationTitle, displayMode: .inline)
            .toolbarBackground(Color.black.opacity(0.6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("No Internet Connection",
                   isPresented: $showNetworkAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(networkAlertMessage)
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraView(onCaptureCompleted: {
                // After taking a photo, always land on Capsule Repository.
                selectedTab = 1
            })
        }
        .onAppear {
            if !networkMonitor.isConnected {
                showNetworkAlert = true
            }
        }
        .onChange(of: networkMonitor.isConnected) { isConnected in
            if !isConnected {
                showNetworkAlert = true
            }
        }
    }
    
    private var navigationTitle: String {
        switch selectedTab {
        case 0: return "Snap Capsule"
        case 1: return "Capsule Repository"
        case 2: return "About"
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
                .foregroundColor(Color.gray)
                .font(.system(size: 18))
            
            TextField("AI Search..", text: $text)
                .focused($isFocused)
                .autocapitalization(.none)
                .foregroundColor(.black)
                .tint(.black)
                .onSubmit(onSearch)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    isFocused = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.white.opacity(0.75))
                        .font(.system(size: 18))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            // Inner glowing search pill
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(isFocused ? 0.55 : 0.40),
                            Color.purple.opacity(isFocused ? 0.55 : 0.40)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    Color(.darkGray).opacity(isFocused ? 0.9 : 0.8),
                    lineWidth: isFocused ? 2 : 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.5), radius: isFocused ? 14 : 10, y: isFocused ? 7 : 5)
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

// Old CapsuleRepositoryView removed - using new implementation from CapsuleRepositoryView.swift
struct OldCapsuleRepositoryView: View {
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
        ImageAnalyzer.shared.analyzeImage(selectedItem.image) { metadata in
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
        // This helper was previously used to import images from a
        // local Mac workspace directory for development/testing.
        // In production builds we keep all user photos inside the app’s
        // own storage and do not load from arbitrary filesystem paths.
        isLoading = false
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
                        NavigationLink(destination: OldImageDetailView(image: item)) {
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
                            .foregroundColor(.gray)
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
                    .foregroundColor(.gray)
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

struct OldImageDetailView: View {
    let image: ImageItem
    @State private var detectedBrands: [BrandDetectionResult] = []
    @State private var isLoadingBrands = false
    @State private var productInfo: ProductInfo?
    @State private var showAnalysisAlert = false
    @State private var analysisAlertMessage: String = ""
    
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
        .alert("Analysis Unavailable", isPresented: $showAnalysisAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(analysisAlertMessage)
        }
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
                        detectedBrands = []
                        
                        // Map common errors to a user-friendly message
                        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
                            analysisAlertMessage = "You appear to be offline. SnapCapsule needs an internet connection to detect brands with AI."
                            showAnalysisAlert = true
                        } else if let visionError = error as? VisionServiceError {
                            switch visionError {
                            case .invalidAPIKey:
                                analysisAlertMessage = "Image analysis is not configured correctly (missing API key). Please contact support."
                            case .invalidImage:
                                analysisAlertMessage = "The selected image could not be processed. Please try a different photo."
                            case .noData:
                                analysisAlertMessage = "The AI service did not return any data. Please try again in a moment."
                            case .apiError(let message):
                                analysisAlertMessage = "The AI service reported an error: \(message)"
                            }
                            showAnalysisAlert = true
                        } else {
                            analysisAlertMessage = "Image analysis failed. Please check your connection and try again. (\(error.localizedDescription))"
                            showAnalysisAlert = true
                        }
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
                                        Color.blue.opacity(0.5),
                                        Color.purple.opacity(0.5)
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
                                gradient: Gradient(colors: [
                                    Color(red: 0.70, green: 0.80, blue: 1.0),
                                    Color(red: 0.80, green: 0.75, blue: 1.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color.white : Color.white.opacity(0.8))
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

struct SettingsView: View {
    @State private var showingContactSheet = false
    @State private var showingAboutSheet = false
    @State private var isImportingTestImages = false
    @State private var importMessage = ""
    @State private var showImportAlert = false
    
    var body: some View {
        ZStack {
            // Keep About screen background clean and white
            Color.white
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // SnapCapsule Logo Section
                    VStack(spacing: 16) {
                        Image("SnapCapsuleLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 140, height: 140)
                            .padding(.top, 16)
                    }
                    .padding(.vertical)
                
                    // Support Section
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Support")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
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
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                            
                            Divider()
                                .padding(.horizontal)
                                .background(Color.white.opacity(0.15))
                            
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
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 0.94, green: 0.94, blue: 0.96)) // light gray tiles
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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 40)
                    
                    // Message
                    VStack(spacing: 16) {
                        Text("Contact Us")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                        
                        Text("We're here to help! Whether you have questions, need support, or want to share feedback, our team is ready to assist you. Reach out to us and we'll get back to you as soon as possible.")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // Email address
                        Button(action: {
                            if let url = URL(string: "mailto:dev@snapcapsule.com") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                Text("dev@snapcapsule.com")
                                    .fontWeight(.semibold)
                            }
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(.systemBackground))
                                    
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.white.opacity(0.9),
                                                    Color.white.opacity(0.7)
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
                                        Color.blue.opacity(0.5),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                }
                .padding()
            }
            .background(Color.white.ignoresSafeArea())
            .navigationBarTitle("Contact Us", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

struct AboutUsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showEmailCopiedAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App Logo
                    Image("SnapCapsuleLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .padding(.top, 20)
                    
                    // App Version
                    VStack(spacing: 4) {
                        Text("Version 1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    // Description
                    VStack(spacing: 16) {
                        descriptionSection(
                            title: "Our Mission",
                            content: "Snap Capsule is dedicated to revolutionizing the way people capture, organize, and explore their photo memories. We believe every photo tells a story worth preserving, and our goal is to make discovering those moments effortless."
                        )
                        
                        descriptionSection(
                            title: "What We Do",
                            content: "Snap Capsule combines intuitive design with powerful AI technology to help you organize and explore your photo collection. By analyzing images, the app can automatically identify objects, scenes, and content within your photos, making it easier to search, categorize, and rediscover your memories."
                        )
                        
                        descriptionSection(
                            title: "Privacy First",
                            content: "Your privacy is our top priority. Snap Capsule processes images only to analyze their visual content and generate labels that help organize your photo collection.\n\nWhen you choose to analyze a photo, the image may be securely sent to trusted AI services for processing. These images are used only for analysis and are not stored by Snap Capsule. We are committed to protecting your data and ensuring your memories remain private and secure."
                        )
                    }
                    .padding(.horizontal)
                    
                    // Social Links
                    VStack(spacing: 8) {
                        Text("Connect With Us")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .fontWeight(.bold)
                            .padding(.top)
                        
                        HStack(spacing: 20) {
                            // Website
                            Button {
                                if let url = URL(string: "https://www.snapcapsule.com") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Image(systemName: "link.circle.fill")
                                    .foregroundColor(.blue)
                            }
                            
                            // Copy support email
                            Button {
                                UIPasteboard.general.string = "dev@snapcapsule.com"
                                showEmailCopiedAlert = true
                            } label: {
                                Image(systemName: "envelope.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .font(.system(size: 30))
                    }
                    
                    // Copyright
                    Text("© 2025 Snap Capsule. All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top)
                }
                .padding()
            }
            .background(Color.white.ignoresSafeArea())
            .navigationBarTitle("About Us", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .alert("Email Copied", isPresented: $showEmailCopiedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("`dev@snapcapsule.com` has been copied. Please email to this address.")
            }
        }
    }
    
    private func descriptionSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.gray)
                .fontWeight(.bold)
            Text(content)
                .font(.body)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // Removed old generic socialButton – actions are now explicit per icon
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
