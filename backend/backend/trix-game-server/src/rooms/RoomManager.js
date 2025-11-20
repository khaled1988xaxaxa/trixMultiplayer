/**
 * Room Manager - Handles game rooms, matchmaking, and player management
 */

const { v4: uuidv4 } = require('uuid');
const TrexGame = require('../game/TrexGame');
const { Player, PlayerPosition } = require('../game/GameModels');
const { AIPlayer } = require('../game/AIPlayer');
const Logger = require('../utils/Logger');
const config = require('../config/gameSettings');

class GameRoom {
  constructor(hostId, hostName, webSocketServer = null, settings = {}) {
    this.id = uuidv4();
    this.hostId = hostId;
    this.hostName = hostName;
    this.webSocketServer = webSocketServer;
    this.name = settings.name || `${hostName}'s Room`;
    this.settings = {
      ...config.DEFAULT_ROOM_SETTINGS,
      ...settings
    };
    
    this.players = new Map(); // sessionId -> PlayerInfo
    this.spectators = new Map(); // sessionId -> SpectatorInfo
    this.status = config.ROOM_STATUS.WAITING;
    this.game = null;
    this.createdAt = new Date();
    this.lastActivity = new Date();
    
    // AI management
    this.aiPlayers = new Map(); // position -> AIPlayer
    this.aiEnabled = true;
    
    // Metrics
    this.metrics = {
      createdAt: new Date(),
      gamesStarted: 0,
      totalPlayTime: 0,
      turnCount: 0,
      aiTurnsProcessed: 0,
      averageTurnTime: 0,
    };
    
    // Turn timeout
    this.currentTurnStartTime = null;
    this.turnTimeoutId = null;
    
    // Game history
    this.trickHistory = [];
    
    Logger.info(`🏠 Room created: ${this.id} by ${hostName}`);
  }

