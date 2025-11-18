# SnapCapsule : AI Powered Photo App

An AI-powered photo management app with intelligent image analysis using Google Cloud Vision API and Apple Vision Framework.

## 🔐 Security & API Key Setup

**IMPORTANT:** Before running the app, you must configure the Google Vision API key securely.

See [SECURE_SETUP.md](./SECURE_SETUP.md) for detailed instructions.

### Quick Start:
1. Copy `.env.example` to `.env` in the project root
2. Add your Google Vision API key to `.env`: `GOOGLE_VISION_API_KEY=your-key-here`
3. The `.env` file is gitignored and won't be committed

The API key is loaded from `.env` file (gitignored) or environment variables - **never hardcoded in source code**.
