# Multiplayer Server Setup Guide

This guide will help you set up a WebSocket server for the Trix multiplayer functionality.

## Prerequisites

- Node.js (v16 or higher)
- npm or yarn
- MongoDB (optional, for persistent storage)

## Server Architecture

The multiplayer server uses WebSocket connections for real-time communication and supports:
- Room management (create, join, leave)
- Game state synchronization
- Player management
- Chat functionality
- Connection management

## Setup Instructions

### 1. Initialize Node.js Project

```bash
mkdir trix-multiplayer-server
cd trix-multiplayer-server
npm init -y
```

### 2. Install Dependencies

```bash
npm install ws express cors helmet compression morgan dotenv uuid
npm install -D nodemon
```

### 3. Environment Configuration

Create `.env` file:

```env
# Server Configuration
PORT=8080
NODE_ENV=development

# Security
JWT_SECRET=your_jwt_secret_here_change_this
API_KEY=your_secure_api_key_here

# CORS
CORS_ORIGIN=http://localhost:3000

# Game Configuration
MAX_ROOMS=100
MAX_PLAYERS_PER_ROOM=4
GAME_TIMEOUT=300000 # 5 minutes
PING_INTERVAL=30000 # 30 seconds
```

### 4. Server Implementation

Create `server.js`:

