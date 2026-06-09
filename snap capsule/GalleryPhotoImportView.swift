import PhotosUI
import SwiftUI

/// Presents the system photo picker (limited access — only the photo you select is read).
struct GalleryPhotoImportView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    var onImportCompleted: (() -> Void)?

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var previewImage: UIImage?
    @State private var phase: ImportPhase = .idle
    @State private var errorPresentation: ImportErrorPresentation?

    private enum ImportPhase: Equatable {
        case idle
        case loadingPreview
        case ready
        case saving
        case success
    }

    private struct ImportErrorPresentation: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private enum ImportFailure: LocalizedError {
        case unreadableSelection
        case decodeFailed
        case fileTooLarge
        case notSignedIn
        case capsulesFull
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case .unreadableSelection:
                return "We couldn't read the photo you selected. Try choosing a different image."
            case .decodeFailed:
                return "This file doesn't appear to be a supported photo format (JPEG, PNG, or HEIC)."
            case .fileTooLarge:
                return "This photo is too large to import. Choose an image under 50 MB."
            case .notSignedIn:
                return "Sign in to save photos to your capsules."
            case .capsulesFull:
                return "Both capsules are full. Delete photos to make room for new imports."
            case .saveFailed(let detail):
                return detail
            }
        }
    }

    /// Hard cap to avoid loading unexpectedly large assets into memory.
    private static let maxImportBytes = 50 * 1024 * 1024

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(.systemGroupedBackground),
                        Color(.secondarySystemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        privacyBanner
                        onePhotoNotice
                        pickerCard
                        previewSection
                        importButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }

                if phase == .saving {
                    savingOverlay
                }

                if phase == .success {
                    successOverlay
                }
            }
            .navigationTitle("Import Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(phase == .saving)
                }
            }
            .onChange(of: selectedItems) { _, newItems in
                Task { await handleSelectionChange(newItems.first) }
            }
            .alert(item: $errorPresentation) { error in
                Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .interactiveDismissDisabled(phase == .saving)
    }

    // MARK: - Sections

    private var privacyBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.title3)
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Private by design")
                    .font(.subheadline.weight(.semibold))
                Text("Snap Capsule uses Apple's photo picker. We only access the single photo you choose — never your full library.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
        )
    }

    private var onePhotoNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "1.circle.fill")
                .foregroundStyle(.purple)
            Text("One photo at a time")
                .font(.subheadline.weight(.medium))
            Spacer()
            Text("Indexed individually")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.purple.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.purple.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("One photo at a time. Each photo is indexed individually.")
    }

    private var pickerCard: some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: 1,
            matching: .images,
            photoLibrary: .shared()
        ) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.18), Color.purple.opacity(0.14)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose from Photos")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Opens the iPhone photo picker")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        }
        .disabled(phase == .saving || phase == .loadingPreview)
        .accessibilityHint("Select one photo from your library")
    }

    @ViewBuilder
    private var previewSection: some View {
        if phase == .loadingPreview {
            previewPlaceholder(title: "Loading preview…", showSpinner: true)
        } else if let previewImage {
            VStack(alignment: .leading, spacing: 10) {
                Text("Preview")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                    .accessibilityLabel("Selected photo preview")

                Button("Choose a different photo") {
                    resetSelection()
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.blue)
                .disabled(phase == .saving)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        } else {
            previewPlaceholder(title: "No photo selected yet", showSpinner: false)
        }
    }

    private func previewPlaceholder(title: String, showSpinner: Bool) -> some View {
        VStack(spacing: 12) {
            if showSpinner {
                ProgressView()
                    .progressViewStyle(.circular)
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
            }
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private var importButton: some View {
        Button {
            importSelectedPhoto()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down")
                Text("Import & Index")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: canImport ? [.blue, .purple] : [.gray.opacity(0.4), .gray.opacity(0.35)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .foregroundStyle(.white)
        }
        .disabled(!canImport)
        .accessibilityHint(canImport ? "Save photo to capsule and start AI indexing" : "Select a photo first")
    }

    private var canImport: Bool {
        previewImage != nil && phase == .ready
    }

    // MARK: - Overlays

    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.15)
                Text("Saving & indexing…")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Text("AI analysis starts automatically")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .transition(.opacity)
    }

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: phase == .success)
                Text("Photo imported")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Indexing in progress")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .transition(.opacity)
    }

    // MARK: - Actions

    @MainActor
    private func handleSelectionChange(_ item: PhotosPickerItem?) async {
        guard let item else {
            previewImage = nil
            phase = .idle
            return
        }

        phase = .loadingPreview
        previewImage = nil

        do {
            let image = try await loadImage(from: item)
            previewImage = image
            withAnimation(.easeOut(duration: 0.25)) {
                phase = .ready
            }
        } catch {
            phase = .idle
            selectedItems = []
            presentError(title: "Couldn't load photo", error: error)
        }
    }

    private func loadImage(from item: PhotosPickerItem) async throws -> UIImage {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw ImportFailure.unreadableSelection
        }

        guard data.count <= Self.maxImportBytes else {
            throw ImportFailure.fileTooLarge
        }

        guard let raw = UIImage(data: data) else {
            throw ImportFailure.decodeFailed
        }

        return raw.normalizedForImageProcessing()
    }

    private func importSelectedPhoto() {
        guard let image = previewImage else { return }

        if !networkMonitor.isConnected {
            presentError(
                title: "No Internet Connection",
                message: "AI indexing needs a connection. You can import when you're back online."
            )
            return
        }

        phase = .saving

        AlbumManager.shared.addImageToAvailableCapsule(image: image, importSource: .gallery) { success, errorMessage in
            DispatchQueue.main.async {
                if success {
                    withAnimation {
                        phase = .success
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        onImportCompleted?()
                        dismiss()
                    }
                } else {
                    phase = .ready
                    presentError(
                        title: "Import failed",
                        message: errorMessage ?? "Something went wrong while saving your photo."
                    )
                }
            }
        }
    }

    private func resetSelection() {
        selectedItems = []
        previewImage = nil
        phase = .idle
    }

    private func presentError(title: String, error: Error) {
        presentError(title: title, message: error.localizedDescription)
    }

    private func presentError(title: String, message: String) {
        errorPresentation = ImportErrorPresentation(title: title, message: message)
    }
}

#Preview {
    GalleryPhotoImportView()
}
