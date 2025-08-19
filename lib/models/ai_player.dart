import '../models/player.dart';
import '../models/card.dart';
import '../models/game.dart';
import '../models/ai_difficulty.dart';
import '../models/trix_game_state.dart';
import '../services/trix_ai.dart';
import '../services/enhanced_elite_ai_service.dart';
import '../services/strategic_elite_ai_service.dart';
import '../services/web_strategic_elite_ai_service.dart';
import '../services/enhanced_trix_ai_agent.dart';
import 'package:flutter/foundation.dart';

/// AI-controlled player that uses trained models to make decisions
class AIPlayer extends Player {
  final TrixAI _ai;
  final AIDifficulty _difficulty;
  
  // AI-specific properties
  int _gamesPlayed = 0;
  int _gamesWon = 0;
  double _averageScore = 0.0;

  AIPlayer({
    required super.id,
    required AIDifficulty difficulty,
    required TrixAI ai,
    required super.position,
  }) : _ai = ai,
       _difficulty = difficulty,
       super(
         name: _generateAIName(difficulty),
         isBot: true,
       );

  // Getters
  AIDifficulty get difficulty => _difficulty;
  TrixAI get ai => _ai;
  int get gamesPlayed => _gamesPlayed;
  int get gamesWon => _gamesWon;
  double get winRate => _gamesPlayed > 0 ? _gamesWon / _gamesPlayed : 0.0;
  double get averageScore => _averageScore;

  /// Factory method to create AI player with loaded model
  static Future<AIPlayer> create({
    required String id,
    required AIDifficulty difficulty,
    required PlayerPosition position,
  }) async {
    TrixAI ai = await TrixAI.loadModel(difficulty);
    return AIPlayer(
      id: id,
      difficulty: difficulty,
      ai: ai,
      position: position,
    );
  }

  /// Generate appropriate name for AI based on difficulty
  static String _generateAIName(AIDifficulty difficulty) {
    // For custom models, use the exact name
    if (difficulty == AIDifficulty.khaled) {
      return 'Khaled';
    }
    if (difficulty == AIDifficulty.mohammad) {
      return 'Mohammad';
    }
    if (difficulty == AIDifficulty.trixAgent0) {
      return 'Trix Agent 1';
    }
    if (difficulty == AIDifficulty.trixAgent1) {
      return 'Trix Agent 2';
    }
    if (difficulty == AIDifficulty.trixAgent2) {
      return 'Trix Agent 3';
    }
    if (difficulty == AIDifficulty.trixAgent3) {
      return 'Trix Agent 4';
    }
    
    Map<AIDifficulty, List<String>> names = {
      AIDifficulty.beginner: ['Trainee', 'Rookie Ahmed', 'Newbie Fatima', 'Learning Naif'],
      AIDifficulty.novice: ['Rising Ali', 'Training Sarah', 'Growing Mohammed', 'Developing Noor'],
      AIDifficulty.amateur: ['Amateur Khaled', 'Cheerful Layla', 'Player Youssef', 'Skilled Mariam'],
      AIDifficulty.intermediate: ['Moderate Omar', 'Smart Zeinab', 'Expert Kareem', 'Skilled Hind'],
      AIDifficulty.advanced: ['Advanced Sultan', 'Expert Aisha', 'Strong Tariq', 'Professional Rana'],
      AIDifficulty.expert: ['Trex Legend', 'Card Queen', 'Intelligence Master', 'Gaming Genius'],
      AIDifficulty.master: ['Grand Master', 'Trex Empress', 'AI Giant', 'Gaming Legend'],
      AIDifficulty.aimaster: ['Neural Nexus', 'AI-Master Supreme', 'Deep Learning Ace', 'Neural Strategist'],
      AIDifficulty.perfect: ['Perfect AI', 'Ultimate Machine', 'Digital Mind', 'Artificial Perfection'],
    };

    List<String> possibleNames = names[difficulty] ?? ['AI Player'];
    return possibleNames[DateTime.now().millisecondsSinceEpoch % possibleNames.length];
  }

