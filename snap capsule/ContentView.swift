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
                VStack(spacing: 0) {
                    // Content area
                    ZStack {
                        switch selectedTab {
                        case 0:
                            // Home/Search view
                            VStack(spacing: 0) {
                                SearchBar(text: $searchText, onSearch: performSearch)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, y: 2)
                                
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
                    
                    // Footer Menu
                    VStack(spacing: 0) {
                        Divider()
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
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0.8),
                                    Color.black.opacity(0.9)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
            }
            .navigationBarTitle(navigationTitle, displayMode: .inline)
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
    
    var body: some View {
        HStack {
            TextField("AI Search..", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .onSubmit(onSearch)
            
            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
            }
        }
    }
}

struct SearchResultsList: View {
    let results: [ImageSearchResult]
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(results, id: \.imageId) { result in
                VStack(alignment: .leading) {
                    Text(result.matchedText)
                        .font(.headline)
                    Text(result.timestamp, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let address = getAddressFromLocation(result.location) {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                Divider()
            }
        }
        .padding(.top)
    }
    
    private func getAddressFromLocation(_ location: CLLocation) -> String? {
        // In a real app, you would use CLGeocoder to get the address
        // For now, we'll just return the coordinates
        return "\(location.coordinate.latitude), \(location.coordinate.longitude)"
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            Text("No Photos Yet")
                .font(.title2)
            Text("Take some photos to get started!")
                .foregroundColor(.secondary)
        }
    }
}

struct CapsuleRepositoryView: View {
    @State private var searchText = ""
    @State private var images: [ImageItem] = []
    @State private var filteredImages: [ImageItem] = []
    @State private var isSearching = false
    @State private var selectedSearchFilter: SearchFilter = .all
    @State private var showingSearchSuggestions = false
    @State private var searchSuggestions: [String] = []
    @State private var isLoading = true
    
    // Custom colors
    private let backgroundColor = Color(red: 0.95, green: 0.95, blue: 0.97)
    private let cardBackground = Color(red: 1, green: 1, blue: 1).opacity(0.8)
    
    // Sample search suggestions based on categories
    private let searchCategories: [SearchCategory] = [
        SearchCategory(icon: "mappin.circle.fill", name: "Locations", examples: ["Beach", "Mountains", "City"]),
        SearchCategory(icon: "car.fill", name: "Objects", examples: ["Car", "Bus", "Statue"]),
        SearchCategory(icon: "tag.fill", name: "Brands", examples: ["Nike", "Puma", "Adidas"]),
        SearchCategory(icon: "face.smiling.fill", name: "People", examples: ["Smiling", "Group", "Portrait"]),
        SearchCategory(icon: "building.2.fill", name: "Places", examples: ["Landmark", "Museum", "Park"]),
        SearchCategory(icon: "calendar", name: "Time", examples: ["Last Week", "Summer 2023", "Yesterday"])
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Enhanced Search Header
            VStack(spacing: 16) {
                // Search Bar with AI indicator
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search your memories...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchText) { newValue in
                            showingSearchSuggestions = !newValue.isEmpty
                            updateSearchSuggestions(for: newValue)
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            showingSearchSuggestions = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                        .opacity(isSearching ? 1 : 0.5)
                }
                .padding(12)
                .background(cardBackground)
                .cornerRadius(15)
                .padding(.horizontal)
                
                // Search Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(SearchFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                isSelected: selectedSearchFilter == filter
                            ) {
                                selectedSearchFilter = filter
                                performSearch()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
            .background(cardBackground)
            .shadow(color: Color.black.opacity(0.05), radius: 5, y: 5)
            
            if showingSearchSuggestions && !searchText.isEmpty {
                SearchSuggestionsView(
                    categories: searchCategories,
                    onSuggestionTapped: { suggestion in
                        searchText = suggestion
                        performSearch()
                        showingSearchSuggestions = false
                    }
                )
                .background(cardBackground)
            } else {
                // Grid view with animation
                ScrollView {
                    if isLoading {
                        ProgressView("Loading photos...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 100)
                    } else if filteredImages.isEmpty {
                        EmptySearchState()
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 3),
                                GridItem(.flexible(), spacing: 3),
                                GridItem(.flexible(), spacing: 3)
                            ],
                            spacing: 3
                        ) {
                            ForEach(filteredImages) { item in
                                NavigationLink(destination: ImageDetailView(image: item)) {
                                    ImageGridItem(item: item)
                                        .aspectRatio(1, contentMode: .fill)
                                }
                            }
                        }
                        .padding(3)
                    }
                }
                .animation(.easeInOut, value: filteredImages)
            }
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            loadImages()
        }
    }
    
    private func updateSearchSuggestions(for query: String) {
        // Simulate AI generating contextual suggestions
        isSearching = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSearching = false
            // In a real app, this would call the AI backend
            searchSuggestions = searchCategories.flatMap { $0.examples }
                .filter { $0.lowercased().contains(query.lowercased()) }
        }
    }
    
    private func performSearch() {
        isSearching = true
        // Simulate search delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSearching = false
            if searchText.isEmpty {
                filteredImages = images
            } else {
                // Filter based on selected filter and search text
                filteredImages = images.filter { item in
                    let searchableText = item.metadata.values
                        .compactMap { $0 as? String }
                        .joined(separator: " ")
                        .lowercased()
                    
                    switch selectedSearchFilter {
                    case .all:
                        return searchableText.contains(searchText.lowercased())
                    case .recent:
                        // Filter for images within the last week
                        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                        return item.timestamp >= oneWeekAgo
                    case .brands:
                        // Filter for brand-related metadata
                        if let brands = item.metadata["brands"] as? [String] {
                            return brands.contains { $0.lowercased().contains(searchText.lowercased()) }
                        }
                        return false
                    case .favorites:
                        // Filter for favorited images
                        return (item.metadata["isFavorite"] as? Bool) == true
                    case .people:
                        // Filter for people-related metadata
                        if let faces = item.metadata["faces"] as? [String] {
                            return faces.contains { $0.lowercased().contains(searchText.lowercased()) }
                        }
                        return false
                    case .places:
                        // Filter for location-related metadata
                        if let location = item.metadata["location"] as? String {
                            return location.lowercased().contains(searchText.lowercased())
                        }
                        return false
                    case .objects:
                        // Filter for object-related metadata
                        if let objects = item.metadata["objects"] as? [String] {
                            return objects.contains { $0.lowercased().contains(searchText.lowercased()) }
                        }
                        return false
                    }
                }
            }
        }
    }
    
    private func loadImages() {
        isLoading = true
        
        // Get the workspace directory path
        let workspacePath = "/Users/administrator/Documents/snap capsule/images"
        print("Attempting to load images from absolute path: \(workspacePath)")
        
        let fileManager = FileManager.default
        
        do {
            // List all files in directory
            let files = try fileManager.contentsOfDirectory(atPath: workspacePath)
            print("Found files: \(files)")
            
            // Filter for image files
            let imageFiles = files.filter { file in
                let fileExtension = (file as NSString).pathExtension.lowercased()
                return ["jpg", "jpeg", "png", "heic"].contains(fileExtension)
            }.filter { !$0.hasPrefix(".") }
            
            print("Found image files: \(imageFiles)")
            
            // Process each image file
            var newImages: [ImageItem] = []
            
            for file in imageFiles {
                let fullPath = (workspacePath as NSString).appendingPathComponent(file)
                print("Loading image from: \(fullPath)")
                
                if let image = UIImage(contentsOfFile: fullPath) {
                    print("Successfully loaded image: \(file)")
                    
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
                } else {
                    print("Failed to load image: \(file)")
                }
            }
            
            print("Total images loaded: \(newImages.count)")
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.images = newImages.sorted(by: { $0.timestamp > $1.timestamp })
                self.filteredImages = self.images
                self.isLoading = false
            }
            
        } catch {
            print("Error loading images: \(error)")
            print("Attempted to load from path: \(workspacePath)")
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
}

