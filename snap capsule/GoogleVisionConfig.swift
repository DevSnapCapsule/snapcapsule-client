import Foundation

// MARK: - Google Cloud Vision API Configuration
/// Secure configuration manager for Google Vision API key.
/// 
/// **Security Best Practices:**
/// - API keys are loaded from .env file (gitignored) or environment variables
/// - Never hardcode API keys in source code
/// - .env file should never be committed to version control
struct GoogleVisionConfig {
    
    // MARK: - Private Constants
    private static let envFileName = ".env"
    private static let apiKeyKey = "GOOGLE_VISION_API_KEY"
    private static let environmentVariableName = "GOOGLE_VISION_API_KEY"
    
    // MARK: - API Key Loading (Priority Order)
    
    /// Load API key from environment variable (highest priority)
    /// Useful for CI/CD pipelines and local development
    private static var apiKeyFromEnvironment: String? {
        guard let envKey = ProcessInfo.processInfo.environment[environmentVariableName],
              !envKey.isEmpty,
              !envKey.hasPrefix("YOUR_"),
              envKey != "YOUR_GOOGLE_CLOUD_VISION_API_KEY_HERE" else {
            return nil
        }
        return envKey
    }
    
    /// Load API key from .env file
    /// This file should be created from .env.example and never committed
    /// The .env file is gitignored for security
    private static var apiKeyFromEnvFile: String? {
        // Try to find .env file in the project root (parent of app bundle)
        // This works for development when running from Xcode
        let possiblePaths = [
            // Project root (where .env should be)
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(envFileName),
            // Parent directory of app bundle (for development)
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent(envFileName),
            // App bundle (fallback, not recommended)
            Bundle.main.bundleURL.appendingPathComponent(envFileName),
            // Documents directory (for runtime)
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(envFileName)
        ].compactMap { $0 }
        
        for envPath in possiblePaths {
            if let apiKey = loadAPIKeyFromEnvFile(at: envPath) {
                return apiKey
            }
        }
        
        return nil
    }
    
