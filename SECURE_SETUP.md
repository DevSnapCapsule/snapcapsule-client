# 🔐 Secure API Key Setup Guide

This guide explains how to securely configure the Google Vision API key for SnapCapsule.

## ⚠️ Security Notice

**NEVER commit API keys to version control!** The `.env` file is automatically excluded from git via `.gitignore`.

## 🚀 Quick Setup (Recommended)

### Step 1: Get Your API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create a new one)
3. Enable the Vision API:
   - Navigate to **APIs & Services** > **Library**
   - Search for "Vision API"
   - Click **Enable**
4. Create credentials:
   - Go to **APIs & Services** > **Credentials**
   - Click **Create Credentials** > **API Key**
   - Copy the generated API key

### Step 2: Configure in App

**Option A: .env File (Recommended for Local Development)**

1. Copy the example file:
   ```bash
   cp .env.example .env
   ```

2. Open `.env` in a text editor

3. Replace `YOUR_GOOGLE_CLOUD_VISION_API_KEY_HERE` with your actual API key:
   ```bash
   GOOGLE_VISION_API_KEY=your-actual-api-key-here
   ```

4. **Important:** The `.env` file is already in `.gitignore` and won't be committed

5. **Location:** Place the `.env` file in the project root directory (same level as the `.xcodeproj` file)

**Option B: Environment Variable (Recommended for CI/CD)**

1. In Xcode:
   - Edit Scheme (⌘ + <)
   - Select **Run** > **Arguments**
   - Under **Environment Variables**, click **+**
   - Name: `GOOGLE_VISION_API_KEY`
   - Value: Your API key

2. Or via Terminal:
   ```bash
   export GOOGLE_VISION_API_KEY="your-api-key-here"
   ```

**Option C: Secrets.plist (Legacy, Deprecated)**

⚠️ **Note:** This method is deprecated. Use `.env` file instead.

If you need to use Secrets.plist for backward compatibility:
1. Copy `Secrets.plist.example` to `Secrets.plist`
2. Add your API key to the plist file
3. Do NOT add it to Xcode target (it will be bundled with the app)

## 🔍 Verify Configuration

The app will automatically check for the API key on startup. You can verify the configuration status by checking the console output or using:

```swift
print(GoogleVisionConfig.configurationStatus)
```

## 🛡️ Security Best Practices

1. **Never commit secrets:**
   - ✅ `.env` file is in `.gitignore`
   - ✅ Never add API keys to source code
   - ✅ Never commit `.env` file to git

2. **Restrict API key usage:**
   - In Google Cloud Console, restrict your API key to:
     - Your app's bundle ID
     - Specific IP addresses (if applicable)
     - Vision API only

3. **Rotate keys regularly:**
   - If a key is compromised, immediately revoke it in Google Cloud Console
   - Generate a new key and update your configuration

4. **Use different keys for different environments:**
   - Development: Use a restricted key with test quotas
   - Production: Use a separate key with production quotas

## 🐛 Troubleshooting

### Error: "Google Vision API Key not configured!"

**Solution:** Ensure you've completed Step 2 above and that:
- `.env` file exists in the project root directory
- The API key value is not empty or a placeholder
- The file format is correct: `GOOGLE_VISION_API_KEY=your-key-here`

### Error: "API key not configured" in console

**Solution:** Check the configuration status:
```swift
print(GoogleVisionConfig.configurationStatus)
```

### API calls failing

**Solution:**
1. Verify the API key is valid in Google Cloud Console
2. Ensure Vision API is enabled for your project
3. Check API quotas and limits
4. Verify network connectivity

## 📚 Additional Resources

- [Google Cloud Vision API Documentation](https://cloud.google.com/vision/docs)
- [API Key Best Practices](https://cloud.google.com/docs/authentication/api-keys)
- [Securing API Keys in iOS Apps](https://developer.apple.com/documentation/security)

## 🔄 Migration from Hardcoded Key

If you're migrating from the old hardcoded key approach:

1. The old hardcoded key has been removed for security
2. Follow Step 2 above to configure your key securely
3. The app will fail to launch if no key is configured (with a helpful error message)
4. This ensures no accidental deployments with missing keys

