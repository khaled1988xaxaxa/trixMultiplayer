import 'package:flutter/foundation.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/card.dart';

/// Lightweight AI service for testing - uses only rule-based logic
class LightweightAIService {
  static final LightweightAIService _instance = LightweightAIService._internal();
  factory LightweightAIService() => _instance;
  LightweightAIService._internal();

  String get providerName => 'Lightweight Rules-Based AI';

  /// Simple contract selection based on hand analysis
  Future<TrexContract?> selectContract({
    required PlayerPosition botPosition,
    required TrexGame game,
    required List<TrexContract> availableContracts,
  }) async {
    if (availableContracts.isEmpty) return null;

    final player = game.getPlayerByPosition(botPosition);
    final hand = player.hand;
    
    if (kDebugMode) {
      print('🤖 Lightweight AI selecting contract for ${botPosition.name}');
      print('   Available: ${availableContracts.map((c) => c.name).join(', ')}');
    }

    // Simple scoring system
    final scores = <TrexContract, int>{};
    
    for (final contract in availableContracts) {
      int score = 0;
      
      switch (contract) {
        case TrexContract.kingOfHearts:
          // Avoid if we have King of Hearts
          score = hand.any((c) => c.isKingOfHearts) ? -100 : 50;
          // Bonus for high spades (protection)
          score += hand.where((c) => c.suit == Suit.spades && c.rank.value >= 11).length * 15;
          break;
          
        case TrexContract.queens:
          // Penalty for each queen
          score = -hand.where((c) => c.rank == Rank.queen).length * 30;
          break;
          
        case TrexContract.diamonds:
          // Penalty for diamonds
          score = -hand.where((c) => c.suit == Suit.diamonds).length * 8;
          break;
          
        case TrexContract.collections:
          // Penalty for dangerous cards
          final dangerousCards = hand.where((c) => 
            c.isKingOfHearts || c.rank == Rank.queen || c.suit == Suit.diamonds).length;
          score = -dangerousCards * 15;
          break;
          
        case TrexContract.trex:
          // Bonus for low cards
          score = hand.where((c) => c.rank.value <= 6).length * 12;
          // Penalty for high cards
          score -= hand.where((c) => c.rank.value >= 11).length * 8;
          break;
      }
      
      scores[contract] = score;
    }
    
    // Find best contract
    final sortedContracts = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final selectedContract = sortedContracts.first.key;
    
    if (kDebugMode) {
      print('   Scores: ${scores.map((k, v) => MapEntry(k.name, v))}');
      print('   Selected: ${selectedContract.name}');
    }
    
    return selectedContract;
  }

  /// Simple card selection based on game state
  Future<Card?> selectCard({
    required PlayerPosition botPosition,
    required TrexGame game,
    required List<Card> hand,
    required List<Card> validCards,
  }) async {
    if (validCards.isEmpty) return null;

    if (kDebugMode) {
      print('🤖 Lightweight AI selecting card for ${botPosition.name}');
      print('   Valid options: ${validCards.map((c) => '${c.rank.name} ${c.suit.name}').join(', ')}');
    }

    Card selectedCard;

    if (game.currentContract == TrexContract.trex) {
      selectedCard = _selectTrexCard(validCards);
    } else {
      selectedCard = _selectTrickCard(validCards, game.currentContract!);
    }

    if (kDebugMode) {
      print('   Selected: ${selectedCard.rank.name} ${selectedCard.suit.name}');
    }

    return selectedCard;
  }

  /// Select card for Trex contract (play highest)
  Card _selectTrexCard(List<Card> validCards) {
    // Play highest card to get rid of it
    validCards.sort((a, b) => b.rank.value.compareTo(a.rank.value));
    return validCards.first;
  }

  /// Select card for trick-based contracts
  Card _selectTrickCard(List<Card> validCards, TrexContract contract) {
    switch (contract) {
      case TrexContract.kingOfHearts:
        return _selectForKingOfHearts(validCards);
      case TrexContract.queens:
        return _selectForQueens(validCards);
      case TrexContract.diamonds:
        return _selectForDiamonds(validCards);
      case TrexContract.collections:
        return _selectForCollections(validCards);
      default:
        validCards.sort((a, b) => a.rank.value.compareTo(b.rank.value));
        return validCards.first;
    }
  }

  /// King of Hearts strategy - avoid at all costs
  Card _selectForKingOfHearts(List<Card> validCards) {
    // Never play King of Hearts if other options exist
    final safeCards = validCards.where((c) => !c.isKingOfHearts).toList();
    
    if (safeCards.isNotEmpty) {
      // Play lowest safe card
      safeCards.sort((a, b) => a.rank.value.compareTo(b.rank.value));
      return safeCards.first;
    }
    
    // Forced to play King of Hearts
    return validCards.first;
  }

  /// Queens strategy - avoid queens
  Card _selectForQueens(List<Card> validCards) {
    final safeCards = validCards.where((c) => c.rank != Rank.queen).toList();
    
    if (safeCards.isNotEmpty) {
      safeCards.sort((a, b) => a.rank.value.compareTo(b.rank.value));
      return safeCards.first;
    }
    
    return validCards.first;
  }

  /// Diamonds strategy - avoid diamonds
  Card _selectForDiamonds(List<Card> validCards) {
    final safeCards = validCards.where((c) => c.suit != Suit.diamonds).toList();
    
    if (safeCards.isNotEmpty) {
      safeCards.sort((a, b) => a.rank.value.compareTo(b.rank.value));
      return safeCards.first;
    }
    
    return validCards.first;
  }

  /// Collections strategy - avoid all dangerous cards
  Card _selectForCollections(List<Card> validCards) {
    final safeCards = validCards.where((c) => 
      !c.isKingOfHearts && c.rank != Rank.queen && c.suit != Suit.diamonds).toList();
    
    if (safeCards.isNotEmpty) {
      safeCards.sort((a, b) => a.rank.value.compareTo(b.rank.value));
      return safeCards.first;
    }
    
    // Play least dangerous card
    validCards.sort((a, b) {
      int scoreA = _getDangerScore(a);
      int scoreB = _getDangerScore(b);
      return scoreA.compareTo(scoreB);
    });
    
    return validCards.first;
  }

  /// Get danger score for collections contract
  int _getDangerScore(Card card) {
    if (card.isKingOfHearts) return 75; // Highest penalty
    if (card.rank == Rank.queen) return 25;
    if (card.suit == Suit.diamonds) return card.rank.value;
    return 0; // Safe card
  }

  /// Fast contract selection (same as regular for lightweight)
  Future<TrexContract?> selectContractWithFastFallback({
    required PlayerPosition botPosition,
    required TrexGame game,
    required List<TrexContract> availableContracts,
  }) async {
    return await selectContract(
      botPosition: botPosition,
      game: game,
      availableContracts: availableContracts,
    );
  }

  /// Fast card selection (same as regular for lightweight)
  Future<Card?> selectCardWithFastFallback({
    required PlayerPosition botPosition,
    required TrexGame game,
    required List<Card> hand,
    required List<Card> validCards,
  }) async {
    return await selectCard(
      botPosition: botPosition,
      game: game,
      hand: hand,
      validCards: validCards,
    );
  }

  /// Test connection (always succeeds for lightweight)
  Future<Map<String, dynamic>> testConnectionWithDebug() async {
    return {
      'success': true,
      'provider': providerName,
      'message': 'Lightweight AI is always available',
      'latency_ms': 0,
    };
  }

  /// Dispose (no-op for lightweight)
  void dispose() {
    if (kDebugMode) print('🤖 Lightweight AI service disposed');
  }
}
