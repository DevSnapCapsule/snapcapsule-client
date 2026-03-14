import SwiftUI
import CoreData

struct CapsuleRepositoryView: View {
    @StateObject private var indexingQueue = IndexingQueue.shared
    @State private var albums: [AlbumEntity] = []
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [ImageEntity] = []
    @State private var showMaxLimitAlert = false
    @State private var maxLimitMessage = ""
    
    var body: some View {
        ZStack {
            // Solid background for better contrast
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Content
                if isSearching && !searchText.isEmpty {
                    // Search Results
                    SearchResultsView(results: searchResults, searchText: searchText, onDelete: {
                        performSearch() // Refresh search results after deletion
                    })
                } else {
                    // Albums View
                    AlbumsGridView(albums: albums, onMaxLimitReached: { message in
                        maxLimitMessage = message
                        showMaxLimitAlert = true
                    })
                }
                
                // Indexing Indicator
                if indexingQueue.isIndexing {
                    IndexingIndicator()
                        .padding()
                }
                
                // Smart Search Bar
                SmartSearchBar(text: $searchText, onSearch: performSearch, onClear: clearSearch)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            loadAlbums()
        }
        .onChange(of: indexingQueue.isIndexing) { isIndexing in
            // When indexing finishes, refresh albums so previews update
            if !isIndexing {
                loadAlbums()
            }
        }
        .alert("Album Limit Reached", isPresented: $showMaxLimitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(maxLimitMessage)
        }
    }
    
    private func loadAlbums() {
        guard let user = UserManager.shared.getCurrentUser() else { return }
        albums = AlbumManager.shared.getAlbums(for: user)
    }
    
    private func performSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearSearch()
            return
        }
        
        isSearching = true
        
        // Search in Core Data
        let context = UserManager.shared.viewContext
        let fetchRequest: NSFetchRequest<ImageEntity> = ImageEntity.fetchRequest()
        
        // Get current user's images only
        guard let user = UserManager.shared.getCurrentUser(),
              let userAlbums = user.albums as? Set<AlbumEntity> else {
            searchResults = []
            return
        }
        
        let albumIds = userAlbums.compactMap { $0.id }
        let albumPredicate = NSPredicate(format: "album.id IN %@", albumIds)
        let searchPredicate = NSPredicate(format: "searchableText CONTAINS[cd] %@", trimmed)
        let indexedPredicate = NSPredicate(format: "isIndexed == YES")
        
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            albumPredicate,
            searchPredicate,
            indexedPredicate
        ])
        
        do {
            let results = try context.fetch(fetchRequest)
            searchResults = results
        } catch {
            print("Search error: \(error)")
            searchResults = []
        }
    }
    
    private func clearSearch() {
        searchText = ""
        isSearching = false
        searchResults = []
    }
}

struct AlbumsGridView: View {
    let albums: [AlbumEntity]
    let onMaxLimitReached: (String) -> Void
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(albums, id: \.id) { album in
                    AlbumCard(album: album, onMaxLimitReached: onMaxLimitReached)
                }
            }
            .padding()
        }
    }
}

struct AlbumCard: View {
    let album: AlbumEntity
    let onMaxLimitReached: (String) -> Void
    @StateObject private var indexingQueue = IndexingQueue.shared
    @State private var images: [ImageEntity] = []
    @State private var showingImages = false
    
    var imageCount: Int {
        AlbumManager.shared.getImageCount(for: album)
    }
    
    var maxImages: Int {
        Int(album.maxImages)
    }
    
    var body: some View {
        Button(action: {
            showingImages = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Thumbnail Grid / Empty State
                if images.isEmpty {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.gray.opacity(0.2),
                                    Color.gray.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 150)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "photo.stack")
                                    .font(.system(size: 40, weight: .semibold))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Text("No photos added")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.7))
                            }
                        )
                } else {
                    ThumbnailGrid(images: Array(images.prefix(4)))
                }
                
                // Album Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(album.name ?? "Unknown Album")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("\(imageCount) / \(maxImages) images")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    imageCount >= maxImages ? Color.red : Color.blue
                                )
                                .frame(width: geometry.size.width * CGFloat(imageCount) / CGFloat(max(maxImages, 1)), height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.94, green: 0.94, blue: 0.96)) // light gray capsule background
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadImages()
        }
        .onChange(of: indexingQueue.isIndexing) { isIndexing in
            // When indexing finishes, refresh the images used for the capsule preview thumbnails
            if !isIndexing {
                loadImages()
            }
        }
        .sheet(isPresented: $showingImages) {
            AlbumImagesView(album: album, onMaxLimitReached: onMaxLimitReached)
        }
        .onChange(of: showingImages) { isShowing in
            if !isShowing {
                // Reload images when sheet is dismissed (after deletion)
                loadImages()
            }
        }
    }
    
    private func loadImages() {
        images = AlbumManager.shared.getImages(for: album)
    }
}

