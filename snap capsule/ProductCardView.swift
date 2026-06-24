import SwiftUI

struct ProductCardView: View {
    let product: Product
    /// Invoked only by the "View on eBay" button — the card itself is not tappable.
    let onViewOnEbay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            productImage
            title
            price
            metadata
            Spacer(minLength: 0)
            viewOnEbayButton
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }

    // MARK: - Image

    private var productImage: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let url = product.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ShimmerPlaceholder()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            imageFallback
                        @unknown default:
                            imageFallback
                        }
                    }
                } else {
                    imageFallback
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var imageFallback: some View {
        ZStack {
            Color.white.opacity(0.08)
            Image(systemName: "photo")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Text

    private var title: some View {
        Text(product.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)
    }

    private var price: some View {
        Text(product.formattedPrice)
            .font(.headline.weight(.bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.cyan.opacity(0.95), Color.blue.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metadata: some View {
        HStack(spacing: 6) {
            if let condition = product.condition, !condition.isEmpty {
                Text(condition)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.black.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.85)))
            }

            if let seller = product.seller, !seller.isEmpty {
                Text(seller)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Action

    private var viewOnEbayButton: some View {
        Button(action: onViewOnEbay) {
            HStack(spacing: 4) {
                Text("View on eBay")
                    .font(.caption2.weight(.semibold))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.75), Color.purple.opacity(0.65)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
    }
}

// MARK: - Shimmer placeholder

struct ShimmerPlaceholder: View {
    @State private var animate = false

    var body: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.14),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: animate ? geo.size.width : -geo.size.width * 0.6)
                }
            }
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    animate = true
                }
            }
    }
}
