import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_log_models.dart';
import '../models/card.dart';

/// Service responsible for collecting and managing AI training data
class GameLoggingService {
  static GameLoggingService? _instance;
  static GameLoggingService get instance => _instance ??= GameLoggingService._();
  
  GameLoggingService._();

  Database? _database;
  final List<GameContext> _contextQueue = [];
  final List<PlayerDecision> _decisionQueue = [];
  Timer? _syncTimer;
  bool _isEnabled = false;
  String? _deviceId;
  
  // Configuration
  static const String _baseUrl = 'http://192.168.0.136:3001'; // Your computer's IP address
  static const String _apiKey = '123456789'; // API key from .env
  static const Duration _syncInterval = Duration(minutes: 5);
  static const int _maxQueueSize = 5; // Reduced for testing - normally 100

  /// Initialize the logging service
  Future<void> initialize() async {
    await _initializeDatabase();
    await _loadSettings();
    await _generateDeviceId();
    
    if (_isEnabled) {
      _startPeriodicSync();
    }
  }

  /// Check if logging is enabled by user preference
  bool get isEnabled => _isEnabled;

  /// Enable or disable logging with user consent
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_logging_enabled', enabled);
    
    if (enabled) {
      _startPeriodicSync();
    } else {
      _stopPeriodicSync();
      await clearAllData();
    }
  }

  /// Get user consent status
  Future<bool> hasUserConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('ai_logging_consent') ?? false;
  }

  /// Set user consent for data collection
  Future<void> setUserConsent(bool consent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_logging_consent', consent);
    
    if (!consent) {
      await setEnabled(false);
    }
  }

  /// Log a game context at a decision point
  Future<void> logGameContext(GameContext context) async {
    if (!_isEnabled) return;

    try {
      // Add to queue
      _contextQueue.add(context);
      
      // Store in local database
      await _insertGameContext(context);
      
      // Trigger sync if queue is getting full
      if (_contextQueue.length >= _maxQueueSize) {
        await _syncData();
      }
    } catch (e) {
      print('Error logging game context: $e');
    }
  }

  /// Log a player decision
  Future<void> logPlayerDecision(PlayerDecision decision) async {
    if (!_isEnabled) return;

    try {
      // Add to queue
      _decisionQueue.add(decision);
      
      // Store in local database
      await _insertPlayerDecision(decision);
      
      // Trigger sync if queue is getting full
      if (_decisionQueue.length >= _maxQueueSize) {
        await _syncData();
      }
    } catch (e) {
      print('Error logging player decision: $e');
    }
  }

  /// Create a game context helper method
  Future<GameContext> createGameContext({
    required String gameId,
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
    return GameContext(
      gameId: gameId,
      timestamp: DateTime.now(),
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
  }

  /// Create a player decision helper method
  Future<PlayerDecision> createPlayerDecision({
    required String gameContextId,
    required String playerId,
    required PlayerAction action,
    AIRecommendation? aiSuggestion,
    DecisionOutcome? outcome,
    required int decisionTimeMs,
  }) async {
    return PlayerDecision(
      decisionId: const Uuid().v4(),
      gameContextId: gameContextId,
      playerId: playerId,
      action: action,
      aiSuggestion: aiSuggestion,
      outcome: outcome,
      decisionTimeMs: decisionTimeMs,
      timestamp: DateTime.now(),
    );
  }

  /// Force sync data to server (for testing purposes)
  Future<void> forceSyncForTesting() async {
    await _syncData();
  }

  /// Sync data to remote server
  Future<void> _syncData() async {
    if (!_isEnabled || !await _hasInternetConnection()) return;

    try {
      // Create batch
      final batch = LogBatch(
        batchId: const Uuid().v4(),
        timestamp: DateTime.now(),
        gameContexts: List.from(_contextQueue),
        playerDecisions: List.from(_decisionQueue),
        deviceId: _deviceId!,
        appVersion: await _getAppVersion(),
      );

      // Send to server
      final response = await http.post(
        Uri.parse('$_baseUrl/api/game-logs/batch'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(batch.toJson()),
      );

      if (response.statusCode == 200) {
        // Clear queues on successful upload
        _contextQueue.clear();
        _decisionQueue.clear();
        
        // Remove synced data from local database
        await _clearSyncedData();
        
        print('Successfully synced ${batch.gameContexts.length} contexts and ${batch.playerDecisions.length} decisions');
      } else {
        print('Failed to sync data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error syncing data: $e');
    }
  }

  /// Initialize local SQLite database
  Future<void> _initializeDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'ai_training_logs.db');
    
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Game contexts table
        await db.execute('''
          CREATE TABLE game_contexts (
            game_id TEXT PRIMARY KEY,
            timestamp TEXT NOT NULL,
            kingdom TEXT NOT NULL,
            round INTEGER NOT NULL,
            current_trick_number INTEGER NOT NULL,
            leading_suit TEXT,
            cards_played_in_trick TEXT NOT NULL,
            player_hand TEXT NOT NULL,
            game_score TEXT NOT NULL,
            available_cards TEXT NOT NULL,
            current_player TEXT NOT NULL,
            player_order TEXT NOT NULL,
            synced INTEGER DEFAULT 0
          )
        ''');

        // Player decisions table
        await db.execute('''
          CREATE TABLE player_decisions (
            decision_id TEXT PRIMARY KEY,
            game_context_id TEXT NOT NULL,
            player_id TEXT NOT NULL,
            action TEXT NOT NULL,
            ai_suggestion TEXT,
            outcome TEXT,
            decision_time_ms INTEGER NOT NULL,
            timestamp TEXT NOT NULL,
            synced INTEGER DEFAULT 0,
            FOREIGN KEY (game_context_id) REFERENCES game_contexts (game_id)
          )
        ''');
      },
    );
  }

  /// Insert game context into local database
  Future<void> _insertGameContext(GameContext context) async {
    if (_database == null) return;

    await _database!.insert(
      'game_contexts',
      {
        'game_id': context.gameId,
        'timestamp': context.timestamp.toIso8601String(),
        'kingdom': context.kingdom,
        'round': context.round,
        'current_trick_number': context.currentTrickNumber,
        'leading_suit': context.leadingSuit,
        'cards_played_in_trick': jsonEncode(context.cardsPlayedInTrick.map((e) => e.toJson()).toList()),
        'player_hand': jsonEncode(context.playerHand.map((e) => e.toJson()).toList()),
        'game_score': jsonEncode(context.gameScore),
        'available_cards': jsonEncode(context.availableCards.map((e) => e.toJson()).toList()),
        'current_player': context.currentPlayer,
        'player_order': jsonEncode(context.playerOrder),
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert player decision into local database
  Future<void> _insertPlayerDecision(PlayerDecision decision) async {
    if (_database == null) return;

    await _database!.insert(
      'player_decisions',
      {
        'decision_id': decision.decisionId,
        'game_context_id': decision.gameContextId,
        'player_id': decision.playerId,
        'action': jsonEncode(decision.action.toJson()),
        'ai_suggestion': decision.aiSuggestion != null ? jsonEncode(decision.aiSuggestion!.toJson()) : null,
        'outcome': decision.outcome != null ? jsonEncode(decision.outcome!.toJson()) : null,
        'decision_time_ms': decision.decisionTimeMs,
        'timestamp': decision.timestamp.toIso8601String(),
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Load unsynced data from database to queues
  Future<void> _loadUnsyncedData() async {
    if (_database == null) return;

    try {
      // Load game contexts
      final contextMaps = await _database!.query(
        'game_contexts',
        where: 'synced = ?',
        whereArgs: [0],
      );

      for (final map in contextMaps) {
        // Reconstruct GameContext from database
        final context = GameContext(
          gameId: map['game_id'] as String,
          timestamp: DateTime.parse(map['timestamp'] as String),
          kingdom: map['kingdom'] as String,
          round: map['round'] as int,
          currentTrickNumber: map['current_trick_number'] as int,
          leadingSuit: map['leading_suit'] as String?,
          cardsPlayedInTrick: (jsonDecode(map['cards_played_in_trick'] as String) as List)
              .map((e) => CardPlay.fromJson(e))
              .toList(),
          playerHand: (jsonDecode(map['player_hand'] as String) as List)
              .map((e) => CardSerialization.fromJson(e))
              .toList(),
          gameScore: Map<String, int>.from(jsonDecode(map['game_score'] as String)),
          availableCards: (jsonDecode(map['available_cards'] as String) as List)
              .map((e) => CardSerialization.fromJson(e))
              .toList(),
          currentPlayer: map['current_player'] as String,
          playerOrder: List<String>.from(jsonDecode(map['player_order'] as String)),
        );
        
        _contextQueue.add(context);
      }

      // Load player decisions
      final decisionMaps = await _database!.query(
        'player_decisions',
        where: 'synced = ?',
        whereArgs: [0],
      );

      for (final map in decisionMaps) {
        final decision = PlayerDecision(
          decisionId: map['decision_id'] as String,
          gameContextId: map['game_context_id'] as String,
          playerId: map['player_id'] as String,
          action: PlayerAction.fromJson(jsonDecode(map['action'] as String)),
          aiSuggestion: map['ai_suggestion'] != null 
              ? AIRecommendation.fromJson(jsonDecode(map['ai_suggestion'] as String))
              : null,
          outcome: map['outcome'] != null 
              ? DecisionOutcome.fromJson(jsonDecode(map['outcome'] as String))
              : null,
          decisionTimeMs: map['decision_time_ms'] as int,
          timestamp: DateTime.parse(map['timestamp'] as String),
        );
        
        _decisionQueue.add(decision);
      }
    } catch (e) {
      print('Error loading unsynced data: $e');
    }
  }

  /// Clear synced data from local database
  Future<void> _clearSyncedData() async {
    if (_database == null) return;

    await _database!.delete('game_contexts', where: 'synced = ?', whereArgs: [1]);
    await _database!.delete('player_decisions', where: 'synced = ?', whereArgs: [1]);
  }

  /// Clear all data (for user privacy)
  Future<void> clearAllData() async {
    if (_database == null) return;

    _contextQueue.clear();
    _decisionQueue.clear();
    
    await _database!.delete('game_contexts');
    await _database!.delete('player_decisions');
  }

  /// Start periodic sync timer
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => _syncData());
  }

  /// Stop periodic sync timer
  void _stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Check internet connectivity
  Future<bool> _hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  /// Load user settings
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // For testing: Auto-enable logging and consent
    final hasConsent = prefs.getBool('ai_logging_consent') ?? false;
    if (!hasConsent) {
      await prefs.setBool('ai_logging_consent', true);
      print('🔧 Auto-enabled AI logging consent for testing');
    }
    
    _isEnabled = prefs.getBool('ai_logging_enabled') ?? true; // Default to true for testing
    if (_isEnabled) {
      await prefs.setBool('ai_logging_enabled', true);
      print('✅ AI Logging enabled for testing');
    }
  }

  /// Generate unique device ID
  Future<void> _generateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');
    
    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      await prefs.setString('device_id', _deviceId!);
    }
  }

  /// Get app version (placeholder)
  Future<String> _getAppVersion() async {
    // You can use package_info_plus to get actual app version
    return '1.0.0';
  }

  /// Dispose resources
  void dispose() {
    _stopPeriodicSync();
    _database?.close();
  }
}
