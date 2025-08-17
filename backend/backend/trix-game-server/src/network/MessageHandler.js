/**
 * Message Handler - Routes and processes incoming WebSocket messages
 */

const Logger = require('../utils/Logger');

class MessageHandler {
  constructor(roomManager, webSocketServer) {
    this.roomManager = roomManager;
    this.webSocketServer = webSocketServer;
  }

  handleMessage(sessionId, message, sendResponse) {
    try {
      const { type, ...data } = message;
      
      Logger.debug(`🔄 Handling ${type} from ${sessionId}`);
      
      switch (type) {
        case 'CREATE_ROOM':
          this.handleCreateRoom(sessionId, data, sendResponse);
          break;
          
        case 'JOIN_ROOM':
          this.handleJoinRoom(sessionId, data, sendResponse);
          break;
          
        case 'LEAVE_ROOM':
          this.handleLeaveRoom(sessionId, data, sendResponse);
          break;
          
        case 'LIST_ROOMS':
          this.handleListRooms(sessionId, data, sendResponse);
          break;
          
        case 'START_GAME':
          this.handleStartGame(sessionId, data, sendResponse);
          break;
          
        case 'ADD_AI':
          this.handleAddAI(sessionId, data, sendResponse);
          break;
          
        case 'ADD_BOT':
          this.handleAddAI(sessionId, data, sendResponse);
          break;
          
        case 'REMOVE_BOT':
          this.handleRemoveAI(sessionId, data, sendResponse);
          break;
          
        case 'KICK_PLAYER':
          this.handleKickPlayer(sessionId, data, sendResponse);
          break;
          
        case 'SELECT_CONTRACT':
          this.handleSelectContract(sessionId, data, sendResponse);
          break;
          
        case 'PLAY_CARD':
          this.handlePlayCard(sessionId, data, sendResponse);
          break;
          
        case 'GET_GAME_STATE':
          this.handleGetGameState(sessionId, data, sendResponse);
          break;
          
        case 'GET_ROOM_STATE':
          this.handleGetRoomState(sessionId, data, sendResponse);
          break;
          
        case 'CHAT_MESSAGE':
          this.handleChatMessage(sessionId, data, sendResponse);
          break;
          
        case 'PING':
          this.handlePing(sessionId, data, sendResponse);
          break;
          
        default:
          this.handleUnknownMessage(sessionId, type, sendResponse);
      }
      
    } catch (error) {
      Logger.error(`❌ Error handling message from ${sessionId}:`, error);
      sendResponse({
        type: 'ERROR',
        error: {
          code: 'HANDLER_ERROR',
          message: error.message
        }
      });
    }
  }

  handleCreateRoom(sessionId, data, sendResponse) {
    try {
      const { playerName, roomSettings } = data;
      
      if (!playerName) {
        throw new Error('Player name is required');
      }
      
      const room = this.roomManager.createRoom(sessionId, playerName, roomSettings);
      
      sendResponse({
        type: 'ROOM_CREATED',
        room: room.getRoomState(sessionId),
        playerInfo: room.players.get(sessionId)
      });
      
      Logger.info(`🏠 Room created by ${playerName}: ${room.id}`);
      
    } catch (error) {
      sendResponse({
        type: 'ERROR',
        error: {
          code: 'CREATE_ROOM_FAILED',
          message: error.message
        }
      });
    }
  }

  handleJoinRoom(sessionId, data, sendResponse) {
    try {
      const { roomId, playerName } = data;
      
      if (!roomId || !playerName) {
        throw new Error('Room ID and player name are required');
      }
      
      const { room, playerInfo } = this.roomManager.joinRoom(roomId, sessionId, playerName);
      
      sendResponse({
        type: 'ROOM_JOINED',
        room: room.getRoomState(sessionId),
        playerInfo
      });
      
      // Notify other players
      this.broadcastRoomUpdate(room.id, sessionId);
      
      Logger.info(`👤 ${playerName} joined room ${roomId}`);
      
    } catch (error) {
      sendResponse({
        type: 'ERROR',
        error: {
          code: 'JOIN_ROOM_FAILED',
          message: error.message
        }
      });
    }
  }

