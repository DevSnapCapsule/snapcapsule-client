import SwiftUI
import CoreData
import Vision

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
        .onChange(of: indexingQueue.isIndexing) { _, isIndexing in
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
        .onChange(of: indexingQueue.isIndexing) { _, isIndexing in
            // When indexing finishes, refresh the images used for the capsule preview thumbnails
            if !isIndexing {
                loadImages()
            }
        }
        .sheet(isPresented: $showingImages) {
            AlbumImagesView(album: album, onMaxLimitReached: onMaxLimitReached)
        }
        .onChange(of: showingImages) { _, isShowing in
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

private struct CapsuleImagePagerToken: Identifiable {
    let id = UUID()
    let initialObjectID: NSManagedObjectID
}

private struct CapsuleLoaderOverlay: View {
    let title: String
    
    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.1)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }
}

private struct CapsuleImagePagerView: View {
    let album: AlbumEntity
    let initialObjectID: NSManagedObjectID
    var onAlbumImagesChanged: () -> Void
    var onDismiss: () -> Void
    
    @State private var images: [ImageEntity] = []
    @State private var selection: NSManagedObjectID?
    @State private var didSetInitialSelection = false
    @State private var hasLoadedImages = false
    @State private var zoomedImageIDs: Set<NSManagedObjectID> = []
    
