/**
 * Card and Game Models for Trix Game Server
 * Ported from Dart to JavaScript with server-side optimizations
 */

// Enums
const Suit = {
  HEARTS: 'hearts',
  DIAMONDS: 'diamonds',
  CLUBS: 'clubs',
  SPADES: 'spades'
};

const Rank = {
  ACE: { name: 'ace', value: 14, shortName: 'A' },
  KING: { name: 'king', value: 13, shortName: 'K' },
  QUEEN: { name: 'queen', value: 12, shortName: 'Q' },
  JACK: { name: 'jack', value: 11, shortName: 'J' },
  TEN: { name: 'ten', value: 10, shortName: '10' },
  NINE: { name: 'nine', value: 9, shortName: '9' },
  EIGHT: { name: 'eight', value: 8, shortName: '8' },
  SEVEN: { name: 'seven', value: 7, shortName: '7' },
  SIX: { name: 'six', value: 6, shortName: '6' },
  FIVE: { name: 'five', value: 5, shortName: '5' },
  FOUR: { name: 'four', value: 4, shortName: '4' },
  THREE: { name: 'three', value: 3, shortName: '3' },
  TWO: { name: 'two', value: 2, shortName: '2' }
};

const PlayerPosition = {
  NORTH: 'north',
  EAST: 'east', 
  SOUTH: 'south',
  WEST: 'west'
};

const TrexContract = {
  KING_OF_HEARTS: {
    name: 'kingOfHearts',
    arabicName: 'شايب الكلب',
    englishName: 'King of Hearts',
    description: 'Avoid taking the King of Hearts (-75 points)',
    baseScore: -75
  },
  QUEENS: {
    name: 'queens',
    arabicName: 'الكباري',
    englishName: 'Queens',
    description: 'Avoid taking Queens (-25 per Queen)',
    baseScore: -25
  },
  DIAMONDS: {
    name: 'diamonds',
    arabicName: 'الديناري',
    englishName: 'Diamonds',
    description: 'Avoid taking Diamonds (-10 per Diamond)',
    baseScore: -10
  },
  COLLECTIONS: {
    name: 'collections',
    arabicName: 'اللمة',
    englishName: 'Collections',
    description: 'Avoid taking tricks (-15 per trick)',
    baseScore: -15
  },
  TREX: {
    name: 'trex',
    arabicName: 'تريكس',
    englishName: 'Trex',
    description: 'Get rid of your cards first (+200 for first)',
    baseScore: 200
  }
};

const GamePhase = {
  CONTRACT_SELECTION: 'contractSelection',
  PLAYING: 'playing',
  TRICK_COMPLETE: 'trickComplete',
  ROUND_END: 'roundEnd',
  KINGDOM_END: 'kingdomEnd',
  GAME_END: 'gameEnd'
};

class Card {
  constructor(suit, rank) {
    this.suit = suit;
    this.rank = rank;
    this.id = `${rank.shortName}${suit.charAt(0).toUpperCase()}`; // e.g., "AH", "KS"
  }

  toString() {
    return this.id;
  }

  toJson() {
    return {
      suit: this.suit,
      rank: this.rank.name,
      id: this.id
    };
  }

  static fromJson(json) {
    const rank = Object.values(Rank).find(r => r.name === json.rank);
    return new Card(json.suit, rank);
  }

  // For sorting
  getValue() {
    return this.rank.value;
  }

  // Card comparison
  isHigherThan(otherCard, trumpSuit = null) {
    // Trump cards beat non-trump
    if (trumpSuit && this.suit === trumpSuit && otherCard.suit !== trumpSuit) {
      return true;
    }
    if (trumpSuit && otherCard.suit === trumpSuit && this.suit !== trumpSuit) {
      return false;
    }
    
    // Same suit comparison
    if (this.suit === otherCard.suit) {
      return this.rank.value > otherCard.rank.value;
    }
    
    // Different suits, neither trump
    return false;
  }
}

class Player {
  constructor(id, name, position, isAI = false) {
    this.id = id;
    this.name = name;
    this.position = position;
    this.isAI = isAI;
    this.hand = [];
    this.tricksWon = 0;
    this.score = 0;
    this.totalScore = 0;
    this.isConnected = true;
    this.lastSeen = new Date();
  }

