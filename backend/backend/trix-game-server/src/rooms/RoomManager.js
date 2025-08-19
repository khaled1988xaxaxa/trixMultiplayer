/**
 * Room Manager - Handles game rooms, matchmaking, and player management
 */

const { v4: uuidv4 } = require('uuid');
const TrexGame = require('../game/TrexGame');
const { Player, PlayerPosition } = require('../game/GameModels');
const { AIPlayer } = require('../game/AIPlayer');
const Logger = require('../utils/Logger');

class GameRoom {
  constructor(hostId, hostName, webSocketServer = null, settings = {}) {
    this.id = uuidv4();
    this.hostId = hostId;
    this.hostName = hostName;
    this.webSocketServer = webSocketServer;
    this.name = settings.name || `${hostName}'s Room`;
    this.settings = {
      maxPlayers: 4,
      isPrivate: false,
      aiDifficulty: 'medium',
      allowSpectators: true,
      gameSpeed: 'normal', // slow, normal, fast
      ...settings
    };
    
    this.players = new Map(); // sessionId -> PlayerInfo
    this.spectators = new Map(); // sessionId -> SpectatorInfo
    this.status = 'waiting'; // waiting, playing, finished
    this.game = null;
    this.createdAt = new Date();
    this.lastActivity = new Date();
    
    // AI management
    this.aiPlayers = new Map(); // position -> AIPlayer
    this.aiEnabled = true;
    
    Logger.info(`🏠 Room created: ${this.id} by ${hostName}`);
  }

  // Player management
  addPlayer(sessionId, playerName, isAI = false) {
    if (this.players.size >= this.settings.maxPlayers) {
      throw new Error('Room is full');
    }
    
    if (this.status !== 'waiting') {
      throw new Error('Game is already in progress');
    }
    
    // Assign position
    const availablePositions = this.getAvailablePositions();
    if (availablePositions.length === 0) {
      throw new Error('No available positions');
    }

    let position;
    // Always assign host to 'south' if available
    if (sessionId === this.hostId) {
      if (availablePositions.includes('south')) {
        position = 'south';
      } else {
        // fallback if south is not available (should not happen for host join)
        position = availablePositions[0];
      }
    } else {
      // assign first available (not south if host not joining)
      const filtered = availablePositions.filter(p => p !== 'south');
      position = filtered.length > 0 ? filtered[0] : availablePositions[0];
    }

    const playerInfo = {
      sessionId,
      name: playerName,
      position,
      isAI,
      isHost: sessionId === this.hostId,
      joinedAt: new Date(),
      isConnected: true
    };

    this.players.set(sessionId, playerInfo);
    this.lastActivity = new Date();

    Logger.info(`👤 Player ${playerName} joined room ${this.id} at position ${position}`);

    // Auto-fill with AI if enabled and room becomes full
    if (this.aiEnabled && this.canStartGame()) {
      this.fillWithAI();
    }

    return playerInfo;
  }

  removePlayer(sessionId) {
    const playerInfo = this.players.get(sessionId);
    if (!playerInfo) {
      return false;
    }
    
    this.players.delete(sessionId);
    this.lastActivity = new Date();
    
    Logger.info(`👤 Player ${playerInfo.name} left room ${this.id}`);
    
    // If game is in progress, replace with AI
    if (this.status === 'playing' && this.game && !playerInfo.isAI) {
      this.replacePlayerWithAI(playerInfo.position, playerInfo.name);
    }
    
    // If host left, assign new host
    if (playerInfo.isHost && this.players.size > 0) {
      this.assignNewHost();
    }
    
    return true;
  }

