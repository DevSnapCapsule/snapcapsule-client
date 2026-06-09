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

### 3. Configure API Access

Photo analysis (Vision) and voice search (Gemini) call **Cloud Run proxies** by default, so **no API keys are required in the iOS app** for normal use. Keys live in Google Secret Manager on the server.

Optional overrides for local development or a custom proxy URL:

#### Option A: Environment Variables (CI/CD or Xcode scheme)

```bash
export GEMINI_PROXY_URL=https://your-gemini-proxy.run.app
export GEMINI_API_KEY=your_gemini_api_key_here   # direct Gemini fallback only
```

Add the same variables under **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables** when running from Xcode.

#### Option B: .env File (local reference)

```bash
cp .env.example .env
```

The `.env` file is gitignored. Values there are **not** read automatically by the iOS app unless you also set them in Xcode or `Secrets.plist`.

#### Option C: Secrets.plist (direct Gemini fallback for voice search)

```bash
cp "snap capsule/Secrets.plist.example" "snap capsule/Secrets.plist"
```

Set `GeminiAPIKey` only if you want voice search to call Gemini directly instead of the Cloud Run proxy. `Secrets.plist` is gitignored.

#### Option D: Config.plist (custom proxy URL)

```bash
cp "snap capsule/Config.plist.example" "snap capsule/Config.plist"
```

Set `GeminiProxyURL` if your deployed proxy URL differs from the app default. See `backend/gemini-proxy/README.md` for deploy steps.

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
