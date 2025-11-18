# 🔧 Google Vision API Troubleshooting Guide

## Issue: No Brand Logos Detected

### **Possible Causes & Solutions**

### 1. **Image Quality Issues**
**Problem**: Image is too dark, blurry, or low quality
**Solutions**:
- ✅ Use high-quality images (at least 300x300 pixels)
- ✅ Ensure good lighting and contrast
- ✅ Try with well-known brand logos (Nike, Apple, McDonald's)
- ✅ Test with images that have clear, prominent logos

### 2. **API Key Issues**
**Problem**: API key not configured or invalid
**Solutions**:
- ✅ Verify API key in `GoogleVisionConfig.swift`
- ✅ Check that Vision API is enabled in Google Cloud Console
- ✅ Ensure API key has proper permissions
- ✅ Test with the debugger: `VisionAPIDebugger.debugImageAnalysis(image)`

### 3. **Network Issues**
**Problem**: No internet connection or API timeout
**Solutions**:
- ✅ Check internet connection
- ✅ Verify API key is valid
- ✅ Check Google Cloud Console for API usage

### 4. **Image Content Issues**
**Problem**: Image doesn't contain recognizable brand logos
**Solutions**:
- ✅ Use images with well-known brand logos
- ✅ Ensure logos are clearly visible and not obscured
- ✅ Try with different brand logos
- ✅ Test with generated test images

## 🧪 **Testing Steps**

### **Step 1: Test API Configuration**
Add this to your app:
```swift
VisionAPIDebugger.debugImageAnalysis(yourImage)
```

### **Step 2: Test with Generated Image**
```swift
if let testImage = VisionAPIDebugger.createTestImageWithLogo() {
    VisionAPIDebugger.testVisionAPI(with: testImage) { success, message in
        print("Test result: \(success) - \(message)")
    }
}
```

### **Step 3: Test with Real Image**
```swift
VisionAPIDebugger.testVisionAPI(with: yourImage) { success, message in
    print("Result: \(success) - \(message)")
}
```

## 🎯 **Recommended Test Images**

Try these types of images for better results:
- ✅ **Nike logo** on shoes or clothing
- ✅ **Apple logo** on devices
- ✅ **McDonald's logo** on packaging
- ✅ **Coca-Cola logo** on bottles
- ✅ **Starbucks logo** on cups
- ✅ **Google logo** on products

## 🔍 **Debug Information**

The debugger will show you:
- 📏 Image dimensions and properties
- 🔑 API key configuration status
- 📊 Number of brands detected
- 🏷️ Brand names and confidence scores
- ❌ Error messages if API fails

## 🚀 **Quick Fixes**

### **Fix 1: Check Image Quality**
```swift
// Add this to your image analysis
VisionAPIDebugger.debugImageAnalysis(image)
```

### **Fix 2: Test API Key**
```swift
// Add this to verify API key
GoogleVisionTest.runDiagnostics()
```

### **Fix 3: Use Test Image**
```swift
// Create a test image with recognizable content
if let testImage = VisionAPIDebugger.createTestImageWithLogo() {
    // Test with this image
}
```

## 📱 **Common Issues & Solutions**

| Issue | Solution |
|-------|----------|
| "No brands detected" | Try with well-known brand logos |
| "API key not configured" | Check `GoogleVisionConfig.swift` |
| "Network error" | Check internet connection |
| "Invalid image" | Use high-quality images |
| "Timeout" | Check API key permissions |

## 🎉 **Success Indicators**

You'll know it's working when you see:
- ✅ "Vision API Success!" in console
- ✅ Brand names displayed in UI
- ✅ Confidence scores shown
- ✅ Brands appear in indexed photos grid

## 📞 **Still Having Issues?**

1. **Check the console** for error messages
2. **Verify API key** is correctly configured
3. **Test with different images** (try Nike, Apple logos)
4. **Check Google Cloud Console** for API usage
5. **Ensure Vision API is enabled** in your project

---

**The most common issue is using images without clear, recognizable brand logos. Try with well-known brands first!**