    var body: some View {
        Group {
            if !hasLoadedImages {
                ZStack {
                    Color.black.ignoresSafeArea()
                    CapsuleLoaderOverlay(title: "Opening photo")
                }
            } else if images.isEmpty {
                ContentUnavailableView(
                    "No Photos",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("This capsule has no images.")
                )
                .onAppear {
                    onAlbumImagesChanged()
                    onDismiss()
                }
            } else {
                TabView(selection: $selection) {
                    ForEach(images, id: \.objectID) { img in
                        ImageDetailView(
                            image: img,
                            dismissAfterDelete: false,
                            onZoomStateChanged: { isZoomed in
                                if isZoomed {
                                    zoomedImageIDs.insert(img.objectID)
                                } else {
                                    zoomedImageIDs.remove(img.objectID)
                                }
                            },
                            onRequestAdjacentPage: { delta in
                                navigateToAdjacentPage(delta: delta)
                            },
                            onDelete: {
                                refreshAfterPageDelete(deletedObjectID: img.objectID)
                            }
                        )
                        .tag(Optional(img.objectID))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .scrollDisabled(isCurrentPageZoomed)
            }
        }
        .background(Color.black)
        .onAppear {
            reloadImages()
            hasLoadedImages = true
            if !didSetInitialSelection {
                selection = images.first(where: { $0.objectID == initialObjectID })?.objectID
                    ?? images.first?.objectID
                didSetInitialSelection = true
            }
        }
    }
    
    private func reloadImages() {
        images = AlbumManager.shared.getImages(for: album)
        let validIDs = Set(images.map(\.objectID))
        zoomedImageIDs = zoomedImageIDs.intersection(validIDs)
    }
    
    private var isCurrentPageZoomed: Bool {
        guard let selection else { return false }
        return zoomedImageIDs.contains(selection)
    }
    
    private func refreshAfterPageDelete(deletedObjectID: NSManagedObjectID) {
        onAlbumImagesChanged()
        reloadImages()
        if images.isEmpty {
            onDismiss()
            return
        }
        let deletedWasCurrent = selection.map { $0 == deletedObjectID } ?? false
        let selectionStillValid = selection.map { sel in images.contains(where: { $0.objectID == sel }) } ?? false
        if deletedWasCurrent || !selectionStillValid {
            selection = images.first?.objectID
        }
    }
    
    /// - Parameter delta: -1 previous, +1 next (ordered like `getImages`: newest first).
    private func navigateToAdjacentPage(delta: Int) {
        guard let sel = selection,
              let idx = images.firstIndex(where: { $0.objectID == sel }) else { return }
        let nextIndex = idx + delta
        guard images.indices.contains(nextIndex) else { return }
        withAnimation(.smooth(duration: 0.32)) {
            selection = images[nextIndex].objectID
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
    @State private var pagerToken: CapsuleImagePagerToken?
    @State private var isMultiSelectMode = false
    @State private var deletionSelection: Set<NSManagedObjectID> = []
    @State private var showBulkDeleteConfirmation = false
    @State private var isBulkDeleting = false
    @State private var bulkDeleteError: String?
    @State private var isShowingGalleryImport = false
    
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
                        
                        Text("Use the camera or import one photo at a time from your library.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Button {
                            isShowingGalleryImport = true
                        } label: {
                            Label("Import from Photos", systemImage: "photo.badge.plus")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.blue.opacity(0.12))
                                )
                        }
                        .padding(.top, 4)
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
                            ImageThumbnailCard(
                                image: image,
                                isMultiSelectMode: isMultiSelectMode,
                                isSelectedForDeletion: deletionSelection.contains(image.objectID),
                                onTap: {
                                    if isMultiSelectMode {
                                        toggleDeletionSelection(for: image.objectID)
                                    } else {
                                        pagerToken = CapsuleImagePagerToken(initialObjectID: image.objectID)
                                    }
                                },
                                onLongPressEnterMultiSelect: {
                                    enterMultiSelect(selecting: image.objectID)
                                },
                                onDelete: {
                                    loadImages()
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(isMultiSelectMode ? "Select Photos" : (album.name ?? "Album"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isMultiSelectMode {
                        Button("Cancel") {
                            exitMultiSelectMode()
                        }
                    } else if !images.isEmpty {
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
                    if isMultiSelectMode {
                        Button(role: .destructive) {
                            guard !deletionSelection.isEmpty else { return }
                            showBulkDeleteConfirmation = true
                        } label: {
                            Text(deletionSelection.isEmpty ? "Delete" : "Delete (\(deletionSelection.count))")
                        }
                        .disabled(deletionSelection.isEmpty || isBulkDeleting)
                    } else {
                        Button {
                            isShowingGalleryImport = true
                        } label: {
                            Image(systemName: "photo.badge.plus")
                        }
                        .accessibilityLabel("Import one photo from library")

                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
            .onAppear {
                loadImages()
            }
            .onChange(of: indexingQueue.isIndexing) { _, isIndexing in
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
            .alert("Delete Selected Photos", isPresented: $showBulkDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteSelectedImages()
                }
            } message: {
                Text("Delete \(deletionSelection.count) photo\(deletionSelection.count == 1 ? "" : "s")? This cannot be undone.")
            }
            .alert("Error", isPresented: .constant(bulkDeleteError != nil)) {
                Button("OK", role: .cancel) {
                    bulkDeleteError = nil
                }
            } message: {
                if let error = bulkDeleteError {
                    Text(error)
                }
            }
            .sheet(item: $pagerToken) { token in
                CapsuleImagePagerView(
                    album: album,
                    initialObjectID: token.initialObjectID,
                    onAlbumImagesChanged: loadImages,
                    onDismiss: { pagerToken = nil }
                )
            }
            .sheet(isPresented: $isShowingGalleryImport) {
                GalleryPhotoImportView(onImportCompleted: loadImages)
            }
            .overlay {
                if isDeletingAll || isBulkDeleting {
                    ZStack {
                        Color.black.opacity(0.28)
                            .ignoresSafeArea()
                        CapsuleLoaderOverlay(title: "Deleting photos")
                    }
                    .transition(.opacity)
                }
            }
        }
    }
    
    private func enterMultiSelect(selecting objectID: NSManagedObjectID) {
        isMultiSelectMode = true
        deletionSelection = [objectID]
    }
    
    private func exitMultiSelectMode() {
        isMultiSelectMode = false
        deletionSelection = []
    }
    
    private func toggleDeletionSelection(for objectID: NSManagedObjectID) {
        if deletionSelection.contains(objectID) {
            deletionSelection.remove(objectID)
        } else {
            deletionSelection.insert(objectID)
        }
    }
    
    private func deleteSelectedImages() {
        let toDelete = images.filter { deletionSelection.contains($0.objectID) }
        guard !toDelete.isEmpty else { return }
        isBulkDeleting = true
        AlbumManager.shared.deleteImages(toDelete) { success, error in
            DispatchQueue.main.async {
                isBulkDeleting = false
                if success {
                    exitMultiSelectMode()
                    loadImages()
                } else {
                    bulkDeleteError = error ?? "Failed to delete photos"
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
    var isMultiSelectMode: Bool = false
    var isSelectedForDeletion: Bool = false
    let onTap: () -> Void
    var onLongPressEnterMultiSelect: (() -> Void)? = nil
    let onDelete: (() -> Void)?
    @State private var suppressNextTapFromLongPress = false
    
    var body: some View {
        Button(action: {
            if suppressNextTapFromLongPress {
                suppressNextTapFromLongPress = false
                return
            }
            onTap()
        }) {
            ZStack(alignment: .topTrailing) {
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
                .overlay(alignment: .topLeading) {
                    if image.isFromGallery && !isMultiSelectMode {
                        GallerySourceBadge(compact: true)
                            .padding(6)
                    }
                }
                .overlay {
                    if isMultiSelectMode {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelectedForDeletion ? Color.blue : Color.white.opacity(0.35), lineWidth: isSelectedForDeletion ? 3 : 1)
                    }
                }
                if isMultiSelectMode {
                    Image(systemName: isSelectedForDeletion ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelectedForDeletion ? Color.blue : Color.secondary.opacity(0.9))
                        .padding(8)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in
                    guard !isMultiSelectMode, let onLongPressEnterMultiSelect else { return }
                    suppressNextTapFromLongPress = true
                    onLongPressEnterMultiSelect()
                }
        )
    }
}

// MARK: - Image detail AI tags (shared between detail + sheet)

private struct ImageDetailAITag: Identifiable, Hashable {
    let label: String
    let category: String
    /// Optional match strength (0–100) for colors and brands.
    var confidencePercent: Int?
    /// Optional normalized focus rectangle (0...1 in image coordinates).
    var focusRect: CGRect?
    
    var id: String { "\(category.lowercased())|\(label.lowercased())" }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ImageDetailAITag, rhs: ImageDetailAITag) -> Bool {
        lhs.id == rhs.id
    }
}

private struct AITagCategorySection: Identifiable {
    let id: String
    let title: String
    let tags: [ImageDetailAITag]
}

/// Bottom gradient + horizontal chips so labels read as part of the photo, not a separate list below.
private struct ImageDetailAITagsPhotoOverlay: View {
    /// Tags shown in the horizontal strip (compact preview).
    let stripTags: [ImageDetailAITag]
    /// Total tags available (sheet may show more than the strip).
    let totalTagCount: Int
    var onViewAll: () -> Void
    var onSelectTag: (ImageDetailAITag) -> Void
    var selectedTagId: String?
    
    private var showEmptyBrandStrip: Bool {
        stripTags.isEmpty && totalTagCount > 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.35),
                        .black.opacity(0.72)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
                .allowsHitTesting(false)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.yellow.opacity(0.95))
                        Text("Detected")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                    }
                    
                    if stripTags.isEmpty {
                        if showEmptyBrandStrip {
                            Text("No brands detected in this photo.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.88))
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.vertical, 2)
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(stripTags) { tag in
                                    Button {
                                        onSelectTag(tag)
                                    } label: {
                                        let isSelected = selectedTagId == tag.id
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(tag.label)
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(isSelected ? .black : .white)
                                                .lineLimit(1)
                                            if let pct = tag.confidencePercent {
                                                Text("\(pct)%")
                                                    .font(.caption2.weight(.semibold))
                                                    .foregroundStyle(isSelected ? .black.opacity(0.75) : .white.opacity(0.82))
                                            }
                                        }
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule()
                                                .fill(isSelected ? .yellow.opacity(0.95) : .white.opacity(0.22))
                                        )
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(isSelected ? .yellow.opacity(0.95) : .white.opacity(0.28), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    
                    Button(action: onViewAll) {
                        HStack(spacing: 6) {
                            Text(totalTagCount > stripTags.count ? "All tags (\(totalTagCount))" : "Details & categories")
                            Image(systemName: "chevron.up")
                                .font(.caption.weight(.semibold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.white.opacity(0.18))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View all AI tags and categories")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
        }
    }
}

/// Translucent bottom sheet — Brand always visible; other categories behind **Other Info**.
private struct ImageDetailAITagsSheet: View {
    let sections: [AITagCategorySection]
    var onSelectTag: (ImageDetailAITag) -> Void
    var selectedTagId: String?
    
    @State private var showOtherInfo = false
    
    private var brandSection: AITagCategorySection? {
        sections.first { $0.id.caseInsensitiveCompare("Brand") == .orderedSame }
    }
    
    private var otherSections: [AITagCategorySection] {
        sections.filter { $0.id.caseInsensitiveCompare("Brand") != .orderedSame }
    }
    
    private var tagGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 108), spacing: 10, alignment: .top)]
    }
    
    @ViewBuilder
    private func tagGrid(tags: [ImageDetailAITag]) -> some View {
        LazyVGrid(columns: tagGridColumns, alignment: .leading, spacing: 10) {
            ForEach(tags) { tag in
                Button {
                    onSelectTag(tag)
                } label: {
                    ImageDetailAITagSheetCard(
                        tag: tag,
                        isSelected: selectedTagId == tag.id
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func categoryBlock(_ section: AITagCategorySection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            
            tagGrid(tags: section.tags)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("AI Tags")
                    .font(.title2.weight(.semibold))
                Spacer()
            }
            .padding(.bottom, 4)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BRAND")
                            .font(.caption.weight(.semibold))
                            .tracking(0.6)
                            .foregroundStyle(.secondary)
                        
                        if let brandSection, !brandSection.tags.isEmpty {
                            tagGrid(tags: brandSection.tags)
                        } else {
                            Text("No brands detected for this image.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    if !otherSections.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    showOtherInfo.toggle()
                                }
                            } label: {
                                HStack {
                                    Text("Other Info")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .rotationEffect(.degrees(showOtherInfo ? 180 : 0))
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.06)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(showOtherInfo ? "Hide other categories" : "Show other categories")
                            
                            if showOtherInfo {
                                ForEach(otherSections) { section in
                                    categoryBlock(section)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ImageDetailAITagSheetCard: View {
    let tag: ImageDetailAITag
    let isSelected: Bool
    
    private var subtitle: String {
        if let pct = tag.confidencePercent {
            return tag.category == "Color" ? "~\(pct)% of image" : "\(pct)% confidence"
        }
        return tag.category
    }
    
    private var subtitleStyle: AnyShapeStyle {
        if tag.confidencePercent == nil {
            return AnyShapeStyle(.tertiary)
        }
        return AnyShapeStyle(.secondary)
    }
    
    private var cardBackgroundStyle: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.blue.opacity(0.14))
        }
        return AnyShapeStyle(.thinMaterial)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tag.label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .blue : .primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(subtitleStyle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardBackgroundStyle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Color.blue.opacity(0.65) : Color.primary.opacity(0.06), lineWidth: 1.2)
        )
    }
}

private struct ImageTagFocusOverlayData {
    let tag: ImageDetailAITag
    let normalizedRect: CGRect
    let croppedImage: UIImage
    let note: String?
}

private struct ImageTagFocusOverlayCard: View {
    let data: ImageTagFocusOverlayData
    var onClose: () -> Void
    @State private var cropMagnification: CGFloat = 1
    @State private var cropMagnificationBase: CGFloat = 1
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("\(data.tag.category): \(data.tag.label)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close tag preview")
            }
            
            GeometryReader { geo in
                Image(uiImage: data.croppedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(cropMagnification)
                    .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.88), value: cropMagnification)
                    .contentShape(Rectangle())
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                cropMagnification = min(4.0, max(1.0, cropMagnificationBase * value))
                            }
                            .onEnded { _ in
                                cropMagnificationBase = cropMagnification
                                if cropMagnification <= 1.02 {
                                    cropMagnification = 1
                                    cropMagnificationBase = 1
                                }
                            }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 420)
            
            if let note = data.note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
        .padding(.horizontal, 20)
    }
}

private struct HighlightSelectionData {
    let tag: ImageDetailAITag
    let normalizedRect: CGRect
    let note: String?
}

struct ImageDetailView: View {
    let image: ImageEntity
    /// When embedded in the capsule swipe pager, deleting should refresh the pager instead of dismissing the sheet.
    var dismissAfterDelete: Bool = true
    var onZoomStateChanged: ((Bool) -> Void)? = nil
    /// Capsule pager only: -1 = older photo, +1 = newer photo (`AlbumManager.getImages` order).
    var onRequestAdjacentPage: ((Int) -> Void)? = nil
    @Environment(\.presentationMode) var presentationMode
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var showAITagsSheet = false
    @State private var showExploreProducts = false
    /// When true, shows gradient + chips on the photo; when false, photo is unobstructed (tags still in sheet).
    @State private var showLabelsOnPhoto = true
    @State private var selectedTagOverlay: ImageTagFocusOverlayData?
    @State private var displayedImage: UIImage?
    @State private var highlightSelection: HighlightSelectionData?
    @State private var isResolvingTagFocus = false
    @State private var liveTagFocusCache: [String: (CGRect, String?)] = [:]
    @State private var noticeText: String?
    @State private var detailMagnification: CGFloat = 1
    @State private var detailMagnificationBase: CGFloat = 1
    @State private var detailPan: CGSize = .zero
    @State private var detailPanBase: CGSize = .zero
    var onDelete: (() -> Void)? = nil
    
    private static let aiCategoryPriority: [String] = [
        "Brand", "Location", "Emotion", "Object", "Color", "Text", "Scene", "Face"
    ]
    
    /// Aligned with Vision pipeline: hide low-confidence brands in the UI.
    private static let minimumBrandConfidenceToShow = 0.54
    
    private static let chromaticColorNames: Set<String> = [
        "red", "orange", "yellow", "green", "blue", "purple", "pink", "brown"
    ]
    
    private func percentString(from confidence: Double) -> Int? {
        guard confidence > 0 else { return nil }
        return max(1, min(99, Int((confidence * 100).rounded())))
    }
    
    /// Full tag map — categories follow `aiCategoryPriority`; each label string appears in **at most one** category (first wins).
    private func buildAITagCategoryMap() -> [String: [ImageDetailAITag]] {
        var categoryMap: [String: [ImageDetailAITag]] = [:]
        var claimedLabelKeys: Set<String> = []
        
        func normalizedKey(_ text: String) -> String {
            text.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: " ", with: "")
        }
        
        func addTag(_ text: String, category: String, confidencePercent: Int? = nil, focusRect: CGRect? = nil) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let dedupeKey = normalizedKey(trimmed)
            guard !claimedLabelKeys.contains(dedupeKey) else { return }
            let key = category.lowercased()
            let existing = categoryMap[key] ?? []
            if existing.contains(where: { $0.label.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                return
            }
            claimedLabelKeys.insert(dedupeKey)
            let tag = ImageDetailAITag(label: trimmed, category: category, confidencePercent: confidencePercent, focusRect: focusRect)
            categoryMap[key, default: []].append(tag)
        }
        
        func isTextLikeLabel(_ text: String) -> Bool {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.count > 6
                || trimmed.contains(" ")
                || trimmed.rangeOfCharacter(from: .decimalDigits) != nil
        }
        
        let labelEntities = (image.labels as? Set<LabelEntity>) ?? []
        let sortedLabelEntities = labelEntities.sorted { $0.confidence > $1.confidence }
        // 1. Brand (highest priority for duplicate strings)
        if let brandEntities = image.brands as? Set<BrandEntity> {
            let sorted = brandEntities.sorted { ($0.confidence) > ($1.confidence) }
            for brand in sorted {
                if let name = brand.name,
                   brand.confidence >= Self.minimumBrandConfidenceToShow,
                   VisionNoiseTerms.isPlausibleBrandName(name) {
                    let pct = min(99, Int((brand.confidence * 100).rounded()))
                    let hasValidBox = brand.boundingBoxWidth > 0 && brand.boundingBoxHeight > 0
                    let focus = hasValidBox
                        ? CGRect(
                            x: brand.boundingBoxX,
                            y: brand.boundingBoxY,
                            width: brand.boundingBoxWidth,
                            height: brand.boundingBoxHeight
                        )
                        : nil
                    addTag(name, category: "Brand", confidencePercent: pct, focusRect: focus)
                }
            }
        }
        
        // 2. Location (from scenes)
        if let sceneEntities = image.scenes as? Set<SceneEntity> {
            for scene in sceneEntities {
                if let name = scene.name, isLocationLike(name) {
                    addTag(name, category: "Location", confidencePercent: percentString(from: scene.confidence))
                }
            }
        }
        
        // 3. Emotion
        let emotionKeywords = ["crying", "sad", "happy", "smiling", "smile", "angry", "surprised", "laughing"]
        for label in sortedLabelEntities {
            guard let name = label.name else { continue }
            let lower = name.lowercased()
            if let keyword = emotionKeywords.first(where: { lower.contains($0) }) {
                addTag(keyword.capitalized, category: "Emotion", confidencePercent: percentString(from: label.confidence))
            }
        }
        
        // 4. Object
        if let objectEntities = image.objects as? Set<ObjectEntity> {
            for object in objectEntities {
                if let name = object.name {
                    addTag(name, category: "Object", confidencePercent: percentString(from: object.confidence))
                }
            }
        }
        for label in sortedLabelEntities {
            guard let name = label.name else { continue }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !VisionNoiseTerms.shouldSuppressAsFreeformLabel(trimmed) else { continue }
            let lower = trimmed.lowercased()
            let isEmotion = emotionKeywords.contains(where: { lower.contains($0) })
            let isLocation = isLocationLike(trimmed)
            guard !isEmotion, !isLocation, !isTextLikeLabel(trimmed) else { continue }
            addTag(trimmed, category: "Object", confidencePercent: percentString(from: label.confidence))
        }
        
        // 5. Color
        if let colorEntities = image.colors as? Set<ColorEntity> {
            for color in colorEntities {
                guard let name = color.name else { continue }
                let lower = name.lowercased()
                let conf = color.confidence
                if conf > 0 {
                    let pct = max(1, min(99, Int((conf * 100).rounded())))
                    addTag(lower, category: "Color", confidencePercent: pct)
                } else {
                    if Self.chromaticColorNames.contains(lower) { continue }
                    addTag(lower, category: "Color", confidencePercent: nil)
                }
            }
        }
        
        // 6. Text (leftover labels)
        for label in sortedLabelEntities {
            guard let name = label.name else { continue }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !VisionNoiseTerms.shouldSuppressAsFreeformLabel(trimmed) else { continue }
            let used = claimedLabelKeys.contains(normalizedKey(trimmed))
            if used { continue }
            if isTextLikeLabel(trimmed) {
                addTag(trimmed, category: "Text", confidencePercent: percentString(from: label.confidence))
            }
        }
        
        // 7. Scene (non-location scenes)
        if let sceneEntities = image.scenes as? Set<SceneEntity> {
            for scene in sceneEntities {
                if let name = scene.name, !isLocationLike(name) {
                    addTag(name, category: "Scene", confidencePercent: percentString(from: scene.confidence))
                }
            }
        }
        
        // 8. Face
        if let faceEntities = image.faces as? Set<FaceEntity> {
            for face in faceEntities {
                if let type = face.faceType, !type.isEmpty {
                    addTag(type, category: "Face", confidencePercent: percentString(from: face.confidence))
                }
            }
        }
        
        for key in categoryMap.keys {
            categoryMap[key]?.sort { lhs, rhs in
                let lp = lhs.confidencePercent ?? -1
                let rp = rhs.confidencePercent ?? -1
                if lp != rp { return lp > rp }
                return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
        }
        
        return categoryMap
    }
    
    private func normalizedClampedRect(_ rect: CGRect, minimumExtent: CGFloat = 0.001) -> CGRect? {
        guard rect.width > 0, rect.height > 0 else { return nil }
        let sanitized = CGRect(
            x: max(0, min(1, rect.origin.x)),
            y: max(0, min(1, rect.origin.y)),
            width: max(0, min(1, rect.size.width)),
            height: max(0, min(1, rect.size.height))
        )
        let maxX = min(1, sanitized.maxX)
        let maxY = min(1, sanitized.maxY)
        let finalRect = CGRect(
            x: sanitized.minX,
            y: sanitized.minY,
            width: max(0, maxX - sanitized.minX),
            height: max(0, maxY - sanitized.minY)
        )
        guard finalRect.width >= minimumExtent, finalRect.height >= minimumExtent else { return nil }
        return finalRect
    }
    
    private func pixelRect(for normalizedRect: CGRect, image: UIImage) -> CGRect {
        let width = image.size.width
        let height = image.size.height
        return CGRect(
            x: normalizedRect.origin.x * width,
            y: normalizedRect.origin.y * height,
            width: normalizedRect.size.width * width,
            height: normalizedRect.size.height * height
        )
    }
    
    private func cropImage(_ image: UIImage, to normalizedRect: CGRect) -> UIImage? {
        let normalizedImage = normalizedUpImage(from: image)
        let rect = pixelRect(for: normalizedRect, image: normalizedImage).integral
        guard rect.width > 1, rect.height > 1, let cg = normalizedImage.cgImage else { return nil }
        guard let cropped = cg.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped, scale: normalizedImage.scale, orientation: .up)
    }
    
    private func normalizedUpImage(from image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
    
    private func makeOverlayData(for tag: ImageDetailAITag, rect: CGRect, note: String?, in image: UIImage) -> ImageTagFocusOverlayData? {
        guard let clamped = normalizedClampedRect(rect) else { return nil }
        guard let crop = cropImage(image, to: clamped) else { return nil }
        return ImageTagFocusOverlayData(tag: tag, normalizedRect: clamped, croppedImage: crop, note: note)
    }
    
    private func makeHighlightSelection(for tag: ImageDetailAITag, in image: UIImage) -> HighlightSelectionData? {
        guard tag.category == "Brand" else { return nil }
        
        var note: String?
        var focus = normalizedClampedRect(tag.focusRect ?? .zero)
        
        if focus == nil {
            let brandEntities = (self.image.brands as? Set<BrandEntity>) ?? []
            if let exact = brandEntities.first(where: { ($0.name ?? "").caseInsensitiveCompare(tag.label) == .orderedSame }) {
                let rect = CGRect(x: exact.boundingBoxX, y: exact.boundingBoxY, width: exact.boundingBoxWidth, height: exact.boundingBoxHeight)
                focus = normalizedClampedRect(rect)
            }
        }
        
        if focus == nil {
            if let cached = liveTagFocusCache[tag.id] {
                focus = normalizedClampedRect(cached.0)
                note = cached.1
            }
        }
        
        guard let clamped = normalizedClampedRect(focus ?? .zero) else { return nil }
        return HighlightSelectionData(tag: tag, normalizedRect: clamped, note: note)
    }
    
    private func topLeftRect(fromVision rect: CGRect) -> CGRect {
        CGRect(x: rect.origin.x, y: 1 - rect.origin.y - rect.height, width: rect.width, height: rect.height)
    }
    
    /// Thin Vision word ranges can degenerate into near-zero thickness in UI coords; widen slightly if needed (e.g. "ASUS").
    private func ensureMinimumHighlightExtentIfNeeded(_ rect: CGRect) -> CGRect {
        let minW: CGFloat = 0.024
        let minH: CGFloat = 0.018
        guard rect.width < minW || rect.height < minH else { return rect }
        let cx = rect.midX
        let cy = rect.midY
        let nw = max(rect.width, minW)
        let nh = max(rect.height, minH)
        var x = cx - nw / 2
        var y = cy - nh / 2
        x = min(max(0, x), 1 - nw)
        y = min(max(0, y), 1 - nh)
        return CGRect(x: x, y: y, width: min(nw, 1 - x), height: min(nh, 1 - y))
    }
    
    private func highlightRectFromVisionObservation(
        _ observation: VNRecognizedTextObservation,
        top: VNRecognizedText,
        matchRange: Range<String.Index>
    ) -> CGRect? {
        let lineTL = topLeftRect(fromVision: observation.boundingBox)
        guard let wordObservation = try? top.boundingBox(for: matchRange) else {
            return lineTL
        }
        let lineBox = observation.boundingBox
        let wr = wordObservation.boundingBox
        let absolute = CGRect(
            x: lineBox.minX + lineBox.width * wr.minX,
            y: lineBox.minY + lineBox.height * wr.minY,
            width: lineBox.width * wr.width,
            height: lineBox.height * wr.height
        )
        var rect = topLeftRect(fromVision: absolute)
        if rect.width < 0.02 || rect.height < 0.015 {
            rect = lineTL
        }
        return ensureMinimumHighlightExtentIfNeeded(rect)
    }
    
    private func bestVisionTextMatchRect(cgImage: CGImage, normalizedLabel: String) -> CGRect? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            var candidates: [CGRect] = []
            let observations = (request.results ?? []).compactMap { $0 as? VNRecognizedTextObservation }
            for obs in observations {
                guard let top = obs.topCandidates(1).first else { continue }
                let line = top.string
                guard let range = line.range(of: normalizedLabel, options: [.caseInsensitive]) else { continue }
                if let r = highlightRectFromVisionObservation(obs, top: top, matchRange: range) {
                    candidates.append(r)
                }
            }
            return candidates.min(by: { $0.width * $0.height < $1.width * $1.height })
        } catch {
            return nil
        }
    }
    
    private func resolveLiveFocusRect(for tag: ImageDetailAITag, image: UIImage, completion: @escaping ((CGRect, String?)?) -> Void) {
        guard tag.category == "Brand" else {
            completion(nil)
            return
        }
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        func finish(_ value: (CGRect, String?)?) {
            DispatchQueue.main.async {
                completion(value)
            }
        }
        
        let normalizedLabel = tag.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        GoogleVisionService.shared.detectTightBrandHighlight(in: image, brandName: tag.label) { apiRect in
            if let apiRect {
                let adjusted = self.ensureMinimumHighlightExtentIfNeeded(apiRect)
                finish((adjusted, nil))
                return
            }
            GoogleVisionService.shared.detectLabelsAndLogos(in: image) { result in
                switch result {
                case .success(let (brands, _)):
                    if let exact = brands.first(where: { $0.brandName.caseInsensitiveCompare(tag.label) == .orderedSame }),
                       let rect = exact.boundingBox {
                        finish((self.ensureMinimumHighlightExtentIfNeeded(rect), nil))
                    } else {
                        self.resolveTextFallback(cgImage: cgImage, normalizedLabel: normalizedLabel) { textFallback in
                            if let textFallback {
                                finish((textFallback, "Highlighting matched logo text."))
                            } else {
                                self.resolveSaliencyFallback(cgImage: cgImage, tagLabel: tag.label) { fallback in
                                    finish(fallback)
                                }
                            }
                        }
                    }
                case .failure:
                    self.resolveTextFallback(cgImage: cgImage, normalizedLabel: normalizedLabel) { textFallback in
                        if let textFallback {
                            finish((textFallback, "Highlighting matched logo text."))
                        } else {
                            self.resolveSaliencyFallback(cgImage: cgImage, tagLabel: tag.label) { fallback in
                                finish(fallback)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func resolveTextFallback(cgImage: CGImage, normalizedLabel: String, completion: @escaping (CGRect?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let match = self.bestVisionTextMatchRect(cgImage: cgImage, normalizedLabel: normalizedLabel)
                .map { self.ensureMinimumHighlightExtentIfNeeded($0) }
            DispatchQueue.main.async { completion(match) }
        }
    }
    
    private func resolveSaliencyFallback(cgImage: CGImage, tagLabel: String, completion: @escaping ((CGRect, String?)?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNGenerateAttentionBasedSaliencyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                guard let observation = request.results?.first as? VNSaliencyImageObservation,
                      let primary = observation.salientObjects?.first else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                let rect = self.topLeftRect(fromVision: primary.boundingBox)
                DispatchQueue.main.async {
                    completion((rect, "Showing best visual match for '\(tagLabel)'."))
                }
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    private func showNotice(_ text: String) {
        noticeText = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            if noticeText == text {
                noticeText = nil
            }
        }
    }
    
    private func onTapTag(_ tag: ImageDetailAITag, sourceImage: UIImage) {
        if tag.category != "Brand" {
            highlightSelection = nil
            selectedTagOverlay = nil
            return
        }
        
        if highlightSelection?.tag.id == tag.id {
            highlightSelection = nil
            selectedTagOverlay = nil
            return
        }
        
        highlightSelection = nil
        selectedTagOverlay = nil
        
        if let base = makeHighlightSelection(for: tag, in: sourceImage) {
            highlightSelection = base
            return
        }
        
        isResolvingTagFocus = true
        resolveLiveFocusRect(for: tag, image: sourceImage) { resolved in
            isResolvingTagFocus = false
            guard let resolved else {
                highlightSelection = nil
                selectedTagOverlay = nil
                showNotice("Unable to resolve an exact highlight for this tag.")
                return
            }
            liveTagFocusCache[tag.id] = resolved
            if let updated = makeHighlightSelection(for: tag, in: sourceImage) {
                highlightSelection = updated
            } else {
                highlightSelection = nil
                selectedTagOverlay = nil
                showNotice("Unable to resolve an exact highlight for this tag.")
            }
        }
    }
    
    /// Horizontal strip only shows detected brand tags; otherwise stays empty.
    private var photoStripTags: [ImageDetailAITag] {
        let map = buildAITagCategoryMap()
        return map["brand"] ?? []
    }
    
    /// Grouped sections for the sheet (one header per category).
    private var aiTagSheetSections: [AITagCategorySection] {
        let map = buildAITagCategoryMap()
        return Self.aiCategoryPriority.compactMap { title in
            let tags = map[title.lowercased()] ?? []
            guard !tags.isEmpty else { return nil }
            return AITagCategorySection(id: title, title: title, tags: tags)
        }
    }
    
    private var selectedTagId: String? {
        highlightSelection?.tag.id
    }
    
    private var aiTagSheetTotalCount: Int {
        aiTagSheetSections.reduce(0) { $0 + $1.tags.count }
    }
    
    private var canExploreProducts: Bool {
        image.isIndexed
            || !((image.labels as? Set<LabelEntity>) ?? []).isEmpty
            || !((image.brands as? Set<BrandEntity>) ?? []).isEmpty
            || !((image.objects as? Set<ObjectEntity>) ?? []).isEmpty
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
    
    private func resetZoomAnimatedForPaging() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            detailMagnification = 1
            detailMagnificationBase = 1
            detailPan = .zero
            detailPanBase = .zero
        }
        onZoomStateChanged?(false)
    }
    
    private func detailMagnifyGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                detailMagnification = min(4.0, max(1.0, detailMagnificationBase * value))
            }
            .onEnded { _ in
                detailMagnificationBase = detailMagnification
                if detailMagnification <= 1.02 {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                        detailMagnification = 1
                        detailMagnificationBase = 1
                        detailPan = .zero
                        detailPanBase = .zero
                    }
                    onZoomStateChanged?(false)
                } else {
                    onZoomStateChanged?(true)
                }
            }
    }
    
    private func detailPanGesture() -> some Gesture {
        DragGesture()
            .onChanged { g in
                guard detailMagnification > 1.02 else { return }
                detailPan = CGSize(width: detailPanBase.width + g.translation.width, height: detailPanBase.height + g.translation.height)
            }
            .onEnded { _ in
                detailPanBase = detailPan
            }
    }
    
    /// When zoomed in the pager, swipe horizontally from the screen edges to change photo (full-width paging is disabled while zoomed).
    private func zoomedPagerEdgeStrip(isLeading: Bool, onSwipeRecognized: @escaping () -> Void) -> some View {
        let stripeWidth: CGFloat = 56
        return Color.clear
            .frame(width: stripeWidth)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 28)
                    .onEnded { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        guard abs(dx) > CGFloat(48), abs(dx) > abs(dy) * CGFloat(1.2) else { return }
                        if isLeading, dx > 0 {
                            onSwipeRecognized()
                        }
                        if !isLeading, dx < 0 {
                            onSwipeRecognized()
                        }
                    }
            )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                GeometryReader { geo in
                    if let filePath = image.filePath,
                       let uiImage = ImageStorageManager.shared.loadImage(from: filePath) {
                        let imageSize = uiImage.size
                        let fittedScale = min(geo.size.width / max(1, imageSize.width), geo.size.height / max(1, imageSize.height))
                        let fittedWidth = imageSize.width * fittedScale
                        let fittedHeight = imageSize.height * fittedScale
                        let fittedRect = CGRect(
                            x: (geo.size.width - fittedWidth) / 2,
                            y: (geo.size.height - fittedHeight) / 2,
                            width: fittedWidth,
                            height: fittedHeight
                        )
                        
                        ZStack {
                            ZStack {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .onAppear { displayedImage = uiImage }
                                    .onChange(of: filePath) { _, _ in
                                        displayedImage = uiImage
                                        selectedTagOverlay = nil
                                        detailMagnification = 1
                                        detailMagnificationBase = 1
                                        detailPan = .zero
                                        detailPanBase = .zero
                                        onZoomStateChanged?(false)
                                    }
                                
                                if let highlight = highlightSelection {
                                    let rect = highlight.normalizedRect
                                    Rectangle()
                                        .stroke(Color.yellow, lineWidth: 2)
                                        .background(
                                            Rectangle()
                                                .fill(Color.yellow.opacity(0.16))
                                        )
                                        .frame(width: fittedRect.width * rect.width, height: fittedRect.height * rect.height)
                                        .position(
                                            x: fittedRect.minX + (fittedRect.width * rect.minX) + (fittedRect.width * rect.width / 2),
                                            y: fittedRect.minY + (fittedRect.height * rect.minY) + (fittedRect.height * rect.height / 2)
                                        )
                                        .allowsHitTesting(false)
                                    
                                    Group {
                                        if isResolvingTagFocus {
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                                .tint(.white)
                                        } else {
                                            Button {
                                                if let data = makeOverlayData(for: highlight.tag, rect: highlight.normalizedRect, note: highlight.note, in: uiImage) {
                                                    selectedTagOverlay = data
                                                } else {
                                                    showNotice("Could not crop this section.")
                                                }
                                            } label: {
                                                HStack(spacing: 5) {
                                                    Image(systemName: "crop")
                                                        .font(.caption.weight(.semibold))
                                                    Text("Crop")
                                                        .font(.caption.weight(.semibold))
                                                }
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 7)
                                                .foregroundStyle(.white)
                                                .background(Capsule().fill(Color.blue.opacity(0.92)))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .position(x: fittedRect.maxX - 44, y: fittedRect.minY + 18)
                                    .transition(.opacity)
                                    .zIndex(3)
                                }
                            }
                            .frame(width: geo.size.width, height: geo.size.height)
                            .scaleEffect(detailMagnification)
                            .offset(detailPan)
                            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: detailMagnification)
                            .animation(.spring(response: 0.38, dampingFraction: 0.88), value: detailPan)
                            .simultaneousGesture(detailMagnifyGesture())
                            .simultaneousGesture(
                                detailPanGesture(),
                                including: detailMagnification > 1.02 ? .all : .subviews
                            )
                            
                            if let overlay = selectedTagOverlay {
                                Color.black.opacity(0.58)
                                    .ignoresSafeArea()
                                    .onTapGesture {
                                        selectedTagOverlay = nil
                                    }
                                    .zIndex(6)
                                
                                VStack {
                                    Spacer(minLength: 20)
                                    ImageTagFocusOverlayCard(data: overlay) {
                                        selectedTagOverlay = nil
                                    }
                                    .frame(maxHeight: geo.size.height * 0.9)
                                    Spacer(minLength: 20)
                                }
                                .zIndex(7)
                            }
                            
                            if let noticeText {
                                VStack {
                                    Spacer().frame(height: max(14, fittedRect.minY + 12))
                                    Text(noticeText)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.black.opacity(0.68))
                                        )
                                    Spacer()
                                }
                                .transition(.opacity)
                                .zIndex(9)
                            }
                            
                            if image.isFromGallery {
                                VStack {
                                    HStack {
                                        GallerySourceBadge()
                                        Spacer()
                                    }
                                    Spacer()
                                }
                                .padding(.top, 8)
                                .padding(.leading, 12)
                                .zIndex(4)
                            }
                            
                            if aiTagSheetTotalCount > 0 && showLabelsOnPhoto {
                                ImageDetailAITagsPhotoOverlay(
                                    stripTags: photoStripTags,
                                    totalTagCount: aiTagSheetTotalCount,
                                    onViewAll: { showAITagsSheet = true },
                                    onSelectTag: { tag in
                                        onTapTag(tag, sourceImage: uiImage)
                                    },
                                    selectedTagId: selectedTagId
                                )
                            }
                            
                            if detailMagnification > 1.02, onRequestAdjacentPage != nil {
                                HStack(spacing: 0) {
                                    zoomedPagerEdgeStrip(isLeading: true) {
                                        resetZoomAnimatedForPaging()
                                        onRequestAdjacentPage?(-1)
                                    }
                                    Spacer(minLength: 0)
                                    zoomedPagerEdgeStrip(isLeading: false) {
                                        resetZoomAnimatedForPaging()
                                        onRequestAdjacentPage?(1)
                                    }
                                }
                                .frame(width: geo.size.width, height: geo.size.height)
                                .allowsHitTesting(true)
                                .zIndex(12)
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            "No Preview",
                            systemImage: "photo",
                            description: Text("This image could not be loaded.")
                        )
                        .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.85), value: selectedTagOverlay?.tag.id)
                
                if isDeleting {
                    ZStack {
                        Color.black.opacity(0.28)
                            .ignoresSafeArea()
                        CapsuleLoaderOverlay(title: "Deleting photo")
                    }
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
            .navigationTitle("Image Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if aiTagSheetTotalCount > 0 {
                            Button {
                                showLabelsOnPhoto.toggle()
                            } label: {
                                Image(systemName: showLabelsOnPhoto ? "eye" : "eye.slash")
                            }
                            .foregroundStyle(.white.opacity(0.95))
                            .accessibilityLabel(showLabelsOnPhoto ? "Hide labels on photo" : "Show labels on photo")
                        }
                        if canExploreProducts {
                            Button {
                                showExploreProducts = true
                            } label: {
                                Label("Explore Products", systemImage: "bag")
                            }
                            .foregroundStyle(.cyan.opacity(0.95))
                            .labelStyle(.iconOnly)
                            .accessibilityLabel("Explore Products")
                        }
                        if aiTagSheetTotalCount > 0 {
                            Button {
                                showAITagsSheet = true
                            } label: {
                                Label("AI Tags", systemImage: "sparkles")
                            }
                            .foregroundStyle(.yellow)
                            .labelStyle(.iconOnly)
                            .accessibilityLabel("Open AI tags")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .foregroundStyle(.red.opacity(0.9))
                        .disabled(isDeleting)
                    }
                }
            }
            .sheet(isPresented: $showExploreProducts) {
                ExploreProductsView(image: image)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
            .sheet(isPresented: $showAITagsSheet) {
                ImageDetailAITagsSheet(
                    sections: aiTagSheetSections,
                    onSelectTag: { tag in
                        if let sourceImage = displayedImage {
                            onTapTag(tag, sourceImage: sourceImage)
                        }
                    },
                    selectedTagId: selectedTagId
                )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
                    .presentationCornerRadius(28)
                    .presentationBackgroundInteraction(.disabled)
            }
            .onChange(of: detailMagnification) { _, newValue in
                onZoomStateChanged?(newValue > 1.02)
            }
            .onAppear {
                onZoomStateChanged?(detailMagnification > 1.02)
            }
            .onDisappear {
                onZoomStateChanged?(false)
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
                    onDelete?()
                    if dismissAfterDelete {
                        presentationMode.wrappedValue.dismiss()
                    }
                } else {
                    deleteError = error ?? "Failed to delete image"
                }
            }
        }
    }
}

/// Drives `.sheet(item:)` so the detail view is built only when Core Data identity is wired (fixes blank sheets from `isPresented` timing).
private struct SearchImageSheetItem: Identifiable {
    /// Stable opaque identity for SwiftUI transitions.
    let id: NSManagedObjectID
}

private struct SearchResultImageDetailHost: View {
    let managedObjectID: NSManagedObjectID
    let onDeleted: () -> Void
    
    var body: some View {
        Group {
            if let entity = resolveImageEntity() {
                ImageDetailView(image: entity, onDelete: {
                    onDeleted()
                })
            } else {
                NavigationStack {
                    ContentUnavailableView(
                        "Couldn’t open photo",
                        systemImage: "exclamationmark.triangle",
                        description: Text("This image may no longer be available.")
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
    }
    
    @Environment(\.dismiss) private var dismiss
    
    private func resolveImageEntity() -> ImageEntity? {
        let ctx = UserManager.shared.viewContext
        do {
            let obj = try ctx.existingObject(with: managedObjectID)
            guard !obj.isDeleted else { return nil }
            return obj as? ImageEntity
        } catch {
            return nil
        }
    }
}

struct SearchResultsView: View {
    let results: [ImageEntity]
    let searchText: String
    var onDelete: (() -> Void)? = nil
    @State private var searchDetailSheetItem: SearchImageSheetItem?
    
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
                    ForEach(results, id: \.objectID) { image in
                        ImageThumbnailCard(
                            image: image,
                            onTap: {
                                searchDetailSheetItem = SearchImageSheetItem(id: image.objectID)
                            },
                            onDelete: onDelete
                        )
                    }
                }
                .padding()
            }
        }
        .sheet(item: $searchDetailSheetItem) { item in
            SearchResultImageDetailHost(managedObjectID: item.id) {
                onDelete?()
                searchDetailSheetItem = nil
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
                    .onChange(of: text) { _, newValue in
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