struct ThumbnailGrid: View {
    let images: [ImageEntity]
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size.width / 2 - 2
            
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    if images.count > 0 {
                        ThumbnailView(image: images[0], size: size)
                    }
                    if images.count > 1 {
                        ThumbnailView(image: images[1], size: size)
                    }
                }
                HStack(spacing: 2) {
                    if images.count > 2 {
                        ThumbnailView(image: images[2], size: size)
                    }
                    if images.count > 3 {
                        ThumbnailView(image: images[3], size: size)
                    }
                }
            }
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ThumbnailView: View {
    let image: ImageEntity
    let size: CGFloat
    
    var body: some View {
        Group {
            if let filePath = image.filePath,
               let uiImage = ImageStorageManager.shared.loadImage(from: filePath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
        }
    }
}

struct AlbumImagesView: View {
    let album: AlbumEntity
    let onMaxLimitReached: (String) -> Void
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var indexingQueue = IndexingQueue.shared
    @State private var images: [ImageEntity] = []
    @State private var showDeleteAllConfirmation = false
    @State private var isDeletingAll = false
    @State private var deleteAllError: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                if images.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 56, weight: .semibold))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Text("No photos added yet")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Use the camera to add photos to this capsule.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 80)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(images, id: \.id) { image in
                            ImageThumbnailCard(image: image, onDelete: {
                                loadImages()
                            })
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(album.name ?? "Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !images.isEmpty {
                        Button(action: {
                            showDeleteAllConfirmation = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text("Delete All")
                            }
                            .foregroundColor(.red)
                        }
                        .disabled(isDeletingAll)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                loadImages()
            }
            .onChange(of: indexingQueue.isIndexing) { isIndexing in
                // When indexing completes, reload images so newly indexed photos appear
                if !isIndexing {
                    loadImages()
                }
            }
            .alert("Delete All Images", isPresented: $showDeleteAllConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All", role: .destructive) {
                    deleteAllImages()
                }
            } message: {
                Text("Are you sure you want to delete all \(images.count) images from this album? This action cannot be undone.")
            }
            .alert("Error", isPresented: .constant(deleteAllError != nil)) {
                Button("OK", role: .cancel) {
                    deleteAllError = nil
                }
            } message: {
                if let error = deleteAllError {
                    Text(error)
                }
            }
        }
    }
    
    private func loadImages() {
        images = AlbumManager.shared.getImages(for: album)
    }
    
    private func deleteAllImages() {
        isDeletingAll = true
        
        AlbumManager.shared.deleteAllImages(from: album) { success, error in
            DispatchQueue.main.async {
                isDeletingAll = false
                
                if success {
                    // Reload images (should be empty now)
                    loadImages()
                } else {
                    deleteAllError = error ?? "Failed to delete all images"
                }
            }
        }
    }
}

struct ImageThumbnailCard: View {
    let image: ImageEntity
    let onDelete: (() -> Void)?
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            Group {
                if let filePath = image.filePath,
                   let uiImage = ImageStorageManager.shared.loadImage(from: filePath) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 120)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            ImageDetailView(image: image, onDelete: {
                onDelete?()
            })
        }
    }
}

struct ImageDetailView: View {
    let image: ImageEntity
    @Environment(\.presentationMode) var presentationMode
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    var onDelete: (() -> Void)? = nil
    
    // Lightweight tag model for display
    private struct AITag: Identifiable, Hashable {
        let id = UUID()
        let label: String
        let category: String
    }
    
