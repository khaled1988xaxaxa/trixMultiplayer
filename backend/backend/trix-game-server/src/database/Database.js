/**
 * Simple in-memory database for testing (replaces MongoDB)
 */

const Logger = require('../utils/Logger');

class Database {
  constructor() {
    this.isConnected = true; // Always connected for in-memory
    this.connection = null;
  }

  async connect() {
    // No actual connection needed for in-memory
    this.isConnected = true;
    Logger.info('🗄️ Using in-memory database (no external dependencies)');
  }

  async disconnect() {
    this.isConnected = false;
    Logger.info('🗄️ In-memory database disconnected');
  }
}

// Simple in-memory storage
const gameSessions = new Map();
const playerStats = new Map();
const roomHistory = new Map();
const serverAnalytics = new Map();

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
      gameSessions.set(gameSession.gameId, gameSession);
      Logger.info(`🗄️ Game session saved: ${gameSession.gameId}`);
      return gameSession;
    } catch (error) {
      Logger.error('🗄️ Error saving game session:', error);
      throw error;
    }
  }

  async getGameSession(gameId) {
    try {
      return gameSessions.get(gameId);
    } catch (error) {
      Logger.error('🗄️ Error getting game session:', error);
      throw error;
    }
  }

  // Player Statistics methods
  async updatePlayerStats(sessionId, playerName, gameResult) {
    try {
      let stats = playerStats.get(sessionId);
      
      if (!stats) {
        stats = {
          sessionId,
          playerName,
          statistics: {
            gamesPlayed: 0,
            gamesWon: 0,
            totalScore: 0,
            averageScore: 0,
            bestScore: 0,
            worstScore: 0,
            favoriteContract: null,
            contractsWon: {
              kingOfHearts: 0,
              queens: 0,
              diamonds: 0,
              collections: 0,
              trex: 0
            },
            aiWins: 0,
            humanWins: 0
          },
          lastPlayed: new Date()
        };
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
      
      playerStats.set(sessionId, stats);
      Logger.info(`🗄️ Player stats updated: ${playerName}`);
      return stats;
      
    } catch (error) {
      Logger.error('🗄️ Error updating player stats:', error);
      throw error;
    }
  }

  async getPlayerStats(sessionId) {
    try {
      return playerStats.get(sessionId);
    } catch (error) {
      Logger.error('🗄️ Error getting player stats:', error);
      throw error;
    }
  }

  async getLeaderboard(limit = 10) {
    try {
      const allStats = Array.from(playerStats.values());
      return allStats
        .sort((a, b) => b.statistics.averageScore - a.statistics.averageScore)
        .slice(0, limit)
        .map(stats => ({
          playerName: stats.playerName,
          'statistics.gamesPlayed': stats.statistics.gamesPlayed,
          'statistics.gamesWon': stats.statistics.gamesWon,
          'statistics.averageScore': stats.statistics.averageScore
        }));
    } catch (error) {
      Logger.error('🗄️ Error getting leaderboard:', error);
      throw error;
    }
  }

  // Room History methods
  async saveRoomHistory(roomHistory) {
    try {
      roomHistory.set(roomHistory.roomId, roomHistory);
      Logger.info(`🗄️ Room history saved: ${roomHistory.roomId}`);
      return roomHistory;
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
      const dateKey = today.toISOString().split('T')[0];

      const existing = serverAnalytics.get(dateKey) || { metrics: {} };
      existing.metrics = { ...existing.metrics, ...metrics };
      existing.metrics.totalConnections = (existing.metrics.totalConnections || 0) + 1;
      
      serverAnalytics.set(dateKey, existing);
      
    } catch (error) {
      Logger.error('🗄️ Error updating analytics:', error);
      throw error;
    }
  }

  async getAnalytics(days = 7) {
    try {
      const allAnalytics = Array.from(serverAnalytics.entries());
      return allAnalytics
        .sort((a, b) => new Date(b[0]) - new Date(a[0]))
        .slice(0, days)
        .map(([date, data]) => ({ date, ...data }));
      
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
  GameSession: null, // Not needed for in-memory
  PlayerStats: null, // Not needed for in-memory
  RoomHistory: null, // Not needed for in-memory
  ServerAnalytics: null // Not needed for in-memory
};
