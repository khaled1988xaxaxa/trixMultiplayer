import 'dart:math';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'card.dart';
import 'player.dart';

enum TrexContract {
  kingOfHearts,
  queens,
  diamonds,
  collections,
  trex;

  String get arabicName {
    switch (this) {
      case TrexContract.kingOfHearts:
        return 'شايب الكلب';
      case TrexContract.queens:
        return 'الكباري';
      case TrexContract.diamonds:
        return 'الديناري';
      case TrexContract.collections:
        return 'اللمة';
      case TrexContract.trex:
        return 'تريكس';
    }
  }

  String get englishName {
    switch (this) {
      case TrexContract.kingOfHearts:
        return 'King of Hearts';
      case TrexContract.queens:
        return 'Queens';
      case TrexContract.diamonds:
        return 'Diamonds';
      case TrexContract.collections:
        return 'Collections';
      case TrexContract.trex:
        return 'Trex';
    }
  }

  String get description {
    switch (this) {
      case TrexContract.kingOfHearts:
        return 'Avoid taking the King of Hearts (-75 points)';
      case TrexContract.queens:
        return 'Avoid taking Queens (-25 per Queen)';
      case TrexContract.diamonds:
        return 'Avoid taking Diamonds (-10 per Diamond)';
      case TrexContract.collections:
        return 'Avoid taking tricks (-15 per trick)';
      case TrexContract.trex:
        return 'Get rid of your cards first (+200 for first)';
    }
  }

  int get baseScore {
    switch (this) {
      case TrexContract.kingOfHearts:
        return -75;
      case TrexContract.queens:
        return -25; // per queen
      case TrexContract.diamonds:
        return -10; // per diamond
      case TrexContract.collections:
        return -15; // per trick
      case TrexContract.trex:
        return 200; // for first place
    }
  }
}

enum GamePhase {
  contractSelection,
  playing,
  trickComplete, // New phase for after a trick is played
  roundEnd,
  kingdomEnd,
  gameEnd;

  String get arabicName {
    switch (this) {
      case GamePhase.contractSelection:
        return 'اختيار العقد';
      case GamePhase.playing:
        return 'اللعب';
      case GamePhase.trickComplete:
        return 'انتهاء الجولة';
      case GamePhase.roundEnd:
        return 'انتهاء الدور';
      case GamePhase.kingdomEnd:
        return 'انتهاء المملكة';
      case GamePhase.gameEnd:
        return 'انتهاء اللعبة';
    }
  }

  String get englishName {
    switch (this) {
      case GamePhase.contractSelection:
        return 'Contract Selection';
      case GamePhase.playing:
        return 'Playing';
      case GamePhase.trickComplete:
        return 'Trick Complete';
      case GamePhase.roundEnd:
        return 'Round End';
      case GamePhase.kingdomEnd:
        return 'Kingdom End';
      case GamePhase.gameEnd:
        return 'Game End';
    }
  }
}

class Trick {
  final Map<PlayerPosition, Card> cards = {};
  PlayerPosition? winner;
  PlayerPosition leadPlayer;

  Trick({required this.leadPlayer});

  void addCard(PlayerPosition position, Card card) {
    cards[position] = card;
  }

  bool get isComplete => cards.length == 4;

  List<Card> get playedCards => cards.values.toList();

  PlayerPosition? determineWinner(Suit? trumpSuit) {
    if (!isComplete) return null;

    Card leadCard = cards[leadPlayer]!;
    Suit leadSuit = leadCard.suit;
    
    PlayerPosition winningPosition = leadPlayer;
    Card winningCard = leadCard;

    for (var entry in cards.entries) {
      Card card = entry.value;
      PlayerPosition position = entry.key;

      // Trump card beats non-trump
      if (trumpSuit != null && card.suit == trumpSuit && winningCard.suit != trumpSuit) {
        winningCard = card;
        winningPosition = position;
      }
      // Higher trump beats lower trump
      else if (trumpSuit != null && card.suit == trumpSuit && winningCard.suit == trumpSuit) {
        if (card.rank.value > winningCard.rank.value) {
          winningCard = card;
          winningPosition = position;
        }
      }
      // Same suit, higher rank wins (if no trump involved)
      else if (card.suit == leadSuit && winningCard.suit == leadSuit && trumpSuit != winningCard.suit) {
        if (card.rank.value > winningCard.rank.value) {
          winningCard = card;
          winningPosition = position;
        }
      }
    }

    winner = winningPosition;
    return winningPosition;
  }
}

