import '../models/card.dart';
import '../models/player.dart';
import '../models/game.dart';

/// Represents the current game state for AI decision making
class TrixGameState {
  final List<Card> playerHand;
  final List<Card> currentTrick;
  final TrexContract? currentContract;
  final PlayerPosition playerPosition;
  final int tricksPlayed;
  final Map<PlayerPosition, int> scores;
  final List<Card> playedCards;
  final PlayerPosition? trumpSuit;
  final bool isFirstTrick;
  final Card? leadCard;

  const TrixGameState({
    required this.playerHand,
    required this.currentTrick,
    required this.currentContract,
    required this.playerPosition,
    required this.tricksPlayed,
    required this.scores,
    required this.playedCards,
    this.trumpSuit,
    this.isFirstTrick = false,
    this.leadCard,
  });

  /// Encode the game state into a string for AI model lookup
  String encode() {
    // Sort hand for consistency
    List<String> sortedHand = playerHand
        .map((card) => _encodeCard(card))
        .toList()
      ..sort();

    // Encode current trick
    List<String> trickCards = currentTrick
        .map((card) => _encodeCard(card))
        .toList();

    // Create compact state representation
    String handStr = sortedHand.take(10).join(''); // Limit for performance
    String trickStr = trickCards.join('');
    String contractStr = currentContract?.name ?? 'none';
    String positionStr = playerPosition.index.toString();
    String tricksStr = tricksPlayed.toString();

    return '$handStr|$trickStr|$contractStr|$positionStr|$tricksStr';
  }

  /// Encode a single card into a compact string
  String _encodeCard(Card card) {
    String suitChar = card.suit.name.substring(0, 1).toUpperCase();
    String rankStr = card.rank.name.substring(0, 1).toUpperCase();
    if (card.rank == Rank.ten) rankStr = 'T';
    if (card.rank == Rank.jack) rankStr = 'J';
    if (card.rank == Rank.queen) rankStr = 'Q';
    if (card.rank == Rank.king) rankStr = 'K';
    if (card.rank == Rank.ace) rankStr = 'A';
    return '$suitChar$rankStr';
  }

  /// Get simplified state for AI models with smaller Q-tables
  String getSimplifiedState() {
    // For beginner/novice AIs, use more general state
    String contractStr = currentContract?.name ?? 'none';
    String handSize = playerHand.length.toString();
    String trickSize = currentTrick.length.toString();
    String position = playerPosition.index.toString();
    
    return '$contractStr|$handSize|$trickSize|$position';
  }

  /// Check if player must follow suit
  bool mustFollowSuit(Card card) {
    if (currentTrick.isEmpty) return true;
    
    Card leadCard = currentTrick.first;
    bool hasLeadSuit = playerHand.any((c) => c.suit == leadCard.suit);
    
    return !hasLeadSuit || card.suit == leadCard.suit;
  }

  /// Get valid cards that can be played
  List<Card> getValidCards() {
    if (currentTrick.isEmpty) {
      // First card, any card is valid (except contract restrictions)
      return List.from(playerHand);
    }

    Card leadCard = currentTrick.first;
    List<Card> sameSuit = playerHand.where((c) => c.suit == leadCard.suit).toList();
    
    if (sameSuit.isNotEmpty) {
      return sameSuit; // Must follow suit
    }
    
    return List.from(playerHand); // Can play any card
  }

  /// Get strategic information for AI
  Map<String, dynamic> getStrategicInfo() {
    return {
      'handSize': playerHand.length,
      'trickPosition': currentTrick.length,
      'isWinning': _isCurrentlyWinning(),
      'dangerousCards': _getDangerousCards(),
      'safeCards': _getSafeCards(),
      'tricksRemaining': 13 - tricksPlayed,
    };
  }

  bool _isCurrentlyWinning() {
    if (currentTrick.isEmpty) return false;
    
    Card leadCard = currentTrick.first;
    Card highestCard = currentTrick.reduce((a, b) {
      if (a.suit != leadCard.suit && b.suit == leadCard.suit) return b;
      if (b.suit != leadCard.suit && a.suit == leadCard.suit) return a;
      return a.rank.value > b.rank.value ? a : b;
    });
    
    // Check if we would win with any of our valid cards
    List<Card> validCards = getValidCards();
    return validCards.any((card) => 
      card.suit == leadCard.suit && 
      card.rank.value > highestCard.rank.value
    );
  }

  List<Card> _getDangerousCards() {
    switch (currentContract) {
      case TrexContract.kingOfHearts:
        return playerHand.where((c) => 
          c.suit == Suit.hearts && c.rank == Rank.king
        ).toList();
        
      case TrexContract.queens:
        return playerHand.where((c) => c.rank == Rank.queen).toList();
        
      case TrexContract.diamonds:
        return playerHand.where((c) => c.suit == Suit.diamonds).toList();
        
      default:
        return [];
    }
  }

  List<Card> _getSafeCards() {
    List<Card> dangerous = _getDangerousCards();
    return playerHand.where((card) => !dangerous.contains(card)).toList();
  }
}

/// Encodes game actions for AI models
class TrixActionEncoder {
  /// Encode a card play action
  static String encodeCardAction(Card card) {
    return _encodeCard(card);
  }

  /// Encode a contract selection action
  static String encodeContractAction(TrexContract contract) {
    return contract.name;
  }

  /// Encode a bid action
  static String encodeBidAction(int bid) {
    return 'bid_$bid';
  }

  static String _encodeCard(Card card) {
    String suitChar = card.suit.name.substring(0, 1).toUpperCase();
    String rankStr = card.rank.name.substring(0, 1).toUpperCase();
    if (card.rank == Rank.ten) rankStr = 'T';
    if (card.rank == Rank.jack) rankStr = 'J';
    if (card.rank == Rank.queen) rankStr = 'Q';
    if (card.rank == Rank.king) rankStr = 'K';
    if (card.rank == Rank.ace) rankStr = 'A';
    return '$suitChar$rankStr';
  }

  /// Decode action back to card (for validation)
  static Card? decodeCardAction(String action) {
    if (action.length != 2) return null;
    
    try {
      String suitChar = action[0];
      String rankChar = action[1];
      
      Suit? suit;
      switch (suitChar) {
        case 'H': suit = Suit.hearts; break;
        case 'D': suit = Suit.diamonds; break;
        case 'C': suit = Suit.clubs; break;
        case 'S': suit = Suit.spades; break;
      }
      
      if (suit == null) return null;
      
      Rank? rank;
      switch (rankChar) {
        case '2': rank = Rank.two; break;
        case '3': rank = Rank.three; break;
        case '4': rank = Rank.four; break;
        case '5': rank = Rank.five; break;
        case '6': rank = Rank.six; break;
        case '7': rank = Rank.seven; break;
        case '8': rank = Rank.eight; break;
        case '9': rank = Rank.nine; break;
        case 'T': rank = Rank.ten; break;
        case 'J': rank = Rank.jack; break;
        case 'Q': rank = Rank.queen; break;
        case 'K': rank = Rank.king; break;
        case 'A': rank = Rank.ace; break;
      }
      
      if (rank == null) return null;
      
      return Card(id: Card.generateId(suit, rank), suit: suit, rank: rank);
    } catch (e) {
      return null;
    }
  }
}
