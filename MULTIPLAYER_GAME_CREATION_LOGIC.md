# Multiplayer Game Creation Logic - Trix

## Overview
The multiplayer game creation system involves coordination between the Flutter client and Node.js backend server. Here's the complete flow and architecture:

---

## Architecture

### Client-Side (Flutter/Dart)
- **`multiplayer_client.dart`**: Main state provider using ChangeNotifier pattern
- **`lobby_screen.dart`**: UI for connection, room creation, and room joining
- **`websocket_service.dart`**: WebSocket communication layer

### Server-Side (Node.js)
- **`RoomManager.js`**: Manages game rooms and player lifecycle
- **`TrexGame.js`**: Core game logic and state management
- **`AIPlayer.js`**: AI player decision making

---

## State Transitions

```
disconnected → connecting → connected → inRoom → inGame
                                        ↓
                                      inLobby (if not in room)
```

### Enum: MultiplayerState
```dart
enum MultiplayerState {
  disconnected,    // Initial state, no server connection
  connecting,      // Attempting to connect
  connected,       // Connected to server, in lobby
  inLobby,         // In lobby, can see/create rooms
  inRoom,          // In a game room, waiting for game start
  inGame,          // Game is active, can play
}
```

---

## Game Creation Flow

### Step 1: Connect to Server

**Client Action** → `connect(serverUrl, playerName)`

```dart
// multiplayer_client.dart
Future<bool> connect(String serverUrl, String playerName) async {
  _setState(MultiplayerState.connecting);
  _serverUrl = serverUrl;
  _playerName = playerName;
  
  final success = await _websocket.connect(serverUrl, playerName: playerName);
  if (success) {
    _setState(MultiplayerState.connected);
    _startListening();
    return true;
  }
  // ...
}
```

**What happens:**
1. Client sends WebSocket connect message to `ws://localhost:8080` (or custom URL)
2. Server receives connection, creates session with unique ID
3. Client transitions to `MultiplayerState.connected`
4. Client begins listening for server messages

---

### Step 2: Create or Join a Room

#### Option A: Create New Room

**Client Action** → `createRoom(roomName, settings)`

```dart
void createRoom(String roomName, {Map<String, dynamic>? settings}) {
  _websocket.createRoom(roomName, settings: settings);
}
```

**Server Processing** (RoomManager.js):

```javascript
class GameRoom {
  constructor(hostId, hostName, webSocketServer = null, settings = {}) {
    this.id = uuidv4();  // Unique room ID
    this.hostId = hostId;
    this.hostName = hostName;
    this.name = settings.name || `${hostName}'s Room`;
    this.settings = {
      maxPlayers: 4,
      isPrivate: false,
      aiDifficulty: 'medium',
      allowSpectators: true,
      gameSpeed: 'normal',
      ...settings
    };
    
    this.players = new Map();     // sessionId → PlayerInfo
    this.spectators = new Map();  // sessionId → SpectatorInfo
    this.status = 'waiting';      // Not started yet
    this.game = null;             // Game instance created at start
    this.aiPlayers = new Map();   // position → AIPlayer instance
    
    Logger.info(`🏠 Room created: ${this.id} by ${hostName}`);
  }
}
```

**Room Settings Structure:**
```javascript
{
  maxPlayers: 4,              // Always 4 for Trix
  isPrivate: false,           // Public room
  aiDifficulty: 'medium',     // 'easy', 'medium', 'hard', 'elite'
  allowSpectators: true,      // Spectators can watch
  gameSpeed: 'normal'         // 'slow', 'normal', 'fast'
}
```

**Server Response:**
```javascript
{
  type: 'ROOM_CREATED',
  data: {
    room: {
      id: 'room-uuid-123',
      name: 'My Room',
      hostId: 'player-session-id',
      players: [PlayerInfo], // Including host
      status: 'waiting',
      settings: {...},
      createdAt: '2025-11-20T...'
    }
  }
}
```

**Client Update:**
```dart
void _handleRoomCreated(ServerMessage message) {
  final roomData = message.data['room'];
  if (roomData != null) {
    _currentRoom = ServerRoom.fromJson(roomData);
    _currentRoomId = _currentRoom!.id;
    _setState(MultiplayerState.inRoom);  // ← Transition
  }
}
```

#### Option B: Join Existing Room

**Client Action** → `joinRoom(roomId)`

```dart
void joinRoom(String roomId) {
  _websocket.joinRoom(roomId, _playerName!);
}
```

**Server Processing:**

```javascript
addPlayer(sessionId, playerName, isAI = false) {
  if (this.players.size >= this.settings.maxPlayers) {
    throw new Error('Room is full');
  }
  
  if (this.status !== 'waiting') {
    throw new Error('Game is already in progress');
  }
  
  // Assign position (north, south, east, west)
  const availablePositions = this.getAvailablePositions();
  const position = availablePositions[0];
  
  const playerInfo = {
    sessionId,
    name: playerName,
    position,
    isAI: false,
    isHost: sessionId === this.hostId,
    joinedAt: new Date(),
    isConnected: true
  };
  
  this.players.set(sessionId, playerInfo);
  Logger.info(`👤 Player ${playerName} joined room ${this.id} at position ${position}`);
  
  // Auto-fill with AI if room becomes full
  if (this.aiEnabled && this.canStartGame()) {
    this.fillWithAI();
  }
}
```

**Position Assignment:**
- **First to join (Host)**: `south`
- **Subsequent players**: `north`, `east`, `west` (in order)
- This is the card player positions around the table

---

## Auto AI Filling

When a player joins and completes the room (4 players total), the system automatically fills remaining positions with AI players.

**Server Logic:**

```javascript
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
```

---

## Room State Management

### Available Positions
```javascript
getAvailablePositions() {
  const occupiedPositions = Array.from(this.players.values())
    .map(p => p.position);
  return Object.values(PlayerPosition)
    .filter(pos => !occupiedPositions.includes(pos));
}

