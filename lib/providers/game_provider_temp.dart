import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/card.dart';
import '../services/ai_service.dart';

class GameProvider with ChangeNotifier {
  TrexGame? _game;
  bool _isLoading = false;
  String? _errorMessage;
  AIService? _aiService;

  TrexGame? get game => _game;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasActiveGame {
    if (kDebugMode) {
      print('🎮 hasActiveGame check: _game is null? ${_game == null}');
      if (_game != null) {
        print('   Game details: Phase=${_game!.phase.englishName}, ' 'Players=${_game!.players.length}, ' +
              'Current player=${_game!.currentPlayer.englishName}');
      }
    }
    // Only check for null game, not empty hands (empty hands are normal at end of rounds)
    return _game != null;
  }

  Player? get currentUser => _game?.players.firstWhere(
    (player) => player.position == PlayerPosition.south,
    orElse: () => _game!.players.first,
  );

  Future<void> startNewGame(Player humanPlayer, List<Player> aiPlayers) async {
    if (kDebugMode) {
      print('🎮 ===== START NEW GAME CALLED (with players) =====');
      print('🎮 Method signature: startNewGame(Player, List<Player>)');
      print('🎮 Human player: "${humanPlayer.name}" (${humanPlayer.position.name})');
      print('🎮 AI players count: ${aiPlayers.length}');
      for (int i = 0; i < aiPlayers.length; i++) {
        print('🎮   AI[$i]: "${aiPlayers[i].name}" (${aiPlayers[i].position.name})');
      }
      print('🎮 ================================================');
    }
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await reinitializeAIService();
      
      final players = [humanPlayer, ...aiPlayers];

      // Verify that we have 4 players total
      if (players.length != 4) {
        throw Exception('Invalid number of players: ${players.length}. Expected 4.');
      }
      
      // Check that all positions are assigned and unique
      final positionSet = players.map((p) => p.position).toSet();
      if (positionSet.length != 4) {
        throw Exception('Duplicate or missing player positions found. Positions: ${players.map((p) => p.position.name).join(', ')}');
      }
      
      // Verify all required positions are present
      final requiredPositions = {PlayerPosition.south, PlayerPosition.west, PlayerPosition.north, PlayerPosition.east};
      if (!positionSet.containsAll(requiredPositions)) {
        throw Exception('Missing required positions. Found: ${positionSet.map((p) => p.name).join(', ')}');
      }

      if (kDebugMode) {
        print('🎮 Players validated: ${players.map((p) => "${p.name} (${p.position.name})").join(', ')}');
      }

      _game = TrexGame(players: players, firstKing: PlayerPosition.south); // Temp king
      
      if (_game == null) {
        throw Exception('Failed to create game object.');
      }

      if (kDebugMode) {
        print('✅ Game object created successfully');
      }
      
      _game!.dealCards();
      if (kDebugMode) {
        print('✅ Cards dealt successfully');
      }
      
      _findFirstKing();
      _game!.startContractSelection();
      
      if (kDebugMode) {
        print('✅ Game setup complete. Phase: ${_game!.phase.englishName}, Current Player: ${_game!.currentPlayer.englishName}');
      }

      _isLoading = false;
      // This is the most critical notification. It tells the UI that the game is ready.
      notifyListeners(); 
      
      // This delay gives the UI a moment to react before bot actions start.
      await Future.delayed(const Duration(milliseconds: 100));
      
      // The check inside the method was causing a premature failure. 
      // The state will be validated by the UI that consumes this provider.
      _handleBotActions();

    } catch (e, s) {
      _isLoading = false;
      _game = null; // Explicitly nullify the game on error
      _errorMessage = 'Error creating game: ${e.toString()}';
      if (kDebugMode) {
        print('❌ ===== ERROR IN startNewGame =====');
        print('❌ Error: $e');
        print('❌ Stack Trace: $s');
        print('❌ =====================================');
      }
      notifyListeners();
      rethrow;
    }
  }

  void _findFirstKing() {
    if (_game == null) {
      if (kDebugMode) print('❌ Error: Game is null in _findFirstKing');
      return;
    }
    
    if (_game!.players.any((p) => p.hand.isEmpty)) {
      if (kDebugMode) {
        print('⚠️ Warning: Some players have empty hands');
      }
    }
    
    PlayerPosition? firstKing;
    Card? lowestSpade;
    
    for (Player player in _game!.players) {
      for (Card card in player.hand) {
        if (card.suit == Suit.spades) {
          if (lowestSpade == null || card.rank.value < lowestSpade.rank.value) {
            lowestSpade = card;
            firstKing = player.position;
          }
        }
      }
    }
    
    if (firstKing == null) {
      if (kDebugMode) print('⚠️ Warning: No spades found, using south as default king');
      firstKing = PlayerPosition.south;
    }
    
    _game!.currentKing = firstKing;
    _game!.currentPlayer = firstKing;
    
    if (kDebugMode) {
      print('👑 First king determined: ${_game!.currentKing.englishName}');
    }
  }

  void selectContract(TrexContract contract) {
    if (_game == null || _game!.phase != GamePhase.contractSelection) return;
    try {
      if (_game!.selectContract(contract)) {
        notifyListeners();
        _handleBotActions();
      }
    } catch (e) {
      _errorMessage = 'Error selecting contract: ${e.toString()}';
      notifyListeners();
    }
  }

  void playCard(Card card) {
    if (_game == null || _game!.phase != GamePhase.playing) return;
    try {
      if (_game!.playCard(PlayerPosition.south, card)) {
        notifyListeners();
        
        // For Trex mode, automatically check the next player for valid moves
        if (_game!.currentContract == TrexContract.trex) {
          checkAndAutoSkipTurn();
        } else {
          _handleBotActions();
        }
      }
    } catch (e) {
      _errorMessage = 'Error playing card: ${e.toString()}';
      notifyListeners();
    }
  }

  void doubleKingOfHearts() {
    if (_game == null || _game!.currentContract != TrexContract.kingOfHearts) return;
    try {
      if (_game!.doubleKingOfHearts()) {
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error doubling king: ${e.toString()}';
      notifyListeners();
    }
  }

  void passTrexTurn() {
    if (_game == null || _game!.currentContract != TrexContract.trex) return;
    if (_game!.currentPlayer != PlayerPosition.south) return;
    try {
      _game!.passTrexTurn();
      notifyListeners();
      _handleBotActions();
    } catch (e) {
      _errorMessage = 'Error passing turn: ${e.toString()}';
      notifyListeners();
    }
  }

  bool get canHumanPlayerPass {
    if (_game == null || _game!.currentContract != TrexContract.trex) return false;
    if (_game!.currentPlayer != PlayerPosition.south) return false;
    final currentUser = this.currentUser;
    if (currentUser == null) return false;
    return !_game!.hasValidTrexMove(currentUser);
  }

  // Use a timeout to prevent bot actions from taking too long
  final _botActionTimeout = Duration(seconds: 5);
  
  Future<void> _handleBotActions() async {
    if (_game == null) return;

    if (_game!.phase == GamePhase.trickComplete) {
      Future.delayed(const Duration(seconds: 1), () {
        if (_game != null) {
          if (kDebugMode) print('⏰ Completing trick after delay');
          _game!.completeTrick();
          notifyListeners();
          _handleBotActions();
        }
      });
      return;
    }

    if (_game!.phase == GamePhase.roundEnd || 
        _game!.phase == GamePhase.kingdomEnd || 
        _game!.phase == GamePhase.gameEnd) {
      if (kDebugMode) print('🏁 Game phase is ${_game!.phase.englishName} - stopping bot actions');
      return;
    }

    if (_game!.currentPlayer == PlayerPosition.south) {
      if (kDebugMode) print('🎮 Human player turn (South) - waiting for user input');
      
      // Auto-skip human player's turn if they have no valid moves in Trex mode
      if (_game!.currentContract == TrexContract.trex) {
        await checkAndAutoSkipTurn();
      }
      return;
    }

    // Use a timeout for bot actions to prevent freezing
    try {
      await      if (_game == null || _game!.currentPlayer == PlayerPosition.south) return;
      
      if (kDebugMode) print('🤖 Bot check: Phase=${_game!.phase.englishName}, Player=${_game!.currentPlayer.englishName}');
        
        if (_game!.phase == GamePhase.contractSelection) {
          final botContract = await _calculateBotContract(_game!.currentPlayer);
          if (botContract != null) {
            if (kDebugMode) print('Bot ${_game!.currentPlayer.englishName} selecting: ${botContract.englishName}');
            _game!.selectContract(botContract);
            notifyListeners();
            _handleBotActions();
          } else {
            if (kDebugMode) print('Bot ${_game!.currentPlayer.englishName} passed contract selection');
            notifyListeners();
            _handleBotActions();
          }
        } else if (_game!.phase == GamePhase.playing) {
          final currentPlayerBefore = _game!.currentPlayer;
          final botCard = await _selectBotCard(_game!.currentPlayer);
          
          if (botCard != null) {
            if (kDebugMode) print('Bot ${_game!.currentPlayer.englishName} attempting to play: ${botCard.rank.englishName} ${botCard.suit.englishName}');
            
            // Debug: Check if the card is actually valid
            bool isCardValid = false;
            if (_game!.currentContract == TrexContract.trex) {
              isCardValid = _game!.canPlayTrexCard(botCard);
            } else {
              final player = _game!.getPlayerByPosition(_game!.currentPlayer);
              isCardValid = _game!.isValidTrickPlay(player, botCard);
            }
            
            if (kDebugMode) print('🔍 Card validity check: $isCardValid');
            
            bool gameStateChanged = _game!.playCard(_game!.currentPlayer, botCard);
            
            if (kDebugMode) print('🎮 Game state changed after play: $gameStateChanged');
            
            if (gameStateChanged) {
              notifyListeners();
              
              // For Trex mode, automatically check the next player for valid moves
              if (_game!.currentContract == TrexContract.trex) {
                checkAndAutoSkipTurn();
              } else {
                _handleBotActions();
              }
            } else {
              if (kDebugMode) print('❌ Bot ${_game!.currentPlayer.englishName} card was rejected by game');
              // Force advance to next player to prevent infinite loop
              _game!.currentPlayer = _game!.currentPlayer.next;
              if (kDebugMode) print('🔄 Forced advancement to ${_game!.currentPlayer.englishName}');
              notifyListeners();
              _handleBotActions();
            }
          } else {
            // Bot passed turn - check if game state actually changed
            if (_game!.currentPlayer != currentPlayerBefore) {
              if (kDebugMode) print('Bot ${currentPlayerBefore.englishName} passed turn, now ${_game!.currentPlayer.englishName}\'s turn');
              notifyListeners();
              _handleBotActions();
            } else {
              // Game state didn't change - this might indicate a problem
              if (kDebugMode) print('⚠️ Bot ${_game!.currentPlayer.englishName} passed but game state unchanged - stopping to prevent infinite loop');
              
              // For Trex, check if all players are stuck
              if (_game!.currentContract == TrexContract.trex) {
                final allPlayersFinishedOrStuck = _game!.players.every((player) => 
                    player.hand.isEmpty || !_game!.hasValidTrexMove(player));
                
                if (allPlayersFinishedOrStuck) {
                  if (kDebugMode) print('🏁 All players finished or stuck in Trex - ending round');
                  _game!.phase = GamePhase.roundEnd;
                  notifyListeners();
                  return;
                }
              }
              
              // For other contracts, similar check
              if (_game!.currentContract != TrexContract.trex) {
                final allPlayersHaveNoCards = _game!.players.every((player) => player.hand.isEmpty);
                if (allPlayersHaveNoCards) {
                  if (kDebugMode) print('🏁 All players finished - ending round');
                  _game!.phase = GamePhase.roundEnd;
                  notifyListeners();
                  return;
                }
              }
              
              // Force advance to break the loop
              if (kDebugMode) print('🔄 Force advancing to break infinite loop');
              _game!.currentPlayer = _game!.currentPlayer.next;
              notifyListeners();
              _handleBotActions();
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print('❌ Error in bot actions: $e');
        _errorMessage = 'Bot action error: ${e.toString()}';
        notifyListeners();
      }
    });
    } catch (e) {
      if (kDebugMode) print('⏱️ Bot action timed out or failed - forcing turn advancement');
      // Emergency fallback - advance the turn if we encounter an error or timeout
      if (_game != null && _game!.currentPlayer != PlayerPosition.south) {
        _game!.currentPlayer = _game!.currentPlayer.next;
        notifyListeners();
        // Try again with the next player
        _handleBotActions();
      }
    }
  }

  Future<TrexContract?> _calculateBotContract(PlayerPosition position) async {
    final availableContracts = _game!.availableContracts;
    if (availableContracts.isEmpty) return null;

    if (_aiService != null) {
      try {
        final aiContract = await _aiService!.selectContractWithFastFallback(
          botPosition: position,
          game: _game!,
          availableContracts: availableContracts,
        );
        if (aiContract != null && availableContracts.contains(aiContract)) {
          return aiContract;
        }
      } catch (e) {
        if (kDebugMode) print('❌ AI contract selection error: $e');
      }
    }
    
    final preferences = _calculateContractPreferences(_game!.getPlayerByPosition(position));
    return preferences.first;
  }

  Future<Card?> _selectBotCard(PlayerPosition position) async {
    final player = _game!.getPlayerByPosition(position);
    if (player.hand.isEmpty) return null;

    // Before trying AI, check if the player has any valid moves in Trex mode
    if (_game!.currentContract == TrexContract.trex) {
      List<Card> validMoves = player.hand.where((card) => _game!.canPlayTrexCard(card)).toList();
      if (validMoves.isEmpty) {
        if (kDebugMode) print('🔍 No valid Trex moves for ${position.englishName} - skipping AI call');
        // Return null immediately so the turn is passed
        return null;
      }
    }

    // Try AI service if available
    if (_aiService != null) {
      try {
        List<Card> validCards;
        if (_game!.currentContract == TrexContract.trex) {
          validCards = player.hand.where((card) => _game!.canPlayTrexCard(card)).toList();
        } else {
          validCards = player.hand.where((card) => _game!.isValidTrickPlay(player, card)).toList();
        }

        if (validCards.isNotEmpty) {
          final aiCard = await _aiService!.selectCardWithFastFallback(
            botPosition: position,
            game: _game!,
            hand: player.hand,
            validCards: validCards,
          );
          if (aiCard != null && validCards.contains(aiCard)) {
            return aiCard;
          }
        }
      } catch (e) {
        if (kDebugMode) print('❌ AI card selection error: $e');
      }
    }

    if (_game!.currentContract == TrexContract.trex) {
      // For Trex, first check if the player has any valid moves at all
      List<Card> validTrexCards = player.hand.where((card) => _game!.canPlayTrexCard(card)).toList();
      
      if (validTrexCards.isEmpty) {
        // Player has no valid moves, pass the turn
        if (kDebugMode) print('Bot ${player.position.englishName} has no valid Trex moves - passing turn');
        _game!.passTrexTurn();
        return null;
      }
      
      // Player has valid moves, select one
      final selectedCard = _selectTrexCard(player);
      if (selectedCard == null) {
        // This should not happen since we already checked for valid moves,
        // but just in case, pass the turn as a fallback
        if (kDebugMode) print('❌ Unexpected: Bot ${player.position.englishName} _selectTrexCard returned null despite having valid moves - passing turn');
        _game!.passTrexTurn();
      }
      return selectedCard;
    } else {
      // For trick-based contracts
      final selectedCard = _selectTrickCard(player);
      if (selectedCard == null) {
        // This should rarely happen in trick-based games
        // If no card is valid, just play the first card (emergency fallback)
        if (player.hand.isNotEmpty) {
          if (kDebugMode) print('Bot ${player.position.englishName} emergency fallback - playing first card');
          return player.hand.first;
        } else {
          if (kDebugMode) print('Bot ${player.position.englishName} has no cards left');
          return null;
        }
      }
      return selectedCard;
    }
  }

  Card? _selectTrexCard(Player player) {
    final validMoves = player.hand.where((card) => _game!.canPlayTrexCard(card)).toList();
    if (validMoves.isEmpty) {
      // Player has no valid Trex moves, will pass the turn in the calling method
      if (kDebugMode) print('Player ${player.position.englishName} has no valid Trex moves');
      return null;
    }
    validMoves.sort((a, b) => b.rank.value.compareTo(a.rank.value));
    return validMoves.first;
  }

  Card? _selectTrickCard(Player player) {
    final allCards = player.hand;
    final validCards = allCards.where((card) => _game!.isValidTrickPlay(player, card)).toList();
    
    if (kDebugMode) {
      print('🎯 Selecting trick card for ${player.position.englishName}:');
      print('   Hand size: ${allCards.length}');
      print('   Valid cards: ${validCards.length}');
      print('   All cards: ${allCards.map((c) => '${c.rank.englishName} ${c.suit.englishName}').join(', ')}');
      if (validCards.isNotEmpty) {
        print('   Valid cards: ${validCards.map((c) => '${c.rank.englishName} ${c.suit.englishName}').join(', ')}');
      }
      if (_game!.currentTrick != null && _game!.currentTrick!.cards.isNotEmpty) {
        final leadCard = _game!.currentTrick!.cards.values.first;
        print('   Lead card: ${leadCard.rank.englishName} ${leadCard.suit.englishName}');
        print('   Has lead suit: ${allCards.any((c) => c.suit == leadCard.suit)}');
      }
    }
    
    if (validCards.isEmpty) {
      // Player has no valid cards for trick play - this should be very rare
      if (kDebugMode) {
        print('⚠️ Player ${player.position.englishName} has no valid cards for trick play');
        print('   This suggests a game logic issue - in trick play, a player should always be able to play some card');
      }
      return null;
    }

    Card selectedCard;
    switch (_game!.currentContract) {
      case TrexContract.kingOfHearts:
        selectedCard = _selectForKingOfHearts(validCards, player);
        break;
      case TrexContract.queens:
        selectedCard = _selectForQueens(validCards, player);
        break;
      case TrexContract.diamonds:
        selectedCard = _selectForDiamonds(validCards, player);
        break;
      case TrexContract.collections:
        selectedCard = _selectForCollections(validCards, player);
        break;
      default:
        selectedCard = validCards.first;
        break;
    }
    
    // Double-check that the selected card is actually valid
    if (!_game!.isValidTrickPlay(player, selectedCard)) {
      if (kDebugMode) print('❌ Selected card ${selectedCard.rank.englishName} ${selectedCard.suit.englishName} is not valid! Using first valid card instead.');
      selectedCard = validCards.first;
    }
    
    if (kDebugMode) print('✅ Selected card: ${selectedCard.rank.englishName} ${selectedCard.suit.englishName}');
    return selectedCard;
  }

  Card _selectForKingOfHearts(List<Card> validCards, Player player) {
    final kingOfHearts = validCards.firstWhere((c) => c.isKingOfHearts, orElse: () => Card(suit: Suit.clubs, rank: Rank.two));
    if (kingOfHearts.suit != Suit.clubs) return kingOfHearts; // This check is a bit weird, but let's keep it.
    validCards.sort((a, b) => a.rank.value.compareTo(b.rank.value));
    return validCards.first;
  }

  Card _selectForQueens(List<Card> validCards, Player player) {
    validCards.sort((a, b) => a.rank.value.compareTo(b.rank.value));
    return validCards.first;
  }

  Card _selectForDiamonds(List<Card> validCards, Player player) {
    validCards.sort((a, b) => a.rank.value.compareTo(b.rank.value));
    return validCards.first;
  }

  Card _selectForCollections(List<Card> validCards, Player player) {
    validCards.sort((a, b) => a.rank.value.compareTo(b.rank.value));
    return validCards.first;
  }

  List<TrexContract> _calculateContractPreferences(Player player) {
    final handAnalysis = _analyzeHand(player.hand);
    final preferences = <TrexContract, int>{};

    for (var contract in _game!.availableContracts) {
      var score = 0;
      switch (contract) {
        case TrexContract.kingOfHearts:
          score += (handAnalysis['hasKingOfHearts'] as bool) ? -100 : 50;
          score += ((handAnalysis['highSpades'] as num) * 10).toInt();
          break;
        case TrexContract.queens:
          score -= ((handAnalysis['queensCount'] as num) * 25).toInt();
          break;
        case TrexContract.diamonds:
          score -= ((handAnalysis['diamondCount'] as num) * 10).toInt();
          break;
        case TrexContract.collections:
          score -= ((13 - (handAnalysis['highCards'] as num)) * 10).toInt();
          break;
        case TrexContract.trex:
          score += ((handAnalysis['lowCards'] as num) * 10).toInt();
          score -= ((handAnalysis['highCards'] as num) * 5).toInt();
          break;
      }
      preferences[contract] = score;
    }

    final sortedPreferences = preferences.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedPreferences.map((e) => e.key).toList();
  }

  Map<String, dynamic> _analyzeHand(List<Card> hand) {
    return {
      'hasKingOfHearts': hand.any((c) => c.isKingOfHearts),
      'queensCount': hand.where((c) => c.rank == Rank.queen).length,
      'diamondCount': hand.where((c) => c.suit == Suit.diamonds).length,
      'highCards': hand.where((c) => c.rank.value >= Rank.jack.value).length,
      'lowCards': hand.where((c) => c.rank.value <= Rank.six.value).length,
      'highSpades': hand.where((c) => c.suit == Suit.spades && c.rank.value >= Rank.jack.value).length,
    };
  }

  void resetGame() {
    _game = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _aiService?.dispose();
    super.dispose();
  }

  Future<void> reinitializeAIService() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('gemini_api_key');
      // final difficulty = AIDifficulty.values.byName(prefs.getString('ai_difficulty') ?? 'intermediate');
      
      if (apiKey != null && apiKey.isNotEmpty) {
        _aiService = AIService(apiKey: apiKey);
        if (kDebugMode) print('✅ AI Service reinitialized successfully.');
      } else {
        _aiService = null;
        if (kDebugMode) print('⚠️ AI Service not initialized (no API key).');
      }
    } catch (e) {
      _aiService = null;
      if (kDebugMode) print('❌ Error reinitializing AI Service: $e');
    }
    notifyListeners();
  }

  bool get isAIServiceAvailable => _aiService != null;

  String get aiServiceStatus {
    if (_aiService == null) return 'Not Configured';
    return 'Active (${_aiService!.providerName})';
  }
  
  Future<Map<String, dynamic>> testAIConnection() async {
    if (_aiService == null) {
      return {
        'success': false,
        'error': 'No AI service configured',
      };
    }
    return await _aiService!.testConnectionWithDebug();
  }

  Future<String> debugGameState() async {
    if (_game == null) return 'No active game.';

    final buffer = StringBuffer();
    buffer.writeln('--- GAME STATE DEBUG ---');
    buffer.writeln('Phase: ${_game!.phase.englishName}');
    buffer.writeln('Current Player: ${_game!.currentPlayer.englishName}');
    buffer.writeln('Current King: ${_game!.currentKing.englishName}');
    buffer.writeln('Contract: ${_game!.currentContract?.englishName ?? 'None'}');
    buffer.writeln('Players:');
    for (final player in _game!.players) {
      buffer.writeln('  - ${player.name} (${player.position.englishName}): ${player.hand.length} cards, Score: ${player.score}');
    }
    buffer.writeln('------------------------');
    return buffer.toString();
  }

  // Check if the current player has valid moves and automatically skip if none available
  Future<void> checkAndAutoSkipTurn() async {
    if (_game == null || _game!.phase != GamePhase.playing) return;
    
    // Safety counter to prevent infinite loops
    int safetyCounter = 0;
    final maxSkips = 4; // Maximum number of consecutive skips
    
    // Keep skipping turns until we find a player with valid moves or reach all players
    while (safetyCounter < maxSkips) {
      safetyCounter++;
      
      // Only check for the current player
      final currentPlayer = _game!.currentPlayer;
      final player = _game!.getPlayerByPosition(currentPlayer);
      
      if (_game!.currentContract == TrexContract.trex) {
        // For Trex mode: if player has no valid moves, auto-pass
        if (!_game!.hasValidTrexMove(player)) {
          if (kDebugMode) print('🔄 Auto-skipping ${currentPlayer.englishName} - no valid Trex moves (Skip #$safetyCounter)');
          
          if (currentPlayer == PlayerPosition.south) {
            // For human player, we need to call the passTrexTurn method
            passTrexTurn();
            // Don't continue the loop after human player
            break;
          } else {
            // For AI players, just pass the turn
            _game!.passTrexTurn();
            notifyListeners();
            
            // If we've skipped all players, we might be in a deadlock - end the round
            if (safetyCounter >= 3) {
              if (kDebugMode) print('⚠️ All players skipped - possible deadlock! Checking for game end condition.');
              
              final allPlayersFinishedOrStuck = _game!.players.every((player) => 
                  player.hand.isEmpty || !_game!.hasValidTrexMove(player));
                
              if (allPlayersFinishedOrStuck) {
                if (kDebugMode) print('🏁 All players finished or stuck in Trex - ending round');
                _game!.phase = GamePhase.roundEnd;
                notifyListeners();
                return;
              }
            }
            
            // Continue the loop to check the next player
            continue;
          }
        } else {
          // Current player has valid moves, stop skipping
          if (kDebugMode && safetyCounter > 1) {
            print('✅ ${currentPlayer.englishName} has valid moves after skipping ${safetyCounter-1} players');
          }
          
          // If it's an AI player, continue with bot actions
          if (currentPlayer != PlayerPosition.south) {
            _handleBotActions();
          }
          
          // Either way, break the loop as we found a player with valid moves
          break;
        }
      } else {
        // For other contracts, players always have at least one valid card to play
        // due to the trick-taking rules, so no need to check further
        break;
      }
    }
    
    if (safetyCounter >= maxSkips) {
      if (kDebugMode) print('⚠️ Reached maximum auto-skip limit - possible infinite loop detected!');
      // Force the game to continue by ending the round
      _game!.phase = GamePhase.roundEnd;
      notifyListeners();
    }
  }
}