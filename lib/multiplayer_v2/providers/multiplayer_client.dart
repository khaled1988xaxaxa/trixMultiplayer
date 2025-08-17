import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../models/server_models.dart';

enum MultiplayerState {
  disconnected,
  connecting,
  connected,
  inLobby,
  inRoom,
  inGame,
}

class MultiplayerClient with ChangeNotifier {
  static final MultiplayerClient _instance = MultiplayerClient._internal();
  factory MultiplayerClient() => _instance;
  MultiplayerClient._internal();

  final WebSocketService _websocket = WebSocketService();
  
  // State
  MultiplayerState _state = MultiplayerState.disconnected;
  String? _currentRoomId;
  ServerRoom? _currentRoom;
  ServerGame? _currentGame;
  String? _playerName;
  String? _serverUrl;
  List<ServerRoom> _availableRooms = [];
  String? _lastError;

  // Getters
  MultiplayerState get state => _state;
  bool get isConnected => _websocket.isConnected;
  String? get sessionId => _websocket.sessionId;
  String? get currentRoomId => _currentRoomId;
  ServerRoom? get currentRoom => _currentRoom;
  ServerGame? get currentGame => _currentGame;
  String? get playerName => _playerName;
  List<ServerRoom> get availableRooms => _availableRooms;
  String? get lastError => _lastError;
  String? get myPosition => _currentRoom?.players
      .firstWhere((p) => p.sessionId == sessionId, orElse: () => ServerPlayer(
        sessionId: '', name: '', position: '', isAI: false, isHost: false, isConnected: false))
      .position;
  bool get isHost => _currentRoom?.players
      .any((p) => p.sessionId == sessionId && p.isHost) ?? false;

  Future<bool> connect(String serverUrl, String playerName) async {
    if (_state != MultiplayerState.disconnected) {
      await disconnect();
    }

    _setState(MultiplayerState.connecting);
    _serverUrl = serverUrl;
    _playerName = playerName;
    _clearError();

    try {
      final success = await _websocket.connect(serverUrl, playerName: playerName);
      if (success) {
        _setState(MultiplayerState.connected);
        _startListening();
        return true;
      } else {
        _setError('Failed to connect to server');
        _setState(MultiplayerState.disconnected);
        return false;
      }
    } catch (e) {
      _setError('Connection error: $e');
      _setState(MultiplayerState.disconnected);
      return false;
    }
  }

  Future<void> disconnect() async {
    await _websocket.disconnect();
    _setState(MultiplayerState.disconnected);
    _currentRoomId = null;
    _currentRoom = null;
    _currentGame = null;
    _availableRooms = [];
    _clearError();
  }

  void createRoom(String roomName, {Map<String, dynamic>? settings}) {
    if (_state != MultiplayerState.connected) {
      _setError('Not connected to server');
      return;
    }
    
    _websocket.createRoom(roomName, settings: settings);
  }

  void joinRoom(String roomId) {
    if (_state != MultiplayerState.connected || _playerName == null) {
      _setError('Not connected or no player name');
      return;
    }
    
    _websocket.joinRoom(roomId, _playerName!);
  }

  void leaveRoom() {
    if (_currentRoomId == null) return;
    
    _websocket.leaveRoom(_currentRoomId!);
    _currentRoomId = null;
    _currentRoom = null;
    _currentGame = null;
    _setState(MultiplayerState.connected);
  }

  void startGame() {
    if (_currentRoomId == null || !isHost) {
      _setError('Cannot start game: not host or not in room');
      return;
    }
    
    _websocket.startGame(_currentRoomId!);
  }

  void selectContract(String contract) {
    if (_currentRoomId == null || _currentGame == null) {
      _setError('Cannot select contract: not in game');
      return;
    }
    
    _websocket.selectContract(_currentRoomId!, contract);
  }

  void playCard(String cardId) {
    if (_currentRoomId == null || _currentGame == null) {
      _setError('Cannot play card: not in game');
      return;
    }
    
    _websocket.playCard(_currentRoomId!, cardId);
  }

  void sendChatMessage(String message) {
    if (_currentRoomId == null) return;
    _websocket.sendChatMessage(_currentRoomId!, message);
  }

  void requestRoomList() {
    if (_state != MultiplayerState.connected) return;
    _websocket.sendMessage({'type': 'LIST_ROOMS'});
  }