enum SearchFilter: String, CaseIterable {
    case all = "All"
    case recent = "Recent"
    case brands = "Brands"
    case favorites = "Favorites"
    case people = "People"
    case places = "Places"
    case objects = "Objects"
}

struct SearchCategory {
    let icon: String
    let name: String
    let examples: [String]
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct SearchSuggestionsView: View {
    let categories: [SearchCategory]
    let onSuggestionTapped: (String) -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(categories, id: \.name) { category in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(.blue)
                            Text(category.name)
                                .font(.headline)
                        }
                        
                        FlowLayout(spacing: 8) {
                            ForEach(category.examples, id: \.self) { example in
                                SuggestionChip(text: example) {
                                    onSuggestionTapped(example)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemBackground))
    }
}

struct SuggestionChip: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        return CGSize(
            width: proposal.width ?? .zero,
            height: rows.last?.maxY ?? .zero
        )
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        for row in rows {
            for element in row.subviews {
                element.subview.place(
                    at: CGPoint(x: bounds.minX + element.origin.x, y: bounds.minY + row.minY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: element.size.width, height: element.size.height)
                )
            }
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row(minY: 0)
        var x: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > (proposal.width ?? .zero) {
                rows.append(currentRow)
                currentRow = Row(minY: currentRow.maxY + spacing)
                x = 0
            }
            
            currentRow.add(subview, origin: CGPoint(x: x, y: 0), size: size)
            x += size.width + spacing
        }
        
