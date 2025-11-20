/**
 * Main TrexGame class - Server-side authoritative game logic
 * Ported and optimized from the Dart implementation
 */

const { 
  Suit, 
  Rank, 
  PlayerPosition, 
  TrexContract, 
  GamePhase, 
  Card, 
  Player, 
  Trick 
} = require('./GameModels');

const Logger = require('../utils/Logger');

class TrexGame {
  constructor(players, firstKing) {
    this.id = this.generateGameId();
    this.players = new Map(); // PlayerPosition -> Player
    this.deck = this.createDeck();
    this.tricks = [];
    this.lastCompletedTrick = null;
    
    // Game state
    this.phase = GamePhase.CONTRACT_SELECTION;
    this.currentContract = null;
    this.currentPlayer = firstKing;
    this.currentKing = firstKing;
    this.currentTrick = null;
    
    // Game progress
    this.round = 1;
    this.kingdom = 1; // 1-4 kingdoms total
    this.tricksWon = new Map(); // PlayerPosition -> number
    this.usedContracts = new Set(); // Contracts used by current king
    
    // Special cards tracking
    this.collectedQueens = new Map(); // PlayerPosition -> Card[]
    this.collectedDiamonds = new Map(); // PlayerPosition -> Card[]
    this.kingOfHeartsCard = null;
    this.kingOfHeartsHolder = null;
    this.isKingOfHeartsDoubled = false;
    
    // Trex game state
    this.trexLayout = {
      [Suit.HEARTS]: [],
      [Suit.DIAMONDS]: [],
      [Suit.CLUBS]: [],
      [Suit.SPADES]: []
    };
    
    // Game metadata
    this.createdAt = new Date();
    this.lastActivity = new Date();
    this.gameHistory = []; // For replay/analysis
    
    // Initialize with players
    this.initializePlayers(players);
    this.initializeCollections();
    
    Logger.info(`🎮 New TrexGame created: ${this.id}`);
    Logger.info(`👑 First King: ${firstKing}`);
  }

