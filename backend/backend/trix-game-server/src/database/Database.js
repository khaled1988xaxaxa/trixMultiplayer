/**
 * Database connection and models for MongoDB
 */

const mongoose = require('mongoose');
const Logger = require('../utils/Logger');

class Database {
  constructor() {
    this.isConnected = false;
    this.connection = null;
  }

  async connect() {
    try {
      const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/trix_game';
      const options = {
        useNewUrlParser: true,
        useUnifiedTopology: true,
        serverSelectionTimeoutMS: 5000,
        heartbeatFrequencyMS: 2000,
      };

      this.connection = await mongoose.connect(mongoUri, options);
      this.isConnected = true;
      
      Logger.info(`🗄️ Connected to MongoDB: ${mongoUri}`);
      
      // Setup connection event handlers
      mongoose.connection.on('error', (error) => {
        Logger.error('🗄️ MongoDB connection error:', error);
      });

      mongoose.connection.on('disconnected', () => {
        Logger.warn('🗄️ MongoDB disconnected');
        this.isConnected = false;
      });

      mongoose.connection.on('reconnected', () => {
        Logger.info('🗄️ MongoDB reconnected');
        this.isConnected = true;
      });

    } catch (error) {
      Logger.error('🗄️ Failed to connect to MongoDB:', error);
      throw error;
    }
  }

  async disconnect() {
    if (this.connection) {
      await mongoose.disconnect();
      this.isConnected = false;
      Logger.info('🗄️ Disconnected from MongoDB');
    }
  }
}

// Game Session Schema
const gameSessionSchema = new mongoose.Schema({
  gameId: { type: String, required: true, unique: true },
  roomId: { type: String, required: true },
  players: [{
    sessionId: String,
    name: String,
    position: String,
    isAI: Boolean,
    finalScore: Number
  }],
  gameData: {
    startedAt: Date,
    completedAt: Date,
    totalRounds: Number,
    totalKingdoms: Number,
    winner: String,
    gameHistory: [mongoose.Schema.Types.Mixed]
  },
  metadata: {
    duration: Number, // in milliseconds
    averageRoundTime: Number,
    contractsUsed: [String],
    aiDifficulty: String
  }
}, {
  timestamps: true
});

// Player Statistics Schema
const playerStatsSchema = new mongoose.Schema({
  sessionId: { type: String, required: true },
  playerName: { type: String, required: true },
  statistics: {
    gamesPlayed: { type: Number, default: 0 },
    gamesWon: { type: Number, default: 0 },
    totalScore: { type: Number, default: 0 },
    averageScore: { type: Number, default: 0 },
    bestScore: { type: Number, default: 0 },
    worstScore: { type: Number, default: 0 },
    favoriteContract: { type: String, default: null },
    contractsWon: {
      kingOfHearts: { type: Number, default: 0 },
      queens: { type: Number, default: 0 },
      diamonds: { type: Number, default: 0 },
      collections: { type: Number, default: 0 },
      trex: { type: Number, default: 0 }
    },
    aiWins: { type: Number, default: 0 },
    humanWins: { type: Number, default: 0 }
  },
  lastPlayed: { type: Date, default: Date.now }
}, {
  timestamps: true
});

// Room History Schema
const roomHistorySchema = new mongoose.Schema({
  roomId: { type: String, required: true },
  hostName: { type: String, required: true },
  settings: {
    maxPlayers: Number,
    aiDifficulty: String,
    gameSpeed: String,
    isPrivate: Boolean
  },
  lifecycle: {
    createdAt: Date,
    gameStartedAt: Date,
    gameEndedAt: Date,
    roomClosedAt: Date
  },
  players: [{
    sessionId: String,
    name: String,
    joinedAt: Date,
    leftAt: Date,
    isAI: Boolean
  }],
  gameResult: {
    winner: String,
    finalScores: [mongoose.Schema.Types.Mixed],
    totalDuration: Number
  }
}, {
  timestamps: true
});

// Server Analytics Schema
const serverAnalyticsSchema = new mongoose.Schema({
  date: { type: Date, required: true, unique: true },
  metrics: {
    totalConnections: { type: Number, default: 0 },
    uniquePlayers: { type: Number, default: 0 },
    roomsCreated: { type: Number, default: 0 },
    gamesCompleted: { type: Number, default: 0 },
    averageGameDuration: { type: Number, default: 0 },
    peakConcurrentUsers: { type: Number, default: 0 },
    aiGamesPercentage: { type: Number, default: 0 }
  },
  performance: {
    averageResponseTime: { type: Number, default: 0 },
    errorRate: { type: Number, default: 0 },
    uptime: { type: Number, default: 0 }
  }
}, {
  timestamps: true
});

