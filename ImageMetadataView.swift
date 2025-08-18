import SwiftUI

struct ImageMetadataView: View {
    let image: UIImage
    let metadata: [String: Any]
    @Environment(\.presentationMode) var presentationMode
    
    func formatValue(_ value: Any) -> String {
        if let dict = value as? [String: Any] {
            return dict.description
        }
        return "\(value)"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom)
                
                ForEach(Array(metadata.keys.sorted()), id: \.self) { key in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(key)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(formatValue(metadata[key]!))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                }
            }
        }
        .navigationBarTitle("Image Metadata", displayMode: .inline)
        .navigationBarItems(trailing: Button("Done") {
            presentationMode.wrappedValue.dismiss()
        })
    }
}

#Preview {
    ImageMetadataView(
        image: UIImage(),
        metadata: [
            "Date": "2024-03-20",
            "Camera": "iPhone 15 Pro",
            "Resolution": "4032x3024"
        ]
    )
} 