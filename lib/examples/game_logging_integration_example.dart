import 'package:flutter/material.dart' hide Card;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../providers/ai_logging_provider.dart';
import '../models/card.dart';
import '../models/game_log_models.dart';

/// Example integration showing how to add AI logging to existing game logic
class GameLoggingIntegrationExample {
  
  /// Example: Initialize logging when starting a new game
  static Future<void> initializeGameLogging(BuildContext context) async {
    final loggingProvider = context.read<AILoggingProvider>();
    
    // Check if logging is enabled and user has given consent
    if (!loggingProvider.isEnabled) return;
    
    // Generate unique game ID
    final gameId = const Uuid().v4();
    
    // Start logging session
    loggingProvider.startGameSession(gameId);
    
    print('✅ Started AI logging session: $gameId');
  }
  
  /// Example: Log game context before human player makes a decision
  static Future<String?> logGameContext(
    BuildContext context, {
    required String kingdom,
    required int round,
    required int trickNumber,
    String? leadingSuit,
    required List<Card> cardsInTrick,
    required List<String> playersInTrick,
    required List<Card> humanPlayerHand,
    required Map<String, int> gameScore,
    required List<Card> validMoves,
    required String currentPlayer,
  }) async {
    final loggingProvider = context.read<AILoggingProvider>();
    
    if (!loggingProvider.isEnabled) return null;
    
    // Convert cards in trick to CardPlay objects
    final cardsPlayedInTrick = <CardPlay>[];
    for (int i = 0; i < cardsInTrick.length; i++) {
      cardsPlayedInTrick.add(CardPlay(
        playerId: playersInTrick[i],
        card: cardsInTrick[i],
        position: i + 1,
        timestamp: DateTime.now(),
      ));
    }
    
    // Generate context ID for correlation
    final contextId = const Uuid().v4();
    
    try {
      await loggingProvider.logGameContext(
        kingdom: kingdom,
        round: round,
        currentTrickNumber: trickNumber,
        leadingSuit: leadingSuit,
        cardsPlayedInTrick: cardsPlayedInTrick,
        playerHand: humanPlayerHand,
        gameScore: gameScore,
        availableCards: validMoves,
        currentPlayer: currentPlayer,
        playerOrder: ['human', 'ai_1', 'ai_2', 'ai_3'], // Adjust as needed
      );
      
      print('📊 Logged game context: $contextId');
      return contextId;
    } catch (e) {
      print('❌ Error logging game context: $e');
      return null;
    }
  }
  
  /// Example: Log human player's card selection
  static Future<void> logHumanCardPlay(
    BuildContext context, {
    required String gameContextId,
    required Card selectedCard,
    required List<Card> availableCards,
    Card? aiRecommendedCard,
    double? aiConfidence,
    String? aiReasoning,
    required int decisionTimeMs,
  }) async {
    final loggingProvider = context.read<AILoggingProvider>();
    
    if (!loggingProvider.isEnabled) return;
    
    try {
      // Create AI recommendation if available
      AIRecommendation? aiRecommendation;
      if (aiRecommendedCard != null) {
        // Calculate alternative options scores (example)
        final alternativeOptions = <String, double>{};
        for (final card in availableCards) {
          if (card != aiRecommendedCard) {
            // This would come from your AI system
            alternativeOptions['${card.suit.name}_${card.rank.name}'] = 
                aiConfidence != null ? aiConfidence * 0.8 : 0.5;
          }
        }
        
        aiRecommendation = AIRecommendation(
          recommendedCard: aiRecommendedCard,
          confidence: aiConfidence ?? 0.5,
          reasoning: aiReasoning ?? 'AI recommendation based on current game state',
          alternativeOptions: alternativeOptions,
        );
      }
      
      // Log the decision
      await loggingProvider.logCardPlay(
        gameContextId: gameContextId,
        playerId: 'human_player',
        cardPlayed: selectedCard,
        aiSuggestion: aiRecommendation,
      );
      
      print('🎯 Logged human card play: ${selectedCard.suit.name} ${selectedCard.rank.name}');
    } catch (e) {
      print('❌ Error logging card play: $e');
    }
  }
  
  /// Example: Update decision outcome after trick is completed
  static Future<void> updateDecisionOutcome(
    BuildContext context, {
    required String gameContextId,
    required bool trickWon,
    required int pointsGained,
    required bool wasOptimalMove,
  }) async {
    final loggingProvider = context.read<AILoggingProvider>();
    
    if (!loggingProvider.isEnabled) return;
    
    // This would typically be done by updating the existing PlayerDecision
    // For now, we'll demonstrate the data structure
    final outcome = DecisionOutcome(
      trickWon: trickWon,
      pointsGained: pointsGained,
      strategicValue: _calculateStrategicValue(pointsGained, trickWon),
      wasOptimal: wasOptimalMove,
      resultDescription: _generateOutcomeDescription(trickWon, pointsGained),
    );
    
    print('📈 Decision outcome: ${outcome.strategicValue} value, ${outcome.pointsGained} points');
  }
  
