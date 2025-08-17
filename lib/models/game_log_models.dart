import 'card.dart';

/// Extension to add JSON serialization to the existing Card class
extension CardSerialization on Card {
  Map<String, dynamic> toJson() {
    return {
      'suit': suit.name,
      'rank': rank.name,
    };
  }
  
  static Card fromJson(Map<String, dynamic> json) {
    final suitName = json['suit'] as String;
    final rankName = json['rank'] as String;
    
    final suit = Suit.values.firstWhere((s) => s.name == suitName);
    final rank = Rank.values.firstWhere((r) => r.name == rankName);
    
    return Card(suit: suit, rank: rank);
  }
}

/// Represents the complete game context at a decision point
class GameContext {
  final String gameId;
  final DateTime timestamp;
  final String kingdom; // trump, no_trump, girls, boys, etc.
  final int round;
  final int currentTrickNumber;
  final String? leadingSuit;
  final List<CardPlay> cardsPlayedInTrick;
  final List<Card> playerHand;
  final Map<String, int> gameScore;
  final List<Card> availableCards;
  final String currentPlayer;
  final List<String> playerOrder;

  GameContext({
    required this.gameId,
    required this.timestamp,
    required this.kingdom,
    required this.round,
    required this.currentTrickNumber,
    this.leadingSuit,
    required this.cardsPlayedInTrick,
    required this.playerHand,
    required this.gameScore,
    required this.availableCards,
    required this.currentPlayer,
    required this.playerOrder,
  });

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'timestamp': timestamp.toIso8601String(),
      'kingdom': kingdom,
      'round': round,
      'currentTrick': {
        'trickNumber': currentTrickNumber,
        'leadingSuit': leadingSuit,
        'cardsPlayed': cardsPlayedInTrick.map((e) => e.toJson()).toList(),
      },
      'playerHand': playerHand.map((e) => e.toJson()).toList(),
      'gameScore': gameScore,
      'availableCards': availableCards.map((e) => e.toJson()).toList(),
      'currentPlayer': currentPlayer,
      'playerOrder': playerOrder,
    };
  }

  factory GameContext.fromJson(Map<String, dynamic> json) {
    return GameContext(
      gameId: json['gameId'],
      timestamp: DateTime.parse(json['timestamp']),
      kingdom: json['kingdom'],
      round: json['round'],
      currentTrickNumber: json['currentTrick']['trickNumber'],
      leadingSuit: json['currentTrick']['leadingSuit'],
      cardsPlayedInTrick: (json['currentTrick']['cardsPlayed'] as List)
          .map((e) => CardPlay.fromJson(e))
          .toList(),
      playerHand: (json['playerHand'] as List)
          .map((e) => CardSerialization.fromJson(e))
          .toList(),
      gameScore: Map<String, int>.from(json['gameScore']),
      availableCards: (json['availableCards'] as List)
          .map((e) => CardSerialization.fromJson(e))
          .toList(),
      currentPlayer: json['currentPlayer'],
      playerOrder: List<String>.from(json['playerOrder']),
    );
  }
}

/// Represents a card played in a trick with player information
class CardPlay {
  final String playerId;
  final Card card;
  final int position;
  final DateTime timestamp;

