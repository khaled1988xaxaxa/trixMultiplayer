import 'package:shared_preferences/shared_preferences.dart';
import '../utils/ai_config.dart';

class AIPerformanceManager {
  static AIPerformanceManager? _instance;
  static AIPerformanceManager get instance => _instance ??= AIPerformanceManager._();
  
  AIPerformanceManager._();
  
  // Performance settings cache
  int? _cachedTimeout;
  bool? _cachedCaching;
  bool? _cachedParallel;
  
  // Get AI timeout setting
  Future<int> getAITimeout() async {
    if (_cachedTimeout != null) return _cachedTimeout!;
    
    final prefs = await SharedPreferences.getInstance();
    _cachedTimeout = prefs.getInt('ai_timeout') ?? 5;
    return _cachedTimeout!;
  }
  
  // Get caching setting
  Future<bool> getCachingEnabled() async {
    if (_cachedCaching != null) return _cachedCaching!;
    
    final prefs = await SharedPreferences.getInstance();
    _cachedCaching = prefs.getBool('enable_caching') ?? AIConfig.enableCaching;
    return _cachedCaching!;
  }
  
  // Get parallel processing setting
  Future<bool> getParallelEnabled() async {
    if (_cachedParallel != null) return _cachedParallel!;
    
    final prefs = await SharedPreferences.getInstance();
    _cachedParallel = prefs.getBool('enable_parallel') ?? AIConfig.enableParallelProcessing;
    return _cachedParallel!;
  }
  
  // Clear settings cache when user changes preferences
  void clearCache() {
    _cachedTimeout = null;
    _cachedCaching = null;
    _cachedParallel = null;
  }
  
  // Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    return {
      'cache_size': 0, // Placeholder since cache is private
      'cache_hits': _getCacheHitRate(),
      'timeout_setting': _cachedTimeout ?? 5,
      'caching_enabled': _cachedCaching ?? true,
      'parallel_enabled': _cachedParallel ?? true,
    };
  }
  
  double _getCacheHitRate() {
    // This would be tracked in a real implementation
    return 0.0; // Placeholder
  }
  
  // Clear AI cache
  void clearAICache() {
    AIConfig.clearCache();
  }
  
  // Quick timeout for fast decisions
  Duration getQuickTimeout() {
    return Duration(seconds: (_cachedTimeout ?? 5) ~/ 2);
  }
}