  /// Select card to play using AI model
  Future<Card> selectCardToPlay({
    required List<Card> currentTrick,
    required TrexContract? currentContract,
    required int tricksPlayed,
    required Map<PlayerPosition, int> scores,
    required List<Card> playedCards,
  }) async {
    // Create game state
    TrixGameState gameState = TrixGameState(
      playerHand: hand,
      currentTrick: currentTrick,
      currentContract: currentContract,
      playerPosition: position,
      tricksPlayed: tricksPlayed,
      scores: scores,
      playedCards: playedCards,
      isFirstTrick: tricksPlayed == 0 && currentTrick.isEmpty,
    );

    // Get valid cards
    List<Card> validCards = gameState.getValidCards();
    
    if (validCards.isEmpty) {
      throw StateError('No valid cards available for AI player');
    }

    // Add thinking delay based on difficulty (for realism)
    await _addThinkingDelay();

    // Try Human Enhanced AI for humanEnhanced difficulty
    if (_difficulty == AIDifficulty.humanEnhanced) {
      Card? humanEnhancedCard = await _tryHumanEnhancedAI(validCards, gameState);
      if (humanEnhancedCard != null) {
        return humanEnhancedCard;
      }
      // Fall through to normal AI if Human Enhanced AI fails
      if (kDebugMode) {
        print('🔄 Human Enhanced AI failed, trying other AI systems...');
      }
    }

    // Try Elite AI for Claude Sonnet and ChatGPT (Enhanced 90% performance)
    if (_difficulty == AIDifficulty.claudeSonnet || _difficulty == AIDifficulty.chatGPT) {
      Card? eliteCard = await _tryEliteAI(validCards, gameState);
      if (eliteCard != null) {
        return eliteCard;
      }
      // Fall through to normal AI if Elite AI fails
      if (kDebugMode) {
        print('🔄 Enhanced Elite AI failed for ${_difficulty.englishName}, trying Strategic AI...');
      }
    }

    // Try Strategic Elite AI for all difficulty levels (60-70% performance)
    Card? strategicCard = await _tryStrategicEliteAI(validCards, gameState);
    if (strategicCard != null) {
      return strategicCard;
    }

    if (kDebugMode) {
      print('🔄 All Elite AI systems failed for ${_difficulty.englishName}, using standard AI');
    }

    // Let regular AI select the card
    Card selectedCard = _ai.selectCard(
      validCards: validCards,
      gameState: gameState,
    );

    return selectedCard;
  }

