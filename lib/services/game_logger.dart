import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/card.dart';

/// Comprehensive logging system to track human player actions for AI training
class GameLogger {
  static final GameLogger _instance = GameLogger._internal();
  factory GameLogger() => _instance;
  GameLogger._internal();

  bool _isEnabled = true;
  List<Map<String, dynamic>> _sessionLogs = [];
  String? _currentSessionId;
  DateTime? _sessionStartTime;
  File? _logFile;

  /// Initialize the logger
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('logging_enabled') ?? true;
      
      if (_isEnabled) {
        await _createLogFile();
        _startNewSession();
        if (kDebugMode) print('📝 Game Logger initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error initializing Game Logger: $e');
    }
  }

  /// Create a new log file for this session
  Future<void> _createLogFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/trix_logs');
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }
      
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      _logFile = File('${logsDir.path}/trix_session_$timestamp.json');
      
      if (kDebugMode) print('📁 Log file created: ${_logFile!.path}');
    } catch (e) {
      if (kDebugMode) print('❌ Error creating log file: $e');
    }
  }

  /// Start a new gaming session
  void _startNewSession() {
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _sessionStartTime = DateTime.now();
    _sessionLogs.clear();
    
    logEvent('session_start', {
      'session_id': _currentSessionId,
      'timestamp': _sessionStartTime!.toIso8601String(),
      'platform': Platform.operatingSystem,
      'app_version': '1.0.0', // You can make this dynamic
    });
  }

  /// Log a game event
  void logEvent(String eventType, Map<String, dynamic> data) {
    if (!_isEnabled) return;

    final logEntry = {
      'session_id': _currentSessionId,
      'timestamp': DateTime.now().toIso8601String(),
      'event_type': eventType,
      'data': data,
    };

    _sessionLogs.add(logEntry);
    
    if (kDebugMode) {
      print('📝 LOG: $eventType - ${data.keys.join(', ')}');
    }

    // Auto-save every 10 events to prevent data loss
    if (_sessionLogs.length % 10 == 0) {
      _saveToFile();
    }
  }

  /// Log contract selection
  void logContractSelection(TrexContract contract, List<TrexContract> availableContracts, Player humanPlayer) {
    logEvent('contract_selection', {
      'selected_contract': contract.name,
      'available_contracts': availableContracts.map((c) => c.name).toList(),
      'hand_size': humanPlayer.hand.length,
      'hand_cards': humanPlayer.hand.map((card) => _cardToJson(card)).toList(),
      'hand_analysis': _analyzeHand(humanPlayer.hand),
      'decision_time': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Log card play action
  void logCardPlay(Card playedCard, Player humanPlayer, TrexGame game) {
    final gameState = _captureGameState(game);
    final validCards = _getValidCards(humanPlayer, game);
    
    logEvent('card_play', {
      'played_card': _cardToJson(playedCard),
      'hand_before': humanPlayer.hand.map((card) => _cardToJson(card)).toList(),
      'valid_cards': validCards.map((card) => _cardToJson(card)).toList(),
      'game_state': gameState,
      'contract': game.currentContract?.name,
      'trick_cards': game.currentTrick?.cards.map((pos, card) => 
        MapEntry(pos.name, _cardToJson(card))),
      'scores_before': game.players.map((p) => {
        'position': p.position.name,
        'score': p.score,
      }).toList(),
      'decision_quality': _analyzeDecisionQuality(playedCard, validCards, game),
    });
  }

  /// Log king of hearts doubling decision
  void logKingOfHeartsDoubling(bool doubled, Player humanPlayer, TrexGame game) {
    logEvent('king_doubling', {
      'doubled': doubled,
      'hand_cards': humanPlayer.hand.map((card) => _cardToJson(card)).toList(),
      'has_king_of_hearts': humanPlayer.hand.any((c) => c.isKingOfHearts),
      'hand_strength': _analyzeHandStrength(humanPlayer.hand, game.currentContract!),
      'risk_assessment': _assessKingDoublingRisk(humanPlayer.hand),
    });
  }

  /// Log Trex turn pass
  void logTrexPass(Player humanPlayer, TrexGame game) {
    final validTrexMoves = humanPlayer.hand.where((card) => game.canPlayTrexCard(card)).toList();
    
    logEvent('trex_pass', {
      'hand_cards': humanPlayer.hand.map((card) => _cardToJson(card)).toList(),
      'valid_trex_moves': validTrexMoves.map((card) => _cardToJson(card)).toList(),
      'forced_pass': validTrexMoves.isEmpty,
      'strategic_pass': validTrexMoves.isNotEmpty,
      'game_state': _captureGameState(game),
    });
  }

  /// Log thinking time (when user takes time to make decision)
  void logThinkingTime(String actionType, Duration thinkingTime, Map<String, dynamic> context) {
    logEvent('thinking_time', {
      'action_type': actionType,
      'thinking_duration_ms': thinkingTime.inMilliseconds,
      'context': context,
      'complexity_score': _calculateComplexityScore(context),
    });
  }

  /// Log game end results
  void logGameEnd(TrexGame game) {
    final finalScores = game.players.map((p) => {
      'position': p.position.name,
      'name': p.name,
      'final_score': p.score,
      'is_human': p.position == PlayerPosition.south,
    }).toList();

    logEvent('game_end', {
      'final_scores': finalScores,
      'winner': finalScores.reduce((a, b) => 
        (a['final_score'] as int) < (b['final_score'] as int) ? a : b),
      'human_rank': _calculateHumanRank(finalScores),
      'session_duration_minutes': _sessionStartTime != null 
        ? DateTime.now().difference(_sessionStartTime!).inMinutes 
        : 0,
    });
    
    _saveToFile();
  }

  /// Log detailed hand management decisions
  void logHandManagement(String actionType, Player humanPlayer, TrexGame game, {
    Card? cardInvolved,
    List<Card>? cardsConsidered,
    String? reasoning,
  }) {
    logEvent('hand_management', {
      'action_type': actionType, // 'card_selection', 'suit_planning', 'risk_assessment'
      'hand_state': {
        'cards': humanPlayer.hand.map((card) => _cardToJson(card)).toList(),
        'analysis': _analyzeHand(humanPlayer.hand),
        'dangerous_cards': _identifyDangerousCards(humanPlayer.hand, game),
      },
      'card_involved': cardInvolved != null ? _cardToJson(cardInvolved) : null,
      'cards_considered': cardsConsidered?.map((card) => _cardToJson(card)).toList(),
      'reasoning': reasoning,
      'game_context': _getGameContext(game),
    });
  }

  /// Log strategic decision making
  void logStrategicDecision(String strategyType, Map<String, dynamic> decisionData, Player humanPlayer, TrexGame game) {
    logEvent('strategic_decision', {
      'strategy_type': strategyType, // 'offensive', 'defensive', 'adaptive', 'risk_mitigation'
      'decision_data': decisionData,
      'hand_analysis': _analyzeHand(humanPlayer.hand),
      'game_state': _getDetailedGameState(game),
      'pressure_level': _calculatePressureLevel(game),
    });
  }

  /// Log player psychology and patterns
  void logPlayerBehavior(String behaviorType, Map<String, dynamic> behaviorData, Duration? hesitationTime) {
    logEvent('player_behavior', {
      'behavior_type': behaviorType, // 'aggressive', 'cautious', 'calculated', 'impulsive'
      'behavior_data': behaviorData,
      'hesitation_time_ms': hesitationTime?.inMilliseconds,
      'confidence_indicator': _calculateConfidenceLevel(hesitationTime),
    });
  }

  /// Log memory and learning patterns
  void logMemoryPattern(String memoryType, Map<String, dynamic> memoryData) {
    logEvent('memory_pattern', {
      'memory_type': memoryType, // 'card_tracking', 'pattern_recognition', 'opponent_modeling'
      'memory_data': memoryData,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Log risk assessment decisions
  void logRiskAssessment(String riskType, double riskLevel, Map<String, dynamic> factors, Player humanPlayer, TrexGame game) {
    logEvent('risk_assessment', {
      'risk_type': riskType, // 'king_of_hearts', 'trick_capture', 'suit_exposure'
      'risk_level': riskLevel, // 0.0 to 1.0
      'risk_factors': factors,
      'mitigation_strategy': _suggestRiskMitigation(riskType, riskLevel, humanPlayer, game),
      'hand_vulnerability': _assessHandVulnerability(humanPlayer.hand, game),
    });
  }

  /// Log adaptation and learning moments
  void logAdaptation(String adaptationType, Map<String, dynamic> adaptationData, Player humanPlayer) {
    logEvent('adaptation', {
      'adaptation_type': adaptationType, // 'style_change', 'strategy_shift', 'learning_moment'
      'adaptation_data': adaptationData,
      'previous_patterns': _getPreviousPatterns(),
      'skill_progression': _assessSkillProgression(humanPlayer),
    });
  }

  /// Log emotional state indicators
  void logEmotionalState(String emotionType, double intensity, Map<String, dynamic>? triggers) {
    logEvent('emotional_state', {
      'emotion_type': emotionType, // 'frustration', 'confidence', 'excitement', 'anxiety'
      'intensity': intensity, // 0.0 to 1.0
      'triggers': triggers,
      'impact_on_play': _assessEmotionalImpact(emotionType, intensity),
    });
  }

  /// Convert card to JSON representation
  Map<String, dynamic> _cardToJson(Card card) {
    return {
      'suit': card.suit.name,
      'rank': card.rank.name,
      'value': card.rank.value,
      'encoded_value': card.suit.index * 13 + (card.rank.value - 2),
    };
  }

  /// Analyze hand composition
  Map<String, dynamic> _analyzeHand(List<Card> hand) {
    return {
      'size': hand.length,
      'suits': {
        'hearts': hand.where((c) => c.suit == Suit.hearts).length,
        'diamonds': hand.where((c) => c.suit == Suit.diamonds).length,
        'clubs': hand.where((c) => c.suit == Suit.clubs).length,
        'spades': hand.where((c) => c.suit == Suit.spades).length,
      },
      'high_cards': hand.where((c) => c.rank.value >= 11).length, // Jack, Queen, King, Ace
      'low_cards': hand.where((c) => c.rank.value <= 6).length,
      'queens': hand.where((c) => c.rank == Rank.queen).length,
      'has_king_of_hearts': hand.any((c) => c.isKingOfHearts),
      'danger_cards': hand.where((c) => 
        c.isKingOfHearts || c.rank == Rank.queen || c.suit == Suit.diamonds).length,
    };
  }

  /// Capture current game state
  Map<String, dynamic> _captureGameState(TrexGame game) {
    return {
      'phase': game.phase.name,
      'current_player': game.currentPlayer.name,
      'current_king': game.currentKing.name,
      'contract': game.currentContract?.name,
      'round_number': 1, // You might want to track this
      'cards_played_in_trick': game.currentTrick?.cards.length ?? 0,
      'tricks_completed': 0, // You might want to track this
    };
  }

  /// Get valid cards for current game state
  List<Card> _getValidCards(Player player, TrexGame game) {
    if (game.currentContract == TrexContract.trex) {
      return player.hand.where((card) => game.canPlayTrexCard(card)).toList();
    } else {
      return player.hand.where((card) => game.isValidTrickPlay(player, card)).toList();
    }
  }

  /// Analyze decision quality
  Map<String, dynamic> _analyzeDecisionQuality(Card playedCard, List<Card> validCards, TrexGame game) {
    final analysis = {
      'total_options': validCards.length,
      'was_forced': validCards.length == 1,
      'played_highest': validCards.isNotEmpty && 
        playedCard.rank.value == validCards.map((c) => c.rank.value).reduce((a, b) => a > b ? a : b),
      'played_lowest': validCards.isNotEmpty && 
        playedCard.rank.value == validCards.map((c) => c.rank.value).reduce((a, b) => a < b ? a : b),
      'avoided_danger': false,
      'strategic_play': false,
    };

    // Analyze danger avoidance
    if (game.currentContract == TrexContract.kingOfHearts) {
      analysis['avoided_danger'] = !playedCard.isKingOfHearts && validCards.any((c) => c.isKingOfHearts);
    } else if (game.currentContract == TrexContract.queens) {
      analysis['avoided_danger'] = playedCard.rank != Rank.queen && validCards.any((c) => c.rank == Rank.queen);
    } else if (game.currentContract == TrexContract.diamonds) {
      analysis['avoided_danger'] = playedCard.suit != Suit.diamonds && validCards.any((c) => c.suit == Suit.diamonds);
    }

    return analysis;
  }

  /// Analyze hand strength for specific contract
  Map<String, dynamic> _analyzeHandStrength(List<Card> hand, TrexContract contract) {
    final strength = {
      'overall_strength': 0.0,
      'contract_specific_risk': 0.0,
      'protective_cards': 0,
    };

    switch (contract) {
      case TrexContract.kingOfHearts:
        strength['contract_specific_risk'] = hand.any((c) => c.isKingOfHearts) ? 1.0 : 0.0;
        strength['protective_cards'] = hand.where((c) => c.suit == Suit.spades && c.rank.value >= 11).length;
        break;
      case TrexContract.queens:
        strength['contract_specific_risk'] = hand.where((c) => c.rank == Rank.queen).length / 4.0;
        break;
      case TrexContract.diamonds:
        strength['contract_specific_risk'] = hand.where((c) => c.suit == Suit.diamonds).length / 13.0;
        break;
      case TrexContract.collections:
        strength['contract_specific_risk'] = hand.where((c) => 
          c.isKingOfHearts || c.rank == Rank.queen || c.suit == Suit.diamonds).length / hand.length;
        break;
      case TrexContract.trex:
        strength['overall_strength'] = hand.where((c) => c.rank.value <= 6).length / hand.length;
        break;
    }

    return strength;
  }

  /// Assess king doubling risk
  Map<String, dynamic> _assessKingDoublingRisk(List<Card> hand) {
    return {
      'has_king_of_hearts': hand.any((c) => c.isKingOfHearts),
      'spade_protection': hand.where((c) => c.suit == Suit.spades && c.rank.value >= 11).length,
      'heart_count': hand.where((c) => c.suit == Suit.hearts).length,
      'risk_level': hand.any((c) => c.isKingOfHearts) ? 'high' : 'low',
    };
  }

  /// Calculate complexity score for thinking time analysis
  int _calculateComplexityScore(Map<String, dynamic> context) {
    int complexity = 0;
    
    if (context.containsKey('valid_cards')) {
      final validCards = context['valid_cards'] as List?;
      complexity += (validCards?.length ?? 0) * 2; // More options = more complex
    }
    
    if (context.containsKey('has_dangerous_cards')) {
      complexity += (context['has_dangerous_cards'] as bool) ? 10 : 0;
    }
    
    return complexity;
  }

  /// Calculate human player's rank in final scores
  int _calculateHumanRank(List<Map<String, dynamic>> finalScores) {
    final humanScore = finalScores.firstWhere((s) => s['is_human'] == true)['final_score'] as int;
    final sortedScores = finalScores.map((s) => s['final_score'] as int).toList()..sort();
    return sortedScores.indexOf(humanScore) + 1;
  }

  /// Save logs to file
  Future<void> _saveToFile() async {
    if (_logFile == null || _sessionLogs.isEmpty) return;

    try {
      final jsonData = {
        'session_info': {
          'session_id': _currentSessionId,
          'start_time': _sessionStartTime?.toIso8601String(),
          'end_time': DateTime.now().toIso8601String(),
          'platform': Platform.operatingSystem,
          'events_count': _sessionLogs.length,
        },
        'events': _sessionLogs,
      };

      await _logFile!.writeAsString(
        const JsonEncoder.withIndent('  ').convert(jsonData),
        mode: FileMode.write,
      );

      if (kDebugMode) print('💾 Saved ${_sessionLogs.length} log entries to file');
    } catch (e) {
      if (kDebugMode) print('❌ Error saving logs: $e');
    }
  }

  /// Get logs directory for export/backup
  Future<String> getLogsDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/trix_logs';
  }

  /// Export logs for training (compressed JSON)
  Future<File?> exportLogsForTraining() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/trix_logs');
      
      if (!await logsDir.exists()) return null;

      final logFiles = await logsDir.list().where((f) => f.path.endsWith('.json')).toList();
      final allLogs = <Map<String, dynamic>>[];

      for (final file in logFiles) {
        try {
          final content = await File(file.path).readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          allLogs.addAll((data['events'] as List).cast<Map<String, dynamic>>());
        } catch (e) {
          if (kDebugMode) print('⚠️ Error reading log file ${file.path}: $e');
        }
      }

      if (allLogs.isEmpty) return null;

      final exportFile = File('${directory.path}/trix_training_data_${DateTime.now().millisecondsSinceEpoch}.json');
      await exportFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'export_info': {
            'timestamp': DateTime.now().toIso8601String(),
            'total_events': allLogs.length,
            'sessions_included': logFiles.length,
          },
          'training_data': allLogs,
        }),
      );

      if (kDebugMode) print('📤 Exported ${allLogs.length} training events to ${exportFile.path}');
      return exportFile;
    } catch (e) {
      if (kDebugMode) print('❌ Error exporting logs: $e');
      return null;
    }
  }

  /// Toggle logging on/off
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('logging_enabled', enabled);
    
    if (enabled && _logFile == null) {
      await initialize();
    }
    
    if (kDebugMode) print('📝 Game logging ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Get current logging status
  bool get isEnabled => _isEnabled;

  /// Dispose and clean up
  Future<void> dispose() async {
    if (_sessionLogs.isNotEmpty) {
      await _saveToFile();
    }
  }

  // =============== HELPER METHODS FOR ENHANCED LOGGING ===============

  /// Identify dangerous cards in hand
  List<Map<String, dynamic>> _identifyDangerousCards(List<Card> hand, TrexGame game) {
    final dangerousCards = <Map<String, dynamic>>[];
    for (final card in hand) {
      if (card.suit == Suit.hearts && card.rank == Rank.king) {
        dangerousCards.add({
          'card': _cardToJson(card),
          'danger_type': 'king_of_hearts',
          'penalty_risk': 75,
        });
      } else if (card.suit == Suit.hearts) {
        dangerousCards.add({
          'card': _cardToJson(card),
          'danger_type': 'hearts_suit',
          'penalty_risk': card.rank.value,
        });
      }
    }
    return dangerousCards;
  }

  /// Get game context information
  Map<String, dynamic> _getGameContext(TrexGame game) {
    final currentTrick = game.currentTrick;
    return {
      'current_trick': currentTrick != null && currentTrick.cards.isNotEmpty ? 
        currentTrick.cards.values.map((card) => _cardToJson(card)).toList() : null,
      'leading_suit': currentTrick != null && currentTrick.cards.isNotEmpty ? 
        currentTrick.cards.values.first.suit.name : null,
      'trick_count': game.tricks.length,
      'current_round': game.round,
      'current_contract': game.currentContract?.name,
    };
  }

  /// Get detailed game state
  Map<String, dynamic> _getDetailedGameState(TrexGame game) {
    return {
      'scores': game.players.map((p) => {
        'position': p.position.name,
        'score': p.score,
        'cards_remaining': p.hand.length,
      }).toList(),
      'round': game.round,
      'kingdom': game.kingdom,
      'king_of_hearts_played': game.kingOfHeartsCard != null,
      'king_of_hearts_doubled': game.isKingOfHeartsDoubled,
      'current_king': game.currentKing.name,
    };
  }

  /// Calculate pressure level in game
  double _calculatePressureLevel(TrexGame game) {
    double pressure = 0.0;
    
    // High scores create pressure
    final maxScore = game.players.map((p) => p.score).reduce((a, b) => a > b ? a : b);
    if (maxScore > 50) pressure += 0.3;
    if (maxScore > 100) pressure += 0.3;
    
    // Late in game creates pressure
    final totalCardsPlayed = game.players.fold(0, (sum, p) => sum + (13 - p.hand.length));
    pressure += (totalCardsPlayed / 52) * 0.4;
    
    return pressure.clamp(0.0, 1.0);
  }

  /// Calculate confidence level based on hesitation time
  double _calculateConfidenceLevel(Duration? hesitationTime) {
    if (hesitationTime == null) return 0.5;
    
    final seconds = hesitationTime.inSeconds;
    if (seconds < 2) return 0.9; // Very confident, quick decision
    if (seconds < 5) return 0.7; // Moderately confident
    if (seconds < 10) return 0.4; // Hesitant
    return 0.1; // Very uncertain
  }

  /// Suggest risk mitigation strategy
  Map<String, dynamic> _suggestRiskMitigation(String riskType, double riskLevel, Player humanPlayer, TrexGame game) {
    switch (riskType) {
      case 'king_of_hearts':
        return {
          'strategy': 'avoid_taking_tricks',
          'priority': 'high',
          'suggested_actions': ['play_low_cards', 'avoid_leading_suits'],
        };
      case 'trick_capture':
        return {
          'strategy': 'defensive_play',
          'priority': riskLevel > 0.7 ? 'high' : 'medium',
          'suggested_actions': ['play_middle_cards', 'avoid_aces_and_kings'],
        };
      default:
        return {
          'strategy': 'general_caution',
          'priority': 'low',
          'suggested_actions': ['observe_opponents'],
        };
    }
  }

  /// Assess hand vulnerability
  Map<String, dynamic> _assessHandVulnerability(List<Card> hand, TrexGame game) {
    int heartCount = hand.where((c) => c.suit == Suit.hearts).length;
    bool hasKingOfHearts = hand.any((c) => c.suit == Suit.hearts && c.rank == Rank.king);
    int highCards = hand.where((c) => c.rank.value >= 11).length;
    
    return {
      'heart_count': heartCount,
      'has_king_of_hearts': hasKingOfHearts,
      'high_cards': highCards,
      'vulnerability_score': (heartCount * 0.3 + (hasKingOfHearts ? 0.5 : 0) + highCards * 0.2).clamp(0.0, 1.0),
    };
  }

  /// Get previous patterns from session
  Map<String, dynamic> _getPreviousPatterns() {
    final contractSelections = _sessionLogs.where((log) => log['event_type'] == 'contract_selection').toList();
    final cardPlays = _sessionLogs.where((log) => log['event_type'] == 'card_play').toList();
    
    return {
      'contract_preferences': _analyzePreviousContracts(contractSelections),
      'play_style': _analyzePreviousPlays(cardPlays),
      'total_decisions': contractSelections.length + cardPlays.length,
    };
  }

  /// Assess skill progression
  Map<String, dynamic> _assessSkillProgression(Player humanPlayer) {
    return {
      'current_score': humanPlayer.score,
      'decision_speed_trend': 'improving', // This would be calculated from actual data
      'risk_management': 'learning', // This would be calculated from actual data
      'strategic_thinking': 'developing', // This would be calculated from actual data
    };
  }

  /// Assess emotional impact on play
  Map<String, dynamic> _assessEmotionalImpact(String emotionType, double intensity) {
    switch (emotionType) {
      case 'frustration':
        return {
          'likely_impact': 'impulsive_decisions',
          'recommended_response': 'encourage_patience',
          'adjustment_needed': intensity > 0.7,
        };
      case 'confidence':
        return {
          'likely_impact': 'aggressive_play',
          'recommended_response': 'maintain_focus',
          'adjustment_needed': intensity > 0.9, // Overconfidence
        };
      default:
        return {
          'likely_impact': 'neutral',
          'recommended_response': 'continue_monitoring',
          'adjustment_needed': false,
        };
    }
  }

  /// Analyze previous card plays
  Map<String, dynamic> _analyzePreviousPlays(List<Map<String, dynamic>> playLogs) {
    if (playLogs.isEmpty) return {'no_data': true};
    
    return {
      'total_plays': playLogs.length,
      'average_thinking_time': 3.5, // Placeholder - would calculate from actual data
      'risk_tendency': 'moderate', // Placeholder - would analyze risk patterns
    };
  }

  /// Analyze previous contract selections
  Map<String, dynamic> _analyzePreviousContracts(List<Map<String, dynamic>> contractLogs) {
    if (contractLogs.isEmpty) return {'no_data': true};
    
    final contracts = contractLogs.map((log) => log['data']['selected_contract']).toList();
    final contractCounts = <String, int>{};
    for (final contract in contracts) {
      contractCounts[contract] = (contractCounts[contract] ?? 0) + 1;
    }
    
    return {
      'most_selected': contractCounts.isNotEmpty ? 
        contractCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key : null,
      'contract_distribution': contractCounts,
    };
  }
}
