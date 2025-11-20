import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/ai_difficulty.dart';
import '../models/card.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../services/ai_service.dart';

/// Optimized AI processing system to reduce delays and improve responsiveness
class AIProcessingOptimizer {
  static final AIProcessingOptimizer _instance = AIProcessingOptimizer._internal();
  factory AIProcessingOptimizer() => _instance;
  AIProcessingOptimizer._internal();

  final Map<String, Timer> _activeTimers = {};
  final Map<String, Completer<Card?>> _pendingDecisions = {};
  final Map<AIDifficulty, int> _adaptiveDelays = {};
  final Map<String, DateTime> _lastDecisionTimes = {};
  
  // Performance metrics
  int _totalDecisions = 0;
  int _fastDecisions = 0;
  double _averageDecisionTime = 0.0;
  
  /// Initialize adaptive delays based on difficulty
  void initialize() {
    for (AIDifficulty difficulty in AIDifficulty.values) {
      _adaptiveDelays[difficulty] = _getBaseDelay(difficulty);
    }
  }

  /// Get optimized delay for AI difficulty with adaptive adjustment
  int getOptimizedDelay(AIDifficulty difficulty, {bool isGameSpeedFast = false}) {
    int baseDelay = _adaptiveDelays[difficulty] ?? _getBaseDelay(difficulty);
    
    // Apply game speed multiplier
    if (isGameSpeedFast) {
      baseDelay = (baseDelay * 0.5).round();
    }
    
    // Add small random variation for realism
    int variation = (baseDelay * 0.2).round();
    int randomDelay = Random().nextInt(variation);
    
    return (baseDelay + randomDelay).clamp(50, 3000); // Min 50ms, Max 3s
  }

  /// Process AI decision with optimized timing
  Future<Card?> processAIDecision({
    required String playerId,
    required AIDifficulty difficulty,
    required Future<Card?> Function() aiDecisionFunction,
    bool isGameSpeedFast = false,
    bool allowParallelProcessing = true,
  }) async {
    final startTime = DateTime.now();
    
    // Cancel any existing decision for this player
    cancelPendingDecision(playerId);
    
    final completer = Completer<Card?>();
    _pendingDecisions[playerId] = completer;
    
    try {
      // Start AI processing immediately
      final aiDecisionFuture = aiDecisionFunction();
      
      // Get optimized delay
      final delay = getOptimizedDelay(difficulty, isGameSpeedFast: isGameSpeedFast);
      
      // Use parallel processing for faster decisions
      if (allowParallelProcessing && !kIsWeb) {
        final result = await _processWithIsolate(aiDecisionFuture, delay);
        completer.complete(result);
      } else {
        // Standard processing with optimized timing
        final result = await _processWithOptimizedTiming(aiDecisionFuture, delay);
        completer.complete(result);
      }
      
      final decision = await completer.future;
      
      // Update performance metrics
      _updatePerformanceMetrics(startTime, decision != null);
      
      // Adapt delay based on performance
      _adaptDelay(difficulty, DateTime.now().difference(startTime).inMilliseconds);
      
      return decision;
    } catch (e) {
      if (kDebugMode) {
        print('❌ AI processing error for $playerId: $e');
      }
      completer.completeError(e);
      rethrow;
    } finally {
      _pendingDecisions.remove(playerId);
      _activeTimers.remove(playerId);
    }
  }

