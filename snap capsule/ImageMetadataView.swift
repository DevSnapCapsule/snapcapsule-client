import SwiftUI

struct ImageMetadataView: View {
    let image: UIImage
    let metadata: [String: Any]
    @Environment(\.presentationMode) var presentationMode
    
    func formatValue(_ value: Any) -> String {
        if let dict = value as? [String: Any] {
            var formattedString = ""
            dict.forEach { key, value in
                formattedString += "\(key): \(value)\n"
            }
            return formattedString
        } else if let date = value as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .medium
            return formatter.string(from: date)
        }
        return "\(value)"
    }
    
    var formattedMetadata: [(String, String)] {
        var result: [(String, String)] = []
        
        // Extract GPS info
        if let gpsInfo = metadata["{GPS}"] as? [String: Any] {
            if let latitudeRef = gpsInfo["LatitudeRef"] as? String,
               let latitude = gpsInfo["Latitude"] as? Double,
               let longitudeRef = gpsInfo["LongitudeRef"] as? String,
               let longitude = gpsInfo["Longitude"] as? Double {
                
                let lat = latitudeRef == "N" ? latitude : -latitude
                let lon = longitudeRef == "E" ? longitude : -longitude
                result.append(("Location", String(format: "%.6f, %.6f", lat, lon)))
            }
            
            if let timestamp = gpsInfo["TimeStamp"] as? String,
               let datestamp = gpsInfo["DateStamp"] as? String {
                result.append(("GPS Time", "\(datestamp) \(timestamp)"))
            }
        }
        
        // Extract basic EXIF info
        if let exif = metadata["{Exif}"] as? [String: Any] {
            if let dateTime = exif["DateTimeOriginal"] as? String {
                result.append(("Date Taken", dateTime))
            }
            if let exposure = exif["ExposureTime"] as? Double {
                result.append(("Exposure Time", "\(exposure) sec"))
            }
            if let fNumber = exif["FNumber"] as? Double {
                result.append(("F-Number", "f/\(fNumber)"))
            }
            if let iso = exif["ISOSpeedRatings"] as? Int {
                result.append(("ISO", "\(iso)"))
            }
            if let focalLength = exif["FocalLength"] as? Double {
                result.append(("Focal Length", "\(focalLength)mm"))
            }
        }
        
        // Extract TIFF info
        if let tiff = metadata["{TIFF}"] as? [String: Any] {
            if let make = tiff["Make"] as? String {
                result.append(("Camera Make", make))
            }
            if let model = tiff["Model"] as? String {
                result.append(("Camera Model", model))
            }
            if let software = tiff["Software"] as? String {
                result.append(("Software", software))
            }
        }
        
        // Add image dimensions
        if let width = metadata["PixelWidth"] as? Int,
           let height = metadata["PixelHeight"] as? Int {
            result.append(("Dimensions", "\(width) × \(height)"))
        }
        
        // Add file size
        if let imageData = image.jpegData(compressionQuality: 1.0) {
            let size = Double(imageData.count) / 1024.0 / 1024.0 // Convert to MB
            result.append(("File Size", String(format: "%.2f MB", size)))
        }
        
        return result
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom)
                
                ForEach(formattedMetadata, id: \.0) { key, value in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(key)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(value)
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

#if DEBUG
struct ImageMetadataView_Previews: PreviewProvider {
    static var previews: some View {
        ImageMetadataView(
            image: UIImage(),
            metadata: [
                "{GPS}": [
                    "LatitudeRef": "N",
                    "Latitude": 37.7749,
                    "LongitudeRef": "W",
                    "Longitude": 122.4194,
                    "TimeStamp": "12:00:00",
                    "DateStamp": "2024:03:20"
                ],
                "{Exif}": [
                    "DateTimeOriginal": "2024:03:20 12:00:00",
                    "ExposureTime": 1/1000,
                    "FNumber": 2.8,
                    "ISOSpeedRatings": 100,
                    "FocalLength": 28
                ],
                "{TIFF}": [
                    "Make": "Apple",
                    "Model": "iPhone 15 Pro",
                    "Software": "iOS 17.0"
                ],
                "PixelWidth": 4032,
                "PixelHeight": 3024
            ]
        )
    }
}
#endif 