class TrexGame {
  final List<Player> players;
  final List<Card> deck;
  final List<Trick> tricks = [];
  Trick? lastCompletedTrick; // To store the last completed trick
  
  GamePhase phase = GamePhase.contractSelection;
  TrexContract? currentContract;
  PlayerPosition currentPlayer;
  PlayerPosition currentKing; // Who owns the current kingdom
  Trick? currentTrick;
  
  int round = 1;
  int kingdom = 1; // 1-4 kingdoms total
  final Map<PlayerPosition, int> tricksWon = {};
  final Set<TrexContract> usedContracts = {}; // Contracts used by current king
  
  // Special cards tracking
  final Map<PlayerPosition, List<Card>> collectedQueens = {};
  final Map<PlayerPosition, List<Card>> collectedDiamonds = {};
  Card? kingOfHeartsCard;
  PlayerPosition? kingOfHeartsHolder;
  bool isKingOfHeartsDoubled = false;
  
  // Trex game state (when playing Trex contract)
  final Map<Suit, List<Card>> trexLayout = {
    Suit.hearts: [],
    Suit.diamonds: [],
    Suit.clubs: [],
    Suit.spades: [],
  };

  TrexGame({
    required this.players,
    required PlayerPosition firstKing,
  }) : deck = _createDeck(),
       currentKing = firstKing,
       currentPlayer = firstKing {
    _initializeCollections();
  }

  void _initializeCollections() {
    for (PlayerPosition pos in PlayerPosition.values) {
      collectedQueens[pos] = [];
      collectedDiamonds[pos] = [];
      tricksWon[pos] = 0;
    }
  }

  static List<Card> _createDeck() {
    List<Card> cards = [];
    for (Suit suit in Suit.values) {
      for (Rank rank in Rank.values) {
        cards.add(Card(id: Card.generateId(suit, rank), suit: suit, rank: rank));
      }
    }
    return cards;
  }

  void shuffleDeck() {
    deck.shuffle(Random());
  }

  void dealCards() {
    // Clear previous hands
    for (Player player in players) {
      player.hand.clear();
    }
    
    // Reset deck
    deck.clear();
    deck.addAll(_createDeck());
    shuffleDeck();
    
    // Deal 13 cards to each player
    int cardsPerPlayer = 13;
    
    for (int i = 0; i < cardsPerPlayer; i++) {
      for (Player player in players) {
        if (deck.isNotEmpty) {
          player.addCard(deck.removeAt(0));
        }
      }
    }
    
    // Sort each player's hand
    for (Player player in players) {
      player.sortHand();
    }
    
    // Find king of hearts
    _findKingOfHearts();
  }

  void _findKingOfHearts() {
    for (Player player in players) {
      for (Card card in player.hand) {
        if (card.suit == Suit.hearts && card.rank == Rank.king) {
          kingOfHeartsCard = card;
          kingOfHeartsHolder = player.position;
          break;
        }
      }
    }
  }

  void startContractSelection() {
    phase = GamePhase.contractSelection;
    currentPlayer = currentKing;
  }

  bool selectContract(TrexContract contract) {
    if (phase != GamePhase.contractSelection) return false;
    if (usedContracts.contains(contract)) return false;

    currentContract = contract;
    usedContracts.add(contract);
    
    if (contract == TrexContract.trex) {
      _initializeTrexLayout();
    }
    
    phase = GamePhase.playing;
    _startPlaying();
    return true;
  }

  void _initializeTrexLayout() {
    // In Trex contract, layout starts empty and players build sequences
    for (Suit suit in Suit.values) {
      trexLayout[suit] = [];
    }
  }

  void _startPlaying() {
    tricksWon.clear();
    for (PlayerPosition pos in PlayerPosition.values) {
      tricksWon[pos] = 0;
    }
    
    if (currentContract == TrexContract.trex) {
      // In Trex, current king starts
      currentPlayer = currentKing;
    } else {
      // In trick-taking contracts, start new trick
      _startNewTrick(currentKing);
    }
  }