  generateGameId() {
    return `game_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  initializePlayers(players) {
    players.forEach(player => {
      this.players.set(player.position, player);
    });
  }

  initializeCollections() {
    for (const position of Object.values(PlayerPosition)) {
      this.collectedQueens.set(position, []);
      this.collectedDiamonds.set(position, []);
      this.tricksWon.set(position, 0);
    }
  }

  createDeck() {
    const cards = [];
    for (const suit of Object.values(Suit)) {
      for (const rank of Object.values(Rank)) {
        cards.push(new Card(suit, rank));
      }
    }
    return cards;
  }

  shuffleDeck() {
    for (let i = this.deck.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [this.deck[i], this.deck[j]] = [this.deck[j], this.deck[i]];
    }
  }

  dealCards() {
    // Clear previous hands
    this.players.forEach(player => {
      player.hand = [];
    });
    
    // Reset and shuffle deck
    this.deck = this.createDeck();
    this.shuffleDeck();
    
    Logger.debug(`🎯 [Card Dealing] Deck created with ${this.deck.length} cards`);
    
    // Deal 13 cards to each player
    const cardsPerPlayer = 13;
    const playerPositions = Array.from(this.players.keys());
    
    for (let i = 0; i < cardsPerPlayer; i++) {
      for (const position of playerPositions) {
        if (this.deck.length > 0) {
          const card = this.deck.pop();
          this.players.get(position).addCard(card);
        }
      }
    }
    
    // Sort each player's hand
    this.players.forEach(player => {
      player.sortHand();
    });
    
    // Find king of hearts
    this.findKingOfHearts();
    
    // Debug logging for each player's hand
    for (const [position, player] of this.players) {
      const cardIds = player.hand.map(c => c.id).join(', ');
      Logger.debug(`🎯 [Card Dealing] ${position} (${player.name}): ${player.hand.length} cards - [${cardIds}]`);
    }
    
    Logger.info(`🃏 Cards dealt. King of Hearts with: ${this.kingOfHeartsHolder}`);
  }

  findKingOfHearts() {
    for (const [position, player] of this.players) {
      for (const card of player.hand) {
        if (card.suit === Suit.HEARTS && card.rank === Rank.KING) {
          this.kingOfHeartsCard = card;
          this.kingOfHeartsHolder = position;
          return;
        }
      }
    }
  }

  // Contract selection methods
  selectContract(contract) {
    if (this.phase !== GamePhase.CONTRACT_SELECTION) {
      throw new Error('Contract can only be selected during contract selection phase');
    }
    
    if (this.usedContracts.has(contract)) {
      throw new Error('This contract has already been used by the current king');
    }
    
    this.currentContract = contract;
    this.usedContracts.add(contract);
    this.phase = GamePhase.PLAYING;
    
    // Reset collections for new round
    this.resetRoundCollections();
    
    Logger.info(`📋 Contract selected: ${contract} by ${this.currentKing}`);
    
    return this.getGameState();
  }

  resetRoundCollections() {
    this.collectedQueens.clear();
    this.collectedDiamonds.clear();
    this.tricksWon.clear();
    this.tricks = [];
    this.currentTrick = null;
    this.lastCompletedTrick = null;
    
    for (const position of Object.values(PlayerPosition)) {
      this.collectedQueens.set(position, []);
      this.collectedDiamonds.set(position, []);
      this.tricksWon.set(position, 0);
    }
    
    if (this.currentContract === TrexContract.TREX.name) {
      // Reset Trex layout
      for (const suit of Object.values(Suit)) {
        this.trexLayout[suit] = [];
      }
    }
  }

  // Card playing methods
  playCard(playerPosition, cardId) {
    if (this.phase !== GamePhase.PLAYING) {
      throw new Error('Cards can only be played during playing phase');
    }
    
    if (playerPosition !== this.currentPlayer) {
      throw new Error('It is not this player\'s turn');
    }
    
    const player = this.players.get(playerPosition);

    // Enhanced card validation logging
    if (player) {
      const serverHand = player.hand.map(c => c.id).join(', ');
      Logger.debug(`🎯 [Card Validation] Player: ${playerPosition} (${player.name}), Attempting to play: ${cardId}`);
      Logger.debug(`🎯 [Card Validation] Server Hand: [${serverHand}]`);
      Logger.debug(`🎯 [Card Validation] Hand size: ${player.hand.length}`);
      
      // Check if card exists in hand
      const hasCard = player.hasCard(cardId);
      Logger.debug(`🎯 [Card Validation] Has card ${cardId}: ${hasCard}`);
      
      if (!hasCard) {
        Logger.error(`❌ [Card Validation] Card ${cardId} NOT found in player ${playerPosition}'s hand!`);
      }
    }

    if (!player || !player.hasCard(cardId)) {
      throw new Error('Player does not have this card');
    }
    
    // Validate move
    if (!this.isValidMove(playerPosition, cardId)) {
      throw new Error('Invalid move');
    }
    
    // Remove card from player's hand
    const card = player.removeCard(cardId);
    
    // Add to current trick
    if (!this.currentTrick) {
      this.currentTrick = new Trick(playerPosition);
    }
    
    this.currentTrick.addCard(playerPosition, card);
    
    // Log the action
    this.addToGameHistory({
      type: 'CARD_PLAYED',
      player: playerPosition,
      card: card.toJson(),
      timestamp: new Date()
    });
    
    Logger.info(`🃏 ${playerPosition} played ${card.toString()}`);
    
    // Check if trick is complete
    if (this.currentTrick.isComplete()) {
      this.completeTrick();
    } else {
      this.advanceToNextPlayer();
    }
    
    this.lastActivity = new Date();
    return this.getGameState();
  }

  isValidMove(playerPosition, cardId) {
    const player = this.players.get(playerPosition);
    if (!player) return false;
    
    const card = player.hand.find(c => c.id === cardId);
    if (!card) return false;
    
    // Get valid moves for this player
    const validMoves = player.getValidMoves(this.currentTrick, this.currentContract);
    
    // Enhanced validation logging
    const isValid = validMoves.some(validCard => validCard.id === cardId);
    Logger.debug(`🎯 [Move Validation] Player: ${playerPosition}, Card: ${cardId}, Valid: ${isValid}, Contract: ${this.currentContract}`);
    
    return isValid;
  }
  
  // Contract enforcement - validate trick according to trump rules
  validateTrickCompliance(trick, contract) {
    if (!trick || trick.cards.size === 0) {
      return true; // Empty trick is valid
    }
    
    try {
      const allPlayers = Array.from(this.players.values());
      
      for (const player of allPlayers) {
        if (player.hand.length === 0) continue; // Skip players with no cards
        
        // Get all cards played in this trick by other players
        const cardsInTrick = Array.from(trick.cards.values());
        if (cardsInTrick.length === 0) continue;
        
        // Determine led suit
        const ledSuit = cardsInTrick[0].suit;
        
        // Check if player followed suit when they should have
        const playerCardsInTrick = trick.cards.get(player.position);
        if (playerCardsInTrick) {
          const playerCardSuit = playerCardsInTrick.suit;
          
          // Player must follow suit if possible
          const hasLedSuit = player.hand.some(c => c.suit === ledSuit);
          if (hasLedSuit && playerCardSuit !== ledSuit) {
            Logger.warn(`⚠️ [Contract Validation] Player ${player.position} did not follow suit in trick`);
            return false;
          }
        }
      }
      
      return true;
    } catch (e) {
      Logger.error(`[Contract Validation] Error validating trick: ${e.message}`);
      return true; // Don't block play on validation error
    }
  }

  completeTrick() {
    const winner = this.currentTrick.determineWinner();
    this.currentTrick.winner = winner;
    
    // Update tricks won
    const currentCount = this.tricksWon.get(winner) || 0;
    this.tricksWon.set(winner, currentCount + 1);
    
    // Collect special cards
    this.processSpecialCards(this.currentTrick);
    
    // Store completed trick
    this.lastCompletedTrick = this.currentTrick;
    this.tricks.push(this.currentTrick);
    
    Logger.info(`🏆 Trick won by: ${winner}`);
    
    // Check if round is complete
    if (this.isRoundComplete()) {
      this.completeRound();
    } else {
      // Start new trick with winner leading
      this.currentTrick = null;
      this.currentPlayer = winner;
      this.phase = GamePhase.TRICK_COMPLETE;
      
      // Brief pause before continuing
      setTimeout(() => {
        this.phase = GamePhase.PLAYING;
      }, 1000);
    }
  }

  processSpecialCards(trick) {
    for (const [position, card] of trick.cards) {
      // Collect queens
      if (card.rank === Rank.QUEEN) {
        this.collectedQueens.get(position).push(card);
      }
      
      // Collect diamonds
      if (card.suit === Suit.DIAMONDS) {
        this.collectedDiamonds.get(position).push(card);
      }
      
      // Handle Trex layout
      if (this.currentContract === TrexContract.TREX.name) {
        this.trexLayout[card.suit].push(card);
      }
    }
  }

  advanceToNextPlayer() {
    const positions = Object.values(PlayerPosition);
    const currentIndex = positions.indexOf(this.currentPlayer);
    const nextIndex = (currentIndex + 1) % positions.length;
    this.currentPlayer = positions[nextIndex];
  }
  
  // Skip current player's turn (e.g., on timeout)
  skipCurrentPlayer() {
    if (this.phase !== GamePhase.PLAYING) {
      throw new Error('Can only skip during playing phase');
    }
    
    const currentPlayer = this.currentPlayer;
    Logger.warn(`⏭️ Skipping turn for player ${currentPlayer}`);
    
    // Move to next player
    this.advanceToNextPlayer();
    
    Logger.info(`➡️ Turn advanced to ${this.currentPlayer}`);
    return this.getGameState();
  }

  isRoundComplete() {
    // Check if all players have empty hands
    return Array.from(this.players.values()).every(player => player.hand.length === 0);
  }

  completeRound() {
    this.phase = GamePhase.ROUND_END;
    
    // Calculate scores for this round
    this.calculateRoundScores();
    
    // Check if kingdom is complete (5 rounds per kingdom)
    if (this.round >= 5) {
      this.completeKingdom();
    } else {
      // Start next round
      this.startNextRound();
    }
  }

  calculateRoundScores() {
    const scores = new Map();
    
    switch (this.currentContract) {
      case TrexContract.KING_OF_HEARTS.name:
        this.calculateKingOfHeartsScores(scores);
        break;
      case TrexContract.QUEENS.name:
        this.calculateQueensScores(scores);
        break;
      case TrexContract.DIAMONDS.name:
        this.calculateDiamondsScores(scores);
        break;
      case TrexContract.COLLECTIONS.name:
        this.calculateCollectionsScores(scores);
        break;
      case TrexContract.TREX.name:
        this.calculateTrexScores(scores);
        break;
    }
    
    // Apply scores to players
    for (const [position, score] of scores) {
      const player = this.players.get(position);
      if (player) {
        player.score = score;
        player.totalScore += score;
      }
    }
    
    Logger.info(`📊 Round ${this.round} scores calculated`);
  }

  calculateKingOfHeartsScores(scores) {
    for (const position of Object.values(PlayerPosition)) {
      scores.set(position, 0);
    }
    
    if (this.kingOfHeartsHolder) {
      const penalty = this.isKingOfHeartsDoubled ? -150 : -75;
      scores.set(this.kingOfHeartsHolder, penalty);
    }
  }

  calculateQueensScores(scores) {
    for (const [position, queens] of this.collectedQueens) {
      const penalty = queens.length * -25;
      scores.set(position, penalty);
    }
  }

  calculateDiamondsScores(scores) {
    for (const [position, diamonds] of this.collectedDiamonds) {
      const penalty = diamonds.length * -10;
      scores.set(position, penalty);
    }
  }

  calculateCollectionsScores(scores) {
    for (const [position, tricksCount] of this.tricksWon) {
      const penalty = tricksCount * -15;
      scores.set(position, penalty);
    }
  }

  calculateTrexScores(scores) {
    // Find the order players finished (empty hands first)
    const finishOrder = [];
    // This would need more complex logic to track when each player finished
    // For now, simplified implementation
    for (const position of Object.values(PlayerPosition)) {
      scores.set(position, 0);
    }
  }

  startNextRound() {
    this.round++;
    this.phase = GamePhase.CONTRACT_SELECTION;
    this.currentPlayer = this.currentKing;
    this.dealCards();
    
    Logger.info(`🔄 Starting round ${this.round}`);
  }

  completeKingdom() {
    this.phase = GamePhase.KINGDOM_END;
    
    // Check if game is complete (4 kingdoms)
    if (this.kingdom >= 4) {
      this.completeGame();
    } else {
      this.startNextKingdom();
    }
  }

  startNextKingdom() {
    this.kingdom++;
    this.round = 1;
    this.usedContracts.clear();
    
    // Advance to next king
    const positions = Object.values(PlayerPosition);
    const currentIndex = positions.indexOf(this.currentKing);
    const nextIndex = (currentIndex + 1) % positions.length;
    this.currentKing = positions[nextIndex];
    this.currentPlayer = this.currentKing;
    
    this.phase = GamePhase.CONTRACT_SELECTION;
    this.dealCards();
    
    Logger.info(`👑 Kingdom ${this.kingdom} started. New king: ${this.currentKing}`);
  }

  completeGame() {
    this.phase = GamePhase.GAME_END;
    
    // Calculate final standings
    const finalScores = Array.from(this.players.values())
      .map(player => ({
        position: player.position,
        name: player.name,
        totalScore: player.totalScore
      }))
      .sort((a, b) => b.totalScore - a.totalScore);
    
    Logger.info(`🏁 Game completed! Final scores:`, finalScores);
    
    return {
      gameComplete: true,
      finalScores
    };
  }

  // AI Integration methods
  getAIMove(playerPosition) {
    const player = this.players.get(playerPosition);
    if (!player || !player.isAI) {
      throw new Error('Not an AI player');
    }
    
    const validMoves = player.getValidMoves(this.currentTrick, this.currentContract);
    
    // Simple AI for now - can be enhanced with ML models
    const randomMove = validMoves[Math.floor(Math.random() * validMoves.length)];
    return randomMove.id;
  }

  // State management
  getGameState(forPlayer = null) {
    const state = {
      id: this.id,
      phase: this.phase,
      currentContract: this.currentContract,
      currentPlayer: this.currentPlayer,
      currentKing: this.currentKing,
      round: this.round,
      kingdom: this.kingdom,
      usedContracts: Array.from(this.usedContracts),
      currentTrick: this.currentTrick ? this.currentTrick.toJson() : null,
      lastCompletedTrick: this.lastCompletedTrick ? this.lastCompletedTrick.toJson() : null,
      tricksWon: Object.fromEntries(this.tricksWon),
      players: {},
      timestamp: new Date().toISOString()
    };
    
    // Add player data
    for (const [position, player] of this.players) {
      // Always include hand for the requesting player, never for others
      const isRequestingPlayer = forPlayer === position;
      const playerData = player.toJson(false, isRequestingPlayer);
      state.players[position] = playerData;
      
      // Debug logging for card synchronization
      if (isRequestingPlayer) {
        Logger.debug(`🎯 [Card Sync] Player ${position} (${player.name}) gets ${playerData.hand?.length || 0} cards`);
        if (playerData.hand) {
          const cardIds = playerData.hand.map(c => c.id).join(', ');
          Logger.debug(`🎯 [Card Sync] Cards: [${cardIds}]`);
        }
      } else {
        Logger.debug(`🎯 [Card Sync] Player ${position} (${player.name}) gets handSize: ${playerData.handSize}`);
      }
    }
    
    return state;
  }

  addToGameHistory(action) {
    this.gameHistory.push(action);
  }

  // Utility methods
  getAvailableContracts() {
    return Object.values(TrexContract)
      .filter(contract => !this.usedContracts.has(contract.name))
      .map(contract => contract.name);
  }

  isPlayerTurn(playerPosition) {
    return this.currentPlayer === playerPosition && this.phase === GamePhase.PLAYING;
  }

  canSelectContract(playerPosition) {
    return this.currentKing === playerPosition && this.phase === GamePhase.CONTRACT_SELECTION;
  }
}

module.exports = TrexGame;
