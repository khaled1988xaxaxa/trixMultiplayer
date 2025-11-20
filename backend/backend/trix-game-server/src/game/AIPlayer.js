/**
 * Server-side AI Player for Trix Game
 * Handles AI decision making and strategy
 */

const { TrexContract, Suit, Rank } = require('./GameModels');
const Logger = require('../utils/Logger');

class AIPlayer {
  constructor(difficulty = 'medium') {
    this.difficulty = difficulty; // 'easy', 'medium', 'hard'
    this.strategies = {
      easy: new EasyStrategy(),
      medium: new MediumStrategy(),
      hard: new HardStrategy()
    };
    Logger.info(`[AIPlayer] Created AIPlayer with difficulty: ${difficulty}`);
  }

  // Main AI decision method
  makeMove(gameState, playerPosition) {
    Logger.info(`[AIPlayer] makeMove called for position: ${playerPosition}, difficulty: ${this.difficulty}`);
    Logger.debug(`[AIPlayer] gameState.phase: ${gameState.phase}, playerPosition: ${playerPosition}`);
    const strategy = this.strategies[this.difficulty];
    if (!strategy || typeof strategy.selectMove !== 'function') {
      Logger.error(`❌ AIPlayer.makeMove: strategy or selectMove is undefined for difficulty '${this.difficulty}' (player: ${playerPosition})`);
      throw new Error(`AIPlayer: No valid strategy for difficulty '${this.difficulty}'`);
    }
    const move = strategy.selectMove(gameState, playerPosition);
    Logger.info(`[AIPlayer] Strategy selected move: ${JSON.stringify(move)} for player: ${playerPosition}`);
    if (!move) {
      Logger.error(`❌ AI strategy returned null move for player: ${playerPosition}`);
      throw new Error(`AI player ${playerPosition} could not make a valid move`);
    }
    Logger.info(`🤖 AI ${playerPosition} (${this.difficulty}): ${move.action} - ${move.cardId || move.contract}`);
    return move;
  }

  // Contract selection for AI
  selectContract(gameState, playerPosition) {
    Logger.info(`[AIPlayer] selectContract called for position: ${playerPosition}, difficulty: ${this.difficulty}`);
    const strategy = this.strategies[this.difficulty];
    return strategy.selectContract(gameState, playerPosition);
  }
}

class BaseStrategy {
  selectMove(gameState, playerPosition) {
    if (gameState.phase === 'contractSelection') {
      return this.selectContract(gameState, playerPosition);
    } else if (gameState.phase === 'playing') {
      return this.selectCard(gameState, playerPosition);
    }
    
    throw new Error('Unknown game phase for AI decision');
  }

  selectContract(gameState, playerPosition) {
    const availableContracts = gameState.usedContracts || [];
    const allContracts = Object.values(TrexContract).map(c => c.name);
    const unused = allContracts.filter(c => !availableContracts.includes(c));
    
    if (unused.length === 0) {
      throw new Error('No contracts available');
    }
    
    // Default: random selection
    const contract = unused[Math.floor(Math.random() * unused.length)];
    return {
      action: 'SELECT_CONTRACT',
      contract: contract
    };
  }

  selectCard(gameState, playerPosition) {
    const player = gameState.players[playerPosition];
    if (!player || !player.hand) {
      throw new Error('Player hand not available');
    }
    
    const validMoves = this.getValidMoves(gameState, playerPosition);
    if (validMoves.length === 0) {
      throw new Error('No valid moves available');
    }
    
    // Default: random selection
    const card = validMoves[Math.floor(Math.random() * validMoves.length)];
    return {
      action: 'PLAY_CARD',
      cardId: card.id
    };
  }

