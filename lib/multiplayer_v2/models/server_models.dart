/// Server-side models for Trix multiplayer game
/// These represent the state as managed by the server

class ServerRoom {
  final String id;
  final String name;
  final String hostId;
  final List<ServerPlayer> players;
  final String status; // 'waiting', 'playing', 'finished'
  final ServerRoomSettings settings;
  final DateTime createdAt;
  final ServerGame? game;

  ServerRoom({
    required this.id,
    required this.name,
    required this.hostId,
    required this.players,
    required this.status,
    required this.settings,
    required this.createdAt,
    this.game,
  });

  factory ServerRoom.fromJson(Map<String, dynamic> json) {
    // Handle players field - could be a list of players or just a count
    List<ServerPlayer> playersList = [];
    if (json['players'] is List) {
      playersList = (json['players'] as List)
          .map((p) => ServerPlayer.fromJson(p))
          .toList();
    } else if (json['players'] is int) {
      // Server sent player count instead of player list - create empty list
      playersList = [];
    }
    
    return ServerRoom(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      hostId: json['hostId'] ?? '',
      players: playersList,
      status: json['status'] ?? 'waiting',
      settings: json['settings'] != null 
          ? ServerRoomSettings.fromJson(json['settings']) 
          : ServerRoomSettings(
              maxPlayers: 4, 
              isPrivate: false,
              aiDifficulty: 'medium',
              allowSpectators: true,
              gameSpeed: 'normal'
            ),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      game: json['game'] != null ? ServerGame.fromJson(json['game']) : null,
    );
  }
}

class ServerPlayer {
  final String sessionId;
  final String name;
  final String position; // 'north', 'south', 'east', 'west'
  final bool isAI;
  final bool isHost;
  final bool isConnected;

  ServerPlayer({
    required this.sessionId,
    required this.name,
    required this.position,
    required this.isAI,
    required this.isHost,
    required this.isConnected,
  });

  factory ServerPlayer.fromJson(Map<String, dynamic> json) {
    final isAIValue = json['isAI'] ?? false;
    print('[DEBUG] ServerPlayer.fromJson: name=${json['name']}, isAI=$isAIValue');
    return ServerPlayer(
      sessionId: json['sessionId'] ?? '',
      name: json['name'] ?? '',
      position: json['position'] ?? 'north',
      isAI: isAIValue,
      isHost: json['isHost'] ?? false,
      isConnected: json['isConnected'] ?? true,
    );
  }
}

class ServerRoomSettings {
  final int maxPlayers;
  final bool isPrivate;
  final String aiDifficulty;
  final bool allowSpectators;
  final String gameSpeed;

  ServerRoomSettings({
    required this.maxPlayers,
    required this.isPrivate,
    required this.aiDifficulty,
    required this.allowSpectators,
    required this.gameSpeed,
  });

  factory ServerRoomSettings.fromJson(Map<String, dynamic> json) {
    return ServerRoomSettings(
      maxPlayers: json['maxPlayers'] ?? 4,
      isPrivate: json['isPrivate'] ?? false,
      aiDifficulty: json['aiDifficulty'] ?? 'medium',
      allowSpectators: json['allowSpectators'] ?? true,
      gameSpeed: json['gameSpeed'] ?? 'normal',
    );
  }
}

class ServerGamePlayer {
  final String id;
  final String name;
  final String position;
  final bool isAI;
  final int tricksWon;
  final int score;
  final int totalScore;
  final bool isConnected;
  final int handSize;
  final List<ServerCard> hand;

  ServerGamePlayer({
    required this.id,
    required this.name,
    required this.position,
    required this.isAI,
    required this.tricksWon,
    required this.score,
    required this.totalScore,
    required this.isConnected,
    required this.handSize,
    required this.hand,
  });

  factory ServerGamePlayer.fromJson(Map<String, dynamic> json) {
    return ServerGamePlayer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      position: json['position'] ?? '',
      isAI: json['isAI'] ?? false,
      tricksWon: json['tricksWon'] ?? 0,
      score: json['score'] ?? 0,
      totalScore: json['totalScore'] ?? 0,
      isConnected: json['isConnected'] ?? true,
      handSize: json['handSize'] ?? 0,
      hand: json['hand'] != null
        ? List<ServerCard>.from((json['hand'] as List).map((c) => ServerCard.fromJson(c)))
        : [],
    );
  }
}