  /// Process AI decision with isolate for better performance
  Future<Card?> _processWithIsolate(Future<Card?> aiDecisionFuture, int delay) async {
    final receivePort = ReceivePort();
    
    try {
      // Start AI processing in background
      final aiResultFuture = aiDecisionFuture;
      
      // Wait for either AI result or minimum delay
      final results = await Future.wait([
        aiResultFuture,
        Future.delayed(Duration(milliseconds: delay)),
      ]);
      
      return results[0] as Card?;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Isolate processing error: $e');
      }
      // Fallback to standard processing
      return await _processWithOptimizedTiming(aiDecisionFuture, delay);
    } finally {
      receivePort.close();
    }
  }

  /// Process AI decision with optimized timing
  Future<Card?> _processWithOptimizedTiming(Future<Card?> aiDecisionFuture, int delay) async {
    final startTime = DateTime.now();
    
    // Start AI processing immediately
    final aiResultFuture = aiDecisionFuture;
    
    // Wait for AI result
    final aiResult = await aiResultFuture;
    
    // Calculate remaining delay
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    final remainingDelay = (delay - elapsed).clamp(0, delay);
    
    // Add remaining delay if needed for realism
    if (remainingDelay > 0) {
      await Future.delayed(Duration(milliseconds: remainingDelay));
    }
    
    return aiResult;
  }

  /// Cancel pending AI decision
  void cancelPendingDecision(String playerId) {
    _activeTimers[playerId]?.cancel();
    _activeTimers.remove(playerId);
    
    final completer = _pendingDecisions[playerId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
    _pendingDecisions.remove(playerId);
  }

  /// Get base delay for difficulty level
  int _getBaseDelay(AIDifficulty difficulty) {
    switch (difficulty) {
      case AIDifficulty.beginner:
        return 1500; // Reduced from 2000-3000ms
      case AIDifficulty.novice:
        return 1200; // Reduced from 1500-2000ms
      case AIDifficulty.amateur:
        return 1000; // Reduced from 1000-1500ms
      case AIDifficulty.intermediate:
        return 800;  // Reduced from 800-1200ms
      case AIDifficulty.advanced:
        return 600;  // Reduced from 600-900ms
      case AIDifficulty.expert:
        return 400;  // Reduced from 400-600ms
      case AIDifficulty.master:
        return 300;  // Reduced from 300-500ms
      case AIDifficulty.aimaster:
        return 200;  // Reduced from 250-350ms
      case AIDifficulty.perfect:
        return 150;  // Reduced from 200-300ms
      case AIDifficulty.khaled:
      case AIDifficulty.mohammad:
        return 400;  // Reduced from 500-800ms
      case AIDifficulty.trixAgent0:
        return 300;  // Reduced from 400-600ms
      case AIDifficulty.trixAgent1:
        return 250;  // Reduced from 350-500ms
      case AIDifficulty.trixAgent2:
        return 200;  // Reduced from 300-500ms
      case AIDifficulty.trixAgent3:
        return 150;  // Reduced from 250-400ms
      case AIDifficulty.claudeSonnet:
        return 200;  // Reduced from 300-500ms
      case AIDifficulty.chatGPT:
        return 150;  // Reduced from 250-400ms
      case AIDifficulty.humanEnhanced:
        return 250;  // Reduced from 300-500ms
      case AIDifficulty.strategicElite:
        return 300;  // Reduced from 400-600ms
      case AIDifficulty.strategicEliteCorrected:
        return 250;  // New optimized delay
    }
  }

  /// Adapt delay based on performance
  void _adaptDelay(AIDifficulty difficulty, int actualTime) {
    final currentDelay = _adaptiveDelays[difficulty] ?? _getBaseDelay(difficulty);
    
    // If AI is consistently fast, reduce delay slightly
    if (actualTime < currentDelay * 0.7) {
      _adaptiveDelays[difficulty] = (currentDelay * 0.95).round().clamp(50, 3000);
    }
    // If AI is slow, increase delay slightly to maintain realism
    else if (actualTime > currentDelay * 1.3) {
      _adaptiveDelays[difficulty] = (currentDelay * 1.05).round().clamp(50, 3000);
    }
  }

  /// Update performance metrics
  void _updatePerformanceMetrics(DateTime startTime, bool successful) {
    _totalDecisions++;
    
    final duration = DateTime.now().difference(startTime).inMilliseconds;
    
    if (successful && duration < 1000) {
      _fastDecisions++;
    }
    
    // Update rolling average
    _averageDecisionTime = ((_averageDecisionTime * (_totalDecisions - 1)) + duration) / _totalDecisions;
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    return {
      'total_decisions': _totalDecisions,
      'fast_decisions': _fastDecisions,
      'fast_decision_rate': _totalDecisions > 0 ? _fastDecisions / _totalDecisions : 0.0,
      'average_decision_time_ms': _averageDecisionTime,
      'adaptive_delays': Map.fromEntries(
        _adaptiveDelays.entries.map((e) => MapEntry(e.key.englishName, e.value))
      ),
    };
  }

  /// Reset performance metrics
  void resetMetrics() {
    _totalDecisions = 0;
    _fastDecisions = 0;
    _averageDecisionTime = 0.0;
    _lastDecisionTimes.clear();
  }

  /// Clean up resources
  void dispose() {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    
    for (final completer in _pendingDecisions.values) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }
    _pendingDecisions.clear();
  }
}

/// AI processing configuration
class AIProcessingConfig {
  static bool enableFastMode = false;
  static bool enableParallelProcessing = true;
  static bool enableAdaptiveDelays = true;
  static double gameSpeedMultiplier = 1.0;
  
  /// Configure AI processing settings
  static void configure({
    bool? fastMode,
    bool? parallelProcessing,
    bool? adaptiveDelays,
    double? speedMultiplier,
  }) {
    if (fastMode != null) enableFastMode = fastMode;
    if (parallelProcessing != null) enableParallelProcessing = parallelProcessing;
    if (adaptiveDelays != null) enableAdaptiveDelays = adaptiveDelays;
    if (speedMultiplier != null) gameSpeedMultiplier = speedMultiplier.clamp(0.1, 3.0);
  }
}