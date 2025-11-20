import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import '../models/server_models.dart';

enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed
}

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamController<ServerMessage>? _messageController;
  StreamController<ConnectionState>? _connectionStateController;
  String? _sessionId;
  String? _playerName;
  String? _serverUrl; // Store server URL for reconnection
  ConnectionState _connectionState = ConnectionState.disconnected;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  DateTime? _lastHeartbeatResponse;
  bool _manualDisconnect = false;
  
  static const int maxReconnectAttempts = 10;
  static const Duration heartbeatInterval = Duration(seconds: 20);
  static const Duration heartbeatTimeout = Duration(seconds: 10);
  static const Duration baseReconnectDelay = Duration(seconds: 1);
  static const Duration maxReconnectDelay = Duration(seconds: 30);

  String? get sessionId => _sessionId;
  bool get isConnected => _connectionState == ConnectionState.connected;
  ConnectionState get connectionState => _connectionState;
  Stream<ServerMessage> get messageStream => _messageController?.stream ?? const Stream.empty();
  Stream<ConnectionState> get connectionStateStream => _connectionStateController?.stream ?? const Stream.empty();

  Future<bool> connect(String serverUrl, {String? playerName}) async {
    try {
      if (kDebugMode) print('🔌 Connecting to WebSocket: $serverUrl');
      
      // Store connection details for reconnection
      _serverUrl = serverUrl;
      _playerName = playerName;
      _manualDisconnect = false;
      
      _setConnectionState(ConnectionState.connecting);
      
      // Close existing connection if any
      await _closeConnection();
      
      // Create new connection
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      _messageController ??= StreamController<ServerMessage>.broadcast();
      _connectionStateController ??= StreamController<ConnectionState>.broadcast();
      
      // Listen to messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
        cancelOnError: false,
      );
      
      // Wait for connection confirmation or timeout
      final completer = Completer<bool>();
      Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          _setConnectionState(ConnectionState.failed);
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
            _setConnectionState(ConnectionState.connected);
            _reconnectAttempts = 0;
            _lastHeartbeatResponse = DateTime.now();
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
      _setConnectionState(ConnectionState.failed);
      return false;
    }
  }

  Future<void> disconnect() async {
    if (kDebugMode) print('🔌 Manually disconnecting WebSocket');
    
    _manualDisconnect = true;
    _reconnectAttempts = 0;
    
    await _closeConnection();
    _setConnectionState(ConnectionState.disconnected);
  }
  
  Future<void> _closeConnection() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    await _channel?.sink.close();
    _channel = null;
    
    _sessionId = null;
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_connectionState != ConnectionState.connected || _channel == null) {
      if (kDebugMode) print('❌ Cannot send message: not connected (state: $_connectionState)');
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
      _handleError(e);
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

  void _setConnectionState(ConnectionState newState) {
    if (_connectionState != newState) {
      _connectionState = newState;
      _connectionStateController?.add(newState);
      if (kDebugMode) print('🔄 Connection state changed to: $newState');
    }
  }

  void _handleMessage(dynamic rawMessage) {
    try {
      final messageData = jsonDecode(rawMessage);
      final message = ServerMessage.fromJson(messageData);
      
      if (kDebugMode) print('📥 Received: ${message.type}');
      
      // Handle special system messages
      if (message.type == 'PONG') {
        _lastHeartbeatResponse = DateTime.now();
        return;
      }
      
      _messageController?.add(message);
      
    } catch (e) {
      if (kDebugMode) print('❌ Error parsing message: $e');
    }
  }

  void _handleError(error) {
    if (kDebugMode) print('❌ WebSocket error: $error');
    if (_connectionState == ConnectionState.connected) {
      _setConnectionState(ConnectionState.reconnecting);
    }
    _attemptReconnect();
  }

  void _handleDisconnection() {
    if (kDebugMode) print('🔌 WebSocket disconnected');
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    
    if (!_manualDisconnect && _connectionState == ConnectionState.connected) {
      _setConnectionState(ConnectionState.reconnecting);
      _attemptReconnect();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) {
      if (_connectionState == ConnectionState.connected) {
        // Check if last heartbeat response was too long ago
        if (_lastHeartbeatResponse != null && 
            DateTime.now().difference(_lastHeartbeatResponse!) > heartbeatTimeout) {
          if (kDebugMode) print('💔 Heartbeat timeout detected');
          _handleError('Heartbeat timeout');
          return;
        }
        
        sendMessage({'type': 'PING', 'data': {}});
      } else {
        timer.cancel();
      }
    });
  }

  void _attemptReconnect() {
    if (_manualDisconnect || _reconnectAttempts >= maxReconnectAttempts) {
      if (_reconnectAttempts >= maxReconnectAttempts) {
        if (kDebugMode) print('❌ Max reconnection attempts reached');
        _setConnectionState(ConnectionState.failed);
      }
      return;
    }

    _reconnectAttempts++;
    if (kDebugMode) print('🔄 Attempting reconnect $_reconnectAttempts/$maxReconnectAttempts');
    
    // Calculate exponential backoff delay
    final delayMs = min(
      baseReconnectDelay.inMilliseconds * pow(2, _reconnectAttempts - 1),
      maxReconnectDelay.inMilliseconds
    ).toInt();
    final delay = Duration(milliseconds: delayMs);
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (_manualDisconnect) return;
      
      if (kDebugMode) print('🔄 Reconnecting to $_serverUrl...');
      
      if (_serverUrl != null) {
        final success = await connect(_serverUrl!, playerName: _playerName);
        if (!success && !_manualDisconnect) {
          _attemptReconnect();
        }
      }
    });
  }
  
  void dispose() {
    _manualDisconnect = true;
    _closeConnection();
    
    if (_messageController != null && !_messageController!.isClosed) {
      _messageController!.close();
    }
    _messageController = null;
    
    if (_connectionStateController != null && !_connectionStateController!.isClosed) {
      _connectionStateController!.close();
    }
    _connectionStateController = null;
  }
}