  void _startListening() {
    _websocket.messageStream.listen(
      _handleMessage,
      onError: (error) {
        if (kDebugMode) print('❌ Message stream error: $error');
        _setError('Connection error: $error');
      },
    );
  }

  void _handleMessage(ServerMessage message) {
    if (kDebugMode) print('🎮 Handling: ${message.type}');

    switch (message.type) {
      case 'ROOM_CREATED':
        _handleRoomCreated(message);
        break;
      case 'ROOM_JOINED':
        _handleRoomJoined(message);
        break;
      case 'ROOM_LEFT':
        _handleRoomLeft(message);
        break;
      case 'ROOM_UPDATE':
        _handleRoomUpdate(message);
        break;
      case 'GAME_STATE_UPDATE':
        _handleGameStateUpdate(message);
        break;
      case 'PLAYER_ACTION':
        _handlePlayerAction(message);
        break;
      case 'CHAT_MESSAGE':
        _handleChatMessage(message);
        break;
      case 'ROOMS_LIST':
        _handleRoomsList(message);
        break;
      case 'AI_ADDED':
        _handleAIAdded(message);
        break;
      case 'AI_REMOVED':
        _handleAIRemoved(message);
        break;
      case 'PLAYER_KICKED':
        _handlePlayerKicked(message);
        break;
      case 'KICKED_FROM_ROOM':
        _handleKickedFromRoom(message);
        break;
      case 'GAME_STARTED':
        _handleGameStarted(message);
        break;
      case 'ERROR':
        _handleError(message);
        break;
      default:
        if (kDebugMode) print('🤷 Unhandled message type: ${message.type}');
    }
  }

  void _handleRoomCreated(ServerMessage message) {
    final roomData = message.data['room'];
    if (roomData != null) {
      _currentRoom = ServerRoom.fromJson(roomData);
      _currentRoomId = _currentRoom!.id;
      _setState(MultiplayerState.inRoom);
      _clearError();
    }
  }

  void _handleRoomJoined(ServerMessage message) {
    final roomData = message.data['room'];
    if (roomData != null) {
      _currentRoom = ServerRoom.fromJson(roomData);
      _currentRoomId = _currentRoom!.id;
      _setState(MultiplayerState.inRoom);
      _clearError();
    }
  }

  void _handleRoomLeft(ServerMessage message) {
    _currentRoomId = null;
    _currentRoom = null;
    _currentGame = null;
    _setState(MultiplayerState.connected);
  }

  void _handleRoomUpdate(ServerMessage message) {
    final roomData = message.data['room'];
    if (roomData != null) {
      final roomId = roomData['id'];
      // Update if we're in this room or if we don't have a current room
      if (_currentRoomId == null || roomId == _currentRoomId) {
        _currentRoom = ServerRoom.fromJson(roomData);
        _currentRoomId = roomId;
        notifyListeners();
        if (kDebugMode) print('🏠 Room updated: ${_currentRoom?.name} (${_currentRoom?.players.length} players)');
      }
    }
  }

  void _handleGameStateUpdate(ServerMessage message) {
    final gameData = message.data['gameState'];
    if (gameData != null) {
      _currentGame = ServerGame.fromJson(gameData);
      _setState(MultiplayerState.inGame);
      notifyListeners();
    }
  }

  void _handlePlayerAction(ServerMessage message) {
    // Handle real-time player actions if needed
    notifyListeners();
  }

  void _handleChatMessage(ServerMessage message) {
    // Handle chat messages if needed
    notifyListeners();
  }

  void _handleRoomsList(ServerMessage message) {
    print('🔍 Raw ROOMS_LIST data: ${message.data}');
    final roomsData = message.data['rooms'] as List?;
    if (roomsData != null) {
      print('🔍 Rooms array: $roomsData');
      for (int i = 0; i < roomsData.length; i++) {
        print('🔍 Room $i: ${roomsData[i]}');
      }
      _availableRooms = roomsData
          .map((r) => ServerRoom.fromJson(r))
          .toList();
      notifyListeners();
    } else {
      print('🔍 No rooms data found in message');
    }
  }

  void _handleError(ServerMessage message) {
    final errorData = message.data['error'];
    if (errorData != null) {
      String errorMessage = errorData['message'] ?? 'Unknown error';
      _setError(errorMessage);
    }
  }

  void _handleAIAdded(ServerMessage message) {
    print('🤖 AI bot added successfully');
    final roomData = message.data['room'];
    if (roomData != null) {
      _currentRoom = ServerRoom.fromJson(roomData);
      notifyListeners();
    }
  }