  CardPlay({
    required this.playerId,
    required this.card,
    required this.position,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'card': card.toJson(),
      'position': position,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory CardPlay.fromJson(Map<String, dynamic> json) {
    return CardPlay(
      playerId: json['playerId'],
      card: CardSerialization.fromJson(json['card']),
      position: json['position'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Represents a player's decision with context and outcome
class PlayerDecision {
  final String decisionId;
  final String gameContextId;
  final String playerId;
  final PlayerAction action;
  final AIRecommendation? aiSuggestion;
  final DecisionOutcome? outcome;
  final int decisionTimeMs;
  final DateTime timestamp;

  PlayerDecision({
    required this.decisionId,
    required this.gameContextId,
    required this.playerId,
    required this.action,
    this.aiSuggestion,
    this.outcome,
    required this.decisionTimeMs,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'decisionId': decisionId,
      'gameContextId': gameContextId,
      'playerId': playerId,
      'playerAction': action.toJson(),
      'aiSuggestion': aiSuggestion?.toJson(),
      'outcomeAnalysis': outcome?.toJson(),
      'decisionTime': decisionTimeMs,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory PlayerDecision.fromJson(Map<String, dynamic> json) {
    return PlayerDecision(
      decisionId: json['decisionId'],
      gameContextId: json['gameContextId'],
      playerId: json['playerId'],
      action: PlayerAction.fromJson(json['playerAction']),
      aiSuggestion: json['aiSuggestion'] != null
          ? AIRecommendation.fromJson(json['aiSuggestion'])
          : null,
      outcome: json['outcomeAnalysis'] != null
          ? DecisionOutcome.fromJson(json['outcomeAnalysis'])
          : null,
      decisionTimeMs: json['decisionTime'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Represents a player action (card play, bid, pass, etc.)
class PlayerAction {
  final String type; // play_card, bid, pass, choose_trump
  final Card? cardPlayed;
  final String? bidValue;
  final Map<String, dynamic>? additionalData;

  PlayerAction({
    required this.type,
    this.cardPlayed,
    this.bidValue,
    this.additionalData,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'cardPlayed': cardPlayed?.toJson(),
      'bidValue': bidValue,
      'additionalData': additionalData,
    };
  }

  factory PlayerAction.fromJson(Map<String, dynamic> json) {
    return PlayerAction(
      type: json['type'],
      cardPlayed: json['cardPlayed'] != null
          ? CardSerialization.fromJson(json['cardPlayed'])
          : null,
      bidValue: json['bidValue'],
      additionalData: json['additionalData'],
    );
  }
}

/// Represents AI recommendation for a decision
class AIRecommendation {
  final Card? recommendedCard;
  final String? recommendedAction;
  final double confidence;
  final String reasoning;
  final Map<String, double>? alternativeOptions;

  AIRecommendation({
    this.recommendedCard,
    this.recommendedAction,
    required this.confidence,
    required this.reasoning,
    this.alternativeOptions,
  });

  Map<String, dynamic> toJson() {
    return {
      'recommendedCard': recommendedCard?.toJson(),
      'recommendedAction': recommendedAction,
      'confidence': confidence,
      'reasoning': reasoning,
      'alternativeOptions': alternativeOptions,
    };
  }

  factory AIRecommendation.fromJson(Map<String, dynamic> json) {
    return AIRecommendation(
      recommendedCard: json['recommendedCard'] != null
          ? CardSerialization.fromJson(json['recommendedCard'])
          : null,
      recommendedAction: json['recommendedAction'],
      confidence: json['confidence'].toDouble(),
      reasoning: json['reasoning'],
      alternativeOptions: json['alternativeOptions'] != null
          ? Map<String, double>.from(json['alternativeOptions'])
          : null,
    );
  }
}

/// Represents the outcome of a decision
class DecisionOutcome {
  final bool trickWon;
  final int pointsGained;
  final String strategicValue; // high, medium, low
  final String? resultDescription;
  final bool wasOptimal;

  DecisionOutcome({
    required this.trickWon,
    required this.pointsGained,
    required this.strategicValue,
    this.resultDescription,
    required this.wasOptimal,
  });

  Map<String, dynamic> toJson() {
    return {
      'trickWon': trickWon,
      'pointsGained': pointsGained,
      'strategicValue': strategicValue,
      'resultDescription': resultDescription,
      'wasOptimal': wasOptimal,
    };
  }

  factory DecisionOutcome.fromJson(Map<String, dynamic> json) {
    return DecisionOutcome(
      trickWon: json['trickWon'],
      pointsGained: json['pointsGained'],
      strategicValue: json['strategicValue'],
      resultDescription: json['resultDescription'],
      wasOptimal: json['wasOptimal'],
    );
  }
}

/// Batch upload container for multiple log entries
class LogBatch {
  final String batchId;
  final DateTime timestamp;
  final List<GameContext> gameContexts;
  final List<PlayerDecision> playerDecisions;
  final String deviceId;
  final String appVersion;

  LogBatch({
    required this.batchId,
    required this.timestamp,
    required this.gameContexts,
    required this.playerDecisions,
    required this.deviceId,
    required this.appVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'batchId': batchId,
      'timestamp': timestamp.toIso8601String(),
      'gameContexts': gameContexts.map((e) => e.toJson()).toList(),
      'playerDecisions': playerDecisions.map((e) => e.toJson()).toList(),
      'deviceId': deviceId,
      'appVersion': appVersion,
    };
  }

  factory LogBatch.fromJson(Map<String, dynamic> json) {
    return LogBatch(
      batchId: json['batchId'],
      timestamp: DateTime.parse(json['timestamp']),
      gameContexts: (json['gameContexts'] as List)
          .map((e) => GameContext.fromJson(e))
          .toList(),
      playerDecisions: (json['playerDecisions'] as List)
          .map((e) => PlayerDecision.fromJson(e))
          .toList(),
      deviceId: json['deviceId'],
      appVersion: json['appVersion'],
    );
  }
}