class ServerGame {
  final String gameId;
  final String phase; // 'contractSelection', 'playing', 'gameEnd'
  final String? currentContract;
  final String currentPlayer;
  final String? currentKing;
  final int round;
  final int kingdom;
  final List<String> usedContracts;
  final ServerTrick? currentTrick;
  final ServerTrick? lastCompletedTrick;
  final Map<String, int> tricksWon;
  final Map<String, ServerGamePlayer> players;
  final String timestamp;

  ServerGame({
    required this.gameId,
    required this.phase,
    this.currentContract,
    required this.currentPlayer,
    this.currentKing,
    required this.round,
    required this.kingdom,
    required this.usedContracts,
    this.currentTrick,
    this.lastCompletedTrick,
    required this.tricksWon,
    required this.players,
    required this.timestamp,
  });

  factory ServerGame.fromJson(Map<String, dynamic> json) {
    return ServerGame(
      gameId: json['id'] ?? '',
      phase: json['phase'] ?? 'waiting',
      currentContract: json['currentContract'],
      currentPlayer: json['currentPlayer'] ?? '',
      currentKing: json['currentKing'],
      round: json['round'] ?? 1,
      kingdom: json['kingdom'] ?? 1,
      usedContracts: json['usedContracts'] != null 
          ? List<String>.from(json['usedContracts'])
          : [],
      currentTrick: json['currentTrick'] != null 
          ? ServerTrick.fromJson(json['currentTrick']) 
          : null,
      lastCompletedTrick: json['lastCompletedTrick'] != null 
          ? ServerTrick.fromJson(json['lastCompletedTrick']) 
          : null,
      tricksWon: json['tricksWon'] != null 
          ? Map<String, int>.from(json['tricksWon'])
          : {},
      players: json['players'] != null
          ? Map<String, ServerGamePlayer>.from(
              json['players'].map((k, v) => MapEntry(k, ServerGamePlayer.fromJson(v)))
            )
          : {},
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class ServerCard {
  final String id;
  final String suit; // 'hearts', 'diamonds', 'clubs', 'spades'
  final String rank; // 'A', '2', '3', ... 'K'
  final int value;

  ServerCard({
    required this.id,
    required this.suit,
    required this.rank,
    required this.value,
  });

  factory ServerCard.fromJson(Map<String, dynamic> json) {
    return ServerCard(
      id: json['id'] ?? '',
      suit: json['suit'] ?? '',
      rank: json['rank'] ?? '',
      value: json['value'] ?? 0,
    );
  }

      String get imagePath {
      // Convert server card format to your existing card image format
      String suitName = suit.toLowerCase();
      String cardName = rank.toLowerCase();
      
      // Map rank names to your image naming convention
      switch (cardName) {
        case 'a':
        case 'ace':
          cardName = 'ace';
          break;
        case 'j':
        case 'jack':
          cardName = 'jack';
          break;
        case 'q':
        case 'queen':
          cardName = 'queen';
          break;
        case 'k':
        case 'king':
          cardName = 'king';
          break;
        case '10':
        case 'ten':
          cardName = '10';
          break;
        case '9':
        case 'nine':
          cardName = '9';
          break;
        case '8':
        case 'eight':
          cardName = '8';
          break;
        case '7':
        case 'seven':
          cardName = '7';
          break;
        case '6':
        case 'six':
          cardName = '6';
          break;
        case '5':
        case 'five':
          cardName = '5';
          break;
        case '4':
        case 'four':
          cardName = '4';
          break;
        case '3':
        case 'three':
          cardName = '3';
          break;
        case '2':
        case 'two':
          cardName = '2';
          break;
      }
      
      return 'assets/cards/${cardName}${suitName[0].toUpperCase()}.png';
    }
}

class ServerTrick {
  final Map<String, ServerCard?> cards; // position -> card
  final String? winner;
  final bool isComplete;

  ServerTrick({
    required this.cards,
    this.winner,
    required this.isComplete,
  });

  factory ServerTrick.fromJson(Map<String, dynamic> json) {
    return ServerTrick(
      cards: json['cards'] != null 
          ? Map<String, ServerCard?>.from(
              json['cards'].map((k, v) => MapEntry(k, 
                v != null ? ServerCard.fromJson(v) : null))
            )
          : {},
      winner: json['winner'],
      isComplete: json['isComplete'] ?? false,
    );
  }
}

// Delta update classes for optimized state synchronization
class GameStateDelta {
  final String? phase;
  final String? currentPlayer;
  final String? currentContract;
  final String? currentKing;
  final Map<String, PlayerDelta>? playerDeltas;
  final TrickDelta? currentTrickDelta;
  final TrickDelta? lastCompletedTrickDelta;
  final Map<String, int>? tricksWonDelta;
  final String timestamp;

  GameStateDelta({
    this.phase,
    this.currentPlayer,
    this.currentContract,
    this.currentKing,
    this.playerDeltas,
    this.currentTrickDelta,
    this.lastCompletedTrickDelta,
    this.tricksWonDelta,
    required this.timestamp,
  });

  factory GameStateDelta.fromJson(Map<String, dynamic> json) {
    return GameStateDelta(
      phase: json['phase'],
      currentPlayer: json['currentPlayer'],
      currentContract: json['currentContract'],
      currentKing: json['currentKing'],
      playerDeltas: json['playerDeltas'] != null
          ? Map<String, PlayerDelta>.from(
              json['playerDeltas'].map((k, v) => MapEntry(k, PlayerDelta.fromJson(v)))
            )
          : null,
      currentTrickDelta: json['currentTrickDelta'] != null
          ? TrickDelta.fromJson(json['currentTrickDelta'])
          : null,
      lastCompletedTrickDelta: json['lastCompletedTrickDelta'] != null
          ? TrickDelta.fromJson(json['lastCompletedTrickDelta'])
          : null,
      tricksWonDelta: json['tricksWonDelta'] != null
          ? Map<String, int>.from(json['tricksWonDelta'])
          : null,
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class PlayerDelta {
  final String? name;
  final bool? isConnected;
  final int? tricksWon;
  final int? score;
  final int? totalScore;
  final int? handSize;
  final List<ServerCard>? addedCards;
  final List<String>? removedCardIds;

  PlayerDelta({
    this.name,
    this.isConnected,
    this.tricksWon,
    this.score,
    this.totalScore,
    this.handSize,
    this.addedCards,
    this.removedCardIds,
  });

  factory PlayerDelta.fromJson(Map<String, dynamic> json) {
    return PlayerDelta(
      name: json['name'],
      isConnected: json['isConnected'],
      tricksWon: json['tricksWon'],
      score: json['score'],
      totalScore: json['totalScore'],
      handSize: json['handSize'],
      addedCards: json['addedCards'] != null
          ? List<ServerCard>.from((json['addedCards'] as List).map((c) => ServerCard.fromJson(c)))
          : null,
      removedCardIds: json['removedCardIds'] != null
          ? List<String>.from(json['removedCardIds'])
          : null,
    );
  }
}

class TrickDelta {
  final Map<String, ServerCard?>? cardChanges;
  final String? winner;
  final bool? isComplete;

  TrickDelta({
    this.cardChanges,
    this.winner,
    this.isComplete,
  });

  factory TrickDelta.fromJson(Map<String, dynamic> json) {
    return TrickDelta(
      cardChanges: json['cardChanges'] != null
          ? Map<String, ServerCard?>.from(
              json['cardChanges'].map((k, v) => MapEntry(k,
                v != null ? ServerCard.fromJson(v) : null))
            )
          : null,
      winner: json['winner'],
      isComplete: json['isComplete'],
    );
  }
}

// State cache for optimized updates
class GameStateCache {
  ServerGame? _cachedGame;
  String? _lastUpdateTimestamp;

  ServerGame? get cachedGame => _cachedGame;
  String? get lastUpdateTimestamp => _lastUpdateTimestamp;

  void updateWithDelta(GameStateDelta delta) {
    if (_cachedGame == null) return;

    // Create updated players map
    final updatedPlayers = Map<String, ServerGamePlayer>.from(_cachedGame!.players);
    
    if (delta.playerDeltas != null) {
      delta.playerDeltas!.forEach((position, playerDelta) {
        final existingPlayer = updatedPlayers[position];
        if (existingPlayer != null) {
          // Update hand with delta changes
          List<ServerCard> updatedHand = List.from(existingPlayer.hand);
          
          if (playerDelta.removedCardIds != null) {
            updatedHand.removeWhere((card) => playerDelta.removedCardIds!.contains(card.id));
          }
          
          if (playerDelta.addedCards != null) {
            updatedHand.addAll(playerDelta.addedCards!);
          }

          updatedPlayers[position] = ServerGamePlayer(
            id: existingPlayer.id,
            name: playerDelta.name ?? existingPlayer.name,
            position: existingPlayer.position,
            isAI: existingPlayer.isAI,
            tricksWon: playerDelta.tricksWon ?? existingPlayer.tricksWon,
            score: playerDelta.score ?? existingPlayer.score,
            totalScore: playerDelta.totalScore ?? existingPlayer.totalScore,
            isConnected: playerDelta.isConnected ?? existingPlayer.isConnected,
            handSize: playerDelta.handSize ?? existingPlayer.handSize,
            hand: updatedHand,
          );
        }
      });
    }

    // Update current trick
    ServerTrick? updatedCurrentTrick = _cachedGame!.currentTrick;
    if (delta.currentTrickDelta != null) {
      final trickDelta = delta.currentTrickDelta!;
      final existingCards = updatedCurrentTrick?.cards ?? <String, ServerCard?>{};
      final updatedCards = Map<String, ServerCard?>.from(existingCards);
      
      if (trickDelta.cardChanges != null) {
        updatedCards.addAll(trickDelta.cardChanges!);
      }
      
      updatedCurrentTrick = ServerTrick(
        cards: updatedCards,
        winner: trickDelta.winner ?? updatedCurrentTrick?.winner,
        isComplete: trickDelta.isComplete ?? updatedCurrentTrick?.isComplete ?? false,
      );
    }

    // Update last completed trick
    ServerTrick? updatedLastTrick = _cachedGame!.lastCompletedTrick;
    if (delta.lastCompletedTrickDelta != null) {
      final trickDelta = delta.lastCompletedTrickDelta!;
      final existingCards = updatedLastTrick?.cards ?? <String, ServerCard?>{};
      final updatedCards = Map<String, ServerCard?>.from(existingCards);
      
      if (trickDelta.cardChanges != null) {
        updatedCards.addAll(trickDelta.cardChanges!);
      }
      
      updatedLastTrick = ServerTrick(
        cards: updatedCards,
        winner: trickDelta.winner ?? updatedLastTrick?.winner,
        isComplete: trickDelta.isComplete ?? updatedLastTrick?.isComplete ?? false,
      );
    }

    // Update tricks won
    final updatedTricksWon = Map<String, int>.from(_cachedGame!.tricksWon);
    if (delta.tricksWonDelta != null) {
      updatedTricksWon.addAll(delta.tricksWonDelta!);
    }

    // Create updated game state
    _cachedGame = ServerGame(
      gameId: _cachedGame!.gameId,
      phase: delta.phase ?? _cachedGame!.phase,
      currentContract: delta.currentContract ?? _cachedGame!.currentContract,
      currentPlayer: delta.currentPlayer ?? _cachedGame!.currentPlayer,
      currentKing: delta.currentKing ?? _cachedGame!.currentKing,
      round: _cachedGame!.round,
      kingdom: _cachedGame!.kingdom,
      usedContracts: _cachedGame!.usedContracts,
      currentTrick: updatedCurrentTrick,
      lastCompletedTrick: updatedLastTrick,
      tricksWon: updatedTricksWon,
      players: updatedPlayers,
      timestamp: delta.timestamp,
    );
    
    _lastUpdateTimestamp = delta.timestamp;
  }

  void updateWithFullState(ServerGame game) {
    _cachedGame = game;
    _lastUpdateTimestamp = game.timestamp;
  }

  void clear() {
    _cachedGame = null;
    _lastUpdateTimestamp = null;
  }
}

// WebSocket message types
class ServerMessage {
  final String type;
  final Map<String, dynamic> data;
  final String? roomId;
  final String? senderId;
  final DateTime timestamp;

  ServerMessage({
    required this.type,
    required this.data,
    this.roomId,
    this.senderId,
    required this.timestamp,
  });

  factory ServerMessage.fromJson(Map<String, dynamic> json) {
    // Create data map from all fields except the core message fields
    Map<String, dynamic> data = Map<String, dynamic>.from(json);
    data.remove('type');
    data.remove('roomId');
    data.remove('senderId');
    data.remove('timestamp');
    
    // If there's already a 'data' field, merge with the extracted fields
    if (json['data'] != null) {
      final existingData = Map<String, dynamic>.from(json['data']);
      data = {...data, ...existingData};
    }
    
    return ServerMessage(
      type: json['type'],
      data: data,
      roomId: json['roomId'],
      senderId: json['senderId'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': data,
      'roomId': roomId,
      'senderId': senderId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