```javascript
const WebSocket = require('ws');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const { v4: uuidv4 } = require('uuid');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8080;

// Security middleware
app.use(helmet());
app.use(compression());
app.use(cors({
  origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
  credentials: true
}));

// Logging
app.use(morgan('combined'));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Create HTTP server
const server = app.createServer();

// Create WebSocket server
const wss = new WebSocket.Server({ server });

// Game state management
const rooms = new Map();
const players = new Map();
const connections = new Map();

// Game logic
const GameManager = {
  // Create a new room
  createRoom(hostId, roomName, settings) {
    const roomId = uuidv4();
    const room = {
      id: roomId,
      name: roomName,
      hostId: hostId,
      players: [],
      status: 'waiting',
      settings: settings,
      createdAt: new Date(),
      currentGame: null,
      currentGameId: null,
    };
    
    rooms.set(roomId, room);
    return room;
  },

  // Join a room
  joinRoom(playerId, roomId, password) {
    const room = rooms.get(roomId);
    if (!room) {
      throw new Error('Room not found');
    }

    if (room.players.length >= room.settings.maxPlayers) {
      throw new Error('Room is full');
    }

    if (room.status !== 'waiting') {
      throw new Error('Game already in progress');
    }

    if (room.settings.password && room.settings.password !== password) {
      throw new Error('Invalid password');
    }

    const player = players.get(playerId);
    if (!player) {
      throw new Error('Player not found');
    }

    // Assign position if not already assigned
    if (!player.position) {
      const positions = ['south', 'west', 'north', 'east'];
      const usedPositions = room.players.map(p => p.position);
      const availablePositions = positions.filter(p => !usedPositions.includes(p));
      
      if (availablePositions.length > 0) {
        player.position = availablePositions[0];
      }
    }

    room.players.push(player);
    player.roomId = roomId;
    player.isReady = false;

    return room;
  },

  // Leave a room
  leaveRoom(playerId, roomId) {
    const room = rooms.get(roomId);
    if (!room) {
      throw new Error('Room not found');
    }

    const playerIndex = room.players.findIndex(p => p.id === playerId);
    if (playerIndex === -1) {
      throw new Error('Player not in room');
    }

    room.players.splice(playerIndex, 1);
    const player = players.get(playerId);
    if (player) {
      player.roomId = null;
      player.position = null;
      player.isReady = false;
    }

    // If room is empty, delete it
    if (room.players.length === 0) {
      rooms.delete(roomId);
    } else if (room.hostId === playerId) {
      // Transfer host to next player
      room.hostId = room.players[0].id;
      room.players[0].isHost = true;
    }

    return room;
  },

  // Start a game
  startGame(roomId) {
    const room = rooms.get(roomId);
    if (!room) {
      throw new Error('Room not found');
    }

    if (room.players.length < 4) {
      throw new Error('Need 4 players to start');
    }

    if (room.status !== 'waiting') {
      throw new Error('Game already in progress');
    }

    // Create game state
    const gameId = uuidv4();
    const gameState = this.createGameState(room, gameId);
    
    room.currentGame = gameState;
    room.currentGameId = gameId;
    room.status = 'playing';

    return gameState;
  },

  // Create initial game state
  createGameState(room, gameId) {
    // Initialize game with 4 players
    const playerHands = {};
    const scores = {};
    
    room.players.forEach(player => {
      playerHands[player.position] = [];
      scores[player.position] = 0;
    });

    return {
      gameId: gameId,
      roomId: room.id,
      phase: 'contractSelection',
      currentContract: null,
      currentPlayer: 'south',
      currentKing: 'south',
      round: 1,
      kingdom: 1,
      scores: scores,
      playerHands: playerHands,
      currentTrick: null,
      completedTricks: [],
      lastUpdated: new Date(),
      metadata: {},
    };
  },

  // Play a card
  playCard(playerId, roomId, card) {
    const room = rooms.get(roomId);
    if (!room || !room.currentGame) {
      throw new Error('No active game');
    }

    const player = players.get(playerId);
    if (!player || player.roomId !== roomId) {
      throw new Error('Player not in room');
    }

    // Validate card play
    // This is a simplified version - you'll need to implement full game logic
    const gameState = room.currentGame;
    
    // Remove card from player's hand
    const playerHand = gameState.playerHands[player.position];
    const cardIndex = playerHand.findIndex(c => 
      c.suit === card.suit && c.rank === card.rank
    );
    
    if (cardIndex === -1) {
      throw new Error('Card not in hand');
    }

    playerHand.splice(cardIndex, 1);

    // Update game state
    gameState.lastUpdated = new Date();

    return gameState;
  },

  // Select contract
  selectContract(playerId, roomId, contract) {
    const room = rooms.get(roomId);
    if (!room || !room.currentGame) {
      throw new Error('No active game');
    }

    const gameState = room.currentGame;
    gameState.currentContract = contract;
    gameState.phase = 'playing';
    gameState.lastUpdated = new Date();

    return gameState;
  },
};

// WebSocket connection handling
wss.on('connection', (ws, req) => {
  const connectionId = uuidv4();
  const playerId = uuidv4();
  
  // Create player
  const player = {
    id: playerId,
    name: `Player_${playerId.substring(0, 8)}`,
    position: null,
    roomId: null,
    isReady: false,
    isHost: false,
    connectedAt: new Date(),
    lastSeen: new Date(),
  };

  players.set(playerId, player);
  connections.set(connectionId, { ws, playerId });

  console.log(`Player connected: ${playerId}`);

  // Send welcome message
  ws.send(JSON.stringify({
    id: uuidv4(),
    type: 'welcome',
    senderId: 'server',
    roomId: '',
    data: {
      playerId: playerId,
      message: 'Welcome to Trix Multiplayer!'
    },
    timestamp: new Date().toISOString()
  }));

  // Handle messages
  ws.on('message', (data) => {
    try {
      const message = JSON.parse(data.toString());
      handleMessage(connectionId, message);
    } catch (error) {
      console.error('Error handling message:', error);
      sendError(ws, 'Invalid message format');
    }
  });

  // Handle disconnection
  ws.on('close', () => {
    handleDisconnection(connectionId);
  });

  // Handle errors
  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
    handleDisconnection(connectionId);
  });
});

// Message handling
function handleMessage(connectionId, message) {
  const connection = connections.get(connectionId);
  if (!connection) return;

  const { ws, playerId } = connection;
  const player = players.get(playerId);

  if (!player) {
    sendError(ws, 'Player not found');
    return;
  }

  // Update last seen
  player.lastSeen = new Date();

  try {
    switch (message.type) {
      case 'createRoom':
        handleCreateRoom(ws, playerId, message);
        break;
      case 'joinRoom':
        handleJoinRoom(ws, playerId, message);
        break;
      case 'leaveRoom':
        handleLeaveRoom(ws, playerId, message);
        break;
      case 'getRooms':
        handleGetRooms(ws, playerId, message);
        break;
      case 'startGame':
        handleStartGame(ws, playerId, message);
        break;
      case 'playCard':
        handlePlayCard(ws, playerId, message);
        break;
      case 'selectContract':
        handleSelectContract(ws, playerId, message);
        break;
      case 'chatMessage':
        handleChatMessage(ws, playerId, message);
        break;
      case 'playerReady':
        handlePlayerReady(ws, playerId, message);
        break;
      case 'ping':
        handlePing(ws, playerId, message);
        break;
      default:
        sendError(ws, `Unknown message type: ${message.type}`);
    }
  } catch (error) {
    console.error('Error handling message:', error);
    sendError(ws, error.message);
  }
}

// Message handlers
function handleCreateRoom(ws, playerId, message) {
  const { name, settings } = message.data;
  const room = GameManager.createRoom(playerId, name, settings);
  
  // Join the room
  GameManager.joinRoom(playerId, room.id);
  
  // Update player as host
  const player = players.get(playerId);
  player.isHost = true;
  player.position = 'south';

  // Send response
  sendResponse(ws, message.id, {
    success: true,
    room: room
  });

  // Broadcast room update
  broadcastToRoom(room.id, {
    id: uuidv4(),
    type: 'roomUpdate',
    senderId: 'server',
    roomId: room.id,
    data: { room: room },
    timestamp: new Date().toISOString()
  });
}

function handleJoinRoom(ws, playerId, message) {
  const { roomId, password } = message.data;
  const room = GameManager.joinRoom(playerId, roomId, password);

  // Send response
  sendResponse(ws, message.id, {
    success: true,
    room: room
  });

  // Broadcast room update
  broadcastToRoom(roomId, {
    id: uuidv4(),
    type: 'roomUpdate',
    senderId: 'server',
    roomId: roomId,
    data: { room: room },
    timestamp: new Date().toISOString()
  });

  // Broadcast player joined
  broadcastToRoom(roomId, {
    id: uuidv4(),
    type: 'playerJoined',
    senderId: 'server',
    roomId: roomId,
    data: { 
      playerId: playerId,
      playerName: players.get(playerId).name
    },
    timestamp: new Date().toISOString()
  });
}

function handleLeaveRoom(ws, playerId, message) {
  const { roomId } = message.data;
  const room = GameManager.leaveRoom(playerId, roomId);

  // Send response
  sendResponse(ws, message.id, {
    success: true
  });

  // Broadcast room update
  if (room) {
    broadcastToRoom(roomId, {
      id: uuidv4(),
      type: 'roomUpdate',
      senderId: 'server',
      roomId: roomId,
      data: { room: room },
      timestamp: new Date().toISOString()
    });
  }

  // Broadcast player left
  broadcastToRoom(roomId, {
    id: uuidv4(),
    type: 'playerLeft',
    senderId: 'server',
    roomId: roomId,
    data: { 
      playerId: playerId,
      playerName: players.get(playerId).name
    },
    timestamp: new Date().toISOString()
  });
}

function handleGetRooms(ws, playerId, message) {
  const availableRooms = Array.from(rooms.values())
    .filter(room => room.status === 'waiting' && room.players.length < room.settings.maxPlayers)
    .map(room => ({
      id: room.id,
      name: room.name,
      hostId: room.hostId,
      players: room.players,
      status: room.status,
      createdAt: room.createdAt,
      settings: room.settings,
      currentGameId: room.currentGameId,
    }));

  sendResponse(ws, message.id, {
    success: true,
    rooms: availableRooms
  });
}

function handleStartGame(ws, playerId, message) {
  const { roomId } = message.data;
  const room = rooms.get(roomId);
  
  if (!room || room.hostId !== playerId) {
    throw new Error('Only host can start game');
  }

  const gameState = GameManager.startGame(roomId);

  // Broadcast game start
  broadcastToRoom(roomId, {
    id: uuidv4(),
    type: 'gameStateUpdate',
    senderId: 'server',
    roomId: roomId,
    data: { gameState: gameState },
    timestamp: new Date().toISOString()
  });
}

function handlePlayCard(ws, playerId, message) {
  const { roomId, card, gameId } = message.data;
  const gameState = GameManager.playCard(playerId, roomId, card);

  // Broadcast game state update
  broadcastToRoom(roomId, {
    id: uuidv4(),
    type: 'gameStateUpdate',
    senderId: 'server',
    roomId: roomId,
    data: { gameState: gameState },
    timestamp: new Date().toISOString()
  });
}

function handleSelectContract(ws, playerId, message) {
  const { roomId, contract, gameId } = message.data;
  const gameState = GameManager.selectContract(playerId, roomId, contract);

  // Broadcast game state update
  broadcastToRoom(roomId, {
    id: uuidv4(),
    type: 'gameStateUpdate',
    senderId: 'server',
    roomId: roomId,
    data: { gameState: gameState },
    timestamp: new Date().toISOString()
  });
}

function handleChatMessage(ws, playerId, message) {
  const { roomId } = message.data;
  const player = players.get(playerId);

  // Broadcast chat message
  broadcastToRoom(roomId, {
    id: uuidv4(),
    type: 'chatMessage',
    senderId: playerId,
    roomId: roomId,
    data: {
      message: message.data.message,
      playerName: player.name,
      timestamp: new Date().toISOString()
    },
    timestamp: new Date().toISOString()
  });
}

function handlePlayerReady(ws, playerId, message) {
  const { roomId, isReady } = message.data;
  const player = players.get(playerId);
  
  if (player && player.roomId === roomId) {
    player.isReady = isReady;
    
    const room = rooms.get(roomId);
    if (room) {
      // Broadcast room update
      broadcastToRoom(roomId, {
        id: uuidv4(),
        type: 'roomUpdate',
        senderId: 'server',
        roomId: roomId,
        data: { room: room },
        timestamp: new Date().toISOString()
      });
    }
  }
}

function handlePing(ws, playerId, message) {
  // Send pong response
  ws.send(JSON.stringify({
    id: uuidv4(),
    type: 'pong',
    senderId: 'server',
    roomId: message.roomId || '',
    data: {},
    timestamp: new Date().toISOString()
  }));
}

// Utility functions
function sendResponse(ws, messageId, data) {
  ws.send(JSON.stringify({
    id: uuidv4(),
    type: 'response',
    senderId: 'server',
    roomId: '',
    data: {
      responseTo: messageId,
      ...data
    },
    timestamp: new Date().toISOString()
  }));
}

function sendError(ws, error) {
  ws.send(JSON.stringify({
    id: uuidv4(),
    type: 'error',
    senderId: 'server',
    roomId: '',
    data: { error: error },
    timestamp: new Date().toISOString()
  }));
}

function broadcastToRoom(roomId, message) {
  const room = rooms.get(roomId);
  if (!room) return;

  room.players.forEach(player => {
    const connection = Array.from(connections.values())
      .find(conn => conn.playerId === player.id);
    
    if (connection && connection.ws.readyState === WebSocket.OPEN) {
      connection.ws.send(JSON.stringify(message));
    }
  });
}

function handleDisconnection(connectionId) {
  const connection = connections.get(connectionId);
  if (!connection) return;

  const { playerId } = connection;
  const player = players.get(playerId);

  if (player && player.roomId) {
    try {
      const room = GameManager.leaveRoom(playerId, player.roomId);
      
      // Broadcast room update
      if (room) {
        broadcastToRoom(player.roomId, {
          id: uuidv4(),
          type: 'roomUpdate',
          senderId: 'server',
          roomId: player.roomId,
          data: { room: room },
          timestamp: new Date().toISOString()
        });
      }

      // Broadcast player left
      broadcastToRoom(player.roomId, {
        id: uuidv4(),
        type: 'playerLeft',
        senderId: 'server',
        roomId: player.roomId,
        data: { 
          playerId: playerId,
          playerName: player.name
        },
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      console.error('Error handling disconnection:', error);
    }
  }

  // Clean up
  players.delete(playerId);
  connections.delete(connectionId);

  console.log(`Player disconnected: ${playerId}`);
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    connections: connections.size,
    players: players.size,
    rooms: rooms.size
  });
});

// Start server
server.listen(PORT, () => {
  console.log(`🚀 Multiplayer server running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 Shutting down server...');
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});
```

### 5. Package.json Scripts

Update `package.json`:

```json
{
  "name": "trix-multiplayer-server",
  "version": "1.0.0",
  "description": "Multiplayer server for Trix card game",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "keywords": ["multiplayer", "websocket", "game", "trix"],
  "author": "Your Name",
  "license": "MIT"
}
```

### 6. Start the Server

```bash
# Development mode
npm run dev