  void _startNewTrick(PlayerPosition leadPlayer) {
    currentTrick = Trick(leadPlayer: leadPlayer);
    currentPlayer = leadPlayer;
  }

  bool playCard(PlayerPosition position, Card card) {
    if (kDebugMode) {
      print('🎮 Attempting to play ${card.rank.englishName} of ${card.suit.englishName} by ${position.englishName}');
      print('   Current phase: ${phase.englishName}');
      print('   Current player: ${currentPlayer.englishName}');
      print('   Current contract: ${currentContract?.englishName}');
    }
    
    if (phase != GamePhase.playing) {
      if (kDebugMode) print('❌ Card play rejected: Wrong phase (${phase.englishName})');
      return false;
    }
    if (position != currentPlayer) {
      if (kDebugMode) print('❌ Card play rejected: Not current player (current: ${currentPlayer.englishName}, attempted: ${position.englishName})');
      return false;
    }
    
    Player player = players.firstWhere((p) => p.position == position);
    if (!player.hand.contains(card)) {
      if (kDebugMode) print('❌ Card play rejected: Card not in player\'s hand');
      return false;
    }
    
    if (currentContract == TrexContract.trex) {
      if (kDebugMode) print('🎯 Playing card in Trex contract');
      return _playTrexCard(position, card);
    } else {
      if (kDebugMode) print('🎯 Playing card in trick-based contract');
      return _playTrickCard(position, card);
    }
  }

  bool canPlayTrexCard(Card card) {
    // Debug logging for Jack cards
    if (card.rank == Rank.jack) {
      if (kDebugMode) {
        print('🃏 Jack of ${card.suit.englishName} can always be played in Trex');
      }
      return true;
    }
    
    // If no cards in suit layout, can only play jacks
    List<Card> suitLayout = trexLayout[card.suit]!;
    if (suitLayout.isEmpty) {
      if (kDebugMode) {
        print('❌ ${card.rank.englishName} of ${card.suit.englishName} cannot be played - no cards in suit layout');
      }
      return false;
    }
    
    // Check if card can be added to sequence (must be adjacent)
    bool canPlay = false;
    for (Card layoutCard in suitLayout) {
      if ((card.rank.value == layoutCard.rank.value + 1) ||
          (card.rank.value == layoutCard.rank.value - 1)) {
        canPlay = true;
        if (kDebugMode) {
          print('✅ ${card.rank.englishName} of ${card.suit.englishName} can be played - adjacent to ${layoutCard.rank.englishName}');
        }
        break;
      }
    }
    
    if (!canPlay && kDebugMode) {
      print('❌ ${card.rank.englishName} of ${card.suit.englishName} cannot be played - not adjacent to any card in layout');
      print('   Layout cards: ${suitLayout.map((c) => c.rank.englishName).join(', ')}');
    }
    
    return canPlay;
  }

  bool hasValidTrexMove(Player player) {
    return player.hand.any((card) => canPlayTrexCard(card));
  }

  bool _playTrexCard(PlayerPosition position, Card card) {
    Player player = players.firstWhere((p) => p.position == position);
    
    // Check if card can be played in Trex
    if (!canPlayTrexCard(card)) {
      if (kDebugMode) print('❌ Trex card play rejected: Not a valid card to play');
      return false;
    }
    
    if (kDebugMode) {
      print('✅ Playing Trex card: ${card.rank.englishName} of ${card.suit.englishName}');
      print('   Before play layout: ${trexLayout.map((suit, cards) => 
          MapEntry(suit.englishName, cards.map((c) => c.rank.englishName).join(', '))).values.join(' | ')}');
    }
    
    // Remove card from hand and add to layout
    player.removeCard(card);
    _addCardToTrexLayout(card);
    