  getValidMoves(gameState, playerPosition) {
    // Add defensive checks
    if (!gameState || !gameState.players || !playerPosition) {
      console.error('❌ Invalid gameState or playerPosition in getValidMoves:', { gameState: !!gameState, players: !!gameState?.players, playerPosition });
      return [];
    }
    
    const player = gameState.players[playerPosition];
    if (!player || !player.hand || !Array.isArray(player.hand)) {
      console.error('❌ Invalid player or hand in getValidMoves:', { playerPosition, player: !!player, hand: !!player?.hand, isArray: Array.isArray(player?.hand) });
      return [];
    }
    
    const currentTrick = gameState.currentTrick;
    
    if (!currentTrick || !currentTrick.cards || Object.keys(currentTrick.cards).length === 0) {
      // First card of trick - can play any card
      return player.hand;
    }
    
    // Must follow suit if possible
    const leadSuit = this.getLeadSuit(currentTrick);
    const cardsOfLeadSuit = player.hand.filter(card => card.suit === leadSuit);
    
    if (cardsOfLeadSuit.length > 0) {
      return cardsOfLeadSuit;
    }
    
    // Can play any card if can't follow suit
    return player.hand;
  }

  getLeadSuit(currentTrick) {
    const positions = ['north', 'east', 'south', 'west'];
    const leadPlayer = currentTrick.leadPlayer;
    
    if (currentTrick.cards[leadPlayer]) {
      return currentTrick.cards[leadPlayer].suit;
    }
    
    return null;
  }
}

class EasyStrategy extends BaseStrategy {
  selectContract(gameState, playerPosition) {
    // Easy AI: prefers simple contracts
    const preferredOrder = [
      TrexContract.COLLECTIONS.name,
      TrexContract.DIAMONDS.name,
      TrexContract.QUEENS.name,
      TrexContract.KING_OF_HEARTS.name,
      TrexContract.TREX.name
    ];
    
    const availableContracts = gameState.usedContracts || [];
    
    for (const contract of preferredOrder) {
      if (!availableContracts.includes(contract)) {
        return {
          action: 'SELECT_CONTRACT',
          contract: contract
        };
      }
    }
    
    return super.selectContract(gameState, playerPosition);
  }

  selectCard(gameState, playerPosition) {
    const validMoves = this.getValidMoves(gameState, playerPosition);
    
    // Add defensive checks
    if (!validMoves || !Array.isArray(validMoves) || validMoves.length === 0) {
      console.error('❌ Invalid validMoves in EasyStrategy selectCard:', { validMoves, isArray: Array.isArray(validMoves), length: validMoves?.length });
      return null;
    }
    
    const contract = gameState.currentContract;
    
    // Easy strategy: play lowest card when possible
    if (contract === TrexContract.KING_OF_HEARTS.name) {
      return this.avoidKingOfHearts(validMoves);
    } else if (contract === TrexContract.QUEENS.name) {
      return this.avoidQueens(validMoves);
    } else if (contract === TrexContract.DIAMONDS.name) {
      return this.avoidDiamonds(validMoves);
    }
    
    // Default: play lowest card
    const sortedCards = validMoves.sort((a, b) => a.rank.value - b.rank.value);
    return {
      action: 'PLAY_CARD',
      cardId: sortedCards[0].id
    };
  }

  avoidKingOfHearts(validMoves) {
    if (!validMoves || !Array.isArray(validMoves) || validMoves.length === 0) {
      console.error('❌ Invalid validMoves in avoidKingOfHearts');
      return null;
    }
    
    const nonKingOfHearts = validMoves.filter(card => 
      !(card.suit === Suit.HEARTS && card.rank === Rank.KING)
    );
    
    if (nonKingOfHearts.length > 0) {
      const lowest = nonKingOfHearts.sort((a, b) => a.rank.value - b.rank.value)[0];
      return { action: 'PLAY_CARD', cardId: lowest.id };
    }
    
    return { action: 'PLAY_CARD', cardId: validMoves[0].id };
  }

  avoidQueens(validMoves) {
    if (!validMoves || !Array.isArray(validMoves) || validMoves.length === 0) {
      console.error('❌ Invalid validMoves in avoidQueens');
      return null;
    }
    
    const nonQueens = validMoves.filter(card => card.rank !== Rank.QUEEN);
    
    if (nonQueens.length > 0) {
      const lowest = nonQueens.sort((a, b) => a.rank.value - b.rank.value)[0];
      return { action: 'PLAY_CARD', cardId: lowest.id };
    }
    
    return { action: 'PLAY_CARD', cardId: validMoves[0].id };
  }