// PlayerPosition enum:
// 'north', 'south', 'east', 'west'
```

### Room Status
- **`waiting`**: Room created, waiting for players or start command
- **`playing`**: Game has been started
- **`finished`**: Game has ended

### Player Info Structure
```javascript
{
  sessionId,      // Unique player session ID
  name,           // Player display name
  position,       // Card position: 'north', 'south', 'east', 'west'
  isAI,           // Boolean: is this an AI player
  isHost,         // Boolean: is this the room host
  joinedAt,       // Timestamp when joined
  isConnected,    // Boolean: currently connected
  difficulty      // (AI only) 'easy', 'medium', 'hard', 'elite'
}
```

---

## Hosting Responsibilities

### Before Game Starts
Only the **host** can:
1. Add AI bots manually
2. Remove AI bots
3. Kick players
4. Start the game

### Host Assignment
- Original creator is host
- If host leaves during `waiting` phase:
  ```javascript
  assignNewHost() {
    const humanPlayers = Array.from(this.players.values())
      .filter(p => !p.isAI);
    if (humanPlayers.length > 0) {
      const newHost = humanPlayers[0];
      newHost.isHost = true;
      this.hostId = newHost.sessionId;
      Logger.info(`👑 New host assigned: ${newHost.name}`);
    }
  }
  ```

---

## Game Start Process

### Prerequisites
```javascript
canStartGame() {
  return this.players.size === this.settings.maxPlayers && 
         this.status === 'waiting';
}
```

**Requires:**
- Exactly 4 players (human + AI combined)
- Room status is `waiting`

### Server-Side Game Creation

**Client Action** → `startGame()` (only host)

```dart
void startGame() {
  if (!isHost) {
    _setError('Only host can start game');
    return;
  }
  _websocket.startGame(_currentRoomId!);
}
```

**Server Processing:**

```javascript
startGame() {
  if (!this.canStartGame()) {
    const reasons = [];
    if (this.players.size !== this.settings.maxPlayers) {
      reasons.push(`players=${this.players.size}/4`);
    }
    if (this.status !== 'waiting') {
      reasons.push(`status=${this.status}`);
    }
    throw new Error('Cannot start game: ' + reasons.join(', '));
  }
  
  // Create game players from room players
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
      hostPosition = playerInfo.position; // Usually 'south'
    }
    gamePlayers.push(gamePlayer);
  }
  
  // Create and initialize game
  const firstKing = hostPosition || 'south';
  this.game = new TrexGame(gamePlayers, firstKing);
  this.game.dealCards();  // Shuffle and deal 13 cards to each
  
  this.status = 'playing';
  
  Logger.info(`🎮 Game started in room ${this.id}`);
  return this.game.getGameState();
}
```

---

## Game State Management

### TrexGame Initialization

```javascript
class TrexGame {
  constructor(players, firstKingPosition) {
    this.players = new Map();  // position → Player
    this.deck = new Deck();    // 52 card deck
    this.phase = 'contractSelection';  // or 'playing', 'gameEnd'
    this.currentKing = firstKingPosition;
    this.currentPlayer = firstKingPosition;
    this.currentTrick = null;
    this.tricksWon = new Map();  // position → tricks count
    
    // Initialize players
    for (const player of players) {
      this.players.set(player.position, player);
      this.tricksWon.set(player.position, 0);
    }
    
    // Initialize scores
    this.round = 1;
    this.kingdom = 1;
    this.usedContracts = new Set();
  }
  