  replacePlayerWithAI(position, originalName) {
    const aiName = `AI (${originalName})`;
    const aiSessionId = `ai_${position}_${Date.now()}`;
    
    const aiPlayerInfo = {
      sessionId: aiSessionId,
      name: aiName,
      position,
      isAI: true,
      isHost: false,
      joinedAt: new Date(),
      isConnected: true,
      replacedPlayer: originalName
    };
    
    this.players.set(aiSessionId, aiPlayerInfo);
    
    // Create AI instance
    const aiPlayer = new AIPlayer(this.settings.aiDifficulty);
    this.aiPlayers.set(position, aiPlayer);
    
    // Update game player
    if (this.game) {
      const gamePlayer = this.game.players.get(position);
      if (gamePlayer) {
        gamePlayer.name = aiName;
        gamePlayer.isAI = true;
        gamePlayer.isConnected = true;
      }
    }
    
    Logger.info(`🤖 Replaced ${originalName} with AI at position ${position}`);
  }

  assignNewHost() {
    const humanPlayers = Array.from(this.players.values()).filter(p => !p.isAI);
    if (humanPlayers.length > 0) {
      const newHost = humanPlayers[0];
      newHost.isHost = true;
      this.hostId = newHost.sessionId;
      Logger.info(`👑 New host assigned: ${newHost.name}`);
    }
  }

  addSpectator(sessionId, spectatorName) {
    if (!this.settings.allowSpectators) {
      throw new Error('Spectators not allowed in this room');
    }
    
    const spectatorInfo = {
      sessionId,
      name: spectatorName,
      joinedAt: new Date()
    };
    
    this.spectators.set(sessionId, spectatorInfo);
    this.lastActivity = new Date();
    
    Logger.info(`👁️ Spectator ${spectatorName} joined room ${this.id}`);
    return spectatorInfo;
  }

  removeSpectator(sessionId) {
    return this.spectators.delete(sessionId);
  }

  getAvailablePositions() {
    const occupiedPositions = Array.from(this.players.values()).map(p => p.position);
    return Object.values(PlayerPosition).filter(pos => !occupiedPositions.includes(pos));
  }

  fillWithAI() {
    const availablePositions = this.getAvailablePositions();
    
    for (const position of availablePositions) {
      const aiSessionId = `ai_${position}_${Date.now()}`;
      const aiName = `AI Player ${position}`;
      
      const aiPlayerInfo = {
        sessionId: aiSessionId,
        name: aiName,
        position,
        isAI: true,
        isHost: false,
        joinedAt: new Date(),
        isConnected: true
      };
      
      this.players.set(aiSessionId, aiPlayerInfo);
      
      // Create AI instance
      const aiPlayer = new AIPlayer(this.settings.aiDifficulty);
      this.aiPlayers.set(position, aiPlayer);
    }
    
    Logger.info(`🤖 Filled room ${this.id} with AI players`);
  }

  addAI(name, difficulty = 'medium') {
    if (this.players.size >= this.settings.maxPlayers) {
      throw new Error('Room is full');
    }
    
    if (this.status !== 'waiting') {
      throw new Error('Game is already in progress');
    }
    
    const availablePositions = this.getAvailablePositions();
    if (availablePositions.length === 0) {
      throw new Error('No available positions');
    }
    
    const position = availablePositions[0];
    const aiSessionId = `ai_${position}_${Date.now()}`;
    const aiName = name || `AI Bot ${position}`;
    
    const aiPlayerInfo = {
      sessionId: aiSessionId,
      name: aiName,
      position,
      isAI: true,
      isHost: false,
      joinedAt: new Date(),
      isConnected: true,
      difficulty
    };
    
    this.players.set(aiSessionId, aiPlayerInfo);
    
    // Create AI instance
    const aiPlayer = new AIPlayer(difficulty);
    this.aiPlayers.set(position, aiPlayer);
    
    this.lastActivity = new Date();
    
    Logger.info(`🤖 Added AI bot ${aiName} to room ${this.id} at position ${position}`);
    return aiPlayerInfo;
  }