    // Build up to 9 mixed-category tags from Core Data metadata
    private var mixedTags: [AITag] {
        var categoryMap: [String: [AITag]] = [:]
        
        func addTag(_ text: String, category: String) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let key = category.lowercased()
            // Avoid duplicates within the same category (case-insensitive)
            let existing = categoryMap[key] ?? []
            if existing.contains(where: { $0.label.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                return
            }
            let tag = AITag(label: trimmed, category: category)
            categoryMap[key, default: []].append(tag)
        }
        
        // Brands (e.g., Mercedes-Benz, Nike)
        if let brandEntities = image.brands as? Set<BrandEntity> {
            let sorted = brandEntities.sorted { ($0.confidence) > ($1.confidence) }
            for brand in sorted {
                if let name = brand.name {
                    addTag(name, category: "Brand")
                }
            }
        }
        
        // Base labels list for further categorisation
        let labelEntities = (image.labels as? Set<LabelEntity>) ?? []
        let labelStrings: [String] = labelEntities.compactMap { $0.name }
        
        // Colors
        if let colorEntities = image.colors as? Set<ColorEntity> {
            for color in colorEntities {
                if let name = color.name {
                    addTag(name.lowercased(), category: "Color")
                }
            }
        }
        
        // Objects (car, shoe, shirt, etc.)
        if let objectEntities = image.objects as? Set<ObjectEntity> {
            for object in objectEntities {
                if let name = object.name {
                    addTag(name, category: "Object")
                }
            }
        }
        
        // Scenes / locations (Taj Mahal, Statue of Liberty, etc.)
        if let sceneEntities = image.scenes as? Set<SceneEntity> {
            for scene in sceneEntities {
                if let name = scene.name {
                    if isLocationLike(name) {
                        addTag(name, category: "Location")
                    } else {
                        addTag(name, category: "Scene")
                    }
                }
            }
        }
        
        // Emotions from labels (crying, smiling, etc.)
        let emotionKeywords = ["crying", "sad", "happy", "smiling", "smile", "angry", "surprised", "laughing"]
        for label in labelStrings {
            let lower = label.lowercased()
            if let keyword = emotionKeywords.first(where: { lower.contains($0) }) {
                addTag(keyword.capitalized, category: "Emotion")
            }
        }
        
        // Popular person names from labels (e.g., Messi)
        let knownPeople = ["messi", "lionel messi", "ronaldo", "cristiano ronaldo", "virat kohli", "neymar", "mbappe"]
        for label in labelStrings {
            let lower = label.lowercased()
            if let match = knownPeople.first(where: { lower.contains($0) }) {
                addTag(match.capitalized, category: "Person")
            } else if looksLikePersonName(label) {
                addTag(label, category: "Person")
            }
        }
        
        // Text snippets from labels (fallback for actual text in image)
        for label in labelStrings {
            let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()
            // Skip if we already used it as person/emotion/location/brand/object/color/scene
            let used = categoryMap.values.flatMap { $0 }.contains { $0.label.caseInsensitiveCompare(trimmed) == .orderedSame }
            if used { continue }
            // Heuristic: treat longer phrases or labels with numbers as text
            if trimmed.count > 6 || trimmed.contains(" ") || trimmed.rangeOfCharacter(from: .decimalDigits) != nil {
                addTag(trimmed, category: "Text")
            }
        }
        
        // Faces / simple person presence (if nothing else)
        if let faceEntities = image.faces as? Set<FaceEntity> {
            for face in faceEntities {
                if let type = face.faceType, !type.isEmpty {
                    addTag(type, category: "Face")
                }
            }
        }
        
        // Now pick up to 9 tags, ensuring each available category appears at least once
        let categoryPriority = [
            "Brand", "Person", "Location", "Emotion", "Object", "Color", "Text", "Scene", "Face"
        ]
        
        var selected: [AITag] = []
        
        // Phase 1: one tag per category (respecting priority)
        for category in categoryPriority {
            guard selected.count < 9 else { break }
            let key = category.lowercased()
            if var tags = categoryMap[key], !tags.isEmpty {
                let tag = tags.removeFirst()
                selected.append(tag)
                categoryMap[key] = tags
            }
        }
        
        // Phase 2: fill remaining slots cycling through categories
        while selected.count < 9 {
            var addedAny = false
            for category in categoryPriority {
                guard selected.count < 9 else { break }
                let key = category.lowercased()
                if var tags = categoryMap[key], !tags.isEmpty {
                    let tag = tags.removeFirst()
                    selected.append(tag)
                    categoryMap[key] = tags
                    addedAny = true
                }
            }
            if !addedAny { break } // no more tags available
        }
        
        return selected
    }
    
