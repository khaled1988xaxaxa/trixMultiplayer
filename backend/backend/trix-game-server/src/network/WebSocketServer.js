/**
 * WebSocket Server - Handles real-time communication with clients
 */

const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');
const MessageHandler = require('./MessageHandler');
const Logger = require('../utils/Logger');

class WebSocketServer {
  constructor(server, roomManager) {
    this.wss = new WebSocket.Server({ server });
    this.roomManager = roomManager;
    this.messageHandler = new MessageHandler(roomManager, this);
    this.clients = new Map(); // sessionId -> { ws, playerInfo }
    
    this.setupWebSocketServer();
    this.startHeartbeat();
    
    Logger.info('🔌 WebSocket server initialized');
  }

  setupWebSocketServer() {
    this.wss.on('connection', (ws, request) => {
      this.handleConnection(ws, request);
    });
  }

  handleConnection(ws, request) {
    const sessionId = uuidv4();
    const clientInfo = {
      ws,
      sessionId,
      playerName: null,
      connectedAt: new Date(),
      lastPing: new Date(),
      isAlive: true
    };
    
    this.clients.set(sessionId, clientInfo);
    
    Logger.info(`🔗 Client connected: ${sessionId} (${this.clients.size} total)`);
    
    // Send connection confirmation
    this.sendToClient(sessionId, {
      type: 'CONNECTION_ESTABLISHED',
      sessionId,
      timestamp: new Date().toISOString()
    });
    
    // Setup message handling
    ws.on('message', (data) => {
      this.handleMessage(sessionId, data);
    });
    
    // Handle disconnection
    ws.on('close', () => {
      this.handleDisconnection(sessionId);
    });
    
    // Handle WebSocket errors
    ws.on('error', (error) => {
      Logger.error(`❌ WebSocket error for ${sessionId}:`, error);
      this.handleDisconnection(sessionId);
    });
    
    // Setup ping/pong for connection health
    ws.on('pong', () => {
      clientInfo.isAlive = true;
      clientInfo.lastPing = new Date();
    });
  }

  handleMessage(sessionId, data) {
    try {
      const message = JSON.parse(data.toString());
      const clientInfo = this.clients.get(sessionId);
      
      if (!clientInfo) {
        Logger.warn(`⚠️ Message from unknown client: ${sessionId}`);
        return;
      }
      
      Logger.debug(`📨 Message from ${sessionId}: ${message.type}`);
      
      // Update client info if player name is provided
      if (message.playerName && !clientInfo.playerName) {
        clientInfo.playerName = message.playerName;
      }
      
      // Process message
      this.messageHandler.handleMessage(sessionId, message, (response) => {
        this.sendResponse(sessionId, message, response);
      });
      
    } catch (error) {
      Logger.error(`❌ Error parsing message from ${sessionId}:`, error);
      this.sendError(sessionId, 'INVALID_MESSAGE', 'Invalid message format');
    }
  }

  handleDisconnection(sessionId) {
    const clientInfo = this.clients.get(sessionId);
    if (clientInfo) {
      Logger.info(`🔌 Client disconnected: ${sessionId} (${clientInfo.playerName || 'unknown'})`);
      
      // Remove from room
      this.roomManager.leaveRoom(sessionId);
      
      // Clean up
      this.clients.delete(sessionId);
    }
  }

  sendResponse(sessionId, originalMessage, response) {
    const responseMessage = {
      ...response,
      requestId: originalMessage.requestId,
      timestamp: new Date().toISOString()
    };
    
    this.sendToClient(sessionId, responseMessage);
  }

  sendToClient(sessionId, message) {
    const clientInfo = this.clients.get(sessionId);
    if (clientInfo && clientInfo.ws.readyState === WebSocket.OPEN) {
      try {
        clientInfo.ws.send(JSON.stringify(message));
      } catch (error) {
        Logger.error(`❌ Error sending message to ${sessionId}:`, error);
        this.handleDisconnection(sessionId);
      }
    }
  }

  sendError(sessionId, errorCode, errorMessage) {
    this.sendToClient(sessionId, {
      type: 'ERROR',
      error: {
        code: errorCode,
        message: errorMessage
      }
    });
  }

  // Broadcast to multiple clients
  broadcastToRoom(roomId, message, excludeSessionId = null) {
    const room = this.roomManager.getRoom(roomId);
    if (!room) {
      return;
    }
    
    // Send to all players in room
    for (const [sessionId] of room.players) {
      if (sessionId !== excludeSessionId) {
        this.sendToClient(sessionId, message);
      }
    }
    
    // Send to spectators
    for (const [sessionId] of room.spectators) {
      if (sessionId !== excludeSessionId) {
        this.sendToClient(sessionId, message);
      }
    }
  }

