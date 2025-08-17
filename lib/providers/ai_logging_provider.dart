import 'package:flutter/foundation.dart';
import '../services/game_logging_service.dart';
import '../models/game_log_models.dart';
import '../models/card.dart';

/// Provider for managing AI training data collection state
class AILoggingProvider with ChangeNotifier {
  final GameLoggingService _loggingService = GameLoggingService.instance;
  
  bool _isEnabled = false;
  bool _hasConsent = false;
  bool _isInitialized = false;
  String? _currentGameId;
  DateTime? _lastDecisionTime;

  bool get isEnabled => _isEnabled;
  bool get hasConsent => _hasConsent;
  bool get isInitialized => _isInitialized;
  String? get currentGameId => _currentGameId;

  /// Initialize the logging provider
  Future<void> initialize() async {
    try {
      await _loggingService.initialize();
      _hasConsent = await _loggingService.hasUserConsent();
      _isEnabled = _loggingService.isEnabled;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing AI logging: $e');
    }
  }

  /// Set user consent for data collection
  Future<void> setUserConsent(bool consent) async {
    try {
      await _loggingService.setUserConsent(consent);
      _hasConsent = consent;
      
      if (consent) {
        await _loggingService.setEnabled(true);
        _isEnabled = true;
      } else {
        _isEnabled = false;
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting user consent: $e');
    }
  }

  /// Enable or disable logging
  Future<void> setLoggingEnabled(bool enabled) async {
    try {
      await _loggingService.setEnabled(enabled);
      _isEnabled = enabled;
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting logging enabled: $e');
    }
  }

  /// Start a new game session for logging
  void startGameSession(String gameId) {
    _currentGameId = gameId;
    notifyListeners();
  }

  /// End the current game session
  Future<void> endGameSession() async {
    _currentGameId = null;
    _lastDecisionTime = null;
    
    // Force sync any remaining data when game ends
    if (_isEnabled) {
      try {
        await forceSyncForTesting();
        debugPrint('📊 Synced AI training data at game end');
      } catch (e) {
        debugPrint('❌ Error syncing data at game end: $e');
      }
    }
    
    notifyListeners();
  }

  /// Log a game context with current game state
  Future<void> logGameContext({
    required String kingdom,
    required int round,
    required int currentTrickNumber,
    String? leadingSuit,
    required List<CardPlay> cardsPlayedInTrick,
    required List<Card> playerHand,
    required Map<String, int> gameScore,
    required List<Card> availableCards,
    required String currentPlayer,
    required List<String> playerOrder,
  }) async {
    if (!_isEnabled || _currentGameId == null) return;

    try {
      final context = await _loggingService.createGameContext(
        gameId: _currentGameId!,
        kingdom: kingdom,
        round: round,
        currentTrickNumber: currentTrickNumber,
        leadingSuit: leadingSuit,
        cardsPlayedInTrick: cardsPlayedInTrick,
        playerHand: playerHand,
        gameScore: gameScore,
        availableCards: availableCards,
        currentPlayer: currentPlayer,
        playerOrder: playerOrder,
      );

      await _loggingService.logGameContext(context);
    } catch (e) {
      debugPrint('Error logging game context: $e');
    }
  }

  /// Log a player decision
  Future<void> logPlayerDecision({
    required String gameContextId,
    required String playerId,
    required PlayerAction action,
    AIRecommendation? aiSuggestion,
    DecisionOutcome? outcome,
  }) async {
    if (!_isEnabled || _currentGameId == null) return;

    try {
      final now = DateTime.now();
      final decisionTime = _lastDecisionTime != null 
          ? now.difference(_lastDecisionTime!).inMilliseconds
          : 0;
      
      final decision = await _loggingService.createPlayerDecision(
        gameContextId: gameContextId,
        playerId: playerId,
        action: action,
        aiSuggestion: aiSuggestion,
        outcome: outcome,
        decisionTimeMs: decisionTime,
      );

      await _loggingService.logPlayerDecision(decision);
      _lastDecisionTime = now;
    } catch (e) {
      debugPrint('Error logging player decision: $e');
    }
  }

  /// Log when a human player plays a card
  Future<void> logCardPlay({
    required String gameContextId,
    required String playerId,
    required Card cardPlayed,
    AIRecommendation? aiSuggestion,
    bool? trickWon,
    int? pointsGained,
    String? strategicValue,
  }) async {
    final action = PlayerAction(
      type: 'play_card',
      cardPlayed: cardPlayed,
    );

    DecisionOutcome? outcome;
    if (trickWon != null && pointsGained != null && strategicValue != null) {
      outcome = DecisionOutcome(
        trickWon: trickWon,
        pointsGained: pointsGained,
        strategicValue: strategicValue,
        wasOptimal: aiSuggestion?.recommendedCard == cardPlayed,
      );
    }

    await logPlayerDecision(
      gameContextId: gameContextId,
      playerId: playerId,
      action: action,
      aiSuggestion: aiSuggestion,
      outcome: outcome,
    );
  }

  /// Log when a human player makes a bid
  Future<void> logBidDecision({
    required String gameContextId,
    required String playerId,
    required String bidValue,
    AIRecommendation? aiSuggestion,
  }) async {
    final action = PlayerAction(
      type: 'bid',
      bidValue: bidValue,
    );

    await logPlayerDecision(
      gameContextId: gameContextId,
      playerId: playerId,
      action: action,
      aiSuggestion: aiSuggestion,
    );
  }

  /// Create an AI recommendation for logging
  AIRecommendation createAIRecommendation({
    Card? recommendedCard,
    String? recommendedAction,
    required double confidence,
    required String reasoning,
    Map<String, double>? alternativeOptions,
  }) {
    return AIRecommendation(
      recommendedCard: recommendedCard,
      recommendedAction: recommendedAction,
      confidence: confidence,
      reasoning: reasoning,
      alternativeOptions: alternativeOptions,
    );
  }

  /// Clear all collected data
  Future<void> clearAllData() async {
    try {
      await _loggingService.clearAllData();
    } catch (e) {
      debugPrint('Error clearing data: $e');
    }
  }

  /// Show privacy consent dialog helper
  bool shouldShowConsentDialog() {
    return !_hasConsent && _isInitialized;
  }

  /// Force sync for testing purposes  
  Future<void> forceSyncForTesting() async {
    try {
      await _loggingService.forceSyncForTesting();
      debugPrint('🔄 Forced sync completed successfully');
    } catch (e) {
      debugPrint('❌ Error during forced sync: $e');
    }
  }

  @override
  void dispose() {
    _loggingService.dispose();
    super.dispose();
  }
}