// Create models
const GameSession = mongoose.model('GameSession', gameSessionSchema);
const PlayerStats = mongoose.model('PlayerStats', playerStatsSchema);
const RoomHistory = mongoose.model('RoomHistory', roomHistorySchema);
const ServerAnalytics = mongoose.model('ServerAnalytics', serverAnalyticsSchema);

// Database service class
class DatabaseService {
  constructor() {
    this.db = new Database();
  }

  async initialize() {
    await this.db.connect();
  }

  async shutdown() {
    await this.db.disconnect();
  }

  // Game Session methods
  async saveGameSession(gameSession) {
    try {
      const session = new GameSession(gameSession);
      await session.save();
      Logger.info(`🗄️ Game session saved: ${gameSession.gameId}`);
      return session;
    } catch (error) {
      Logger.error('🗄️ Error saving game session:', error);
      throw error;
    }
  }

  async getGameSession(gameId) {
    try {
      return await GameSession.findOne({ gameId });
    } catch (error) {
      Logger.error('🗄️ Error getting game session:', error);
      throw error;
    }
  }

  // Player Statistics methods
  async updatePlayerStats(sessionId, playerName, gameResult) {
    try {
      let stats = await PlayerStats.findOne({ sessionId });
      
      if (!stats) {
        stats = new PlayerStats({
          sessionId,
          playerName,
          statistics: {}
        });
      }

      // Update statistics
      stats.statistics.gamesPlayed += 1;
      if (gameResult.won) {
        stats.statistics.gamesWon += 1;
      }
      
      stats.statistics.totalScore += gameResult.score;
      stats.statistics.averageScore = stats.statistics.totalScore / stats.statistics.gamesPlayed;
      
      if (gameResult.score > stats.statistics.bestScore) {
        stats.statistics.bestScore = gameResult.score;
      }
      if (gameResult.score < stats.statistics.worstScore) {
        stats.statistics.worstScore = gameResult.score;
      }

      if (gameResult.contract) {
        stats.statistics.contractsWon[gameResult.contract] += 1;
      }

      stats.lastPlayed = new Date();
      
      await stats.save();
      Logger.info(`🗄️ Player stats updated: ${playerName}`);
      return stats;
      
    } catch (error) {
      Logger.error('🗄️ Error updating player stats:', error);
      throw error;
    }
  }

  async getPlayerStats(sessionId) {
    try {
      return await PlayerStats.findOne({ sessionId });
    } catch (error) {
      Logger.error('🗄️ Error getting player stats:', error);
      throw error;
    }
  }

  async getLeaderboard(limit = 10) {
    try {
      return await PlayerStats.find({})
        .sort({ 'statistics.averageScore': -1 })
        .limit(limit)
        .select('playerName statistics.gamesPlayed statistics.gamesWon statistics.averageScore');
    } catch (error) {
      Logger.error('🗄️ Error getting leaderboard:', error);
      throw error;
    }
  }

  // Room History methods
  async saveRoomHistory(roomHistory) {
    try {
      const history = new RoomHistory(roomHistory);
      await history.save();
      Logger.info(`🗄️ Room history saved: ${roomHistory.roomId}`);
      return history;
    } catch (error) {
      Logger.error('🗄️ Error saving room history:', error);
      throw error;
    }
  }

  // Analytics methods
  async updateDailyAnalytics(metrics) {
    try {
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      await ServerAnalytics.findOneAndUpdate(
        { date: today },
        { 
          $set: { metrics },
          $inc: { 'metrics.totalConnections': 1 }
        },
        { upsert: true }
      );
      
    } catch (error) {
      Logger.error('🗄️ Error updating analytics:', error);
      throw error;
    }
  }

  async getAnalytics(days = 7) {
    try {
      const startDate = new Date();
      startDate.setDate(startDate.getDate() - days);
      
      return await ServerAnalytics.find({
        date: { $gte: startDate }
      }).sort({ date: -1 });
      
    } catch (error) {
      Logger.error('🗄️ Error getting analytics:', error);
      throw error;
    }
  }

  // Health check
  isConnected() {
    return this.db.isConnected;
  }
}

module.exports = {
  Database,
  DatabaseService,
  GameSession,
  PlayerStats,
  RoomHistory,
  ServerAnalytics
};