# Production mode
npm start
```

## Configuration

### Environment Variables

- `PORT`: Server port (default: 8080)
- `NODE_ENV`: Environment (development/production)
- `JWT_SECRET`: Secret for JWT tokens
- `API_KEY`: API key for authentication
- `CORS_ORIGIN`: Allowed CORS origin
- `MAX_ROOMS`: Maximum number of rooms
- `MAX_PLAYERS_PER_ROOM`: Maximum players per room
- `GAME_TIMEOUT`: Game timeout in milliseconds
- `PING_INTERVAL`: Ping interval in milliseconds

### Server Features

1. **Room Management**
   - Create rooms with custom settings
   - Join/leave rooms
   - Password protection
   - Host transfer

2. **Game State Synchronization**
   - Real-time game state updates
   - Card playing
   - Contract selection
   - Score tracking

3. **Player Management**
   - Player connections
   - Ready status
   - Position assignment
   - Disconnection handling

4. **Communication**
   - Chat messages
   - System notifications
   - Error handling
   - Ping/pong for connection health

## Testing

### Manual Testing

1. Start the server
2. Open browser console
3. Create WebSocket connection:
```javascript
const ws = new WebSocket('ws://localhost:8080');
ws.onmessage = (event) => console.log(JSON.parse(event.data));
ws.onopen = () => console.log('Connected');
```

4. Send test message:
```javascript
ws.send(JSON.stringify({
  id: 'test-1',
  type: 'ping',
  senderId: 'test',
  roomId: '',
  data: {},
  timestamp: new Date().toISOString()
}));
```

### Load Testing

Use tools like Artillery or WebSocket-bench for load testing:

```bash
npm install -g artillery
artillery quick --count 10 --num 1 ws://localhost:8080
```

## Deployment

### Local Development

```bash
npm run dev
```

### Production Deployment

1. Set environment variables
2. Use PM2 for process management:
```bash
npm install -g pm2
pm2 start server.js --name trix-multiplayer
pm2 save
pm2 startup
```

3. Use Nginx as reverse proxy:
```nginx
location /ws {
    proxy_pass http://localhost:8080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
}
```

## Security Considerations

1. **Input Validation**: Validate all incoming messages
2. **Rate Limiting**: Implement rate limiting for connections
3. **Authentication**: Add JWT-based authentication
4. **HTTPS/WSS**: Use secure connections in production
5. **CORS**: Configure CORS properly
6. **Error Handling**: Don't expose sensitive information in errors

## Monitoring

### Health Check

```bash
curl http://localhost:8080/health
```

### Logs

Monitor server logs for:
- Connection/disconnection events
- Game state changes
- Error messages
- Performance metrics

## Troubleshooting

### Common Issues

1. **Connection Refused**: Check if server is running and port is available
2. **CORS Errors**: Verify CORS configuration
3. **Message Parsing Errors**: Check message format
4. **Memory Leaks**: Monitor connection cleanup

### Debug Mode

Enable debug logging by setting `NODE_ENV=development` in `.env`.

## Next Steps

1. **Database Integration**: Add MongoDB for persistent storage
2. **Authentication**: Implement user accounts and JWT
3. **Game Logic**: Add complete Trix game rules
4. **Spectators**: Support for watching games
5. **Tournaments**: Add tournament support
6. **Analytics**: Game statistics and analytics