  removeAI(botId) {
    const botInfo = this.players.get(botId);
    if (!botInfo || !botInfo.isAI) {
      throw new Error('Bot not found or not an AI player');
    }
    
    if (this.status !== 'waiting') {
      throw new Error('Cannot remove AI during game');
    }
    
    // Remove from players
    this.players.delete(botId);
    
    // Remove AI instance
    this.aiPlayers.delete(botInfo.position);
    
    this.lastActivity = new Date();
    
    Logger.info(`🤖 Removed AI bot ${botInfo.name} from room ${this.id}`);
    return botInfo;
  }

  kickPlayer(playerId) {
    const playerInfo = this.players.get(playerId);
    if (!playerInfo) {
      throw new Error('Player not found');
    }
    
    if (playerInfo.isHost) {
      throw new Error('Cannot kick the host');
    }
    
    if (this.status === 'playing') {
      // Replace with AI during game
      this.replacePlayerWithAI(playerInfo.position, playerInfo.name);
    } else {
      // Just remove during waiting
      this.players.delete(playerId);
    }
    
    this.lastActivity = new Date();
    
    Logger.info(`👤 Kicked player ${playerInfo.name} from room ${this.id}`);
    return playerInfo;
  }

  // Game management
  canStartGame() {
    return this.players.size === this.settings.maxPlayers && this.status === 'waiting';
  }

  startGame() {
    if (!this.canStartGame()) {
      // Detailed diagnostics
      const reasons = [];
      if (this.players.size !== this.settings.maxPlayers) {
        reasons.push(`players=${this.players.size}/${this.settings.maxPlayers}`);
      }
      if (this.status !== 'waiting') {
        reasons.push(`status=${this.status}`);
      }
      Logger.warn(`⚠️ startGame blocked in room ${this.id}. Reasons: ${reasons.join(', ') || 'unknown'}`);
      throw new Error('Cannot start game - ' + (reasons.join(', ') || 'invalid state'));
    }
    
    // Create game players
    const gamePlayers = [];
    let hostPosition = null;
    for (const [sessionId, playerInfo] of this.players) {
      const gamePlayer = new Player(
        sessionId,
        playerInfo.name,
        playerInfo.position,
        playerInfo.isAI
      );
      if (playerInfo.isHost) {
        hostPosition = playerInfo.position;
      }
      gamePlayers.push(gamePlayer);
    }

    // Set first king to host's position (should be 'south')
    const firstKing = hostPosition || 'south';

    // Create game
    this.game = new TrexGame(gamePlayers, firstKing);
    this.game.dealCards();

    this.status = 'playing';
    this.lastActivity = new Date();

    Logger.info(`🎮 Game started in room ${this.id} with first king: ${firstKing}`);

    return this.game.getGameState();
  }

  // Game actions
  selectContract(sessionId, contract) {
    if (!this.game || this.status !== 'playing') {
      Logger.error(`[selectContract] No active game. status=${this.status}`);
      throw new Error('No active game');
    }

    const playerInfo = this.players.get(sessionId);
    if (!playerInfo) {
      Logger.error(`[selectContract] Player not in room. sessionId=${sessionId}`);
      throw new Error('Player not in room');
    }

    Logger.info(`[selectContract] Attempt by ${playerInfo.name} (${playerInfo.position}) for contract=${contract}`);
    Logger.info(`[selectContract] Game phase=${this.game.phase}, currentKing=${this.game.currentKing}, usedContracts=${Array.from(this.game.usedContracts).join(',')}`);

    if (!this.game.canSelectContract(playerInfo.position)) {
      Logger.error(`[selectContract] Cannot select contract: phase=${this.game.phase}, currentKing=${this.game.currentKing}, player=${playerInfo.position}`);
      throw new Error('Cannot select contract');
    }

    this.lastActivity = new Date();
    return this.game.selectContract(contract);
  }

