import SwiftUI
import SafariServices

struct BrandDetectionView: View {
    let brands: [BrandDetectionResult]
    let productInfo: ProductInfo?
    
    init(brands: [BrandDetectionResult], productInfo: ProductInfo? = nil) {
        self.brands = brands
        self.productInfo = productInfo
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("Detected Brands")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            if brands.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No brands detected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("This image doesn't contain any recognizable brand logos")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(brands.enumerated()), id: \.offset) { index, brand in
                        BrandCard(brand: brand)
                    }
                }
            }
            
            // Explore Similar Products Button
            if let productInfo = productInfo {
                if productInfo.isValid {
                    ExploreSimilarProductsButton(productInfo: productInfo)
                        .padding(.top, 8)
                } else {
                    // Debug: Show why button isn't appearing
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Debug Info:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Brand: \(productInfo.brand ?? "nil")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Product: \(productInfo.product ?? "nil")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Valid: \(productInfo.isValid ? "Yes" : "No")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(8)
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
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
    }
}

struct BrandCard: View {
    let brand: BrandDetectionResult
    
    var body: some View {
        HStack(spacing: 12) {
            // Brand icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "tag.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
            
            // Brand information
            VStack(alignment: .leading, spacing: 4) {
                Text(brand.brandName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack {
                    Text("Confidence:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(brand.confidence * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(confidenceColor)
                }
                
                if let boundingBox = brand.boundingBox {
                    Text("Position: \(Int(boundingBox.origin.x)), \(Int(boundingBox.origin.y))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Confidence indicator
            VStack {
                Circle()
                    .fill(confidenceColor)
                    .frame(width: 12, height: 12)
                
                Text("\(Int(brand.confidence * 100))%")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(confidenceColor)
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
                                Color.white.opacity(0.25),
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
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.15)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
    }
    
    private var confidenceColor: Color {
        if brand.confidence >= 0.8 {
            return .green
        } else if brand.confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Explore Similar Products Button
struct ExploreSimilarProductsButton: View {
    let productInfo: ProductInfo
    @State private var isPressed = false
    @State private var showSafari = false
    @State private var safariURL: URL?
    
    var body: some View {
        Button(action: {
            openProductSearch()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Explore Similar Products")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(buildSearchDescription())
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
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
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .sheet(isPresented: $showSafari) {
            if let safariURL = safariURL {
                SafariView(url: safariURL)
            }
        }
    }
    
    private func buildSearchDescription() -> String {
        var parts: [String] = []
        // Gender is optional - include if available
        if let gender = productInfo.gender {
            parts.append(gender.capitalized)
        }
        // Brand is required
        if let brand = productInfo.brand {
            parts.append(brand)
        }
        // Product is required
        if let product = productInfo.product {
            parts.append(product)
        }
        
        // If no parts, return a default message
        if parts.isEmpty {
            return "Similar products"
        }
        
        return parts.joined(separator: " • ")
    }
    
    private func openProductSearch() {
        guard let url = ProductAnalyzer.shared.generateSearchURL(for: productInfo) else {
            print("❌ Failed to generate search URL")
            return
        }
        
        // Open in Safari
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            print("❌ Cannot open URL: \(url)")
            // Fallback to in-app SafariViewController (often works better on Simulator)
            safariURL = url
            showSafari = true
        }
    }
}

// MARK: - SafariView (SFSafariViewController wrapper)
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    BrandDetectionView(
        brands: [
            BrandDetectionResult(
                brandName: "Nike",
                confidence: 0.95,
                boundingBox: CGRect(x: 100, y: 50, width: 200, height: 100)
            ),
            BrandDetectionResult(
                brandName: "Apple",
                confidence: 0.75,
                boundingBox: CGRect(x: 300, y: 150, width: 150, height: 80)
            )
        ],
        productInfo: ProductInfo(gender: "men", brand: "Nike", product: "shoe")
    )
}