  void _handleAIRemoved(ServerMessage message) {
    print('🤖 AI bot removed successfully');
    final roomData = message.data['room'];
    if (roomData != null) {
      _currentRoom = ServerRoom.fromJson(roomData);
      notifyListeners();
    }
  }

  void _handlePlayerKicked(ServerMessage message) {
    print('👤 Player kicked successfully');
    final roomData = message.data['room'];
    if (roomData != null) {
      _currentRoom = ServerRoom.fromJson(roomData);
      notifyListeners();
    }
  }

  void _handleKickedFromRoom(ServerMessage message) {
    print('😓 You were kicked from the room');
    _currentRoom = null;
    _setState(MultiplayerState.connected);
    _setError('You were kicked from the room by the host');
  }

  void _handleGameStarted(ServerMessage message) {
    print('🎮 Game started! Transitioning to game screen...');
    print('🔍 Raw game data: ${message.data}');
    
    final gameStateData = message.data['gameState'];
    if (gameStateData != null) {
      print('🔍 Game state data: $gameStateData');
      try {
        _currentGame = ServerGame.fromJson(gameStateData);
        _setState(MultiplayerState.inGame);
        notifyListeners();
        print('✅ Successfully parsed game state');
      } catch (e) {
        print('❌ Error parsing game state: $e');
        _setError('Failed to parse game state: $e');
      }
    } else {
      print('⚠️ No game state data in GAME_STARTED message');
      // Still transition to game state even without game data
      _setState(MultiplayerState.inGame);
      notifyListeners();
    }
  }

  void _setState(MultiplayerState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _lastError = error;
    if (kDebugMode) print('❌ Multiplayer error: $error');
    notifyListeners();
  }

  void _clearError() {
    _lastError = null;
  }

  // Helper method to get player's cards
  // Note: Cards are typically sent separately for security reasons in multiplayer games
  // The server game state only contains handSize, not actual cards
  List<dynamic> getMyCards() {
    // TODO: Implement proper card handling through separate WebSocket messages
    // For now, return empty list until we implement card dealing messages
    return [];
  }

  // Helper method to check if it's my turn
  bool get isMyTurn {
    if (_currentGame == null) return false;
    return _currentGame!.currentPlayer == myPosition;
  }

  // Helper method to get current trick cards
  Map<String, dynamic>? getCurrentTrick() {
    if (_currentGame?.currentTrick == null) return null;
    
    final trick = _currentGame!.currentTrick!;
    return {
      'cards': trick.cards,
      'winner': trick.winner,
      'isComplete': trick.isComplete,
    };
  }

  // Quick reconnect method
  Future<bool> reconnect() async {
    if (_serverUrl != null && _playerName != null) {
      return await connect(_serverUrl!, _playerName!);
    }
    return false;
  }

  // AI Bot Management Methods
  void addBot({String? botName, String? difficulty}) {
    if (!isHost || _currentRoom == null) return;
    
    final message = {
      'type': 'ADD_BOT',
      'roomId': _currentRoom!.id,
      'botName': botName ?? 'AI Bot ${_currentRoom!.players.length + 1}',
      'difficulty': difficulty ?? 'medium',
    };
    
    _websocket.sendMessage(message);
    print('📤 Sent: ADD_BOT');
  }

  void removeBot(String botId) {
    if (!isHost || _currentRoom == null) return;
    
    final message = {
      'type': 'REMOVE_BOT',
      'roomId': _currentRoom!.id,
      'botId': botId,
    };
    
    _websocket.sendMessage(message);
    print('📤 Sent: REMOVE_BOT');
  }

  void kickPlayer(String playerId) {
    if (!isHost || _currentRoom == null) return;
    
    final message = {
      'type': 'KICK_PLAYER',
      'roomId': _currentRoom!.id,
      'playerId': playerId,
    };
    
    _websocket.sendMessage(message);
    print('📤 Sent: KICK_PLAYER');
  }

  // Helper methods for UI
  bool get canAddBot => isHost && _currentRoom != null && _currentRoom!.players.length < 4;
  int get availableBotSlots => _currentRoom != null ? 4 - _currentRoom!.players.length : 0;
  List<ServerPlayer> get humanPlayers => _currentRoom?.players.where((p) => !p.isAI).toList() ?? [];
  List<ServerPlayer> get botPlayers => _currentRoom?.players.where((p) => p.isAI).toList() ?? [];
}