  handleLeaveRoom(sessionId, data, sendResponse) {
    try {
      const room = this.roomManager.getRoomByPlayer(sessionId);
      if (room) {
        const roomId = room.id;
        this.roomManager.leaveRoom(sessionId);
        
        sendResponse({
          type: 'ROOM_LEFT',
          roomId
        });
        
        // Notify remaining players
        this.broadcastRoomUpdate(roomId, sessionId);
        
        Logger.info(`👤 Player left room ${roomId}`);
      } else {
        sendResponse({
          type: 'ROOM_LEFT',
          message: 'Not in any room'
        });
      }
      
    } catch (error) {
      sendResponse({
        type: 'ERROR',
        error: {
          code: 'LEAVE_ROOM_FAILED',
          message: error.message
        }
      });
    }
  }

  handleListRooms(sessionId, data, sendResponse) {
    try {
      const rooms = this.roomManager.listRooms();
      
      sendResponse({
        type: 'ROOMS_LIST',
        rooms
      });
      
    } catch (error) {
      sendResponse({
        type: 'ERROR',
        error: {
          code: 'LIST_ROOMS_FAILED',
          message: error.message
        }
      });
    }
  }

  handleStartGame(sessionId, data, sendResponse) {
    try {
      const room = this.roomManager.getRoomByPlayer(sessionId);
      if (!room) {
        throw new Error('Not in a room');
      }
      
      const playerInfo = room.players.get(sessionId);
      if (!playerInfo || !playerInfo.isHost) {
        throw new Error('Only host can start the game');
      }

  Logger.info(`🟢 START_GAME requested by host ${playerInfo.name} in room ${room.id}. players=${room.players.size}/${room.settings.maxPlayers} status=${room.status}`);
      
      const gameState = room.startGame();
      
      sendResponse({
        type: 'GAME_STARTED',
        gameState
      });
      
      // Notify all players
      this.broadcastGameStart(room.id, gameState, sessionId);
      
      Logger.info(`🎮 Game started in room ${room.id}`);
      
    } catch (error) {
      sendResponse({
        type: 'ERROR',
        error: {
          code: 'START_GAME_FAILED',
          message: error.message
        }
      });
    }
  }

  handleAddAI(sessionId, data, sendResponse) {
    try {
      const room = this.roomManager.getRoomByPlayer(sessionId);
      if (!room) {
        throw new Error('Not in a room');
      }
      
      const playerInfo = room.players.get(sessionId);
      if (!playerInfo || !playerInfo.isHost) {
        throw new Error('Only host can add AI players');
      }
      
      if (room.status !== 'waiting') {
        throw new Error('Cannot add AI players - game already started');
      }
      
      const availablePositions = room.getAvailablePositions();
      if (availablePositions.length === 0) {
        throw new Error('Room is already full');
      }
      
      // Add AI players to fill available positions
      room.fillWithAI();
      
      sendResponse({
        type: 'AI_ADDED',
        room: room.getRoomState()
      });
      
      // Notify all players in the room
      this.broadcastRoomUpdate(room.id, sessionId);
      
      Logger.info(`🤖 AI players added to room ${room.id} by ${playerInfo.name}`);
      
    } catch (error) {
      sendResponse({
        type: 'ERROR',
        error: {
          code: 'ADD_AI_FAILED',
          message: error.message
        }
      });
    }
  }

  handleSelectContract(sessionId, data, sendResponse) {
    try {
      const { contract } = data;
      
      if (!contract) {
        throw new Error('Contract is required');
      }
      
      const room = this.roomManager.getRoomByPlayer(sessionId);
      if (!room) {
        throw new Error('Not in a room');
      }
      
      const gameState = room.selectContract(sessionId, contract);
      
      sendResponse({
        type: 'CONTRACT_SELECTED',
        contract,
        gameState
      });
      
      // Notify all players
      this.broadcastPlayerAction(room.id, {
        type: 'CONTRACT_SELECTED',
        player: room.players.get(sessionId)?.position,
        contract
      }, sessionId);
      
      this.broadcastGameState(room.id, gameState, sessionId);
      
      Logger.info(`📋 Contract ${contract} selected in room ${room.id}`);
      
    } catch (error) {
      sendResponse({
        type: 'ERROR',
        error: {
          code: 'SELECT_CONTRACT_FAILED',
          message: error.message
        }
      });
    }
  }

