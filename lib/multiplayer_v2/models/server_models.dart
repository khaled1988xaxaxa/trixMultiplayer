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
    return ServerPlayer(
      sessionId: json['sessionId'] ?? '',
      name: json['name'] ?? '',
      position: json['position'] ?? 'north',
      isAI: json['isAI'] ?? false,
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
        cardName = 'ace';
        break;
      case 'j':
        cardName = 'jack';
        break;
      case 'q':
        cardName = 'queen';
        break;
      case 'k':
        cardName = 'king';
        break;
    }
    
    return 'assets/cards/${cardName}_of_${suitName}.png';
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
