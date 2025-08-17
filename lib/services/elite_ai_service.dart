import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/ai_difficulty.dart';
import '../models/card.dart';

/// Service to handle Elite AI models (Claude Sonnet and ChatGPT)
class EliteAIService {
  static EliteAIService? _instance;
  static EliteAIService get instance => _instance ??= EliteAIService._();
  
  EliteAIService._();
  
  bool _isInitialized = false;
  final Map<AIDifficulty, bool> _modelAvailability = {};
  
  /// Initialize the Elite AI service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Check if Python and required packages are available
      await _checkPythonAvailability();
      
      // Check model file availability
      await _checkModelAvailability();
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('🚀 Elite AI Service initialized successfully');
        print('🤖 Claude Sonnet available: ${_modelAvailability[AIDifficulty.claudeSonnet]}');
        print('🤖 ChatGPT available: ${_modelAvailability[AIDifficulty.chatGPT]}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize Elite AI Service: $e');
      }
      // Don't rethrow - Elite AI is optional
    }
  }
  
  /// Check if Python and required packages are available
  Future<void> _checkPythonAvailability() async {
    try {
      if (kIsWeb) {
        // Web platform doesn't support Python integration
        return;
      }
      
      // Try to run a simple Python command
      final result = await Process.run('python', ['--version']);
      if (result.exitCode == 0) {
        if (kDebugMode) {
          print('✅ Python available: ${result.stdout}');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ Python not available or not in PATH');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Python availability check failed: $e');
      }
    }
  }
  
  /// Check if elite AI model files are available
  Future<void> _checkModelAvailability() async {
    try {
      // Check Claude Sonnet model
      final claudeModelPath = 'assets/ai_models/claude_sonnet_ai/agent_gen100_steps5000000_106953.zip';
      final claudeAvailable = await _isAssetAvailable(claudeModelPath);
      _modelAvailability[AIDifficulty.claudeSonnet] = claudeAvailable;
      
      // Check ChatGPT model
      final chatgptModelPath = 'assets/ai_models/chatgpt_ai/agent_gen99_steps5000000_372161.zip';
      final chatgptAvailable = await _isAssetAvailable(chatgptModelPath);
      _modelAvailability[AIDifficulty.chatGPT] = chatgptAvailable;
      
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Model availability check failed: $e');
      }
      // Default to false for all models
      _modelAvailability[AIDifficulty.claudeSonnet] = false;
      _modelAvailability[AIDifficulty.chatGPT] = false;
    }
  }
  
  /// Check if an asset file exists
  Future<bool> _isAssetAvailable(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Check if a specific elite AI model is available
  bool isModelAvailable(AIDifficulty difficulty) {
    if (!_isInitialized) return false;
    
    return _modelAvailability[difficulty] ?? false;
  }
  
  /// Get AI move from elite AI model
  Future<Map<String, dynamic>> getEliteAIMove({
    required AIDifficulty difficulty,
    required List<Card> playerCards,
    required List<Card> validCards,
    required String gameMode,
    required List<Card> playedCards,
    required int currentPlayer,
    required int tricksWon,
    required bool heartsBroken,
  }) async {
    
    // Check if model is available
    if (!isModelAvailable(difficulty)) {
      return _getFallbackResponse(difficulty, validCards);
    }
    
    try {
      // Prepare game state for Python AI
      final gameState = {
        'player_cards': playerCards.map((card) => _cardToValue(card)).toList(),
        'valid_cards': validCards.map((card) => _cardToValue(card)).toList(),
        'game_mode': gameMode,
        'played_cards': playedCards.map((card) => _cardToValue(card)).toList(),
        'current_player': currentPlayer,
        'tricks_won': tricksWon,
        'hearts_broken': heartsBroken,
      };
      
      // Get model name for Python script
      String modelName = difficulty == AIDifficulty.claudeSonnet ? 'claude_sonnet' : 'chatgpt';
      
      // Call Python AI integration
      final result = await _callPythonAI(modelName, gameState);
      
      if (result['success'] == true) {
        return {
          'success': true,
          'cardValue': result['best_card'],
          'confidence': result['confidence'],
          'reasoning': result['reasoning'],
          'modelName': result['model_name'],
          'isEliteAI': result['is_elite_ai'] ?? true,
        };
      } else {
        throw Exception(result['error'] ?? 'Unknown error from Python AI');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Elite AI call failed for $difficulty: $e');
      }
      
      return _getFallbackResponse(difficulty, validCards);
    }
  }
  
  /// Convert Card to integer value for Python AI
  int _cardToValue(Card card) {
    // Convert to standard card value: suit * 13 + rank
    // Suits: Clubs=0, Diamonds=1, Hearts=2, Spades=3
    // Ranks: Two=0, Three=1, ..., Ace=12
    int suitValue = card.suit.index;
    int rankValue = card.rank.value - 2; // Convert to 0-based
    return suitValue * 13 + rankValue;
  }
  
  /// Call Python AI integration script
  Future<Map<String, dynamic>> _callPythonAI(String modelName, Map<String, dynamic> gameState) async {
    if (kIsWeb) {
      throw Exception('Python AI not supported on web platform');
    }
    
    try {
      // Convert game state to JSON
      final gameStateJson = jsonEncode(gameState);
      
      // Get path to Python script
      final scriptPath = 'lib/services/elite_ai_integration.py';
      
      // Run Python script
      final result = await Process.run(
        'python',
        [scriptPath, modelName, gameStateJson],
        workingDirectory: Directory.current.path,
      );
      
      if (result.exitCode == 0) {
        final responseText = result.stdout.toString().trim();
        return jsonDecode(responseText);
      } else {
        throw Exception('Python script failed: ${result.stderr}');
      }
      
    } catch (e) {
      throw Exception('Failed to call Python AI: $e');
    }
  }
  
  /// Get fallback response when elite AI is not available
  Map<String, dynamic> _getFallbackResponse(AIDifficulty difficulty, List<Card> validCards) {
    // Intelligent fallback strategy
    Card chosenCard;
    String reasoning;
    
    if (validCards.isEmpty) {
      chosenCard = Card(suit: Suit.clubs, rank: Rank.two);
      reasoning = 'No valid cards available - fallback card';
    } else {
      // Elite AI fallback: choose strategically
      chosenCard = _getStrategicFallbackCard(validCards, difficulty);
      reasoning = _getFallbackReasoning(chosenCard, difficulty);
    }
    
    return {
      'success': true,
      'cardValue': _cardToValue(chosenCard),
      'confidence': 0.7, // Lower confidence for fallback
      'reasoning': reasoning,
      'modelName': '${difficulty.englishName} (Fallback)',
      'isEliteAI': false,
    };
  }
  
  /// Get strategic fallback card when elite AI is not available
  Card _getStrategicFallbackCard(List<Card> validCards, AIDifficulty difficulty) {
    // Sort cards by strategic value
    final sortedCards = List<Card>.from(validCards);
    sortedCards.sort((a, b) => _cardToValue(a).compareTo(_cardToValue(b)));
    
    // Elite AI fallback strategies
    if (difficulty == AIDifficulty.claudeSonnet) {
      // Claude Sonnet style: conservative, analytical
      // Prefer middle-range cards to avoid extremes
      final middleIndex = sortedCards.length ~/ 2;
      return sortedCards[middleIndex];
    } else {
      // ChatGPT style: dynamic, adaptive
      // Mix of low and strategic cards
      final strategicIndex = (sortedCards.length * 0.3).round();
      return sortedCards[strategicIndex.clamp(0, sortedCards.length - 1)];
    }
  }
  
  /// Get fallback reasoning text
  String _getFallbackReasoning(Card chosenCard, AIDifficulty difficulty) {
    final cardName = '${chosenCard.rank.englishName} of ${chosenCard.suit.englishName}';
    
    if (difficulty == AIDifficulty.claudeSonnet) {
      return 'Strategic analysis (fallback): Playing $cardName with conservative approach';
    } else {
      return 'Adaptive strategy (fallback): Playing $cardName with dynamic positioning';
    }
  }
  
  /// Get elite AI models status
  Map<String, dynamic> getEliteAIStatus() {
    return {
      'initialized': _isInitialized,
      'claude_sonnet_available': _modelAvailability[AIDifficulty.claudeSonnet] ?? false,
      'chatgpt_available': _modelAvailability[AIDifficulty.chatGPT] ?? false,
      'python_integration': !kIsWeb,
    };
  }
}
