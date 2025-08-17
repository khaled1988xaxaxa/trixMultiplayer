import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import '../models/server_models.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamController<ServerMessage>? _messageController;
  String? _sessionId;
  String? _playerName; // Store player name for convenience methods
  bool _isConnected = false;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration heartbeatInterval = Duration(seconds: 30);
  static const Duration reconnectDelay = Duration(seconds: 3);

  String? get sessionId => _sessionId;
  bool get isConnected => _isConnected;
  Stream<ServerMessage> get messageStream => _messageController?.stream ?? const Stream.empty();

  Future<bool> connect(String serverUrl, {String? playerName}) async {
    try {
      if (kDebugMode) print('🔌 Connecting to WebSocket: $serverUrl');
      
      // Store player name for later use
      _playerName = playerName;
      
      // Close existing connection if any
      await disconnect();
      
      // Create new connection
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      _messageController = StreamController<ServerMessage>.broadcast();
      
      // Listen to messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );
      
      // Wait for connection confirmation or timeout
      final completer = Completer<bool>();
      Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });
      
      // Listen for session ID (connection confirmation)
      late StreamSubscription subscription;
      subscription = messageStream.listen((message) {
        if (message.type == 'CONNECTION_ESTABLISHED') {
          final sessionId = message.data['sessionId'];
          
          if (sessionId != null) {
            _sessionId = sessionId;
            _isConnected = true;
            _reconnectAttempts = 0;
            _startHeartbeat();
            
            if (!completer.isCompleted) {
              completer.complete(true);
            }
            subscription.cancel();
          }
        }
      });
      
      final success = await completer.future;
      if (kDebugMode) print(success ? '✅ WebSocket connected' : '❌ WebSocket connection failed');
      return success;
      
    } catch (e) {
      if (kDebugMode) print('❌ WebSocket connection error: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    if (kDebugMode) print('🔌 Disconnecting WebSocket');
    
    _isConnected = false;
    _sessionId = null;
    _reconnectAttempts = 0;
    
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    
    await _channel?.sink.close();
    _channel = null;
    
    await _messageController?.close();
    _messageController = null;
  }

  void sendMessage(Map<String, dynamic> message) {
    if (!_isConnected || _channel == null) {
      if (kDebugMode) print('❌ Cannot send message: not connected');
      return;
    }

    try {
      final jsonMessage = jsonEncode({
        ...message,
        'sessionId': _sessionId,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      _channel!.sink.add(jsonMessage);
      if (kDebugMode) print('📤 Sent: ${message['type']}');
      
    } catch (e) {
      if (kDebugMode) print('❌ Error sending message: $e');
    }
  }

  // Convenience methods for common actions
  void createRoom(String roomName, {Map<String, dynamic>? settings}) {
    sendMessage({
      'type': 'CREATE_ROOM',
      'playerName': _getPlayerName(),
      'roomSettings': settings ?? {},
    });
  }

  void joinRoom(String roomId, String playerName) {
    sendMessage({
      'type': 'JOIN_ROOM',
      'roomId': roomId,
      'playerName': playerName,
    });
  }

  void leaveRoom(String roomId) {
    sendMessage({
      'type': 'LEAVE_ROOM',
    });
  }

  void startGame(String roomId) {
    sendMessage({
      'type': 'START_GAME',
    });
  }

  void selectContract(String roomId, String contract) {
    sendMessage({
      'type': 'SELECT_CONTRACT',
      'contract': contract,
    });
  }

  void playCard(String roomId, String cardId) {
    sendMessage({
      'type': 'PLAY_CARD',
      'cardId': cardId,
    });
  }

  void sendChatMessage(String roomId, String message) {
    sendMessage({
      'type': 'CHAT_MESSAGE',
      'message': message,
    });
  }

  String _getPlayerName() {
    return _playerName ?? 'Player${DateTime.now().millisecondsSinceEpoch % 1000}';
  }

  void _handleMessage(dynamic rawMessage) {
    try {
      final messageData = jsonDecode(rawMessage);
      final message = ServerMessage.fromJson(messageData);
      
      if (kDebugMode) print('📥 Received: ${message.type}');
      
      // Handle special system messages
      if (message.type == 'PONG') {
        // Heartbeat response - just log
        return;
      }
      
      _messageController?.add(message);
      
    } catch (e) {
      if (kDebugMode) print('❌ Error parsing message: $e');
    }
  }

  void _handleError(error) {
    if (kDebugMode) print('❌ WebSocket error: $error');
    _isConnected = false;
    _attemptReconnect();
  }

  void _handleDisconnection() {
    if (kDebugMode) print('🔌 WebSocket disconnected');
    _isConnected = false;
    _heartbeatTimer?.cancel();
    _attemptReconnect();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) {
      if (_isConnected) {
        sendMessage({'type': 'PING', 'data': {}});
      } else {
        timer.cancel();
      }
    });
  }

  void _attemptReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      if (kDebugMode) print('❌ Max reconnection attempts reached');
      return;
    }

    _reconnectAttempts++;
    if (kDebugMode) print('🔄 Attempting reconnect $_reconnectAttempts/$maxReconnectAttempts');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, () async {
      // Try to reconnect to the same server
      // Note: You might want to store the server URL for reconnection
      if (kDebugMode) print('🔄 Reconnecting...');
      // Implementation depends on how you want to handle reconnection
      // You might need to emit an event that the UI can listen to
    });
  }
}
