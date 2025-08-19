/**
 * Main Trix Game Server
 * Server-side authoritative multiplayer Trix card game
 */

const express = require('express');
const http = require('http');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
require('dotenv').config();

// Import our modules
const WebSocketServer = require('./src/network/WebSocketServer');
const MessageHandler = require('./src/network/MessageHandler');
const { RoomManager } = require('./src/rooms/RoomManager');
const { DatabaseService } = require('./src/database/Database');
const Logger = require('./src/utils/Logger');

class TrixGameServer {
  constructor() {
    this.app = express();
    this.server = null;
    this.wsServer = null;
    this.roomManager = new RoomManager();
    this.database = new DatabaseService();
    
    this.port = process.env.PORT || 8080;
    this.host = process.env.HOST || '0.0.0.0';
    
    this.setupExpress();
    this.setupRoutes();
    this.setupGracefulShutdown();
  }

  setupExpress() {
    // Security middleware
    this.app.use(helmet({
      contentSecurityPolicy: false, // Disable for WebSocket support
      crossOriginEmbedderPolicy: false
    }));
    
    // Compression
    this.app.use(compression());
    
    // CORS
    this.app.use(cors({
      origin: process.env.CORS_ORIGIN || ['http://localhost:3000', 'http://localhost:8080'],
      credentials: true,
      methods: ['GET', 'POST', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization']
    }));
    
    // Logging
    if (process.env.NODE_ENV !== 'test') {
      this.app.use(morgan('combined', {
        stream: {
          write: (message) => Logger.info(message.trim())
        }
      }));
    }
    
    // Body parsing
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ extended: true, limit: '10mb' }));
    
    // Trust proxy for proper IP handling
    this.app.set('trust proxy', 1);
  }

  setupRoutes() {
    // Health check
    this.app.get('/health', (req, res) => {
      const health = {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        database: this.database.isConnected(),
        websocket: this.wsServer ? 'active' : 'inactive',
        stats: this.wsServer ? this.wsServer.getStats() : null
      };
      
      res.json(health);
    });

    // Server info
    this.app.get('/info', (req, res) => {
      res.json({
        name: 'Trix Game Server',
        version: '1.0.0',
        description: 'Server-side authoritative Trix card game',
        websocket: {
          endpoint: `/ws`,
          protocol: 'ws'
        },
        features: [
          'Real-time multiplayer',
          'AI players',
          'Room management',
          'Game state synchronization',
          'Reconnection support',
          'Spectator mode'
        ]
      });
    });

    // List public rooms
    this.app.get('/api/rooms', (req, res) => {
      try {
        const rooms = this.roomManager.listRooms();
        res.json({
          success: true,
          rooms,
          total: rooms.length
        });
      } catch (error) {
        Logger.error('❌ Error listing rooms:', error);
        res.status(500).json({
          success: false,
          error: 'Internal server error'
        });
      }
    });

    // Server statistics
    this.app.get('/api/stats', (req, res) => {
      try {
        const stats = {
          server: {
            uptime: process.uptime(),
            memory: process.memoryUsage(),
            version: process.version
          },
          rooms: this.roomManager.getStats(),
          websocket: this.wsServer ? this.wsServer.getStats() : null
        };
        
        res.json({
          success: true,
          stats
        });
      } catch (error) {
        Logger.error('❌ Error getting stats:', error);
        res.status(500).json({
          success: false,
          error: 'Internal server error'
        });
      }
    });

    // API documentation
    this.app.get('/api/docs', (req, res) => {
      res.json({
        websocketMessages: {
          client_to_server: [
            'CREATE_ROOM',
            'JOIN_ROOM',
            'LEAVE_ROOM',
            'LIST_ROOMS',
            'START_GAME',
            'ADD_AI',
            'SELECT_CONTRACT',
            'PLAY_CARD',
            'GET_GAME_STATE',
            'GET_ROOM_STATE',
            'CHAT_MESSAGE',
            'PING'
          ],
          server_to_client: [
            'CONNECTION_ESTABLISHED',
            'ROOM_CREATED',
            'ROOM_JOINED',
            'ROOM_LEFT',
            'ROOMS_LIST',
            'GAME_STARTED',
            'CONTRACT_SELECTED',
            'CARD_PLAYED',
            'GAME_STATE_UPDATE',
            'ROOM_UPDATE',
            'PLAYER_ACTION',
            'CHAT_MESSAGE',
            'ERROR',
            'PONG'
          ]
        },
        gameFlow: [
          '1. Connect to WebSocket',
          '2. Create or join a room',
          '3. Wait for game to start (host starts game)',
          '4. Select contracts (when king)',
          '5. Play cards in turns',
          '6. Complete rounds and kingdoms',
          '7. View final results'
        ]
      });
    });

    // 404 handler
    this.app.use('*', (req, res) => {
      res.status(404).json({
        success: false,
        error: 'Endpoint not found',
        message: 'Use WebSocket connection for game communication'
      });
    });

    // Error handler
    this.app.use((error, req, res, next) => {
      Logger.error('❌ Express error:', error);
      res.status(500).json({
        success: false,
        error: 'Internal server error'
      });
    });
  }

  async start() {
    try {
      // Initialize database
      await this.database.initialize();
      Logger.info('🗄️ Database initialized');

      // Create HTTP server
      this.server = http.createServer(this.app);

      // Initialize WebSocket server
      this.wsServer = new WebSocketServer(this.server, this.roomManager);
      
      // Connect message handler to WebSocket server for broadcasting
      this.connectMessageHandler();
      
      // Start AI processing
      this.wsServer.startAIProcessing();

      // Start server
      Logger.info(`🔧 Attempting to bind to host: ${this.host}, port: ${this.port}`);
      this.server.listen(this.port, this.host, () => {
        Logger.info(`🚀 Trix Game Server started`);
        Logger.info(`🌐 HTTP Server: http://${this.host}:${this.port}`);
        Logger.info(`🔌 WebSocket Server: ws://${this.host}:${this.port}`);
        Logger.info(`📊 Health Check: http://${this.host}:${this.port}/health`);
        Logger.info(`📖 API Docs: http://${this.host}:${this.port}/api/docs`);
      });

      // Start periodic tasks
      this.startPeriodicTasks();

    } catch (error) {
      Logger.error('❌ Failed to start server:', error);
      process.exit(1);
    }
  }

  connectMessageHandler() {
    // Connect MessageHandler broadcasting methods to WebSocketServer
    if (this.wsServer && this.wsServer.messageHandler) {
      const messageHandler = this.wsServer.messageHandler;
      
      messageHandler.broadcastRoomUpdate = (roomId, excludeSessionId) => {
        this.wsServer.broadcastRoomUpdate(roomId, excludeSessionId);
      };
      
      messageHandler.broadcastGameStart = (roomId, gameState, excludeSessionId) => {
        this.wsServer.broadcastToRoom(roomId, {
          type: 'GAME_STARTED',
          gameState,
          timestamp: new Date().toISOString()
        }, excludeSessionId);
      };
      
      messageHandler.broadcastPlayerAction = (roomId, action, excludeSessionId) => {
        this.wsServer.broadcastPlayerAction(roomId, action, excludeSessionId);
      };
      
      messageHandler.broadcastGameState = (roomId, gameState, excludeSessionId) => {
        this.wsServer.broadcastGameState(roomId, gameState, excludeSessionId);
      };
      
      messageHandler.broadcastToRoom = (roomId, message, excludeSessionId) => {
        this.wsServer.broadcastToRoom(roomId, message, excludeSessionId);
      };
    }
  }

  startPeriodicTasks() {
    // Room cleanup every 5 minutes
    setInterval(() => {
      this.roomManager.cleanup();
    }, 5 * 60 * 1000);

    // Server statistics logging every 30 minutes
    setInterval(() => {
      const stats = {
        rooms: this.roomManager.getStats(),
        websocket: this.wsServer ? this.wsServer.getStats() : null,
        memory: process.memoryUsage(),
        uptime: process.uptime()
      };
      Logger.info('📊 Server statistics:', stats);
    }, 30 * 60 * 1000);

    Logger.info('⏰ Periodic tasks started');
  }

  setupGracefulShutdown() {
    const gracefulShutdown = async (signal) => {
      Logger.info(`🛑 Received ${signal}, starting graceful shutdown...`);
      
      try {
        // Stop accepting new connections
        if (this.server) {
          this.server.close(() => {
            Logger.info('✅ HTTP server closed');
          });
        }

        // Close WebSocket connections
        if (this.wsServer) {
          this.wsServer.shutdown();
        }

        // Close database connection
        if (this.database) {
          await this.database.shutdown();
        }

        Logger.info('✅ Graceful shutdown completed');
        process.exit(0);
        
      } catch (error) {
        Logger.error('❌ Error during shutdown:', error);
        process.exit(1);
      }
    };

    // Handle different termination signals
    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));
    process.on('SIGUSR2', () => gracefulShutdown('SIGUSR2')); // Nodemon restart

    // Handle uncaught exceptions
    process.on('uncaughtException', (error) => {
      Logger.error('❌ Uncaught Exception:', error && error.stack ? error.stack : error);
      if (error && typeof error === 'object') {
        try {
          Logger.error('❌ Uncaught Exception (full object):', JSON.stringify(error, Object.getOwnPropertyNames(error), 2));
        } catch (e) {}
      }
      gracefulShutdown('UNCAUGHT_EXCEPTION');
    });

    process.on('unhandledRejection', (reason, promise) => {
      Logger.error('❌ Unhandled Rejection at:', promise, 'reason:', reason && reason.stack ? reason.stack : reason);
      if (reason && typeof reason === 'object') {
        try {
          Logger.error('❌ Unhandled Rejection (full object):', JSON.stringify(reason, Object.getOwnPropertyNames(reason), 2));
        } catch (e) {}
      }
      gracefulShutdown('UNHANDLED_REJECTION');
    });
  }
}

// Start the server if this file is run directly
if (require.main === module) {
  const server = new TrixGameServer();
  server.start().catch(error => {
    Logger.error('❌ Failed to start server:', error);
    process.exit(1);
  });
}

module.exports = TrixGameServer;
