# Trix Multiplayer V2 - Server-Authoritative Architecture

This is a complete rewrite of the multiplayer system for the Trix card game, moving from client-side game logic to proper server-authoritative architecture.

## 🎯 **Key Improvements**

### ✅ **What We Fixed**
- **Server-side game logic**: All game state and rules are now on the server
- **Real-time synchronization**: WebSocket-based instant updates
- **AI replacement**: Disconnected players are automatically replaced by AI
- **Reconnection support**: Players can rejoin ongoing games
- **Clean architecture**: Separated concerns between client and server

### ❌ **What We Removed**
- Client-side game state management
- Complex multiplayer providers with mixed responsibilities
- Inconsistent state synchronization
- Manual player management

## 📁 **New Architecture**

### **Server-Side (`backend/trix-game-server/`)**
```
src/
├── game/
│   ├── GameModels.js      # Card, Player, Trick models
│   ├── TrexGame.js        # Core game logic
│   └── AIPlayer.js        # Server-side AI
├── rooms/
│   └── RoomManager.js     # Room lifecycle management
├── network/
│   ├── WebSocketServer.js # Real-time communication
│   └── MessageHandler.js  # Message routing
├── database/
│   └── Database.js        # MongoDB integration
└── utils/
    └── Logger.js          # Centralized logging
```

### **Client-Side (`lib/multiplayer_v2/`)**
```
models/
└── server_models.dart     # Server state representations
services/
└── websocket_service.dart # WebSocket communication
providers/
└── multiplayer_client.dart # Main multiplayer provider
screens/
└── lobby_screen.dart      # Clean lobby interface
```

## 🚀 **Getting Started**

### **1. Start the Server**
```bash
cd backend/trix-game-server
npm install
npm start
```

Server will run on: `http://localhost:8080`

### **2. Update Flutter Dependencies**
Make sure you have the required packages in `pubspec.yaml`:
```yaml
dependencies:
  web_socket_channel: ^2.4.0
  connectivity_plus: ^5.0.0
  provider: ^6.1.0
```

### **3. Initialize Multiplayer**
```dart
// In your main app, add the provider
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => MultiplayerClient()),
    // ... other providers
  ],
  child: MyApp(),
)
```

### **4. Use the New Lobby**
```dart
// Navigate to multiplayer
Navigator.push(context, MaterialPageRoute(
  builder: (_) => const MultiplayerLobbyScreenV2(),
));
```

## 🎮 **Game Flow**

### **1. Connection**
- Client connects to WebSocket server
- Server assigns session ID
- Heartbeat system maintains connection

### **2. Room Management**
- Create/join rooms with up to 4 players
- AI automatically fills empty slots
- Host can start games

### **3. Game Play**
- Server deals cards and manages all game state
- Players send actions (select contract, play card)
- Server validates and broadcasts updates
- Real-time synchronization for all players

### **4. AI & Reconnection**
- Disconnected players replaced by AI instantly
- Players can reconnect and resume playing
- AI plays with configurable difficulty

## 🔌 **WebSocket API**

### **Client → Server Messages**
- `CREATE_ROOM` - Create a new game room
- `JOIN_ROOM` - Join existing room
- `START_GAME` - Start the game (host only)
- `SELECT_CONTRACT` - Choose contract (king only)
- `PLAY_CARD` - Play a card (during turn)

### **Server → Client Messages**
- `GAME_STATE_UPDATE` - Full game state sync
- `PLAYER_ACTION` - Real-time player actions
- `ROOM_UPDATE` - Room status changes
- `CHAT_MESSAGE` - Chat messages

## 🗃️ **Database Integration**

The server uses MongoDB to store:
- Game sessions and history
- Player statistics
- Room analytics
- Server performance metrics

## 🔧 **Configuration**

### **Server Environment (`.env`)**
```env
NODE_ENV=development
PORT=8080
MONGODB_URI=mongodb://localhost:27017/trix_game
AI_MOVE_DELAY_MS=2000
MAX_ROOMS=100
```

### **Client Configuration**
Default server URL: `ws://localhost:8080`
Can be changed in `MultiplayerClient.initialize(serverUrl: 'your-url')`

## 🧪 **Testing**

### **Server Health Check**
Visit: `http://localhost:8080/health`

### **API Documentation**
Visit: `http://localhost:8080/api/docs`

### **Room List**
Visit: `http://localhost:8080/api/rooms`

## 🚧 **Next Steps**

1. **Complete Flutter Integration**
   - Create room screen for game play
   - Implement card playing UI
   - Add chat system

2. **Enhanced Features**
   - Spectator mode
   - Game replays
   - Tournament system

3. **Production Readiness**
   - Authentication system
   - Rate limiting
   - Load balancing
   - SSL/TLS encryption

## 📝 **Migration Notes**

### **Removed Files (Backed up in `backup/multiplayer_old/`)**
- `lib/providers/multiplayer_*.dart`
- `lib/services/multiplayer_*.dart`
- `lib/models/multiplayer_models.dart`
- `lib/screens/multiplayer_*.dart`
- `backend/trix-multiplayer-server/`

### **Key Differences**
- **State Management**: Server is the single source of truth
- **Real-time Updates**: WebSocket streams instead of polling
- **AI Integration**: Server-side AI with strategic play
- **Error Handling**: Proper error codes and messages
- **Reconnection**: Automatic with AI replacement

## 🎯 **Benefits**

✅ **Authoritative Server**: No cheating, consistent game state
✅ **Real-time**: Instant updates for all players  
✅ **Scalable**: Clean separation of concerns
✅ **Robust**: Automatic reconnection and AI replacement
✅ **Maintainable**: Clear architecture and documentation
✅ **Extensible**: Easy to add features and game modes

The new system provides a solid foundation for multiplayer Trix gaming with professional-grade architecture and real-time capabilities.