  broadcastToAllClients(message) {
    for (const [sessionId] of this.clients) {
      this.sendToClient(sessionId, message);
    }
  }

  // Game state broadcasting
  broadcastGameState(roomId, gameState, excludeSessionId = null) {
    const room = this.roomManager.getRoom(roomId);
    if (!room) {
      return;
    }
    
    // Send personalized game state to each player
    for (const [sessionId, playerInfo] of room.players) {
      if (sessionId !== excludeSessionId) {
        const personalizedState = room.game ? 
          room.game.getGameState(playerInfo.position) : 
          gameState;
        
        this.sendToClient(sessionId, {
          type: 'GAME_STATE_UPDATE',
          gameState: personalizedState,
          timestamp: new Date().toISOString()
        });
      }
    }
    
    // Send general state to spectators
    for (const [sessionId] of room.spectators) {
      if (sessionId !== excludeSessionId) {
        this.sendToClient(sessionId, {
          type: 'GAME_STATE_UPDATE',
          gameState: gameState,
          timestamp: new Date().toISOString()
        });
      }
    }
  }

  // Player action broadcasting
  broadcastPlayerAction(roomId, action, excludeSessionId = null) {
    this.broadcastToRoom(roomId, {
      type: 'PLAYER_ACTION',
      action,
      timestamp: new Date().toISOString()
    }, excludeSessionId);
  }

  // Room update broadcasting
  broadcastRoomUpdate(roomId, excludeSessionId = null) {
    const room = this.roomManager.getRoom(roomId);
    if (!room) {
      return;
    }
    
    // Send personalized room state to each player
    for (const [sessionId, playerInfo] of room.players) {
      if (sessionId !== excludeSessionId) {
        this.sendToClient(sessionId, {
          type: 'ROOM_UPDATE',
          room: room.getRoomState(sessionId),
          timestamp: new Date().toISOString()
        });
      }
    }
    
    // Send general room state to spectators
    for (const [sessionId] of room.spectators) {
      if (sessionId !== excludeSessionId) {
        this.sendToClient(sessionId, {
          type: 'ROOM_UPDATE',
          room: room.getRoomState(),
          timestamp: new Date().toISOString()
        });
      }
    }
  }

  // Heartbeat system
  startHeartbeat() {
    const heartbeatInterval = parseInt(process.env.WS_HEARTBEAT_INTERVAL) || 30000;
    const timeout = parseInt(process.env.WS_TIMEOUT) || 60000;
    
    setInterval(() => {
      const now = new Date();
      
      for (const [sessionId, clientInfo] of this.clients) {
        // Check if client is still alive
        if (!clientInfo.isAlive) {
          Logger.info(`💔 Client ${sessionId} failed heartbeat`);
          this.handleDisconnection(sessionId);
          continue;
        }
        
        // Check for timeout
        if (now - clientInfo.lastPing > timeout) {
          Logger.info(`⏰ Client ${sessionId} timed out`);
          clientInfo.ws.terminate();
          this.handleDisconnection(sessionId);
          continue;
        }
        
        // Send ping
        clientInfo.isAlive = false;
        if (clientInfo.ws.readyState === WebSocket.OPEN) {
          clientInfo.ws.ping();
        }
      }
    }, heartbeatInterval);
    
    Logger.info(`💓 Heartbeat system started (${heartbeatInterval}ms interval)`);
  }

  // AI turn processing
  startAIProcessing() {
    const aiInterval = parseInt(process.env.AI_MOVE_DELAY_MS) || 2000;
    
    setInterval(() => {
      this.roomManager.processAllAITurns();
    }, aiInterval);
    
    Logger.info(`🤖 AI processing started (${aiInterval}ms interval)`);
  }

  // Statistics and monitoring
  getStats() {
    return {
      connectedClients: this.clients.size,
      activeConnections: Array.from(this.clients.values())
        .filter(client => client.ws.readyState === WebSocket.OPEN).length,
      roomStats: this.roomManager.getStats()
    };
  }

  // Graceful shutdown
  shutdown() {
    Logger.info('🛑 Shutting down WebSocket server...');
    
    // Notify all clients
    this.broadcastToAllClients({
      type: 'SERVER_SHUTDOWN',
      message: 'Server is shutting down',
      timestamp: new Date().toISOString()
    });
    
    // Close all connections
    for (const [sessionId, clientInfo] of this.clients) {
      clientInfo.ws.close(1001, 'Server shutdown');
    }
    
    // Close WebSocket server
    this.wss.close(() => {
      Logger.info('✅ WebSocket server closed');
    });
  }
}

module.exports = WebSocketServer;