  dealCards() {
    this.deck.shuffle();
    let cardIndex = 0;
    
    // Deal 13 cards to each player
    for (const [position, player] of this.players) {
      player.hand = [];
      for (let i = 0; i < 13; i++) {
        player.hand.push(this.deck.cards[cardIndex++]);
      }
    }
    
    Logger.info(`🃏 Cards dealt to all players`);
  }
}
```

### Game Phases

1. **contractSelection**
   - King selects trump contract
   - AI players skip this phase (king contracts)
   - Lasts ~1 second (automated)

2. **playing**
   - Players take turns playing cards
   - Server validates legal moves
   - AI processes turns automatically
   - Tricks are completed, scored, and next trick starts

3. **gameEnd**
   - All 13 tricks completed
   - Scores calculated
   - Game finished

---

## Real-Time Updates

### Message Types

#### GAME_STATE_UPDATE
Sent whenever game state changes:
```javascript
{
  type: 'GAME_STATE_UPDATE',
  data: {
    gameState: {
      id: 'game-id',
      phase: 'playing',
      currentPlayer: 'east',
      currentKing: 'south',
      round: 1,
      kingdom: 1,
      players: {
        north: { ... },
        south: { ... },
        east: { ... },
        west: { ... }
      },
      currentTrick: { ... },
      tricksWon: { north: 1, south: 0, east: 2, west: 0 }
    }
  }
}
```

#### CARD_PLAYED
Broadcast when a card is played:
```javascript
{
  type: 'CARD_PLAYED',
  data: {
    player: 'east',
    card: 'six_of_spades',
    gameState: { ... }  // Updated game state
  }
}
```

#### AI_CARD_PLAYED
Broadcast when AI plays a card:
```javascript
{
  type: 'AI_CARD_PLAYED',
  data: {
    action: {
      cardId: 'king_of_hearts',
      player: 'north'
    }
  }
}
```

---

## AI Turn Processing

### Server-Side AI Loop

```javascript
// In RoomManager, runs every 1000ms
setInterval(() => {
  for (const [roomId, room] of roomManager.rooms) {
    if (room.status === 'playing') {
      const result = room.processAITurn();
      if (result) {
        broadcastGameState(roomId, result);
      }
    }
  }
}, 1000);
```

### AI Turn Processing Logic

```javascript
processAITurn() {
  if (!this.game || this.status !== 'playing') {
    return null;
  }
  
  if (this.game.phase === 'gameEnd') {
    return null;
  }
  
  const currentPlayerPosition = this.game.currentPlayer;
  const aiPlayer = this.aiPlayers.get(currentPlayerPosition);
  
  if (!aiPlayer) {
    // Current player is human, wait
    return null;
  }
  
  try {
    Logger.info(`[AI] Processing AI turn: ${currentPlayerPosition}`);
    
    const gameState = this.game.getGameState(currentPlayerPosition);
    const aiMove = aiPlayer.makeMove(gameState, currentPlayerPosition);
    
    if (aiMove.action === 'PLAY_CARD') {
      const cardId = aiMove.cardId;
      Logger.info(`🤖 AI ${currentPlayerPosition}: PLAY_CARD - ${cardId}`);
      
      return this.game.playCard(currentPlayerPosition, cardId);
    }
  } catch (e) {
    Logger.error(`[AI] Error processing AI turn:`, e);
  }
  
  return null;
}
```

---

## Client-Side Game Updates

### Listening for Updates

```dart
void _startListening() {
  _websocket.messageStream.listen(
    _handleMessage,
    onError: (error) {
      _setError('Connection error: $error');
    },
  );
}

void _handleMessage(ServerMessage message) {
  switch (message.type) {
    case 'GAME_STATE_UPDATE':
      _handleGameStateUpdate(message);
      break;
    case 'CARD_PLAYED':
      _handleCardPlayed(message);
      break;
    case 'GAME_STARTED':
      _handleGameStarted(message);
      break;
    // ... more cases
  }
}
```

### Updating Local State

```dart
void _handleGameStateUpdate(ServerMessage message) {
  final gameData = message.data['gameState'];
  if (gameData != null) {
    _currentGame = ServerGame.fromJson(gameData);
    _setState(MultiplayerState.inGame);
    
    // Enhanced debug logging
    print('🔄 [DEBUG] GameStateUpdate:');
    print('   Phase: ${_currentGame!.phase}');
    print('   Current Player: ${_currentGame!.currentPlayer}');
    print('   Is My Turn: $isMyTurn');
    _currentGame!.players.forEach((position, player) {
      print('   Player $position: ${player.name}, '
            'Hand size: ${player.hand.length}, '
            'isAI: ${player.isAI}');
    });
    
    notifyListeners();  // Rebuild widgets
  }
}