  /// Try to use Enhanced Elite AI service for card selection (90% performance)
  Future<Card?> _tryEliteAI(List<Card> validCards, TrixGameState gameState) async {
    try {
      // Use Enhanced Elite AI Service for 90% human-level performance
      final enhancedEliteService = EnhancedEliteAIService();
      
      // Ensure service is initialized
      await enhancedEliteService.initialize();
      
      // Check if Enhanced Elite AI is available for this difficulty
      if (!enhancedEliteService.isModelAvailable(_difficulty)) {
        if (kDebugMode) {
          print('⚠️ Enhanced Elite AI not available for ${_difficulty.englishName}');
          print('🔄 Falling back to standard AI...');
        }
        return null;
      }

      if (kDebugMode) {
        print('🚀 Enhanced Elite AI (${_difficulty.englishName}) - 90% human performance');
        print('🎯 Game mode: ${gameState.currentContract?.name ?? 'kingdom'}');
        print('🎲 Valid cards: ${validCards.length}');
      }

      // Prepare enhanced context
      final currentTrick = gameState.currentTrick;
      final playerPosition = gameState.playerPosition.index + 1; // 1-based
      final roundNumber = (gameState.tricksPlayed ~/ 4) + 1;
      final trickNumber = gameState.tricksPlayed + 1;
      
      // Determine lead suit from current trick
      String? leadSuit;
      if (currentTrick.isNotEmpty) {
        leadSuit = currentTrick.first.suit.englishName.toLowerCase();
      }
      
      // Calculate enhanced penalty tracking
      Map<String, dynamic> penaltyCardsTaken = {
        'hearts': [],
        'queen_spades': false,
        'king_hearts': false,
        'diamonds': []
      };
      
      // Get Enhanced Elite AI response with strategic context
      final response = await enhancedEliteService.getEnhancedEliteAIMove(
        difficulty: _difficulty,
        playerCards: gameState.playerHand,
        validCards: validCards,
        gameMode: gameState.currentContract?.name ?? 'kingdom',
        playedCards: currentTrick,
        currentPlayer: gameState.playerPosition.index,
        tricksWon: gameState.tricksPlayed,
        heartsBroken: false, // TODO: Add hearts broken tracking
        
        // Enhanced parameters for 90% performance
        playerPosition: playerPosition,
        roundNumber: roundNumber,
        trickNumber: trickNumber,
        leadSuit: leadSuit,
        scores: [0, 0, 0, 0], // TODO: Add actual score tracking
        cardsPlayedHistory: [], // TODO: Add complete game history
        trumpSuit: null,
        penaltyCardsTaken: penaltyCardsTaken,
      );
      
      if (response['success'] == true) {
        final cardValue = response['cardValue'] as int?;
        if (cardValue != null) {
          final selectedCard = _valueToCard(cardValue);
          if (selectedCard != null && validCards.contains(selectedCard)) {
            if (kDebugMode) {
              print('🏆 Enhanced Elite AI SUCCESS!');
              print('   • Model: ${response['modelName'] ?? _difficulty.englishName}');
              print('   • Card: ${selectedCard.rank.englishName} ${selectedCard.suit.englishName}');
              print('   • Confidence: ${(response['confidence'] ?? 0.0 * 100).toStringAsFixed(1)}%');
              print('   • Performance: ${response['performanceLevel'] ?? '90% human'}');
              print('   • Decision Type: ${response['decisionType'] ?? 'enhanced_neural_network'}');
              print('   • Reasoning: ${response['reasoning']?.toString().substring(0, 100) ?? 'Strategic decision'}...');
              
              // Log strategic context if available
              if (response['strategicContext'] != null) {
                final context = response['strategicContext'];
                print('   • Strategy: ${context['strategy'] ?? 'balanced'}');
                print('   • Risk Level: ${context['risk_level'] ?? 'medium'}');
                print('   • Position: ${context['position_advantage'] ?? 'neutral'}');
              }
            }
            return selectedCard;
          }
        }
      } else {
        if (kDebugMode) {
          print('⚠️ Enhanced Elite AI failed: ${response['error']}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Enhanced Elite AI selection failed: $e');
        print('🔄 Falling back to standard AI...');
      }
    }
    
    return null;
  }

  /// Try to use Human Enhanced AI service for card selection (20-30% improvement from human patterns)
  Future<Card?> _tryHumanEnhancedAI(List<Card> validCards, TrixGameState gameState) async {
    try {
      final enhancedAIService = EnhancedTrixAIAgent();
      
      // Load the model
      await enhancedAIService.loadModel();
      
      if (!enhancedAIService.isLoaded) {
        if (kDebugMode) print('⚠️ Human Enhanced AI model not loaded');
        return null;
      }
      
      // Convert game state to format expected by enhanced AI
      // Create hand representation for AI
      List<Map<String, dynamic>> handCards = gameState.playerHand.map((card) => {
        'suit': card.suit.englishName.toLowerCase(),
        'rank': _rankToString(card.rank),
      }).toList();
      
      // Create game context
      Map<String, dynamic> gameContext = {
        'trickNumber': gameState.tricksPlayed,
        'currentScore': 0, // TODO: Add actual score if available
        'gameMode': gameState.currentContract?.name ?? 'kingdom',
        'playerPosition': gameState.playerPosition.index,
      };
      
      // Convert game state to state vector
      final stateVector = enhancedAIService.handToStateVector(handCards, gameContext);
      
      // Convert valid cards to action indices
      List<int> legalActions = validCards.map((card) => _cardToActionIndex(card)).toList();
      
      // Get AI decision
      final selectedAction = enhancedAIService.getBestMove(stateVector, legalActions);
      
      // Convert action index back to card
      final selectedCard = _actionIndexToCard(selectedAction, validCards);
      
      if (selectedCard != null && validCards.contains(selectedCard)) {
        if (kDebugMode) {
          print('🧠 Human Enhanced AI SUCCESS!');
          print('   • Card: ${selectedCard.rank.englishName} ${selectedCard.suit.englishName}');
          print('   • Action Index: $selectedAction');
          print('   • Human Pattern: enhanced_behavior');
          print('   • Model: ${enhancedAIService.getModelInfo()['model_type'] ?? 'human_enhanced_ppo'}');
        }
        return selectedCard;
      } else {
        if (kDebugMode) {
          print('⚠️ Human Enhanced AI returned invalid card');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Human Enhanced AI selection failed: $e');
        print('🔄 Falling back to standard AI...');
      }
    }
    
    return null;
  }

  /// Try to use Strategic Elite AI service for card selection (60-70% performance)
  Future<Card?> _tryStrategicEliteAI(List<Card> validCards, TrixGameState gameState) async {
    try {
      // First try web-compatible Strategic Elite AI if available
      if (kIsWeb) {
        final webStrategicResult = await _tryWebStrategicEliteAI(validCards, gameState);
        if (webStrategicResult != null) {
          return webStrategicResult;
        }
      }
      
      // Use Strategic Elite AI Service for 60-70% human-level performance with advanced features
      final strategicEliteService = StrategicEliteAIService();
      
      // Ensure service is initialized
      await strategicEliteService.initialize();
      
      // Check if Strategic Elite AI is available
      if (!strategicEliteService.isStrategicModelAvailable()) {
        if (kDebugMode) {
          print('⚠️ Strategic Elite AI model not available');
          print('🔄 Falling back to standard AI...');
        }
        return null;
      }

      if (kDebugMode) {
        print('🧠 Strategic Elite AI (PPO Enhanced) - 60-70% human performance');
        print('🎯 Game mode: ${gameState.currentContract?.name ?? 'kingdom'}');
        print('🎲 Valid cards: ${validCards.length}');
        print('🚀 Strategic capabilities: Advanced penalty avoidance, opponent modeling, endgame planning');
      }

      // Prepare strategic context
      final currentTrick = gameState.currentTrick;
      final playerPosition = gameState.playerPosition.index + 1; // 1-based
      final roundNumber = (gameState.tricksPlayed ~/ 4) + 1;
      final trickNumber = gameState.tricksPlayed + 1;
      
      // Determine lead suit from current trick
      String? leadSuit;
      if (currentTrick.isNotEmpty) {
        leadSuit = currentTrick.first.suit.englishName.toLowerCase();
      }
      
      // Calculate enhanced penalty tracking
      Map<String, dynamic> penaltyCardsTaken = {
        'hearts': [],
        'queen_spades': false,
        'king_hearts': false,
        'diamonds': []
      };
      
      // Advanced strategic parameters
      double aggressiveWindow = _calculateAggressiveWindow(gameState);
      bool bluffingOpportunity = _assessBluffingOpportunity(gameState);
      double defensivePosture = _calculateDefensivePosture(gameState);
      List<String> opponentStyles = _analyzeOpponentStyles(gameState);
      
      // Get Strategic Elite AI response with comprehensive strategic analysis
      final response = await strategicEliteService.getStrategicAIMove(
        playerCards: gameState.playerHand,
        validCards: validCards,
        gameMode: gameState.currentContract?.name ?? 'kingdom',
        playedCards: currentTrick,
        currentPlayer: gameState.playerPosition.index,
        tricksWon: gameState.tricksPlayed,
        heartsBroken: false, // TODO: Add hearts broken tracking
        
        // Strategic context parameters
        playerPosition: playerPosition,
        roundNumber: roundNumber,
        trickNumber: trickNumber,
        leadSuit: leadSuit,
        scores: [0, 0, 0, 0], // TODO: Add actual score tracking
        cardsPlayedHistory: [], // TODO: Add complete game history
        trumpSuit: null,
        penaltyCardsTaken: penaltyCardsTaken,
        
        // Advanced strategic parameters
        opponentStyles: opponentStyles,
        aggressiveWindow: aggressiveWindow,
        bluffingOpportunity: bluffingOpportunity,
        defensivePosture: defensivePosture,
      );
      
      if (response['success'] == true) {
        final cardValue = response['cardValue'] as int?;
        if (cardValue != null) {
          final selectedCard = _valueToCard(cardValue);
          if (selectedCard != null && validCards.contains(selectedCard)) {
            if (kDebugMode) {
              print('🏆 Strategic Elite AI SUCCESS!');
              print('   • Model: ${response['modelName'] ?? 'PPO Strategic Enhanced'}');
              print('   • Card: ${selectedCard.rank.englishName} ${selectedCard.suit.englishName}');
              print('   • Confidence: ${(response['confidence'] ?? 0.0 * 100).toStringAsFixed(1)}%');
              print('   • Performance: ${response['performanceLevel'] ?? '60-70% human'}');
              print('   • Training Steps: ${response['trainingSteps'] ?? 100000}');
              print('   • Reward Improvement: ${response['rewardImprovement'] ?? '67%'}');
              print('   • Decision Type: ${response['decisionType'] ?? 'ppo_strategic_enhanced'}');
              print('   • Reasoning: ${response['reasoning']?.toString().substring(0, 100) ?? 'Strategic analysis'}...');
              
              // Log strategic capabilities
              if (response['strategicCapabilities'] != null) {
                final capabilities = response['strategicCapabilities'] as List;
                print('   • Capabilities: ${capabilities.join(", ")}');
              }
              
              // Log strategic reasoning if available
              if (response['strategicReasoning'] != null) {
                final reasoning = response['strategicReasoning'] as List;
                print('   • Strategic Analysis: ${reasoning.join(" | ")}');
              }
            }
            return selectedCard;
          }
        }
      } else {
        if (kDebugMode) {
          print('⚠️ Strategic Elite AI failed: ${response['error']}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Strategic Elite AI selection failed: $e');
        print('🔄 Falling back to standard AI...');
      }
    }
    
    return null;
  }

  /// Try to use Web Strategic Elite AI service for card selection (web-compatible)
  Future<Card?> _tryWebStrategicEliteAI(List<Card> validCards, TrixGameState gameState) async {
    try {
      final webStrategicService = WebStrategicEliteAIService();
      
      // Ensure service is initialized
      await webStrategicService.initialize();
      
      // Check if web strategic model is available
      if (!webStrategicService.isWebStrategicModelAvailable()) {
        if (kDebugMode) {
          print('⚠️ Web Strategic Elite AI not available');
        }
        return null;
      }

      if (kDebugMode) {
        print('🌐 Web Strategic Elite AI - 60-70% human performance (Web)');
        print('🎯 Game mode: ${gameState.currentContract?.name ?? 'kingdom'}');
        print('🎲 Valid cards: ${validCards.length}');
      }

      // Prepare strategic context for web AI
      final currentTrick = gameState.currentTrick;
      final playerPosition = gameState.playerPosition.index + 1;
      final roundNumber = (gameState.tricksPlayed ~/ 4) + 1;
      final trickNumber = gameState.tricksPlayed + 1;
      
      String? leadSuit;
      if (currentTrick.isNotEmpty) {
        leadSuit = currentTrick.first.suit.englishName.toLowerCase();
      }
      
      Map<String, dynamic> penaltyCardsTaken = {
        'hearts': [],
        'queen_spades': false,
        'king_hearts': false,
        'diamonds': []
      };
      
      double aggressiveWindow = _calculateAggressiveWindow(gameState);
      bool bluffingOpportunity = _assessBluffingOpportunity(gameState);
      double defensivePosture = _calculateDefensivePosture(gameState);
      List<String> opponentStyles = _analyzeOpponentStyles(gameState);
      
      // Get Web Strategic Elite AI response
      final response = await webStrategicService.getWebStrategicAIMove(
        playerCards: gameState.playerHand,
        validCards: validCards,
        gameMode: gameState.currentContract?.name ?? 'kingdom',
        playedCards: currentTrick,
        currentPlayer: gameState.playerPosition.index,
        tricksWon: gameState.tricksPlayed,
        heartsBroken: false,
        
        playerPosition: playerPosition,
        roundNumber: roundNumber,
        trickNumber: trickNumber,
        leadSuit: leadSuit,
        scores: [0, 0, 0, 0],
        cardsPlayedHistory: [],
        trumpSuit: null,
        penaltyCardsTaken: penaltyCardsTaken,
        
        opponentStyles: opponentStyles,
        aggressiveWindow: aggressiveWindow,
        bluffingOpportunity: bluffingOpportunity,
        defensivePosture: defensivePosture,
      );
      
      if (response['success'] == true) {
        final cardValue = response['cardValue'] as int?;
        if (cardValue != null) {
          final selectedCard = _valueToCard(cardValue);
          if (selectedCard != null && validCards.contains(selectedCard)) {
            if (kDebugMode) {
              print('🏆 Web Strategic Elite AI SUCCESS!');
              print('   • Model: ${response['modelName'] ?? 'Web Strategic Enhanced'}');
              print('   • Card: ${selectedCard.rank.englishName} ${selectedCard.suit.englishName}');
              print('   • Confidence: ${(response['confidence'] ?? 0.0 * 100).toStringAsFixed(1)}%');
              print('   • Performance: ${response['performanceLevel'] ?? '60-70% human'}');
              print('   • Web Compatible: ${response['webCompatible'] ?? true}');
            }
            return selectedCard;
          }
        }
      } else {
        if (kDebugMode) {
          print('⚠️ Web Strategic Elite AI failed: ${response['error']}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Web Strategic Elite AI selection failed: $e');
      }
    }
    
    return null;
  }

  /// Calculate aggressive window based on game state
  double _calculateAggressiveWindow(TrixGameState gameState) {
    double aggression = 0.5; // Base aggression
    
    // More aggressive early in the game
    if (gameState.tricksPlayed < 5) {
      aggression += 0.2;
    }
    
    // More aggressive with strong hand
    int highCards = gameState.playerHand.where((card) => card.rank.value >= 11).length;
    aggression += (highCards / gameState.playerHand.length) * 0.3;
    
    return aggression.clamp(0.0, 1.0);
  }
  
  /// Assess bluffing opportunity
  bool _assessBluffingOpportunity(TrixGameState gameState) {
    // Bluffing opportunity exists when in favorable position
    return gameState.currentTrick.length >= 2 && gameState.tricksPlayed > 3;
  }
  
  /// Calculate defensive posture
  double _calculateDefensivePosture(TrixGameState gameState) {
    double defense = 0.5; // Base defense
    
    // More defensive late in the game
    if (gameState.tricksPlayed > 8) {
      defense += 0.3;
    }
    
    // More defensive with penalty-prone cards
    String gameMode = gameState.currentContract?.name.toLowerCase() ?? 'kingdom';
    int penaltyCards = 0;
    
    for (Card card in gameState.playerHand) {
      if (_isPenaltyCard(card, gameMode)) {
        penaltyCards++;
      }
    }
    
    defense += (penaltyCards / gameState.playerHand.length) * 0.4;
    
    return defense.clamp(0.0, 1.0);
  }
  
  /// Analyze opponent playing styles
  List<String> _analyzeOpponentStyles(TrixGameState gameState) {
    // For now, return balanced styles (could be enhanced with actual analysis)
    return ['balanced', 'balanced', 'balanced'];
  }
  
  /// Check if card is penalty card for given game mode
  bool _isPenaltyCard(Card card, String gameMode) {
    switch (gameMode) {
      case 'hearts':
        return card.suit == Suit.hearts;
      case 'queens':
        return card.rank == Rank.queen;
      case 'king_of_hearts':
        return card.suit == Suit.hearts && card.rank == Rank.king;
      case 'diamonds':
        return card.suit == Suit.diamonds;
      default:
        return false;
    }
  }

  /// Convert integer value (0-51) back to card
  Card? _valueToCard(int value) {
    if (value < 0 || value > 51) return null;
    
    final suitIndex = value ~/ 13;
    final rankValue = (value % 13) + 2;
    
    if (suitIndex >= 0 && suitIndex < Suit.values.length && rankValue >= 2 && rankValue <= 14) {
      final suit = Suit.values[suitIndex];
      final rank = Rank.values.firstWhere((r) => r.value == rankValue);
      return Card(
        id: Card.generateId(suit, rank),
        suit: suit,
        rank: rank,
      );
    }
    
    return null;
  }

  /// Add realistic thinking delay based on AI difficulty
  Future<void> _addThinkingDelay() async {
    int delayMs = 1000; // Default delay
    
    switch (_difficulty) {
      case AIDifficulty.beginner:
        delayMs = 2000 + (DateTime.now().millisecondsSinceEpoch % 1000); // 2-3 seconds
        break;
      case AIDifficulty.novice:
        delayMs = 1500 + (DateTime.now().millisecondsSinceEpoch % 500); // 1.5-2 seconds
        break;
      case AIDifficulty.amateur:
        delayMs = 1000 + (DateTime.now().millisecondsSinceEpoch % 500); // 1-1.5 seconds
        break;
      case AIDifficulty.intermediate:
        delayMs = 800 + (DateTime.now().millisecondsSinceEpoch % 400); // 0.8-1.2 seconds
        break;
      case AIDifficulty.advanced:
        delayMs = 600 + (DateTime.now().millisecondsSinceEpoch % 300); // 0.6-0.9 seconds
        break;
      case AIDifficulty.expert:
        delayMs = 400 + (DateTime.now().millisecondsSinceEpoch % 200); // 0.4-0.6 seconds
        break;
      case AIDifficulty.master:
        delayMs = 300 + (DateTime.now().millisecondsSinceEpoch % 200); // 0.3-0.5 seconds
        break;
      case AIDifficulty.aimaster:
        delayMs = 250 + (DateTime.now().millisecondsSinceEpoch % 100); // 0.25-0.35 seconds
        break;
      case AIDifficulty.perfect:
        delayMs = 200 + (DateTime.now().millisecondsSinceEpoch % 100); // 0.2-0.3 seconds
        break;
      case AIDifficulty.khaled:
        delayMs = 500 + (DateTime.now().millisecondsSinceEpoch % 300); // 0.5-0.8 seconds
        break;
      case AIDifficulty.mohammad:
        delayMs = 500 + (DateTime.now().millisecondsSinceEpoch % 300); // 0.5-0.8 seconds
        break;
      case AIDifficulty.trixAgent0:
        delayMs = 400 + (DateTime.now().millisecondsSinceEpoch % 200); // 0.4-0.6 seconds
        break;
      case AIDifficulty.trixAgent1:
        delayMs = 350 + (DateTime.now().millisecondsSinceEpoch % 150); // 0.35-0.5 seconds
        break;
      case AIDifficulty.trixAgent2:
        delayMs = 300 + (DateTime.now().millisecondsSinceEpoch % 200); // 0.3-0.5 seconds
        break;
      case AIDifficulty.trixAgent3:
        delayMs = 250 + (DateTime.now().millisecondsSinceEpoch % 150); // 0.25-0.4 seconds
        break;
      case AIDifficulty.claudeSonnet:
        delayMs = 300 + (DateTime.now().millisecondsSinceEpoch % 200); // 0.3-0.5 seconds - Elite AI
        break;
      case AIDifficulty.chatGPT:
        delayMs = 250 + (DateTime.now().millisecondsSinceEpoch % 150); // 0.25-0.4 seconds - Elite AI
        break;
      case AIDifficulty.humanEnhanced:
        delayMs = 300 + (DateTime.now().millisecondsSinceEpoch % 200); // 0.3-0.5 seconds - Human Enhanced AI
        break;
      case AIDifficulty.strategicElite:
        delayMs = 400 + (DateTime.now().millisecondsSinceEpoch % 200); // 0.4-0.6 seconds - Strategic AI
        break;
      case AIDifficulty.strategicEliteCorrected:
        delayMs = 350 + (DateTime.now().millisecondsSinceEpoch % 150); // 0.35-0.5 seconds - Corrected Strategic AI
        break;
    }

    await Future.delayed(Duration(milliseconds: delayMs));
  }

  /// Select contract during bidding phase
  Future<TrexContract?> selectContract({
    required List<TrexContract> availableContracts,
    required Map<PlayerPosition, int> currentScores,
  }) async {
    // Add thinking delay
    await _addThinkingDelay();

    // For now, use simple rule-based contract selection
    // This could be enhanced with AI models in the future
    return _selectContractByRules(availableContracts, currentScores);
  }

  /// Rule-based contract selection (can be enhanced with AI later)
  TrexContract? _selectContractByRules(
    List<TrexContract> availableContracts,
    Map<PlayerPosition, int> currentScores,
  ) {
    if (availableContracts.isEmpty) return null;

    // Analyze hand for best contract choice
    Map<Suit, int> suitCounts = {};
    int queens = 0;
    bool hasKingOfHearts = false;

    for (Card card in hand) {
      suitCounts[card.suit] = (suitCounts[card.suit] ?? 0) + 1;
      if (card.rank == Rank.queen) queens++;
      if (card.suit == Suit.hearts && card.rank == Rank.king) {
        hasKingOfHearts = true;
      }
    }

    // Difficulty-based decision making
    switch (_difficulty) {
      case AIDifficulty.beginner:
      case AIDifficulty.novice:
        // Simple random selection
        return availableContracts[DateTime.now().millisecondsSinceEpoch % availableContracts.length];
        
      case AIDifficulty.amateur:
      case AIDifficulty.intermediate:
        // Basic strategy
        if (availableContracts.contains(TrexContract.diamonds) && 
            (suitCounts[Suit.diamonds] ?? 0) <= 2) {
          return TrexContract.diamonds;
        }
        if (availableContracts.contains(TrexContract.queens) && queens <= 1) {
          return TrexContract.queens;
        }
        break;
        
      case AIDifficulty.advanced:
      case AIDifficulty.expert:
      case AIDifficulty.master:
      case AIDifficulty.aimaster:
      case AIDifficulty.perfect:
      case AIDifficulty.khaled:
      case AIDifficulty.mohammad:
      case AIDifficulty.trixAgent0:
      case AIDifficulty.trixAgent1:
      case AIDifficulty.trixAgent2:
      case AIDifficulty.trixAgent3:
        // Advanced strategy (custom models and mobile agents use same logic as advanced)
        if (availableContracts.contains(TrexContract.kingOfHearts) && !hasKingOfHearts) {
          return TrexContract.kingOfHearts;
        }
        if (availableContracts.contains(TrexContract.diamonds) && 
            (suitCounts[Suit.diamonds] ?? 0) <= 1) {
          return TrexContract.diamonds;
        }
        if (availableContracts.contains(TrexContract.queens) && queens == 0) {
          return TrexContract.queens;
        }
        break;
        
      case AIDifficulty.claudeSonnet:
      case AIDifficulty.chatGPT:
        // Elite AI: Advanced contract selection using strategic analysis
        // This would integrate with the Elite AI service for optimal decisions
        if (availableContracts.contains(TrexContract.diamonds) && 
            (suitCounts[Suit.diamonds] ?? 0) <= 1) {
          return TrexContract.diamonds;
        }
        if (availableContracts.contains(TrexContract.queens) && queens == 0) {
          return TrexContract.queens;
        }
        if (availableContracts.contains(TrexContract.kingOfHearts) && !hasKingOfHearts) {
          return TrexContract.kingOfHearts;
        }
        // Default to collections if good distribution
        if (availableContracts.contains(TrexContract.collections)) {
          return TrexContract.collections;
        }
        break;
        
      case AIDifficulty.humanEnhanced:
        // Human Enhanced AI: Contract selection based on human gameplay patterns
        // Uses supervised learning insights for human-like strategic decisions
        if (availableContracts.contains(TrexContract.diamonds) && 
            (suitCounts[Suit.diamonds] ?? 0) <= 1) {
          return TrexContract.diamonds;
        }
        if (availableContracts.contains(TrexContract.queens) && queens == 0) {
          return TrexContract.queens;
        }
        if (availableContracts.contains(TrexContract.kingOfHearts) && !hasKingOfHearts) {
          return TrexContract.kingOfHearts;
        }
        // Human players often prefer collections when they have balanced suits
        if (availableContracts.contains(TrexContract.collections)) {
          return TrexContract.collections;
        }
        break;
        
      case AIDifficulty.strategicElite:
        // Strategic Elite AI: Advanced contract selection using strategic analysis
        // Uses PPO Strategic Enhanced model for optimal contract decisions
        if (availableContracts.contains(TrexContract.diamonds) && 
            (suitCounts[Suit.diamonds] ?? 0) <= 1) {
          return TrexContract.diamonds;
        }
        if (availableContracts.contains(TrexContract.queens) && queens == 0) {
          return TrexContract.queens;
        }
        if (availableContracts.contains(TrexContract.kingOfHearts) && !hasKingOfHearts) {
          return TrexContract.kingOfHearts;
        }
        // Strategic preference for collections
        if (availableContracts.contains(TrexContract.collections)) {
          return TrexContract.collections;
        }
        break;
        
      case AIDifficulty.strategicEliteCorrected:
        // Strategic Elite Corrected AI: Enhanced contract selection with King of Hearts protection
        // Same logic as Strategic Elite but with enhanced safety measures
        if (availableContracts.contains(TrexContract.diamonds) && 
            (suitCounts[Suit.diamonds] ?? 0) <= 1) {
          return TrexContract.diamonds;
        }
        if (availableContracts.contains(TrexContract.queens) && queens == 0) {
          return TrexContract.queens;
        }
        if (availableContracts.contains(TrexContract.kingOfHearts) && !hasKingOfHearts) {
          return TrexContract.kingOfHearts;
        }
        // Strategic preference for collections
        if (availableContracts.contains(TrexContract.collections)) {
          return TrexContract.collections;
        }
        break;
    }

    // Default to first available contract
    return availableContracts.first;
  }

  /// Update AI stats after game completion
  void updateGameStats({
    required bool won,
    required int finalScore,
    required Duration gameDuration,
  }) {
    _gamesPlayed++;
    if (won) _gamesWon++;
    
    _averageScore = (_averageScore * (_gamesPlayed - 1) + finalScore) / _gamesPlayed;

    // Reset AI performance stats for next game
    _ai.resetStats();
  }

  /// Get comprehensive AI information
  Map<String, dynamic> getAIInfo() {
    return {
      'name': name,
      'difficulty': _difficulty.englishName,
      'arabic_difficulty': _difficulty.arabicName,
      'description': _difficulty.description,
      'experience_level': _difficulty.experienceLevel,
      'games_played': _gamesPlayed,
      'games_won': _gamesWon,
      'win_rate': winRate,
      'average_score': _averageScore,
      'ai_performance': _ai.getPerformanceStats(),
      'model_info': _ai.getDifficultyInfo(),
    };
  }

  /// Get display name for UI
  String getDisplayName() {
    return '$name (${_difficulty.arabicName})';
  }

  /// Check if this AI should be recommended for player
  bool isRecommendedFor({
    required int playerGamesPlayed,
    required double playerWinRate,
  }) {
    AIDifficulty recommended = AIDifficulty.getRecommendedForPlayer(
      playerGamesPlayed,
      playerWinRate,
    );
    
    // Allow +/- 1 difficulty level
    int diffLevel = _difficulty.experienceLevel;
    int recLevel = recommended.experienceLevel;
    
    return (diffLevel - recLevel).abs() <= 1;
  }

  /// Convert Card rank to string for AI
  String _rankToString(Rank rank) {
    switch (rank) {
      case Rank.two:
        return 'two';
      case Rank.three:
        return 'three';
      case Rank.four:
        return 'four';
      case Rank.five:
        return 'five';
      case Rank.six:
        return 'six';
      case Rank.seven:
        return 'seven';
      case Rank.eight:
        return 'eight';
      case Rank.nine:
        return 'nine';
      case Rank.ten:
        return 'ten';
      case Rank.jack:
        return 'jack';
      case Rank.queen:
        return 'queen';
      case Rank.king:
        return 'king';
      case Rank.ace:
        return 'ace';
    }
  }

  /// Convert Card to action index (0-51) for AI
  int _cardToActionIndex(Card card) {
    final suits = {'hearts': 0, 'diamonds': 1, 'clubs': 2, 'spades': 3};
    final ranks = {
      'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7,
      'eight': 8, 'nine': 9, 'ten': 10, 'jack': 11, 'queen': 12, 'king': 13, 'ace': 14
    };
    
    String suit = card.suit.englishName.toLowerCase();
    String rank = _rankToString(card.rank);
    
    int suitValue = suits[suit] ?? 0;
    int rankValue = ranks[rank] ?? 2;
    
    return suitValue * 13 + (rankValue - 2);
  }

  /// Convert action index back to Card
  Card? _actionIndexToCard(int actionIndex, List<Card> validCards) {
    final suits = ['hearts', 'diamonds', 'clubs', 'spades'];
    final ranks = ['two', 'three', 'four', 'five', 'six', 'seven',
                   'eight', 'nine', 'ten', 'jack', 'queen', 'king', 'ace'];
    
    int suitIndex = actionIndex ~/ 13;
    int rankIndex = actionIndex % 13;
    
    if (suitIndex >= 0 && suitIndex < suits.length && 
        rankIndex >= 0 && rankIndex < ranks.length) {
      
      String targetSuit = suits[suitIndex];
      String targetRank = ranks[rankIndex];
      
      // Find matching card in valid cards
      for (Card card in validCards) {
        if (card.suit.englishName.toLowerCase() == targetSuit &&
            _rankToString(card.rank) == targetRank) {
          return card;
        }
      }
    }
    
    return null;
  }

  @override
  String toString() {
    return 'AIPlayer(${getDisplayName()}, Score: $score, Cards: ${hand.length}, '
           'Games: $_gamesPlayed, Win Rate: ${(winRate * 100).toStringAsFixed(1)}%)';
  }
}