  playCard(sessionId, cardId) {
    if (!this.game || this.status !== 'playing') {
      throw new Error('No active game');
    }
    
    const playerInfo = this.players.get(sessionId);
    if (!playerInfo) {
      throw new Error('Player not in room');
    }
    
    if (!this.game.isPlayerTurn(playerInfo.position)) {
      throw new Error('Not player\'s turn');
    }
    
    this.lastActivity = new Date();
    const gameState = this.game.playCard(playerInfo.position, cardId);
    
    // Check if game ended
    if (this.game.phase === 'gameEnd') {
      this.status = 'finished';
    }
    
    return gameState;
  }

  // AI processing
  processAITurn() {
    if (!this.game || this.status !== 'playing') {
      return null;
    }
    
    // Check if game is in a valid state for AI processing
    if (this.game.phase === 'gameEnd' || this.game.phase === 'finished') {
      return null;
    }
    
    const currentPlayerPosition = this.game.currentPlayer;
    
    // Validate current player
    if (!currentPlayerPosition) {
      return null;
    }
    
    const aiPlayer = this.aiPlayers.get(currentPlayerPosition);
    
    if (!aiPlayer) {
      return null; // Not an AI player's turn
    }
    
    try {
      // Guard: if phase requires contract selection but current player isn't king, skip
      if (this.game.phase === 'contractSelection' && this.game.currentKing !== currentPlayerPosition) {
        return null;
      }

      // Guard: if phase is playing but it's not current player's turn, skip (race safety)
      if (this.game.phase === 'playing' && this.game.currentPlayer !== currentPlayerPosition) {
        return null;
      }

      // IMPORTANT: pass currentPlayerPosition so gameState includes that AI player's hand
      const gameState = this.game.getGameState(currentPlayerPosition);
      
      // Additional validation
      if (!gameState || !gameState.players || !gameState.players[currentPlayerPosition]) {
        Logger.warn(`⚠️ Invalid game state for AI player ${currentPlayerPosition} in room ${this.id}`);
        return null;
      }
      
      // Fallback: ensure hand exists
      if (!gameState.players[currentPlayerPosition].hand) {
        try {
          const internalPlayer = this.game.players.get(currentPlayerPosition);
            if (internalPlayer) {
              gameState.players[currentPlayerPosition].hand = internalPlayer.hand.map(c => c.toJson());
              Logger.warn(`⚠️ Reconstructed missing hand for AI ${currentPlayerPosition} in room ${this.id}`);
            }
        } catch (e) {
          Logger.error(`❌ Failed to reconstruct hand for ${currentPlayerPosition}:`, e);
        }
      }

      const aiMove = aiPlayer.makeMove(gameState, currentPlayerPosition);
      
      if (!aiMove || !aiMove.action) {
        Logger.warn(`⚠️ AI player ${currentPlayerPosition} returned invalid move in room ${this.id}`);
        return null;
      }
      
      if (aiMove.action === 'SELECT_CONTRACT') {
        const result = this.game.selectContract(aiMove.contract);
        // Broadcast contract selection to all players
        if (this.webSocketServer) {
          this.webSocketServer.broadcastGameState(this.id, result);
        }
        return result;
      } else if (aiMove.action === 'PLAY_CARD') {
        const result = this.game.playCard(currentPlayerPosition, aiMove.cardId);
        
        // Check if game ended
        if (this.game.phase === 'gameEnd') {
          this.status = 'finished';
        }
        
        // Broadcast AI card play to all players
        if (this.webSocketServer) {
          this.webSocketServer.broadcastPlayerAction(this.id, {
            type: 'AI_CARD_PLAYED',
            player: currentPlayerPosition,
            cardId: aiMove.cardId,
            timestamp: new Date().toISOString()
          });
          
          this.webSocketServer.broadcastGameState(this.id, result);
        }
        return result;
      }
    } catch (error) {
      // More detailed error logging
      Logger.error(`❌ AI error in room ${this.id} for player ${currentPlayerPosition || 'unknown'}:`, {
        error: error.message || error,
        stack: error.stack,
        gamePhase: this.game?.phase,
        currentPlayer: this.game?.currentPlayer,
        roomStatus: this.status
      });
    }
    
    return null;
  }