bool get isMyTurn {
  if (_currentGame == null) return false;
  return _currentGame!.currentPlayer == myPosition;
}
```

---

## Key Data Structures

### ServerRoom (Dart)
```dart
class ServerRoom {
  final String id;
  final String name;
  final String hostId;
  final List<ServerPlayer> players;
  final String status;           // 'waiting', 'playing', 'finished'
  final ServerRoomSettings settings;
  final DateTime createdAt;
  final ServerGame? game;
}
```

### ServerGame (Dart)
```dart
class ServerGame {
  final String gameId;
  final String phase;             // 'contractSelection', 'playing', 'gameEnd'
  final String currentPlayer;     // Position: 'north', 'south', 'east', 'west'
  final String? currentKing;
  final int round;
  final int kingdom;
  final List<String> usedContracts;
  final ServerTrick? currentTrick;
  final Map<String, int> tricksWon;
  final Map<String, ServerGamePlayer> players;  // position → player
}
```

### ServerGamePlayer (Dart)
```dart
class ServerGamePlayer {
  final String id;
  final String name;
  final String position;
  final bool isAI;
  final int tricksWon;
  final int score;
  final int totalScore;
  final bool isConnected;
  final int handSize;
  final List<ServerCard> hand;  // 13 cards per player
}
```

---

## Complete Game Creation Sequence Diagram

```
CLIENT (Flutter)                    SERVER (Node.js)
    |                                    |
    |-- connect("ws://...", name) ---→   |
    |← CONNECTED                          |
    |                                    |
    |-- createRoom("My Room") ----→      | Create GameRoom
    |← ROOM_CREATED                      | Status: waiting
    |                                    |
    | [Other player joins]               |
    |← ROOM_UPDATE (2 players)          |
    |                                    |
    | [Host clicks Start]                |
    |-- startGame() ----→                | Validate canStartGame()
    |                                    | - 4 players? ✓
    |                                    | - Status waiting? ✓
    |                                    | - Create TrexGame
    |                                    | - Deal 13 cards each
    |                                    | - Phase: contractSelection
    |← GAME_STARTED                      |
    | State: inGame                      | Status: playing
    |                                    |
    | [Contract selection happens]       | Auto (King contracts)
    | [Phase: playing]                   |
    |                                    |
    | [Wait for current player]          |
    |← GAME_STATE_UPDATE                 | Phase: playing
    |   currentPlayer: my_position       | Current: human player
    |                                    |
    | [Human plays card]                 |
    |-- playCard(cardId) ----→           | Validate card ownership
    |                                    | Remove from hand
    |                                    | Add to trick
    |← CARD_PLAYED                       | Check if trick complete
    |← GAME_STATE_UPDATE                 | currentPlayer: AI_position
    |   currentPlayer: AI_position       |
    |                                    | [1000ms interval passes]
    |                                    | processAITurn():
    |                                    | - Get AI decision
    |                                    | - Play card
    |                                    | - Update state
    |← CARD_PLAYED (AI)                  |
    |← GAME_STATE_UPDATE                 | currentPlayer: next_player
    |                                    |
    | [Game continues...]                | [Loop until gameEnd]
    |                                    |
    | [Final trick completed]            |
    |← GAME_STATE_UPDATE                 | Phase: gameEnd
    |   Phase: gameEnd                   | Final scores
    |                                    | Status: finished
```

---

## Error Handling

### Common Errors

1. **Cannot Start Game**
   - Room doesn't have 4 players
   - Game already started
   - Room status is not 'waiting'

2. **Invalid Card Play**
   - Player doesn't have card
   - Not player's turn
   - Invalid move per game rules

3. **Connection Lost**
   - WebSocket disconnected
   - Player replaced with AI if mid-game

4. **Full Room**
   - Cannot join, already has 4 players

---

## Summary

The multiplayer game creation system:

1. **Client connects** to server via WebSocket
2. **Host creates room** with default settings (4 max, medium AI difficulty)
3. **Players join** room, assigned positions (N/S/E/W)
4. **AI auto-fills** when room completes (4 players)
5. **Host starts game** → Server creates TrexGame instance
6. **Cards dealt** → 13 per player
7. **Game phases** cycle: contractSelection → playing → gameEnd
8. **Real-time updates** broadcast to all players
9. **AI processes turns** automatically every 1 second
10. **Human players** receive turn notification via `isMyTurn` flag

All communication is WebSocket-based, allowing real-time multiplayer experiences with automatic AI participation.