    if (kDebugMode) {
      print('   After play layout: ${trexLayout.map((suit, cards) => 
          MapEntry(suit.englishName, cards.map((c) => c.rank.englishName).join(', '))).values.join(' | ')}');
    }
    
    // Check if player finished
    if (player.hand.isEmpty) {
      if (kDebugMode) print('🏁 Player ${position.englishName} finished with no cards left');
      _handleTrexFinish(position);
      return true;
    }
    
    // Next player
    currentPlayer = currentPlayer.next;
    return true;
  }

  void passTrexTurn() {
    // Move to next player when passing in Trex
    currentPlayer = currentPlayer.next;
  }

  void _addCardToTrexLayout(Card card) {
    trexLayout[card.suit]!.add(card);
    trexLayout[card.suit]!.sort((a, b) => a.rank.value.compareTo(b.rank.value));
  }

  void _handleTrexFinish(PlayerPosition position) {
    // Award points based on finish order
    int finishedCount = players.where((p) => p.hand.isEmpty).length;
    Player player = players.firstWhere((p) => p.position == position);
    
    switch (finishedCount) {
      case 1:
        player.score += 200;
        if (kDebugMode) print('🏆 ${position.englishName} awarded 200 points for finishing 1st');
        break;
      case 2:
        player.score += 150;
        if (kDebugMode) print('🥈 ${position.englishName} awarded 150 points for finishing 2nd');
        break;
      case 3:
        player.score += 100;
        if (kDebugMode) print('🥉 ${position.englishName} awarded 100 points for finishing 3rd');
        
        // When 3 players finish, award 50 points to the last player who still has cards
        _awardPointsToLastPlayer();
        break;
      case 4:
        player.score += 50;
        if (kDebugMode) print('👍 ${position.englishName} awarded 50 points for finishing 4th');
        break;
    }
    
    // Check if round is complete
    if (finishedCount >= 3) {
      _completeRound();
    }
  }
  
  // Helper method to award 50 points to the last player with cards
  void _awardPointsToLastPlayer() {
    // Find the player who still has cards
    final playersWithCards = players.where((p) => p.hand.isNotEmpty).toList();
    
    if (playersWithCards.length == 1) {
      final lastPlayer = playersWithCards.first;
      lastPlayer.score += 50;
      if (kDebugMode) {
        print('👍 ${lastPlayer.position.englishName} awarded 50 points as the last player with cards');
      }
    }
  }

  bool _playTrickCard(PlayerPosition position, Card card) {
    if (currentTrick == null) return false;
    
    Player player = players.firstWhere((p) => p.position == position);
    
    // Validate card play (must follow suit if possible)
    if (!_isValidTrickPlay(player, card)) return false;
    
    // Remove card from player's hand and add to trick
    player.removeCard(card);
    currentTrick!.addCard(position, card);
    
    if (currentTrick!.isComplete) {
      phase = GamePhase.trickComplete; // Transition to new phase, don't complete trick yet
    } else {
      currentPlayer = currentPlayer.next;
    }
    
    return true;
  }

  bool isValidTrickPlay(Player player, Card card) {
    if (currentTrick == null || currentTrick!.cards.isEmpty) return true; // Can lead any card
    
    // Must follow suit if possible
    Suit leadSuit = currentTrick!.cards.values.first.suit;
    bool hasLeadSuit = player.hand.any((c) => c.suit == leadSuit);
    
    if (hasLeadSuit && card.suit != leadSuit) return false;
    
    return true;
  }

  bool _isValidTrickPlay(Player player, Card card) {
    return isValidTrickPlay(player, card);
  }

  void _completeTrick() {
    if (currentTrick == null) return;

    try {
      PlayerPosition? winner = currentTrick!.determineWinner(null);
      if (winner != null) {
        tricksWon[winner] = (tricksWon[winner] ?? 0) + 1;
        tricks.add(currentTrick!);
        lastCompletedTrick = currentTrick; // Set the last completed trick here

        // Handle special cards based on contract
        _handleSpecialCards(currentTrick!, winner);

        // Clear current trick before starting new one
        currentTrick = null;

        // Check if round is complete (either all tricks played or an early end condition)
        if (tricks.length == 13 || phase == GamePhase.roundEnd) {
          _completeRound();
        } else {
          _startNewTrick(winner);
        }
      } else {
        // If no winner determined, clear the trick
        currentTrick = null;
      }
    } catch (e) {
      // Safe fallback - clear the trick and continue
      currentTrick = null;
      // Move to next player or restart trick
      if (tricks.length < 13) {
        _startNewTrick(currentKing);
      }
    }
  }

  void completeTrick() {
    // This will be called by the provider after a delay
    if (phase == GamePhase.trickComplete) {
      _completeTrick();
      // If _completeTrick ended the round, the phase will be something else (e.g., contractSelection).
      // If it was a normal trick, the phase will still be trickComplete, so we switch it to playing.
      if (phase == GamePhase.trickComplete) {
        phase = GamePhase.playing;
      }
    }
  }

  void _handleSpecialCards(Trick trick, PlayerPosition winner) {
    try {
      Player? winnerPlayer = players.firstWhere((p) => p.position == winner);
      if (currentContract == null) return;

      bool roundShouldEnd = false;

      for (Card card in trick.playedCards) {
        switch (currentContract!) {
          case TrexContract.kingOfHearts:
            if (card.suit == Suit.hearts && card.rank == Rank.king) {
              int penalty = isKingOfHeartsDoubled ? -150 : -75;
              winnerPlayer.score += penalty;

              // Give bonus to original holder if doubled
              if (isKingOfHeartsDoubled && kingOfHeartsHolder != null && kingOfHeartsHolder != winner) {
                players.firstWhere((p) => p.position == kingOfHeartsHolder!).score += 75;
              }
              roundShouldEnd = true;
            }
            break;

          case TrexContract.queens:
            if (card.rank == Rank.queen) {
              collectedQueens[winner]?.add(card);
              winnerPlayer.score += -25;
            }
            break;

          case TrexContract.diamonds:
            if (card.suit == Suit.diamonds) {
              collectedDiamonds[winner]?.add(card);
              winnerPlayer.score += -10;
            }
            break;

          default:
            // No special card handling for other contracts
            break;
        }
      }

      // Collections penalty (per trick)
      if (currentContract == TrexContract.collections) {
        winnerPlayer.score += -15;
      }

      // Check for end conditions after processing all cards in the trick
      if (currentContract == TrexContract.queens) {
        int totalQueensCollected = collectedQueens.values.fold(0, (sum, list) => sum + list.length);
        if (totalQueensCollected >= 4) {
          roundShouldEnd = true;
        }
      } else if (currentContract == TrexContract.diamonds) {
        int totalDiamondsCollected = collectedDiamonds.values.fold(0, (sum, list) => sum + list.length);
        if (totalDiamondsCollected >= 13) {
          roundShouldEnd = true;
        }
      }

      if (roundShouldEnd) {
        phase = GamePhase.roundEnd;
      }
    } catch (e) {
      // Safe fallback
    }
  }

  void _completeRound() {
    phase = GamePhase.roundEnd;
    
    // Check if kingdom is complete
    if (usedContracts.length >= 5) {
      _completeKingdom();
    } else {
      _prepareNextRound();
    }
  }

  void _completeKingdom() {
    phase = GamePhase.kingdomEnd;
    
    if (kingdom >= 4) {
      phase = GamePhase.gameEnd;
    } else {
      _prepareNextKingdom();
    }
  }

  void _prepareNextRound() {
    // Reset for next round in same kingdom
    tricks.clear();
    tricksWon.clear();
    currentTrick = null;
    lastCompletedTrick = null; // Reset for the new round
    
    // Clear collections
    for (PlayerPosition pos in PlayerPosition.values) {
      collectedQueens[pos]!.clear();
      collectedDiamonds[pos]!.clear();
      tricksWon[pos] = 0;
    }
    
    round++;
    dealCards();
    startContractSelection();
  }

  void _prepareNextKingdom() {
    // Move to next kingdom
    kingdom++;
    currentKing = currentKing.next;
    usedContracts.clear();
    round = 1;
    
    // Reset collections
    _initializeCollections();
    
    dealCards();
    startContractSelection();
  }

  bool doubleKingOfHearts() {
    if (currentContract != TrexContract.kingOfHearts) return false;
    if (kingOfHeartsHolder != currentPlayer) return false;
    
    isKingOfHeartsDoubled = true;
    return true;
  }

  Player? get winner {
    if (phase != GamePhase.gameEnd) return null;
    return players.reduce((a, b) => a.score > b.score ? a : b);
  }

  Player getPlayerByPosition(PlayerPosition position) {
    return players.firstWhere((player) => player.position == position);
  }

  List<TrexContract> get availableContracts {
    return TrexContract.values.where((contract) => !usedContracts.contains(contract)).toList();
  }
}