  // Player management
  addPlayer(sessionId, playerName, isAI = false) {
    if (this.players.size >= this.settings.maxPlayers) {
      throw new Error(config.ERROR_MESSAGE.ROOM_FULL);
    }
    
    if (this.status !== config.ROOM_STATUS.WAITING) {
      throw new Error(config.ERROR_MESSAGE.GAME_IN_PROGRESS);
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
    const firstKing = hostPosition || config.HOST_POSITION;

    // Create game
    this.game = new TrexGame(gamePlayers, firstKing);
    this.game.dealCards();

    this.status = config.ROOM_STATUS.PLAYING;
    this.lastActivity = new Date();
    this.metrics.gamesStarted++;
    this.currentTurnStartTime = Date.now();
    this.startTurnTimer();

    Logger.info(`🎮 Game started in room ${this.id} with first king: ${firstKing}`);

    return this.game.getGameState();
  }

  // Turn timeout handling
  startTurnTimer() {
    this.clearTurnTimer();
    
    if (this.status !== config.ROOM_STATUS.PLAYING) return;
    
    this.turnTimeoutId = setTimeout(() => {
      const currentPlayer = this.game?.currentPlayer;
      Logger.warn(`⏰ Turn timeout for player ${currentPlayer} in room ${this.id}`);
      
      try {
        // Skip the current player's turn
        if (this.game && this.game.phase === config.PHASE.PLAYING) {
          // Move to next player
          this.game.skipCurrentPlayer();
          Logger.info(`⏭️ Skipped turn for player ${currentPlayer}`);
          
          // Broadcast update
          if (this.webSocketServer) {
            this.webSocketServer.broadcastGameState(this.id, this.game.getGameState());
          }
          
          // Process AI chain if needed
          this.processAIChain();
        }
      } catch (e) {
        Logger.error(`Error handling turn timeout: ${e.message}`);
      }
      
      // Restart timer for next player
      this.startTurnTimer();
    }, config.TURN_TIMEOUT_MS);
  }
  
  clearTurnTimer() {
    if (this.turnTimeoutId) {
      clearTimeout(this.turnTimeoutId);
      this.turnTimeoutId = null;
    }
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
    if (!this.game || this.status !== config.ROOM_STATUS.PLAYING) {
      throw new Error('No active game');
    }
    
    const playerInfo = this.players.get(sessionId);
    if (!playerInfo) {
      throw new Error(config.ERROR_MESSAGE.PLAYER_NOT_FOUND);
    }
    
    if (!this.game.isPlayerTurn(playerInfo.position)) {
      throw new Error(config.ERROR_MESSAGE.NOT_YOUR_TURN);
    }
    
    this.lastActivity = new Date();
    this.metrics.turnCount++;
    
    const gameState = this.game.playCard(playerInfo.position, cardId);
    
    // Record turn time
    if (this.currentTurnStartTime) {
      const turnTime = Date.now() - this.currentTurnStartTime;
      this.metrics.averageTurnTime = 
        (this.metrics.averageTurnTime * (this.metrics.turnCount - 1) + turnTime) / this.metrics.turnCount;
      this.currentTurnStartTime = Date.now();
    }
    
    // Check if game ended
    if (this.game.phase === config.PHASE.GAME_END) {
      this.status = config.ROOM_STATUS.FINISHED;
      this.metrics.totalPlayTime = Date.now() - this.metrics.createdAt;
      this.clearTurnTimer();
    } else {
      // Restart timer for next player
      this.startTurnTimer();
      
      // Process AI chain if needed
      setImmediate(() => this.processAIChain());
    }
    
    return gameState;
  }

  // AI processing - Event-driven approach
  async processAIChain() {
    if (!this.game || this.status !== config.ROOM_STATUS.PLAYING) {
      return null;
    }
    
    if (this.game.phase === config.PHASE.GAME_END || this.game.phase === 'finished') {
      return null;
    }
    
    const startTime = Date.now();
    let processedMoves = 0;
    
    try {
      // Process AI turns until a human player's turn or timeout
      while (this.game && this.status === config.ROOM_STATUS.PLAYING) {
        const currentPlayer = this.game.currentPlayer;
        if (!currentPlayer) break;
        
        const aiPlayer = this.aiPlayers.get(currentPlayer);
        if (!aiPlayer) {
          // Current player is human, stop
          Logger.debug(`[AI] Stopping AI chain: Current player ${currentPlayer} is human`);
          break;
        }
        
        // Check timeout
        if (Date.now() - startTime > config.AI_CHAIN_PROCESS_TIMEOUT_MS) {
          Logger.warn(`[AI] AI chain timeout in room ${this.id}`);
          break;
        }
        
        // Process this AI move
        const result = this.processAISingleTurn();
        if (result) {
          processedMoves++;
          
          // Broadcast update
          if (this.webSocketServer) {
            this.webSocketServer.broadcastPlayerAction(this.id, {
              type: config.MESSAGE_TYPE.AI_CARD_PLAYED,
              player: currentPlayer,
              cardId: result.lastCardPlayed,
              timestamp: new Date().toISOString()
            });
            this.webSocketServer.broadcastGameState(this.id, this.game.getGameState());
          }
          
          // Delay between AI moves
          await this.delay(config.AI_MOVE_DELAY_MS);
        } else {
          break;
        }
      }
      
      Logger.debug(`[AI] AI chain processed ${processedMoves} moves in ${Date.now() - startTime}ms`);
      return processedMoves > 0 ? this.game.getGameState() : null;
    } catch (e) {
      Logger.error(`[AI] Error in AI chain: ${e.message}`);
      return null;
    }
  }

  // Single AI turn processing
  processAISingleTurn() {
    if (!this.game || this.status !== config.ROOM_STATUS.PLAYING) {
      Logger.debug(`[AI] Skipping processAISingleTurn: No active game. Room=${this.id}`);
      return null;
    }
    
    if (this.game.phase === config.PHASE.GAME_END) {
      Logger.debug(`[AI] Skipping processAISingleTurn: Game ended. Room=${this.id}`);
      return null;
    }
    
    const currentPlayerPosition = this.game.currentPlayer;
    if (!currentPlayerPosition) {
      Logger.debug(`[AI] Skipping processAISingleTurn: No current player. Room=${this.id}`);
      return null;
    }
    
    const aiPlayer = this.aiPlayers.get(currentPlayerPosition);
    if (!aiPlayer) {
      Logger.debug(`[AI] Skipping processAISingleTurn: Current player is not AI. Room=${this.id}, Position=${currentPlayerPosition}`);
      return null;
    }
    
    try {
      Logger.info(`[AI] Processing single AI turn: Room=${this.id}, Position=${currentPlayerPosition}`);
      
      if (this.game.phase === config.PHASE.CONTRACT_SELECTION && this.game.currentKing !== currentPlayerPosition) {
        Logger.debug(`[AI] Skipping contract selection: Not king`);
        return null;
      }
      
      if (this.game.phase === config.PHASE.PLAYING && this.game.currentPlayer !== currentPlayerPosition) {
        Logger.debug(`[AI] Skipping play card: Not current player's turn`);
        return null;
      }
      
      const gameState = this.game.getGameState(currentPlayerPosition);
      if (!gameState || !gameState.players || !gameState.players[currentPlayerPosition]) {
        Logger.warn(`[AI] Invalid game state for AI player ${currentPlayerPosition}`);
        return null;
      }
      
      // Reconstruct hand if missing
      if (!gameState.players[currentPlayerPosition].hand) {
        try {
          const internalPlayer = this.game.players.get(currentPlayerPosition);
          if (internalPlayer) {
            gameState.players[currentPlayerPosition].hand = internalPlayer.hand.map(c => c.toJson());
          }
        } catch (e) {
          Logger.error(`[AI] Failed to reconstruct hand: ${e.message}`);
        }
      }
      
      const aiMove = aiPlayer.makeMove(gameState, currentPlayerPosition);
      Logger.info(`[AI] AI move result:`, aiMove);
      
      if (!aiMove || !aiMove.action) {
        Logger.warn(`[AI] AI returned invalid move`);
        return null;
      }
      
      if (aiMove.action === 'SELECT_CONTRACT') {
        Logger.info(`[AI] AI selecting contract: ${aiMove.contract}`);
        const result = this.game.selectContract(aiMove.contract);
        return { ...result, lastCardPlayed: aiMove.contract };
      } else if (aiMove.action === 'PLAY_CARD') {
        Logger.info(`[AI] AI playing card: ${aiMove.cardId}`);
        const result = this.game.playCard(currentPlayerPosition, aiMove.cardId);
        
        this.metrics.aiTurnsProcessed++;
        
        // Record trick if completed
        if (result.trickCompleted) {
          this.trickHistory.push({
            number: this.trickHistory.length + 1,
            winner: result.trickWinner,
            timestamp: new Date()
          });
        }
        
        if (this.game.phase === config.PHASE.GAME_END) {
          this.status = config.ROOM_STATUS.FINISHED;
          this.metrics.totalPlayTime = Date.now() - this.metrics.createdAt;
          this.clearTurnTimer();
        }
        
        return { ...result, lastCardPlayed: aiMove.cardId };
      }
    } catch (error) {
      Logger.error(`[AI] Error processing AI turn:`, {
        error: error.message,
        room: this.id,
        player: currentPlayerPosition,
        phase: this.game?.phase
      });
    }
    
    return null;
  }

  // Fallback processAITurn for compatibility
  processAITurn() {
    return this.processAISingleTurn();
  }

  // Utility: Delay helper
  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  // Remove all players and clean up
  removeAllPlayers() {
    this.clearTurnTimer();
    this.players.clear();
    this.spectators.clear();
    this.aiPlayers.clear();
    Logger.info(`🧹 Cleared all players from room ${this.id}`);
  }

  // Spectator support
  handleSpectatorMessage(spectatorId, message) {
    const spectator = this.spectators.get(spectatorId);
    if (!spectator) {
      Logger.warn(`Spectator ${spectatorId} not found in room ${this.id}`);
      return null;
    }
    
    if (message.type === 'WATCH_GAME') {
      // Send full game state to spectator
      return this.game ? this.game.getGameState() : null;
    }
    
    if (message.type === 'GET_TRICKS') {
      // Send trick history to spectator
      return {
        tricks: this.trickHistory,
        totalTricks: this.trickHistory.length
      };
    }
    
    return null;
  }

  // Metrics and diagnostics
  getMetrics() {
    return {
      roomId: this.id,
      status: this.status,
      players: this.players.size,
      spectators: this.spectators.size,
      aiCount: this.aiPlayers.size,
      phase: this.game?.phase,
      currentPlayer: this.game?.currentPlayer,
      metrics: this.metrics,
      trickCount: this.trickHistory.length,
      averageTurnTime: Math.round(this.metrics.averageTurnTime),
      totalPlayTime: this.metrics.totalPlayTime
    };
  }
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
  constructor(webSocketServer = null) {
    this.rooms = new Map(); // roomId -> GameRoom
    this.playerRooms = new Map(); // sessionId -> roomId
    this.webSocketServer = webSocketServer;
    
    this.cleanupInterval = setInterval(() => this.cleanup(), 5 * 60 * 1000); // 5 minutes
    
    // Fallback AI interval (for rooms without active players)
    this.aiInterval = setInterval(() => {
      const start = Date.now();
      let aiMoves = 0;
      
      if (this.rooms) {
        for (const room of this.rooms.values()) {
          if (typeof room.processAITurn === 'function') {
            const result = room.processAITurn();
            if (result) aiMoves++;
          }
        }
      }
      
      Logger.debug(`[AI] Fallback AI interval: ${aiMoves} moves in ${Date.now() - start}ms`);
    }, config.AI_PROCESS_INTERVAL_MS);
    
    Logger.info(`✅ RoomManager initialized`);
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

  // Process AI turns for all active rooms
  processAllAITurns() {
    const start = Date.now();
    let totalAIMoves = 0;

    if (!this.rooms || this.rooms.size === 0) {
      return { processed: 0, time: 0 };
    }

    for (const room of this.rooms.values()) {
      if (room && room.isActive && room.isActive()) {
        try {
          // Use event-driven AI processing if available
          if (typeof room.processAIChain === 'function') {
            // processAIChain is async but we fire and forget here
            // The actual processing happens via setImmediate in playCard
            totalAIMoves++;
          }
        } catch (error) {
          Logger.error(`Error processing AI for room ${room.id}: ${error.message}`);
        }
      }
    }

    const duration = Date.now() - start;
    return { processed: totalAIMoves, time: duration };
  }

  // Get server statistics
  getStats() {
    return {
      totalRooms: this.rooms.size,
      activeRooms: Array.from(this.rooms.values()).filter(room => room.isActive()).length,
      totalPlayers: Array.from(this.rooms.values()).reduce((total, room) => total + room.players.size, 0),
      totalSpectators: Array.from(this.rooms.values()).reduce((total, room) => total + room.spectators.size, 0),
      roomsByStatus: {
        waiting: Array.from(this.rooms.values()).filter(room => room.status === 'waiting').length,
        playing: Array.from(this.rooms.values()).filter(room => room.status === 'playing').length,
        finished: Array.from(this.rooms.values()).filter(room => room.status === 'finished').length
      }
    };
  }
}

module.exports = { RoomManager, GameRoom };
