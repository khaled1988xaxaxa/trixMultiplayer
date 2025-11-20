import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'object_pool.dart';

/// Performance monitoring utility for tracking object creation and memory usage
class PerformanceMonitor {
  static final Map<String, int> _objectCounts = {};
  static final Map<String, DateTime> _lastLogTime = {};
  static const Duration _logInterval = Duration(seconds: 5);
  
  /// Track object creation
  static void trackObjectCreation(String objectType) {
    if (!kDebugMode) return;
    
    _objectCounts[objectType] = (_objectCounts[objectType] ?? 0) + 1;
    
    final now = DateTime.now();
    final lastLog = _lastLogTime[objectType];
    
    if (lastLog == null || now.difference(lastLog) >= _logInterval) {
      developer.log(
        'Object creation: $objectType count: ${_objectCounts[objectType]}',
        name: 'PerformanceMonitor',
      );
      _lastLogTime[objectType] = now;
    }
  }
  
  /// Log cache statistics
  static void logCacheStats() {
    if (!kDebugMode) return;
    
    final stats = CacheManager.getStats();
    developer.log(
      'Cache Stats: $stats',
      name: 'PerformanceMonitor',
    );
  }
  
  /// Reset all counters
  static void reset() {
    _objectCounts.clear();
    _lastLogTime.clear();
  }
  
  /// Get current object counts
  static Map<String, int> getObjectCounts() {
    return Map.from(_objectCounts);
  }
  
  /// Log memory usage warning
  static void logMemoryWarning(String context, int objectCount) {
    if (!kDebugMode) return;
    
    developer.log(
      'Memory Warning: $context - $objectCount objects created',
      name: 'PerformanceMonitor',
      level: 900, // Warning level
    );
  }
}

/// Mixin for widgets to track their creation
mixin PerformanceTrackingMixin {
  void trackCreation(String widgetType) {
    PerformanceMonitor.trackObjectCreation(widgetType);
  }
}

/// Widget wrapper that tracks creation
class PerformanceTrackedWidget extends StatelessWidget {
  final Widget child;
  final String widgetType;
  
  const PerformanceTrackedWidget({
    Key? key,
    required this.child,
    required this.widgetType,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    PerformanceMonitor.trackObjectCreation(widgetType);
    return child;
  }
}

/// Performance metrics collector
class PerformanceMetrics {
  static final Map<String, List<Duration>> _buildTimes = {};
  static final Map<String, DateTime> _buildStartTimes = {};
  
  /// Start timing a build operation
  static void startBuildTimer(String widgetName) {
    if (!kDebugMode) return;
    _buildStartTimes[widgetName] = DateTime.now();
  }
  
  /// End timing a build operation
  static void endBuildTimer(String widgetName) {
    if (!kDebugMode) return;
    
    final startTime = _buildStartTimes[widgetName];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      _buildTimes[widgetName] ??= [];
      _buildTimes[widgetName]!.add(duration);
      
      // Log if build time is excessive
      if (duration.inMilliseconds > 16) { // More than one frame at 60fps
        developer.log(
          'Slow build: $widgetName took ${duration.inMilliseconds}ms',
          name: 'PerformanceMetrics',
          level: 900,
        );
      }
      
      _buildStartTimes.remove(widgetName);
    }
  }
  
  /// Get average build time for a widget
  static Duration? getAverageBuildTime(String widgetName) {
    final times = _buildTimes[widgetName];
    if (times == null || times.isEmpty) return null;
    
    final totalMs = times.fold<int>(0, (sum, duration) => sum + duration.inMilliseconds);
    return Duration(milliseconds: totalMs ~/ times.length);
  }
  
  /// Log performance summary
  static void logSummary() {
    if (!kDebugMode) return;
    
    developer.log('=== Performance Summary ===', name: 'PerformanceMetrics');
    
    for (final entry in _buildTimes.entries) {
      final avgTime = getAverageBuildTime(entry.key);
      developer.log(
        '${entry.key}: ${entry.value.length} builds, avg: ${avgTime?.inMilliseconds}ms',
        name: 'PerformanceMetrics',
      );
    }
    
    PerformanceMonitor.logCacheStats();
  }
  
  /// Clear all metrics
  static void clear() {
    _buildTimes.clear();
    _buildStartTimes.clear();
  }
}