        if !currentRow.subviews.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    struct Row {
        var minY: CGFloat
        var maxY: CGFloat = 0
        var subviews: [(subview: LayoutSubview, origin: CGPoint, size: CGSize)] = []
        
        mutating func add(_ subview: LayoutSubview, origin: CGPoint, size: CGSize) {
            subviews.append((subview: subview, origin: origin, size: size))
            maxY = max(maxY, minY + size.height)
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

struct EmptySearchState: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("AI-Powered Search")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Search by location, objects, people,\nbrands, or any memory you can think of!")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 50)
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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(uiImage: image.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                
                ImageMetadataContent(image: image.image, metadata: image.metadata)
                    .padding()
                    .background(Color(red: 0.95, green: 0.93, blue: 0.90))
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FooterMenuItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? .white : .gray)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PeopleSearchBar: View {
    @Binding var text: String
    let onSearch: () -> Void
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search people...", text: $text)
                    .autocapitalization(.none)
                    .onSubmit(onSearch)
                
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
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
                .background(Color(.systemBackground))
            
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
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, y: 2)
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
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                
                Button(action: { /* Decline friend request */ }) {
                    Text("Decline")
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, y: 2)
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
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, y: 2)
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
                                    .foregroundColor(.blue)
                                Text("Location Access")
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        
                        Divider()
                            .padding(.horizontal)
                        
                        Toggle(isOn: $mediaPermission) {
                            HStack {
                                Image(systemName: "photo.fill")
                                    .foregroundColor(.blue)
                                Text("Media Access")
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                    }
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, y: 2)
                }
                
                // Subscription Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subscription")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Button(action: { showingSubscriptionSheet = true }) {
                        HStack {
                            Image(systemName: "star.circle.fill")
                                .foregroundColor(.yellow)
                            Text("Upgrade to Premium")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 2)
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
                                    .foregroundColor(.blue)
                                Text("Help & Support")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                        }
                        
                        Divider()
                            .padding(.horizontal)
                        
                        Button(action: { showingContactSheet = true }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.blue)
                                Text("Contact Us")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                        }
                        
                        Divider()
                            .padding(.horizontal)
                        
                        Button(action: { showingAboutSheet = true }) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("About Us")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                        }
                    }
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, y: 2)
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

#Preview {
    ContentView()
}
