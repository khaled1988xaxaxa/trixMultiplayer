class AIConfig {
  // AI Provider Configuration
  static const String defaultProvider = 'deepseek'; // 'deepseek' or 'openai'
  
  // DeepSeek API Configuration
  static const String deepSeekApiKey = 'sk-39ccf16b3db84748a5210179350dbe86'; // Replace with your actual API key
  
  // OpenAI API Configuration  
  static const String openAIApiKey = 'YOUR_OPENAI_API_KEY_HERE'; // Add your OpenAI API key
  
  // Provider URLs
  static const String deepSeekBaseUrl = 'https://api.deepseek.com/chat/completions';
  static const String openAIBaseUrl = 'https://api.openai.com/v1/chat/completions';
  
  // Provider Models - Updated with correct DeepSeek model names
  static const String deepSeekModel = 'deepseek-chat'; // Try the basic model first
  static const String deepSeekModelV2 = 'deepseek-coder'; // Alternative model
  static const String deepSeekModelV3 = 'deepseek-reasoner'; // Another alternative
  static const String openAIModel = 'gpt-3.5-turbo'; // or 'gpt-4' for better quality
  
  // AI Settings
  static const bool enableAI = true; // Set to false to use only simple bot logic
  static const Duration aiTimeout = Duration(seconds: 5); // Reduced from 10 to 5 seconds
  static const double aiTemperature = 0.7; // Controls AI creativity (0.0 = deterministic, 1.0 = creative)
  
  // Performance Optimization Settings
  static const bool enableCaching = true;
  static const int maxCacheSize = 100;
  static const bool enableParallelProcessing = true;
  static const Duration quickTimeout = Duration(seconds: 3); // For quick decisions
  static const int maxPromptLength = 800; // Reduced prompt size for faster processing
  
  // Fallback settings
  static const bool useFallbackOnError = true;
  static const bool logAIDecisions = true; // Enable for debugging
  
  // Performance settings
  static const int maxRetries = 1; // Reduced from 2 to 1 for faster response
  static const Duration retryDelay = Duration(milliseconds: 300); // Reduced delay
  
  // Provider-specific settings
  static const Map<String, Map<String, dynamic>> providerSettings = {
    'deepseek': {
      'temperature': 0.7,
      'max_tokens': 150,
      'top_p': 0.9,
    },
    'openai': {
      'temperature': 0.6,
      'max_tokens': 120,
      'top_p': 0.8,
    },
  };
  
  // Cache management
  static final Map<String, dynamic> _responseCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration cacheExpiry = Duration(minutes: 10);
  
  // Get cached response if available and not expired
  static dynamic getCachedResponse(String key) {
    if (!enableCaching || !_responseCache.containsKey(key)) return null;
    
    final timestamp = _cacheTimestamps[key];
    if (timestamp != null && DateTime.now().difference(timestamp) > cacheExpiry) {
      _responseCache.remove(key);
      _cacheTimestamps.remove(key);
      return null;
    }
    
    return _responseCache[key];
  }
  
  // Cache a response
  static void cacheResponse(String key, dynamic response) {
    if (!enableCaching) return;
    
    _responseCache[key] = response;
    _cacheTimestamps[key] = DateTime.now();
    
    // Clean cache if it gets too large
    if (_responseCache.length > maxCacheSize) {
      _cleanCache();
    }
  }
  
  // Clean old cache entries
  static void _cleanCache() {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    _cacheTimestamps.forEach((key, timestamp) {
      if (now.difference(timestamp) > cacheExpiry) {
        keysToRemove.add(key);
      }
    });
    
    for (final key in keysToRemove) {
      _responseCache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    // If still too large, remove oldest entries
    if (_responseCache.length > maxCacheSize) {
      final sortedEntries = _cacheTimestamps.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      final toRemove = sortedEntries.take(_responseCache.length - maxCacheSize);
      for (final entry in toRemove) {
        _responseCache.remove(entry.key);
        _cacheTimestamps.remove(entry.key);
      }
    }
  }
  
  // Clear all cache
  static void clearCache() {
    _responseCache.clear();
    _cacheTimestamps.clear();
  }
  
  // Get provider configuration
  static Map<String, dynamic> getProviderConfig(String provider) {
    return providerSettings[provider] ?? providerSettings['deepseek']!;
  }
  
  // Get API key for provider
  static String getApiKey(String provider) {
    switch (provider) {
      case 'deepseek':
        return deepSeekApiKey;
      case 'openai':
        return openAIApiKey;
      default:
        return deepSeekApiKey;
    }
  }
  
  // Get base URL for provider
  static String getBaseUrl(String provider) {
    switch (provider) {
      case 'deepseek':
        return deepSeekBaseUrl;
      case 'openai':
        return openAIBaseUrl;
      default:
        return deepSeekBaseUrl;
    }
  }
  
  // Get model for provider
  static String getModel(String provider) {
    switch (provider) {
      case 'deepseek':
        return deepSeekModel;
      case 'openai':
        return openAIModel;
      default:
        return deepSeekModel;
    }
  }
}