  addCard(card) {
    this.hand.push(card);
  }

  removeCard(cardId) {
    const index = this.hand.findIndex(card => card.id === cardId);
    if (index !== -1) {
      return this.hand.splice(index, 1)[0];
    }
    return null;
  }

  hasCard(cardId) {
    return this.hand.some(card => card.id === cardId);
  }

  sortHand() {
    this.hand.sort((a, b) => {
      // Sort by suit first, then by rank value
      if (a.suit === b.suit) {
        return b.rank.value - a.rank.value; // Descending order
      }
      return a.suit.localeCompare(b.suit);
    });
  }

  getValidMoves(currentTrick, currentContract) {
    if (!currentTrick || currentTrick.cards.size === 0) {
      // First card of trick - can play any card
      if (currentContract === TrexContract.TREX.name) {
        // In Trex, must follow suit layout rules
        return this.getValidTrexMoves();
      }
      return this.hand.slice(); // All cards valid
    }

    const leadSuit = currentTrick.getLeadSuit();
    const cardsOfLeadSuit = this.hand.filter(card => card.suit === leadSuit);
    
    if (cardsOfLeadSuit.length > 0) {
      return cardsOfLeadSuit; // Must follow suit
    }
    
    return this.hand.slice(); // Can play any card if can't follow suit
  }

  getValidTrexMoves() {
    // Trex specific rules for valid moves
    // This would need to be implemented based on Trex layout rules
    return this.hand.slice();
  }

  toJson(includeHand = false, isCurrentPlayer = false) {
    const playerData = {
      id: this.id,
      name: this.name,
      position: this.position,
      isAI: this.isAI,
      tricksWon: this.tricksWon,
      score: this.score,
      totalScore: this.totalScore,
      isConnected: this.isConnected,
      handSize: this.hand.length
    };

    if (includeHand || isCurrentPlayer) {
      playerData.hand = this.hand.map(card => card.toJson());
    }

    return playerData;
  }
}

class Trick {
  constructor(leadPlayer) {
    this.cards = new Map(); // PlayerPosition -> Card
    this.leadPlayer = leadPlayer;
    this.winner = null;
  }

  addCard(playerPosition, card) {
    this.cards.set(playerPosition, card);
  }

  isComplete() {
    return this.cards.size === 4;
  }

  getLeadCard() {
    return this.cards.get(this.leadPlayer);
  }

  getLeadSuit() {
    const leadCard = this.getLeadCard();
    return leadCard ? leadCard.suit : null;
  }

  determineWinner(trumpSuit = null) {
    if (!this.isComplete()) return null;

    const leadCard = this.getLeadCard();
    const leadSuit = leadCard.suit;
    
    let winningPosition = this.leadPlayer;
    let winningCard = leadCard;

    for (const [position, card] of this.cards) {
      // Trump card beats non-trump
      if (trumpSuit && card.suit === trumpSuit && winningCard.suit !== trumpSuit) {
        winningCard = card;
        winningPosition = position;
      }
      // Higher trump beats lower trump
      else if (trumpSuit && card.suit === trumpSuit && winningCard.suit === trumpSuit) {
        if (card.rank.value > winningCard.rank.value) {
          winningCard = card;
          winningPosition = position;
        }
      }
      // Same suit, higher rank wins (if no trump involved)
      else if (card.suit === leadSuit && winningCard.suit === leadSuit && trumpSuit !== winningCard.suit) {
        if (card.rank.value > winningCard.rank.value) {
          winningCard = card;
          winningPosition = position;
        }
      }
    }

    this.winner = winningPosition;
    return winningPosition;
  }

  toJson() {
    const cardsObj = {};
    for (const [position, card] of this.cards) {
      cardsObj[position] = card.toJson();
    }

    return {
      cards: cardsObj,
      leadPlayer: this.leadPlayer,
      winner: this.winner,
      isComplete: this.isComplete()
    };
  }
}

module.exports = {
  Suit,
  Rank,
  PlayerPosition,
  TrexContract,
  GamePhase,
  Card,
  Player,
  Trick
};