  avoidDiamonds(validMoves) {
    if (!validMoves || !Array.isArray(validMoves) || validMoves.length === 0) {
      console.error('❌ Invalid validMoves in avoidDiamonds');
      return null;
    }
    
    const nonDiamonds = validMoves.filter(card => card.suit !== Suit.DIAMONDS);
    
    if (nonDiamonds.length > 0) {
      const lowest = nonDiamonds.sort((a, b) => a.rank.value - b.rank.value)[0];
      return { action: 'PLAY_CARD', cardId: lowest.id };
    }
    
    return { action: 'PLAY_CARD', cardId: validMoves[0].id };
  }
}

class MediumStrategy extends EasyStrategy {
  selectContract(gameState, playerPosition) {
    const player = gameState.players[playerPosition];
    if (!player || !player.hand) {
      return super.selectContract(gameState, playerPosition);
    }
    
    // Analyze hand for best contract
    const handAnalysis = this.analyzeHand(player.hand);
    const availableContracts = gameState.usedContracts || [];
    
    // Choose contract based on hand strength
    if (!availableContracts.includes(TrexContract.KING_OF_HEARTS.name) && 
        !handAnalysis.hasKingOfHearts) {
      return { action: 'SELECT_CONTRACT', contract: TrexContract.KING_OF_HEARTS.name };
    }
    
    if (!availableContracts.includes(TrexContract.QUEENS.name) && 
        handAnalysis.queensCount === 0) {
      return { action: 'SELECT_CONTRACT', contract: TrexContract.QUEENS.name };
    }
    
    if (!availableContracts.includes(TrexContract.DIAMONDS.name) && 
        handAnalysis.diamondsCount <= 2) {
      return { action: 'SELECT_CONTRACT', contract: TrexContract.DIAMONDS.name };
    }
    
    return super.selectContract(gameState, playerPosition);
  }

  analyzeHand(hand) {
    const analysis = {
      hasKingOfHearts: false,
      queensCount: 0,
      diamondsCount: 0,
      highCards: 0,
      lowCards: 0
    };
    
    hand.forEach(card => {
      if (card.suit === Suit.HEARTS && card.rank === Rank.KING) {
        analysis.hasKingOfHearts = true;
      }
      if (card.rank === Rank.QUEEN) {
        analysis.queensCount++;
      }
      if (card.suit === Suit.DIAMONDS) {
        analysis.diamondsCount++;
      }
      if (card.rank.value >= 11) {
        analysis.highCards++;
      }
      if (card.rank.value <= 7) {
        analysis.lowCards++;
      }
    });
    
    return analysis;
  }

  selectCard(gameState, playerPosition) {
    const validMoves = this.getValidMoves(gameState, playerPosition);
    
    // Check if we have valid moves
    if (!validMoves || validMoves.length === 0) {
      console.error('❌ No valid moves available for AI player:', { playerPosition, validMoves });
      return null;
    }
    
    const currentTrick = gameState.currentTrick;
    const contract = gameState.currentContract;
    
    let result;
    
    // Medium strategy: consider trick context
    if (currentTrick && Object.keys(currentTrick.cards).length > 0) {
      result = this.playInTrick(validMoves, currentTrick, contract);
    } else {
      // Leading a trick
      result = this.leadTrick(validMoves, contract);
    }
    
    // If the strategy methods return null, fall back to first available card
    if (!result && validMoves.length > 0) {
      console.warn('⚠️ AI strategy returned null, falling back to first available card');
      result = {
        action: 'PLAY_CARD',
        cardId: validMoves[0].id
      };
    }
    
    return result;
  }

  playInTrick(validMoves, currentTrick, contract) {
    // Add defensive checks
    if (!validMoves || !Array.isArray(validMoves) || validMoves.length === 0) {
      console.error('❌ Invalid validMoves in playInTrick:', { validMoves, isArray: Array.isArray(validMoves), length: validMoves?.length });
      return null; // Return null to indicate no valid move
    }
    
    // Try to avoid winning dangerous tricks
    if (contract === TrexContract.KING_OF_HEARTS.name) {
      return this.playSafeInKingOfHearts(validMoves, currentTrick);
    }
    
    // Default medium strategy: play middle-value cards
    const sortedCards = validMoves.sort((a, b) => a.rank.value - b.rank.value);
    const middleIndex = Math.floor(sortedCards.length / 2);
    
    return {
      action: 'PLAY_CARD',
      cardId: sortedCards[middleIndex].id
    };
  }

