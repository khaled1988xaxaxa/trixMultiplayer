import 'package:flutter/foundation.dart';
import '../models/ai_difficulty.dart';
import '../models/ai_player.dart';
import '../models/player.dart';
import '../services/ai_manager.dart';
import '../services/elite_ai_service.dart';

class AIProvider extends ChangeNotifier {
  final AIManager _aiManager = AIManager();
  final EliteAIService _eliteAIService = EliteAIService.instance;
  
  // Current state
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Player preferences
  AIDifficulty _preferredDifficulty = AIDifficulty.safeFallback;
  bool _adaptiveDifficulty = true;
  
  // Game session
  List<AIPlayer> _currentAIPlayers = [];
  final Map<String, Map<String, dynamic>> _gameStats = {};
  
  // Player performance tracking
  int _playerGamesPlayed = 0;
  int _playerGamesWon = 0;
  double _playerAverageScore = 0.0;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AIDifficulty get preferredDifficulty => _preferredDifficulty;
  bool get adaptiveDifficulty => _adaptiveDifficulty;
  List<AIPlayer> get currentAIPlayers => List.unmodifiable(_currentAIPlayers);
  int get playerGamesPlayed => _playerGamesPlayed;
  int get playerGamesWon => _playerGamesWon;
  double get playerWinRate => _playerGamesPlayed > 0 ? _playerGamesWon / _playerGamesPlayed : 0.0;
  double get playerAverageScore => _playerAverageScore;

  /// Get Elite AI service status
  Map<String, dynamic> get eliteAIStatus => _eliteAIService.getEliteAIStatus();
  
  /// Check if a specific elite AI model is available
  bool isEliteAIAvailable(AIDifficulty difficulty) {
    return _eliteAIService.isModelAvailable(difficulty);
  }