    /// Parse .env file and extract API key
    private static func loadAPIKeyFromEnvFile(at url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        
        // Parse .env file format: KEY=value
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            // Skip comments and empty lines
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // Parse KEY=value format
            let parts = trimmed.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                var value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                
                // Remove quotes if present
                if (value.hasPrefix("\"") && value.hasSuffix("\"")) || 
                   (value.hasPrefix("'") && value.hasSuffix("'")) {
                    value = String(value.dropFirst().dropLast())
                }
                
                if key == apiKeyKey && !value.isEmpty &&
                   !value.hasPrefix("YOUR_") &&
                   value != "YOUR_GOOGLE_CLOUD_VISION_API_KEY_HERE" {
                    return value
                }
            }
        }
        
        return nil
    }
    
    /// Load API key from Secrets.plist file (legacy support)
    /// ⚠️ DEPRECATED: Use .env file instead
    private static var apiKeyFromSecretsPlist: String? {
        // First try to load from app bundle (development only - not recommended for production)
        if let plistPath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: plistPath),
           let apiKey = plist["GoogleVisionAPIKey"] as? String,
           !apiKey.isEmpty,
           !apiKey.hasPrefix("YOUR_"),
           apiKey != "YOUR_GOOGLE_CLOUD_VISION_API_KEY_HERE" {
            return apiKey
        }
        
        // Also try to load from Documents directory (outside app bundle - more secure)
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let secretsPath = documentsPath.appendingPathComponent("Secrets.plist")
            if FileManager.default.fileExists(atPath: secretsPath.path),
               let plist = NSDictionary(contentsOf: secretsPath),
               let apiKey = plist["GoogleVisionAPIKey"] as? String,
               !apiKey.isEmpty,
               !apiKey.hasPrefix("YOUR_"),
               apiKey != "YOUR_GOOGLE_CLOUD_VISION_API_KEY_HERE" {
                return apiKey
            }
        }
        
        return nil
    }
    
    /// Load API key from Info.plist (fallback for legacy support)
    /// ⚠️ SECURITY WARNING: Info.plist is typically committed to version control
    /// This method is deprecated and should not be used in production
    private static var apiKeyFromInfoPlist: String? {
        #if DEBUG
        // Only allow Info.plist in debug builds
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: apiKeyKey) as? String,
              !apiKey.isEmpty,
              !apiKey.hasPrefix("YOUR_"),
              apiKey != "YOUR_GOOGLE_CLOUD_VISION_API_KEY_HERE" else {
            return nil
        }
        return apiKey
        #else
        // Disable Info.plist loading in release builds for security
        return nil
        #endif
    }
    
    // MARK: - Public API
    
    /// Get the API key from the most appropriate secure source
    /// Priority: Environment Variable > .env file > Secrets.plist (legacy) > Info.plist (legacy)
    /// 
    /// - Returns: The API key if found
    /// - Throws: `ConfigurationError.missingAPIKey` if no valid key is found
    static func getAPIKey() throws -> String {
        // Priority 1: Environment variable (for CI/CD and local dev)
        if let envKey = apiKeyFromEnvironment {
            return envKey
        }
        
        // Priority 2: .env file (recommended for local development)
        if let envFileKey = apiKeyFromEnvFile {
            return envFileKey
        }
        
        // Priority 3: Secrets.plist (legacy support, deprecated)
        if let secretsKey = apiKeyFromSecretsPlist {
            return secretsKey
        }
        
        // Priority 4: Info.plist (legacy support, not recommended)
        if let infoKey = apiKeyFromInfoPlist {
            return infoKey
        }
        
        // No valid key found - throw error instead of crashing
        throw ConfigurationError.missingAPIKey
    }
    
    /// Get the API key (computed property for backward compatibility)
    /// ⚠️ WARNING: This will crash the app if key is missing (use only during development)
    /// For production, use `getAPIKey()` with proper error handling
    static var effectiveAPIKey: String {
        // In debug builds, provide helpful error message
        #if DEBUG
        do {
            return try getAPIKey()
        } catch {
            fatalError("""
            ❌ Google Vision API Key not configured!
            
            Please configure your API key using one of these methods:
            
            1. **Recommended: Create .env file**
               - Copy `.env.example` to `.env` in the project root
               - Add your API key: GOOGLE_VISION_API_KEY=your-key-here
               - The .env file is gitignored and won't be committed
            
            2. **Environment Variable (for CI/CD)**
               - Set GOOGLE_VISION_API_KEY environment variable
               - Xcode: Edit Scheme > Run > Arguments > Environment Variables
            
            3. **Secrets.plist (legacy, deprecated)**
               - Use .env file instead
            
            Get your API key from: https://console.cloud.google.com/apis/credentials
            """)
        }
        #else
        // In release builds, return empty string and let the service handle the error gracefully
        return (try? getAPIKey()) ?? ""
        #endif
    }
    
    /// Check if API key is properly configured
    static var isConfigured: Bool {
        // Try to get the key without fatal error
        if let _ = apiKeyFromEnvironment { return true }
        if let _ = apiKeyFromEnvFile { return true }
        if let _ = apiKeyFromSecretsPlist { return true }
        if let _ = apiKeyFromInfoPlist { return true }
        return false
    }
    
    /// Get configuration status for debugging
    static var configurationStatus: String {
        if let _ = apiKeyFromEnvironment {
            return "✅ Configured via environment variable (GOOGLE_VISION_API_KEY)"
        }
        if let _ = apiKeyFromEnvFile {
            return "✅ Configured via .env file"
        }
        if let _ = apiKeyFromSecretsPlist {
            return "⚠️ Configured via Secrets.plist (deprecated - use .env file instead)"
        }
        if let _ = apiKeyFromInfoPlist {
            return "⚠️ Configured via Info.plist (deprecated - use .env file instead)"
        }
        return "❌ Not configured - API key missing"
    }
}

// MARK: - Configuration Error
enum ConfigurationError: LocalizedError {
    case missingAPIKey
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return """
            Google Vision API Key is not configured.
            
            Please set up your API key using one of these methods:
            1. Create .env file from .env.example (recommended)
            2. Set GOOGLE_VISION_API_KEY environment variable
            3. Legacy: Use Secrets.plist (deprecated)
            """
        }
    }
}