  leadTrick(validMoves, contract) {
    // Add defensive checks
    if (!validMoves || !Array.isArray(validMoves) || validMoves.length === 0) {
      console.error('❌ Invalid validMoves in leadTrick:', { validMoves, isArray: Array.isArray(validMoves), length: validMoves?.length });
      return null; // Return null to indicate no valid move
    }
    
    // When leading, play high cards to control the trick
    const sortedCards = validMoves.sort((a, b) => b.rank.value - a.rank.value);
    
    return {
      action: 'PLAY_CARD',
      cardId: sortedCards[0].id
    };
  }

  playSafeInKingOfHearts(validMoves, currentTrick) {
    // Strategy: avoid playing/keeping high hearts that could capture King if not forced
    // 1. If we can dump a high non-heart card that won't win, play lowest non-heart
    const nonHearts = validMoves.filter(c => c.suit !== Suit.HEARTS);
    if (nonHearts.length > 0) {
      // Prefer lowest rank to shed safely
      const lowest = nonHearts.sort((a, b) => a.rank.value - b.rank.value)[0];
      return { action: 'PLAY_CARD', cardId: lowest.id };
    }
    // 2. All hearts: play lowest heart (reduce risk of winning later)
    const lowestHeart = validMoves.sort((a, b) => a.rank.value - b.rank.value)[0];
    return { action: 'PLAY_CARD', cardId: lowestHeart.id };
  }

  playTrex(validMoves, gameState) {
    // Trex-specific strategy
    return super.selectCard({ players: { [playerPosition]: { hand: validMoves } } }, playerPosition);
  }
}

class HardStrategy extends MediumStrategy {
  constructor() {
    super();
    this.cardMemory = new Map(); // Remember played cards
    this.playerProfiles = new Map(); // Track player behaviors
  }

  selectContract(gameState, playerPosition) {
    // Advanced contract selection based on complete game analysis
    const handAnalysis = this.analyzeHand(gameState.players[playerPosition].hand);
    const gameAnalysis = this.analyzeGameState(gameState);
    
    // Complex decision tree for contract selection
    return this.advancedContractSelection(handAnalysis, gameAnalysis, gameState);
  }

  advancedContractSelection(handAnalysis, gameAnalysis, gameState) {
    // Implement advanced AI logic here
    // For now, fall back to medium strategy
    return super.selectContract(gameState, 'placeholder');
  }

  analyzeGameState(gameState) {
    return {
      roundsRemaining: 5 - gameState.round,
      kingdomsRemaining: 4 - gameState.kingdom,
      playerScores: Object.values(gameState.players).map(p => p.totalScore)
    };
  }

  selectCard(gameState, playerPosition) {
    // Advanced card selection with memory and prediction
    this.updateCardMemory(gameState);
    
    const validMoves = this.getValidMoves(gameState, playerPosition);
    
    // Add defensive checks
    if (!validMoves || !Array.isArray(validMoves) || validMoves.length === 0) {
      console.error('❌ Invalid validMoves in HardStrategy selectCard:', { validMoves, isArray: Array.isArray(validMoves), length: validMoves?.length });
      return null;
    }
    
    const prediction = this.predictOpponentMoves(gameState, playerPosition);
    
    return this.selectOptimalCard(validMoves, gameState, prediction);
  }

  updateCardMemory(gameState) {
    // Track cards that have been played
    if (gameState.lastCompletedTrick) {
      for (const [position, card] of Object.entries(gameState.lastCompletedTrick.cards)) {
        this.cardMemory.set(card.id, { player: position, trick: gameState.tricks.length });
      }
    }
  }

  predictOpponentMoves(gameState, playerPosition) {
    // Predict what opponents might play
    return {
      likelyCards: [],
      dangerousCards: [],
      safeCards: []
    };
  }

  selectOptimalCard(validMoves, gameState, prediction) {
    // Use advanced algorithms to select the best card
    // Implement minimax, Monte Carlo, or other AI techniques
    
    // For now, enhanced medium strategy
    return super.selectCard(gameState, 'placeholder');
  }
}

module.exports = {
  AIPlayer,
  EasyStrategy,
  MediumStrategy,
  HardStrategy
};
