# SnapCapsule

An AI-powered photo management iOS application that uses Google Cloud Vision API and Apple Vision Framework to intelligently analyze, organize, and search through your photo collection.

## Features

- 📸 **Smart Photo Capture**: Take photos with automatic metadata extraction
- 🔍 **AI-Powered Search**: Search your photos using natural language queries
- 🏷️ **Automatic Tagging**: Images are automatically tagged with detected objects, scenes, labels, and brands
- 📦 **Capsule Organization**: Organize photos into capsules (albums) with configurable image limits
- 🎨 **Brand Detection**: Automatically detect brands and products in images
- 💾 **Local Storage**: All data stored locally using Core Data
- 🔐 **Privacy First**: No cloud authentication required - works completely offline

## Requirements

- iOS 15.0+
- Xcode 14.0+
- CocoaPods (for dependency management)
- Google Cloud Vision API key

## Installation

### 1. Clone the Repository

```bash
git clone <repository-url>
cd "snap capsule"
```

### 2. Install Dependencies

```bash
pod install
```

### 3. Configure API Key

The app requires a Google Cloud Vision API key for image analysis. You can provide it in one of the following ways:

#### Option A: Environment Variable (Recommended for CI/CD)

```bash
export GOOGLE_VISION_API_KEY=your_api_key_here
```

#### Option B: .env File (Recommended for Local Development)

1. Create a `.env` file in the project root:
```bash
touch .env
```

2. Add your API key:
```
GOOGLE_VISION_API_KEY=your_api_key_here
```

**Note**: The `.env` file is gitignored and will not be committed to version control.

#### Option C: Secrets.plist (Legacy, Deprecated)

1. Copy the example file:
```bash
cp "snap capsule/Secrets.plist.example" "snap capsule/Secrets.plist"
```

2. Add your API key to `Secrets.plist`

**Note**: `Secrets.plist` is also gitignored for security.

### 4. Open the Workspace

```bash
open "snap capsule.xcworkspace"
```

**Important**: Always open the `.xcworkspace` file (not `.xcodeproj`) when using CocoaPods.

### 5. Build and Run

1. Select your target device or simulator
2. Press `Cmd + B` to build
3. Press `Cmd + R` to run

## Project Structure

```
snap capsule/
├── snap capsule/              # Main app source code
│   ├── SnapCapsuleApp.swift   # App entry point
│   ├── ContentView.swift      # Main UI view
│   ├── CameraView.swift       # Camera interface
│   ├── CapsuleRepositoryView.swift  # Album management
│   ├── ImageAnalyzer.swift    # Image analysis logic
│   ├── GoogleVisionService.swift    # Google Vision API integration
│   ├── MetadataManager.swift  # Core Data operations
│   ├── UserManager.swift      # User management
│   └── Assets.xcassets/       # App assets
├── snap capsuleTests/         # Unit tests
├── snap capsuleUITests/       # UI tests
├── Podfile                    # CocoaPods dependencies
└── README.md                  # This file
```

## Dependencies

- **GoogleCloudVision**: Google Cloud Vision API client
- **SwiftyJSON**: JSON parsing library

## Architecture

### Core Components

- **Core Data**: Local data persistence for users, albums, and images
- **Google Vision API**: Cloud-based image analysis for labels, objects, brands
- **Apple Vision Framework**: On-device image analysis
- **SwiftUI**: Modern declarative UI framework

### Data Model

- **UserEntity**: Represents a user with email and album preferences
- **AlbumEntity**: Represents a capsule/album with image limits
- **ImageEntity**: Represents a photo with metadata and relationships
- **LabelEntity, ColorEntity, ObjectEntity, SceneEntity**: Metadata tags

## Security

- ✅ API keys are never hardcoded in source code
- ✅ Sensitive files (`.env`, `Secrets.plist`) are gitignored
- ✅ No cloud authentication required
- ✅ All data stored locally on device

## Development

### Running Tests

```bash
# Unit tests
Cmd + U in Xcode

# Or via command line
xcodebuild test -workspace "snap capsule.xcworkspace" -scheme "snap capsule" -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftUI best practices
- Maintain consistent naming conventions
- Add documentation comments for public APIs

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

[Add your license here]

## Support

For issues and questions, please open an issue on GitHub.

## Acknowledgments

- Google Cloud Vision API for image analysis capabilities
- Apple Vision Framework for on-device processing