  // State management
  getRoomState(forSessionId = null) {
    const state = {
      id: this.id,
      name: this.name,
      hostId: this.hostId,
      status: this.status,
      settings: this.settings,
      createdAt: this.createdAt,
      lastActivity: this.lastActivity,
      players: Array.from(this.players.values()),
      spectators: Array.from(this.spectators.values()),
      gameState: this.game ? this.game.getGameState(
        forSessionId ? this.players.get(forSessionId)?.position : null
      ) : null
    };
    
    return state;
  }

  isActive() {
    const now = new Date();
    const maxIdleTime = 30 * 60 * 1000; // 30 minutes
    return (now - this.lastActivity) < maxIdleTime;
  }

  isEmpty() {
    return this.players.size === 0 && this.spectators.size === 0;
  }

  hasHumanPlayers() {
    return Array.from(this.players.values()).some(p => !p.isAI);
  }
}

class RoomManager {
  // Process AI turns for all rooms
  processAllAITurns() {
    if (!this.rooms) return;
    for (const room of this.rooms.values()) {
      if (typeof room.processAITurn === 'function') {
        room.processAITurn();
      }
    }
  }
  constructor(webSocketServer = null) {
    this.rooms = new Map(); // roomId -> GameRoom
    this.playerRooms = new Map(); // sessionId -> roomId
    this.webSocketServer = webSocketServer;
    this.cleanupInterval = setInterval(() => this.cleanup(), 5 * 60 * 1000); // 5 minutes
  }

  createRoom(hostSessionId, hostName, settings) {
    const room = new GameRoom(hostSessionId, hostName, this.webSocketServer, settings);
    this.rooms.set(room.id, room);
    
    // Add host as first player
    room.addPlayer(hostSessionId, hostName);
    this.playerRooms.set(hostSessionId, room.id);
    
    return room;
  }

  joinRoom(roomId, sessionId, playerName) {
    const room = this.rooms.get(roomId);
    if (!room) {
      throw new Error('Room not found');
    }
    
    // Remove from previous room if any
    this.leaveRoom(sessionId);
    
    const playerInfo = room.addPlayer(sessionId, playerName);
    this.playerRooms.set(sessionId, roomId);
    
    return { room, playerInfo };
  }

  leaveRoom(sessionId) {
    const roomId = this.playerRooms.get(sessionId);
    if (!roomId) {
      return false;
    }
    
    const room = this.rooms.get(roomId);
    if (room) {
      room.removePlayer(sessionId);
      room.removeSpectator(sessionId);
      
      // Remove room if empty
      if (room.isEmpty()) {
        this.rooms.delete(roomId);
      }
    }
    
    this.playerRooms.delete(sessionId);
    return true;
  }

  getRoom(roomId) {
    return this.rooms.get(roomId);
  }

  getRoomByPlayer(sessionId) {
    const roomId = this.playerRooms.get(sessionId);
    return roomId ? this.rooms.get(roomId) : null;
  }

  listRooms() {
    return Array.from(this.rooms.values())
      .filter(room => !room.settings.isPrivate)
      .map(room => ({
        id: room.id,
        name: room.name,
        status: room.status,
        players: room.players.size,
        maxPlayers: room.settings.maxPlayers,
        hasGame: !!room.game
      }));
  }

  // Cleanup inactive rooms
  cleanup() {
    const toDelete = [];
    
    for (const [roomId, room] of this.rooms) {
      if (!room.isActive() || (room.isEmpty() && room.status !== 'playing')) {
        toDelete.push(roomId);
      }
    }
    
    for (const roomId of toDelete) {
      const room = this.rooms.get(roomId);
      if (room) {
        Logger.info(`🧹 Cleaning up inactive room ${roomId}`);
        room.removeAllPlayers(); // Ensure all players are removed
        this.rooms.delete(roomId);
      }
    }
  }
}

module.exports = { RoomManager, GameRoom };