    private func isLocationLike(_ text: String) -> Bool {
        let lower = text.lowercased()
        let locationKeywords = [
            "taj mahal",
            "statue of liberty",
            "eiffel tower",
            "tower bridge",
            "golden gate",
            "bridge",
            "temple",
            "palace",
            "monument",
            "landmark"
        ]
        return locationKeywords.contains(where: { lower.contains($0) })
    }
    
    private func looksLikePersonName(_ text: String) -> Bool {
        let words = text.split(separator: " ")
        guard !words.isEmpty, words.count <= 3 else { return false }
        // Simple heuristic: each word starts with uppercase and rest are letters
        return words.allSatisfy { word in
            guard let first = word.first, first.isUppercase else { return false }
            return word.dropFirst().allSatisfy { $0.isLetter }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Image
                    if let filePath = image.filePath,
                       let uiImage = ImageStorageManager.shared.loadImage(from: filePath) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(16)
                            .padding()
                    }
                    
                    // Mixed AI tags (brands, emotions, people, objects, colors, text, locations)
                    if !mixedTags.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("AI Tags")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(mixedTags) { tag in
                                    Text(tag.label)
                                        .font(.caption)
                                        .lineLimit(1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(.ultraThinMaterial)
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Delete Button
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.headline)
                            Text("Delete Image")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.red.opacity(0.8),
                                                Color.red.opacity(0.6)
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
                        .shadow(color: Color.red.opacity(0.3), radius: 8, y: 4)
                    }
                    .disabled(isDeleting)
                    .opacity(isDeleting ? 0.6 : 1.0)
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Image Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Delete Image", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteImage()
                }
            } message: {
                Text("Are you sure you want to delete this image? This action cannot be undone.")
            }
            .alert("Error", isPresented: .constant(deleteError != nil)) {
                Button("OK", role: .cancel) {
                    deleteError = nil
                }
            } message: {
                if let error = deleteError {
                    Text(error)
                }
            }
        }
    }
    
    private func deleteImage() {
        isDeleting = true
        
        AlbumManager.shared.deleteImage(image) { success, error in
            DispatchQueue.main.async {
                isDeleting = false
                
                if success {
                    // Call the onDelete callback if provided
                    onDelete?()
                    // Dismiss the view
                    presentationMode.wrappedValue.dismiss()
                } else {
                    deleteError = error ?? "Failed to delete image"
                }
            }
        }
    }
}

struct SearchResultsView: View {
    let results: [ImageEntity]
    let searchText: String
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        ScrollView {
            if results.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No images found")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("Try searching for different terms")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(results, id: \.id) { image in
                        ImageThumbnailCard(image: image, onDelete: onDelete)
                    }
                }
                .padding()
            }
        }
    }
}

struct SmartSearchBar: View {
    @Binding var text: String
    let onSearch: () -> Void
    let onClear: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 18))
            
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("Search images...")
                        .foregroundColor(Color.black.opacity(0.4)) // light black placeholder
                        .font(.body)
                }
                
                TextField("", text: $text)
                    .focused($isFocused)
                    .autocapitalization(.none)
                    .foregroundColor(.black)
                    .tint(.black)
                    .onSubmit(onSearch)
                    .onChange(of: text) { newValue in
                        if newValue.isEmpty {
                            onClear()
                        }
                    }
            }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    isFocused = false
                    onClear()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.94, green: 0.94, blue: 0.96)) // light gray search bar background
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 3)
    }
}

struct IndexingIndicator: View {
    @StateObject private var indexingQueue = IndexingQueue.shared
    
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Indexing images...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if indexingQueue.indexingProgress > 0 {
                    ProgressView(value: indexingQueue.indexingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
            }
        }
        .padding()
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 12)
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
            RoundedRectangle(cornerRadius: 12)
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
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
    }
}