  /// Initialize the AI system
  Future<void> initialize() async {
    if (_isInitialized) return;

    _setLoading(true);
    _clearError();

    try {
      await _aiManager.initialize();
      
      // Initialize Elite AI service for Claude Sonnet and ChatGPT models
      await _eliteAIService.initialize();
      
      _isInitialized = true;
      
      // Load saved preferences
      await _loadPreferences();
      
      if (kDebugMode) {
        print('✅ AI Provider initialized successfully');
      }
    } catch (e) {
      _setError('Failed to initialize AI system: $e');
      if (kDebugMode) {
        print('❌ AI Provider initialization failed: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  /// Create AI opponents for a game
  Future<List<AIPlayer>> createAIOpponents({
    required int opponentCount,
    List<AIDifficulty>? specificDifficulties,
    List<PlayerPosition>? positions,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      List<AIDifficulty> difficulties;
      List<PlayerPosition> playerPositions;

      if (specificDifficulties != null && specificDifficulties.length == opponentCount) {
        difficulties = specificDifficulties;
      } else {
        // Generate balanced team based on player performance
        difficulties = _generateBalancedDifficulties(opponentCount);
      }

      playerPositions = positions ?? _generatePositions(opponentCount);

      List<AIPlayer> aiPlayers = await _aiManager.createAIPlayers(
        difficulties: difficulties,
        positions: playerPositions,
      );

      _currentAIPlayers = aiPlayers;
      notifyListeners();

      return aiPlayers;
    } catch (e) {
      _setError('Failed to create AI opponents: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Create a single AI player
  Future<AIPlayer> createAIPlayer({
    required AIDifficulty difficulty,
    required PlayerPosition position,
    String? customName,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      AIPlayer aiPlayer = await _aiManager.createAIPlayer(
        difficulty: difficulty,
        position: position,
        customName: customName,
      );

      _currentAIPlayers.add(aiPlayer);
      notifyListeners();

      return aiPlayer;
    } catch (e) {
      _setError('Failed to create AI player: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Update player preferences
  void updatePreferredDifficulty(AIDifficulty difficulty) {
    _preferredDifficulty = difficulty;
    _savePreferences();
    notifyListeners();
  }

  void toggleAdaptiveDifficulty(bool enabled) {
    _adaptiveDifficulty = enabled;
    _savePreferences();
    notifyListeners();
  }

  /// Get recommended difficulty based on player performance
  AIDifficulty getRecommendedDifficulty() {
    if (!_adaptiveDifficulty) return _preferredDifficulty;

    return _aiManager.getRecommendedDifficulty(
      playerGamesPlayed: _playerGamesPlayed,
      playerWinRate: playerWinRate,
      currentDifficulty: _preferredDifficulty,
    );
  }

  /// Update player performance after a game
  void updatePlayerPerformance({
    required bool won,
    required int score,
    required Duration gameDuration,
    required List<AIPlayer> opponents,
  }) {
    _playerGamesPlayed++;
    if (won) _playerGamesWon++;
    
    _playerAverageScore = ((_playerAverageScore * (_playerGamesPlayed - 1)) + score) / _playerGamesPlayed;

    // Update AI player stats
    for (AIPlayer opponent in opponents) {
      _aiManager.updatePlayerStats(
        playerId: opponent.id,
        won: !won, // Opponent won if player lost
        finalScore: 0, // We'd need actual opponent scores
        gameDuration: gameDuration,
      );
    }

    // Automatically adjust difficulty if adaptive is enabled
    if (_adaptiveDifficulty) {
      AIDifficulty recommended = getRecommendedDifficulty();
      if (recommended != _preferredDifficulty) {
        _preferredDifficulty = recommended;
        if (kDebugMode) {
          print('🎯 Auto-adjusted difficulty to ${recommended.englishName}');
        }
      }
    }

    _savePreferences();
    notifyListeners();
  }

  /// Generate balanced AI difficulties
  List<AIDifficulty> _generateBalancedDifficulties(int count) {
    if (_adaptiveDifficulty) {
      return _aiManager.getBalancedTeam(
        playerCount: 4 - count, // Assuming 4-player game
        playerSkillLevel: getRecommendedDifficulty(),
      );
    } else {
      // Use preferred difficulty with slight variations
      List<AIDifficulty> difficulties = [];
      int baseLevel = _preferredDifficulty.experienceLevel;
      
      for (int i = 0; i < count; i++) {
        int level = (baseLevel + (i - count ~/ 2)).clamp(1, 8);
        AIDifficulty? difficulty = AIDifficulty.availableDifficulties
            .where((d) => d.experienceLevel == level)
            .firstOrNull;
        
        // If no difficulty found at exact level, use closest available
        difficulty ??= AIDifficulty.availableDifficulties
              .reduce((a, b) => 
                (a.experienceLevel - level).abs() < 
                (b.experienceLevel - level).abs() ? a : b);
        
        difficulties.add(difficulty);
      }
      
      return difficulties;
    }
  }

  /// Generate player positions
  List<PlayerPosition> _generatePositions(int count) {
    List<PlayerPosition> available = [
      PlayerPosition.east,
      PlayerPosition.west,
      PlayerPosition.north,
    ];
    
    return available.take(count).toList();
  }

  /// Clean up current game session
  void endGameSession() {
    for (AIPlayer player in _currentAIPlayers) {
      _aiManager.removeAIPlayer(player.id);
    }
    _currentAIPlayers.clear();
    notifyListeners();
  }

  /// Get AI statistics
  Map<String, dynamic> getAIStatistics() {
    Map<String, dynamic> stats = _aiManager.getAIStatistics();
    stats['player_performance'] = {
      'games_played': _playerGamesPlayed,
      'games_won': _playerGamesWon,
      'win_rate': playerWinRate,
      'average_score': _playerAverageScore,
    };
    return stats;
  }

  /// Get available AI difficulties
  List<AIDifficulty> getAvailableDifficulties() {
    return _aiManager.getAvailableDifficulties();
  }

  /// Create practice opponents
  Future<List<AIPlayer>> createPracticeOpponents({
    AIDifficulty? targetDifficulty,
    int count = 3,
  }) async {
    AIDifficulty difficulty = targetDifficulty ?? getRecommendedDifficulty();
    
    try {
      List<AIPlayer> opponents = await _aiManager.createPracticeOpponents(
        targetDifficulty: difficulty,
        count: count,
      );
      
      _currentAIPlayers = opponents;
      notifyListeners();
      
      return opponents;
    } catch (e) {
      _setError('Failed to create practice opponents: $e');
      rethrow;
    }
  }

  /// Create tournament opponents
  Future<List<AIPlayer>> createTournamentOpponents() async {
    try {
      List<AIPlayer> opponents = await _aiManager.createTournamentOpponents();
      _currentAIPlayers = opponents;
      notifyListeners();
      return opponents;
    } catch (e) {
      _setError('Failed to create tournament opponents: $e');
      rethrow;
    }
  }

  /// Load preferences from storage
  Future<void> _loadPreferences() async {
    // In a real app, you'd load from SharedPreferences
    // For now, using default values
    if (kDebugMode) {
      print('📱 Loading AI preferences...');
    }
  }

  /// Save preferences to storage
  void _savePreferences() {
    // In a real app, you'd save to SharedPreferences
    if (kDebugMode) {
      print('💾 Saving AI preferences...');
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Reset all AI data
  void reset() {
    endGameSession();
    _aiManager.cleanup();
    _isInitialized = false;
    _playerGamesPlayed = 0;
    _playerGamesWon = 0;
    _playerAverageScore = 0.0;
    _gameStats.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    endGameSession();
    super.dispose();
  }
}