  /// Example: End logging session when game finishes
  static Future<void> endGameLogging(BuildContext context) async {
    final loggingProvider = context.read<AILoggingProvider>();
    
    if (!loggingProvider.isEnabled) return;
    
    // End the current logging session
    loggingProvider.endGameSession();
    
    print('🏁 Ended AI logging session');
  }
  
  /// Helper: Calculate strategic value of a move
  static String _calculateStrategicValue(int pointsGained, bool trickWon) {
    if (pointsGained >= 10 || (trickWon && pointsGained >= 5)) {
      return 'high';
    } else if (pointsGained >= 3 || trickWon) {
      return 'medium';
    } else {
      return 'low';
    }
  }
  
  /// Helper: Generate outcome description
  static String _generateOutcomeDescription(bool trickWon, int pointsGained) {
    if (trickWon && pointsGained > 0) {
      return 'Won trick and gained $pointsGained points';
    } else if (trickWon) {
      return 'Won trick with no penalty points';
    } else if (pointsGained < 0) {
      return 'Lost trick and received ${pointsGained.abs()} penalty points';
    } else {
      return 'Lost trick but avoided penalty points';
    }
  }
}

/// Widget mixin to easily add logging capabilities to game screens
mixin GameLoggingMixin<T extends StatefulWidget> on State<T> {
  String? _currentGameId;
  String? _currentContextId;
  DateTime? _lastDecisionTime;
  
  /// Initialize logging for the current game
  Future<void> initializeLogging() async {
    final loggingProvider = context.read<AILoggingProvider>();
    
    if (loggingProvider.isEnabled) {
      _currentGameId = const Uuid().v4();
      loggingProvider.startGameSession(_currentGameId!);
      _lastDecisionTime = DateTime.now();
    }
  }
  
  /// Log game state before human decision
  Future<void> logGameState({
    required String kingdom,
    required int round,
    required int trickNumber,
    String? leadingSuit,
    required List<Card> playerHand,
    required Map<String, int> scores,
    required List<Card> validMoves,
  }) async {
    final loggingProvider = context.read<AILoggingProvider>();
    
    if (!loggingProvider.isEnabled) return;
    
    _currentContextId = const Uuid().v4();
    
    await loggingProvider.logGameContext(
      kingdom: kingdom,
      round: round,
      currentTrickNumber: trickNumber,
      leadingSuit: leadingSuit,
      cardsPlayedInTrick: [], // Add current trick cards
      playerHand: playerHand,
      gameScore: scores,
      availableCards: validMoves,
      currentPlayer: 'human',
      playerOrder: ['human', 'ai_1', 'ai_2', 'ai_3'],
    );
  }
  
  /// Log human card selection
  Future<void> logCardSelection(Card selectedCard, {
    Card? aiRecommendation,
    double? confidence,
  }) async {
    if (_currentContextId == null) return;
    
    final now = DateTime.now();
    final decisionTime = _lastDecisionTime != null 
        ? now.difference(_lastDecisionTime!).inMilliseconds 
        : 0;
    
    await GameLoggingIntegrationExample.logHumanCardPlay(
      context,
      gameContextId: _currentContextId!,
      selectedCard: selectedCard,
      availableCards: [], // Add available cards
      aiRecommendedCard: aiRecommendation,
      aiConfidence: confidence,
      decisionTimeMs: decisionTime,
    );
    
    _lastDecisionTime = now;
  }
  
  /// Cleanup logging on dispose
  void disposeLogging() {
    final loggingProvider = context.read<AILoggingProvider>();
    if (loggingProvider.isEnabled && _currentGameId != null) {
      loggingProvider.endGameSession();
    }
  }
}

/// Example usage in a game screen widget
class ExampleGameScreenWithLogging extends StatefulWidget {
  const ExampleGameScreenWithLogging({super.key});
  
  @override
  State<ExampleGameScreenWithLogging> createState() => _ExampleGameScreenWithLoggingState();
}

class _ExampleGameScreenWithLoggingState extends State<ExampleGameScreenWithLogging> 
    with GameLoggingMixin {
  
  @override
  void initState() {
    super.initState();
    
    // Initialize logging when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initializeLogging();
    });
  }
  
  @override
  void dispose() {
    // Clean up logging
    disposeLogging();
    super.dispose();
  }
  
  // Example method when human player selects a card
  void onCardSelected(Card selectedCard) {
    // Log the game state before decision
    logGameState(
      kingdom: 'hearts', // Get from game state
      round: 1, // Get from game state
      trickNumber: 1, // Get from game state
      playerHand: [], // Get human player hand
      scores: {}, // Get current scores
      validMoves: [], // Get valid card moves
    );
    
    // Log the card selection
    logCardSelection(
      selectedCard,
      aiRecommendation: null, // Get AI recommendation if available
      confidence: null, // Get AI confidence if available
    );
    
    // Continue with normal game logic...
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trix Game'),
        actions: [
          // Show logging status indicator
          Consumer<AILoggingProvider>(
            builder: (context, loggingProvider, child) {
              if (loggingProvider.isEnabled) {
                return const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.psychology, color: Colors.green),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Game UI would go here'),
      ),
    );
  }
}