  handlePlayCard(sessionId, data, sendResponse) {
    try {
      const { cardId } = data;
      
      if (!cardId) {
        throw new Error('Card ID is required');
      }
      
      const room = this.roomManager.getRoomByPlayer(sessionId);
      if (!room) {
        throw new Error('Not in a room');
      }
      
      const gameState = room.playCard(sessionId, cardId);
      
      sendResponse({
        type: 'CARD_PLAYED',
        cardId,
        gameState
      });
      
      // Notify all players
      this.broadcastPlayerAction(room.id, {
        type: 'CARD_PLAYED',
        player: room.players.get(sessionId)?.position,
        cardId
      }, sessionId);
      
      this.broadcastGameState(room.id, gameState, sessionId);
      
      Logger.info(`🃏 Card ${cardId} played in room ${room.id}`);
      
    } catch (error) {
      sendResponse({
        type: 'ERROR',
        error: {
          code: 'PLAY_CARD_FAILED',
          message: error.message
        }
      });
    }
  }

  handleGetGameState(sessionId, data, sendResponse) {
    try {
      const room = this.roomManager.getRoomByPlayer(sessionId);
      if (!room) {
        throw new Error('Not in a room');
      }
      
      if (!room.game) {
        throw new Error('No active game');
      }
      
      const playerInfo = room.players.get(sessionId);
      const gameState = room.game.getGameState(playerInfo?.position);
      
      sendResponse({
        type: 'GAME_STATE_UPDATE',
        gameState
      });
      
    } catch (error) {
      sendResponse({
        type: 'ERROR',
        error: {
          code: 'GET_GAME_STATE_FAILED',
          message: error.message
        }
      });
    }
  }

  handleGetRoomState(sessionId, data, sendResponse) {
    try {
      const room = this.roomManager.getRoomByPlayer(sessionId);
      if (!room) {
        throw new Error('Not in a room');
      }
      
      const roomState = room.getRoomState(sessionId);
      
      sendResponse({
        type: 'ROOM_STATE',
        roomState
      });
      
    } catch (error) {
      sendResponse({
        type: 'ERROR',
        error: {
          code: 'GET_ROOM_STATE_FAILED',
          message: error.message
        }
      });
    }
  }

  handleChatMessage(sessionId, data, sendResponse) {
    try {
      const { message } = data;
      
      if (!message) {
        throw new Error('Message is required');
      }
      
      const room = this.roomManager.getRoomByPlayer(sessionId);
      if (!room) {
        throw new Error('Not in a room');
      }
      
      const playerInfo = room.players.get(sessionId) || room.spectators.get(sessionId);
      if (!playerInfo) {
        throw new Error('Player not found in room');
      }
      
      const chatMessage = {
        type: 'CHAT_MESSAGE',
        player: {
          name: playerInfo.name,
          position: playerInfo.position
        },
        message,
        timestamp: new Date().toISOString()
      };
      
      // Broadcast to all in room
      this.broadcastToRoom(room.id, chatMessage, sessionId);
      
      sendResponse({
        type: 'CHAT_SENT',
        message: chatMessage
      });
      
    } catch (error) {
      sendResponse({
        type: 'ERROR',
        error: {
          code: 'CHAT_FAILED',
          message: error.message
        }
      });
    }
  }

  handlePing(sessionId, data, sendResponse) {
    sendResponse({
      type: 'PONG',
      timestamp: new Date().toISOString()
    });
  }

  handleUnknownMessage(sessionId, type, sendResponse) {
    Logger.warn(`⚠️ Unknown message type: ${type} from ${sessionId}`);
    sendResponse({
      type: 'ERROR',
      error: {
        code: 'UNKNOWN_MESSAGE_TYPE',
        message: `Unknown message type: ${type}`
      }
    });
  }

  handleStartGame(sessionId, data, sendResponse) {
    try {
      const room = this.roomManager.getRoomByPlayer(sessionId);
      if (!room) {
        throw new Error('Not in a room');
      }

      const playerInfo = room.players.get(sessionId);
      if (!playerInfo || !playerInfo.isHost) {
        throw new Error('Only the host can start the game');
      }

      if (room.players.size < 4) {
        throw new Error('Need exactly 4 players to start the game');
      }

      const gameState = room.startGame();
      
      // Broadcast to all players in room
      this.broadcastGameStart(room.id, gameState);
      
      sendResponse({
        type: 'GAME_STARTED',
        gameState
      });
      
      Logger.info(`🎮 Game started in room ${room.id}`);
      
    } catch (error) {
      sendResponse({
        type: 'ERROR',
        error: {
          code: 'START_GAME_FAILED',
          message: error.message
        }
      });
    }
  }

