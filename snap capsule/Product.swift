import Foundation

struct Product: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let price: Double?
    let currency: String?
    let imageUrl: String?
    let buyUrl: String?
    let seller: String?
    let condition: String?
    let source: String?

    var formattedPrice: String {
        guard let price, price > 0 else {
            return "Price unavailable"
        }
        let code = currency ?? "USD"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: price)) ?? String(format: "%.2f %@", price, code)
    }

    var buyURL: URL? {
        guard let buyUrl, let url = URL(string: buyUrl) else { return nil }
        return url
    }

    var imageURL: URL? {
        guard let imageUrl, let url = URL(string: imageUrl) else { return nil }
        return url
    }
}
