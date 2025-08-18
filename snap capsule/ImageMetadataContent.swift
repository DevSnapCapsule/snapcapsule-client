import SwiftUI
import CoreLocation

struct ImageMetadataContent: View {
    let image: UIImage
    let metadata: [String: Any]
    
    var formattedMetadata: [(String, String)] {
        var result: [(String, String)] = []
        
        print("Processing metadata in ImageMetadataContent: \(metadata)")
        
        // Extract GPS info
        if let gpsInfo = metadata["{GPS}"] as? [String: Any] {
            print("Found GPS info: \(gpsInfo)")
            
            var locationFound = false
            
            // Try standard format
            if let latitudeRef = gpsInfo["LatitudeRef"] as? String,
               let latitude = gpsInfo["Latitude"] as? Double,
               let longitudeRef = gpsInfo["LongitudeRef"] as? String,
               let longitude = gpsInfo["Longitude"] as? Double {
                
                let lat = latitudeRef == "N" ? latitude : -latitude
                let lon = longitudeRef == "E" ? longitude : -longitude
                result.append(("Location", String(format: "%.6f, %.6f", lat, lon)))
                locationFound = true
            }
            // Try array format (some cameras store coordinates as arrays)
            else if let latitudeArray = gpsInfo["Latitude"] as? [Double],
                    let longitudeArray = gpsInfo["Longitude"] as? [Double],
                    let latRef = gpsInfo["LatitudeRef"] as? String,
                    let lonRef = gpsInfo["LongitudeRef"] as? String {
                
                let latitude = latitudeArray[0] + (latitudeArray[1] / 60.0) + (latitudeArray[2] / 3600.0)
                let longitude = longitudeArray[0] + (longitudeArray[1] / 60.0) + (longitudeArray[2] / 3600.0)
                
                let lat = latRef == "N" ? latitude : -latitude
                let lon = lonRef == "E" ? longitude : -longitude
                result.append(("Location", String(format: "%.6f, %.6f", lat, lon)))
                locationFound = true
            }
            // Try direct coordinate format
            else if let latitude = gpsInfo["Latitude"] as? Double,
                    let longitude = gpsInfo["Longitude"] as? Double {
                result.append(("Location", String(format: "%.6f, %.6f", latitude, longitude)))
                locationFound = true
            }
            
            if !locationFound {
                result.append(("Location", "No location data available"))
            }
            
            if let timestamp = gpsInfo["TimeStamp"] as? String,
               let datestamp = gpsInfo["DateStamp"] as? String {
                result.append(("GPS Time", "\(datestamp) \(timestamp)"))
            }
            
            // Add all GPS data for debugging
            result.append(("Raw GPS Data", "\(gpsInfo)"))
        } else {
            result.append(("Location", "No location data available - Enable Location Services when taking photos to include location information"))
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Image Information")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 8)
            
            ForEach(formattedMetadata, id: \.0) { key, value in
                VStack(alignment: .leading, spacing: 4) {
                    Text(key)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(value)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                if key != formattedMetadata.last?.0 {
                    Divider()
                        .padding(.vertical, 8)
                }
            }
        }
    }
} 