  handleAddAI(sessionId, data, sendResponse) {
    try {
      const { botName, difficulty } = data;
      const room = this.roomManager.getRoomByPlayer(sessionId);
      
      if (!room) {
        throw new Error('Not in a room');
      }

      const playerInfo = room.players.get(sessionId);
      if (!playerInfo || !playerInfo.isHost) {
        throw new Error('Only the host can add AI bots');
      }

      if (room.players.size >= 4) {
        throw new Error('Room is full');
      }

      const aiPlayer = room.addAI(botName || `AI Bot ${room.players.size + 1}`, difficulty || 'medium');
      
      // Broadcast room update to all players
      this.broadcastRoomUpdate(room.id);
      
      sendResponse({
        type: 'AI_ADDED',
        aiPlayer,
        room: room.getRoomState(sessionId)
      });
      
      Logger.info(`🤖 AI bot added to room ${room.id}: ${aiPlayer.name}`);
      
    } catch (error) {
      sendResponse({
        type: 'ERROR',
        error: {
          code: 'ADD_AI_FAILED',
          message: error.message
        }
      });
    }
  }

  handleRemoveAI(sessionId, data, sendResponse) {
    try {
      const { botId } = data;
      const room = this.roomManager.getRoomByPlayer(sessionId);
      
      if (!room) {
        throw new Error('Not in a room');
      }

      const playerInfo = room.players.get(sessionId);
      if (!playerInfo || !playerInfo.isHost) {
        throw new Error('Only the host can remove AI bots');
      }

      const removed = room.removeAI(botId);
      
      // Broadcast room update to all players
      this.broadcastRoomUpdate(room.id);
      
      sendResponse({
        type: 'AI_REMOVED',
        removedBot: removed,
        room: room.getRoomState(sessionId)
      });
      
      Logger.info(`🤖 AI bot removed from room ${room.id}: ${removed.name}`);
      
    } catch (error) {
      sendResponse({
        type: 'ERROR',
        error: {
          code: 'REMOVE_AI_FAILED',
          message: error.message
        }
      });
    }
  }

  handleKickPlayer(sessionId, data, sendResponse) {
    try {
      const { playerId } = data;
      const room = this.roomManager.getRoomByPlayer(sessionId);
      
      if (!room) {
        throw new Error('Not in a room');
      }

      const hostInfo = room.players.get(sessionId);
      if (!hostInfo || !hostInfo.isHost) {
        throw new Error('Only the host can kick players');
      }

      if (playerId === sessionId) {
        throw new Error('Cannot kick yourself');
      }

      const kickedPlayer = room.kickPlayer(playerId);
      
      // Notify the kicked player
      if (this.webSocketServer) {
        this.webSocketServer.sendToPlayer(playerId, {
          type: 'KICKED_FROM_ROOM',
          reason: 'Kicked by host'
        });
      }
      
      // Broadcast room update to remaining players
      this.broadcastRoomUpdate(room.id, playerId);
      
      sendResponse({
        type: 'PLAYER_KICKED',
        kickedPlayer,
        room: room.getRoomState(sessionId)
      });
      
      Logger.info(`👤 Player kicked from room ${room.id}: ${kickedPlayer.name}`);
      
    } catch (error) {
      sendResponse({
        type: 'ERROR',
        error: {
          code: 'KICK_PLAYER_FAILED',
          message: error.message
        }
      });
    }
  }

  // Broadcasting helpers (these would be connected to WebSocketServer)
  broadcastRoomUpdate(roomId, excludeSessionId) {
    if (this.webSocketServer) {
      this.webSocketServer.broadcastRoomUpdate(roomId, excludeSessionId);
    }
    Logger.debug(`📢 Broadcasting room update for ${roomId}`);
  }

  broadcastGameStart(roomId, gameState, excludeSessionId) {
    if (this.webSocketServer) {
      this.webSocketServer.broadcastGameState(roomId, gameState, excludeSessionId);
    }
    Logger.debug(`📢 Broadcasting game start for ${roomId}`);
  }

  broadcastPlayerAction(roomId, action, excludeSessionId) {
    if (this.webSocketServer) {
      this.webSocketServer.broadcastPlayerAction(roomId, action, excludeSessionId);
    }
    Logger.debug(`📢 Broadcasting player action for ${roomId}`);
  }

  broadcastGameState(roomId, gameState, excludeSessionId) {
    // This would be implemented in WebSocketServer
    Logger.debug(`📢 Broadcasting game state for ${roomId}`);
  }

  broadcastToRoom(roomId, message, excludeSessionId) {
    // This would be implemented in WebSocketServer
    Logger.debug(`📢 Broadcasting to room ${roomId}`);
  }
}

module.exports = MessageHandler;
