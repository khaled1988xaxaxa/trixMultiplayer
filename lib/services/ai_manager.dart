import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/ai_difficulty.dart';
import '../models/ai_player.dart';
import '../models/player.dart';

/// Service to manage AI players and their behavior
class AIManager {
  static final AIManager _instance = AIManager._internal();
  factory AIManager() => _instance;
  AIManager._internal();

  final Map<String, AIPlayer> _activePlayers = {};
  final Map<AIDifficulty, int> _difficultyUsage = {};
  bool _isInitialized = false;

  /// Initialize the AI manager
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Pre-load frequently used AI models for better performance
      await _preloadCommonAIs();
      _isInitialized = true;
      
      if (kDebugMode) {
        print('🤖 AI Manager initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize AI Manager: $e');
      }
      rethrow;
    }
  }

  /// Pre-load common AI difficulties for better performance
  Future<void> _preloadCommonAIs() async {
    // Only preload models that are actually available in pubspec.yaml
    List<AIDifficulty> commonDifficulties = AIDifficulty.availableDifficulties;

    List<Future<void>> loadTasks = commonDifficulties.map((difficulty) async {
      try {
        await AIPlayer.create(
          id: 'preload_${difficulty.name}',
          difficulty: difficulty,
          position: PlayerPosition.north,
        );
        
        if (kDebugMode) {
          print('✅ Pre-loaded ${difficulty.englishName} AI');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to pre-load ${difficulty.englishName} AI: $e');
        }
      }
    }).toList();

    await Future.wait(loadTasks);
  }

  /// Create AI players for a game
  Future<List<AIPlayer>> createAIPlayers({
    required List<AIDifficulty> difficulties,
    required List<PlayerPosition> positions,
  }) async {
    if (difficulties.length != positions.length) {
      throw ArgumentError('Difficulties and positions lists must have the same length');
    }

    List<AIPlayer> aiPlayers = [];
    
    for (int i = 0; i < difficulties.length; i++) {
      try {
        AIPlayer aiPlayer = await AIPlayer.create(
          id: 'ai_${positions[i].name}_${DateTime.now().millisecondsSinceEpoch}',
          difficulty: difficulties[i],
          position: positions[i],
        );
        
        aiPlayers.add(aiPlayer);
        _activePlayers[aiPlayer.id] = aiPlayer;
        _difficultyUsage[difficulties[i]] = (_difficultyUsage[difficulties[i]] ?? 0) + 1;
        
        if (kDebugMode) {
          print('🤖 Created ${difficulties[i].englishName} AI: ${aiPlayer.name}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Failed to create ${difficulties[i].englishName} AI: $e');
        }
        rethrow;
      }
    }

    return aiPlayers;
  }

  /// Create a single AI player
  Future<AIPlayer> createAIPlayer({
    required AIDifficulty difficulty,
    required PlayerPosition position,
    String? customName,
  }) async {
    try {
      AIPlayer aiPlayer = await AIPlayer.create(
        id: 'ai_${position.name}_${DateTime.now().millisecondsSinceEpoch}',
        difficulty: difficulty,
        position: position,
      );

      if (customName != null) {
        // Create a copy with custom name
        aiPlayer = AIPlayer(
          id: aiPlayer.id,
          difficulty: difficulty,
          ai: aiPlayer.ai,
          position: position,
        );
        // Note: We'd need to add a method to set custom name in AIPlayer
      }

      _activePlayers[aiPlayer.id] = aiPlayer;
      _difficultyUsage[difficulty] = (_difficultyUsage[difficulty] ?? 0) + 1;

      return aiPlayer;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to create AI player: $e');
      }
      rethrow;
    }
  }

  /// Get recommended AI difficulty based on player performance
  AIDifficulty getRecommendedDifficulty({
    required int playerGamesPlayed,
    required double playerWinRate,
    AIDifficulty? currentDifficulty,
  }) {
    AIDifficulty recommended = AIDifficulty.getRecommendedForPlayer(
      playerGamesPlayed,
      playerWinRate,
    );

    // If player is consistently winning, suggest harder AI (if available)
    if (playerWinRate > 0.7 && playerGamesPlayed > 10) {
      int nextLevel = recommended.experienceLevel + 1;
      AIDifficulty? harder = AIDifficulty.availableDifficulties
          .where((d) => d.experienceLevel == nextLevel)
          .firstOrNull;
      
      if (harder != null) {
        return harder;
      } else {
        // Return the strongest available
        return AIDifficulty.strongestAvailable;
      }
    }

    // If player is struggling, suggest easier AI (if available)
    if (playerWinRate < 0.3 && playerGamesPlayed > 5) {
      int prevLevel = recommended.experienceLevel - 1;
      AIDifficulty? easier = AIDifficulty.availableDifficulties
          .where((d) => d.experienceLevel == prevLevel)
          .firstOrNull;
      
      if (easier != null) {
        return easier;
      } else {
        // Return the easiest available
        return AIDifficulty.beginner;
      }
    }

    return recommended;
  }

  /// Get balanced team of AI difficulties for multiplayer
  List<AIDifficulty> getBalancedTeam({
    required int playerCount,
    required AIDifficulty playerSkillLevel,
  }) {
    if (playerCount < 1 || playerCount > 3) {
      throw ArgumentError('Player count must be between 1 and 3');
    }

    List<AIDifficulty> team = [];
    int baseLevel = playerSkillLevel.experienceLevel;

    switch (playerCount) {
      case 1:
        // Three AI opponents with varied difficulty
        team = [
          _getDifficultyByLevel(baseLevel - 1),
          _getDifficultyByLevel(baseLevel),
          _getDifficultyByLevel(baseLevel + 1),
        ];
        break;
        
      case 2:
        // Two AI opponents
        team = [
          _getDifficultyByLevel(baseLevel),
          _getDifficultyByLevel(baseLevel + 1),
        ];
        break;
        
      case 3:
        // One AI opponent
        team = [_getDifficultyByLevel(baseLevel)];
        break;
    }

    return team;
  }

  /// Get difficulty by experience level with bounds checking
  AIDifficulty _getDifficultyByLevel(int level) {
    int clampedLevel = level.clamp(
      AIDifficulty.beginner.experienceLevel,
      AIDifficulty.strongestAvailable.experienceLevel,
    );
    
    // Try to find an available difficulty at this level
    AIDifficulty? found = AIDifficulty.availableDifficulties
        .where((d) => d.experienceLevel == clampedLevel)
        .firstOrNull;
    
    // If not found, return the closest available difficulty
    if (found == null) {
      return AIDifficulty.availableDifficulties
          .reduce((a, b) => 
            (a.experienceLevel - clampedLevel).abs() < 
            (b.experienceLevel - clampedLevel).abs() ? a : b);
    }
    
    return found;
  }

  /// Get AI statistics
  Map<String, dynamic> getAIStatistics() {
    Map<String, dynamic> stats = {
      'total_active_players': _activePlayers.length,
      'difficulty_usage': {},
      'active_players': [],
    };

    // Count difficulty usage
    for (var entry in _difficultyUsage.entries) {
      stats['difficulty_usage'][entry.key.englishName] = entry.value;
    }

    // Get active player info
    for (var player in _activePlayers.values) {
      stats['active_players'].add(player.getAIInfo());
    }

    return stats;
  }

  /// Clean up inactive AI players
  void cleanup() {
    _activePlayers.clear();
    _difficultyUsage.clear();
    
    if (kDebugMode) {
      print('🧹 AI Manager cleaned up');
    }
  }

  /// Remove specific AI player
  void removeAIPlayer(String playerId) {
    AIPlayer? player = _activePlayers.remove(playerId);
    if (player != null) {
      int currentUsage = _difficultyUsage[player.difficulty] ?? 0;
      if (currentUsage > 0) {
        _difficultyUsage[player.difficulty] = currentUsage - 1;
      }
    }
  }

  /// Update AI player stats after game
  void updatePlayerStats({
    required String playerId,
    required bool won,
    required int finalScore,
    required Duration gameDuration,
  }) {
    AIPlayer? player = _activePlayers[playerId];
    if (player != null) {
      player.updateGameStats(
        won: won,
        finalScore: finalScore,
        gameDuration: gameDuration,
      );
    }
  }

  /// Get available AI difficulties
  List<AIDifficulty> getAvailableDifficulties() {
    return AIDifficulty.availableDifficulties;
  }

  /// Get AI player by ID
  AIPlayer? getAIPlayer(String playerId) {
    return _activePlayers[playerId];
  }

  /// Check if AI manager is ready
  bool get isReady => _isInitialized;

  /// Get most popular AI difficulty
  AIDifficulty get mostPopularDifficulty {
    if (_difficultyUsage.isEmpty) return AIDifficulty.safeFallback;
    
    return _difficultyUsage.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Create AI opponents for practice mode
  Future<List<AIPlayer>> createPracticeOpponents({
    required AIDifficulty targetDifficulty,
    required int count,
  }) async {
    List<AIDifficulty> difficulties = [];
    List<PlayerPosition> positions = [
      PlayerPosition.east,
      PlayerPosition.west,
      PlayerPosition.north,
    ];

    // Create varied opponents around the target difficulty
    for (int i = 0; i < count; i++) {
      int variation = (i - count ~/ 2); // -1, 0, 1 for 3 opponents
      int targetLevel = targetDifficulty.experienceLevel + variation;
      difficulties.add(_getDifficultyByLevel(targetLevel));
    }

    return await createAIPlayers(
      difficulties: difficulties.take(count).toList(),
      positions: positions.take(count).toList(),
    );
  }

  /// Get tournament-style AI opponents (progressively harder)
  Future<List<AIPlayer>> createTournamentOpponents() async {
    // Use only available difficulties for tournament mode
    List<AIDifficulty> availableDiffs = AIDifficulty.availableDifficulties;
    List<AIDifficulty> tournamentDifficulties = [];
    
    if (availableDiffs.length >= 3) {
      // Use the three available difficulties
      tournamentDifficulties = availableDiffs.take(3).toList();
    } else {
      // Repeat the strongest available difficulty to fill slots
      while (tournamentDifficulties.length < 3) {
        tournamentDifficulties.addAll(availableDiffs);
      }
      tournamentDifficulties = tournamentDifficulties.take(3).toList();
    }

    List<PlayerPosition> positions = [
      PlayerPosition.east,
      PlayerPosition.west,
      PlayerPosition.north,
    ];

    return await createAIPlayers(
      difficulties: tournamentDifficulties,
      positions: positions,
    );
  }
}
