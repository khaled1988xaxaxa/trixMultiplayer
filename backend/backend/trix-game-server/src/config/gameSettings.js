/**
 * Game Configuration Settings
 * Centralized configuration for all game constants
 */

module.exports = {
  // Game Rules
  MAX_PLAYERS: 4,
  CARDS_PER_PLAYER: 13,
  TOTAL_CARDS: 52,
  TRICKS_PER_GAME: 13,
  
  // Game Phases
  PHASE: {
    CONTRACT_SELECTION: 'contractSelection',
    PLAYING: 'playing',
    GAME_END: 'gameEnd',
  },
  
  // Player Positions
  POSITIONS: ['north', 'south', 'east', 'west'],
  HOST_POSITION: 'south',
  
  // Timing (in milliseconds)
  TURN_TIMEOUT_MS: 30000,              // 30 seconds per turn
  AI_PROCESS_INTERVAL_MS: 1000,        // Fallback interval if no event
  AI_MOVE_DELAY_MS: 100,               // Delay between consecutive AI moves
  AI_CHAIN_PROCESS_TIMEOUT_MS: 5000,   // Max time to process AI chain
  RECONNECT_TIMEOUT_MS: 5000,          // Time to wait for reconnection
  MESSAGE_BATCH_INTERVAL_MS: 100,      // Batch WebSocket messages
  CONTRACT_SELECTION_TIMEOUT_MS: 5000, // Auto-select if timeout
  
  // AI Settings
  AI_DIFFICULTY: {
    EASY: 'easy',
    MEDIUM: 'medium',
    HARD: 'hard',
    ELITE: 'elite',
  },
  
  DEFAULT_AI_DIFFICULTY: 'medium',
  
  // Room Settings
  DEFAULT_ROOM_SETTINGS: {
    maxPlayers: 4,
    isPrivate: false,
    aiDifficulty: 'medium',
    allowSpectators: true,
    gameSpeed: 'normal', // slow, normal, fast
  },
  
  GAME_SPEED: {
    SLOW: 'slow',     // Extra delays for learning
    NORMAL: 'normal', // Balanced
    FAST: 'fast',     // Minimal delays
  },
  
  // Message Types
  MESSAGE_TYPE: {
    // Room Messages
    ROOM_CREATED: 'ROOM_CREATED',
    ROOM_JOINED: 'ROOM_JOINED',
    ROOM_LEFT: 'ROOM_LEFT',
    ROOM_UPDATE: 'ROOM_UPDATE',
    
    // Game Messages
    GAME_STARTED: 'GAME_STARTED',
    GAME_STATE_UPDATE: 'GAME_STATE_UPDATE',
    CARD_PLAYED: 'CARD_PLAYED',
    AI_CARD_PLAYED: 'AI_CARD_PLAYED',
    
    // Player Messages
    PLAYER_ACTION: 'PLAYER_ACTION',
    CONTRACT_SELECTED: 'CONTRACT_SELECTED',
    
    // Admin Messages
    AI_ADDED: 'AI_ADDED',
    AI_REMOVED: 'AI_REMOVED',
    PLAYER_KICKED: 'PLAYER_KICKED',
    KICKED_FROM_ROOM: 'KICKED_FROM_ROOM',
    
    // List Messages
    ROOMS_LIST: 'ROOMS_LIST',
    CHAT_MESSAGE: 'CHAT_MESSAGE',
    
    // Status Messages
    ERROR: 'ERROR',
    GAME_END: 'GAME_END',
    TRICK_COMPLETED: 'TRICK_COMPLETED',
  },
  
  // Room Status
  ROOM_STATUS: {
    WAITING: 'waiting',
    PLAYING: 'playing',
    FINISHED: 'finished',
  },
  
  // Error Messages
  ERROR_MESSAGE: {
    ROOM_FULL: 'Room is full',
    GAME_IN_PROGRESS: 'Game is already in progress',
    NO_AVAILABLE_POSITIONS: 'No available positions',
    NOT_YOUR_TURN: 'Not your turn',
    INVALID_CARD: 'Card not in hand',
    CANNOT_START_GAME: 'Cannot start game - insufficient players',
    PLAYER_NOT_FOUND: 'Player not found',
    ROOM_NOT_FOUND: 'Room not found',
    NOT_HOST: 'Only host can perform this action',
    CARD_VALIDATION_FAILED: 'Card play violates game rules',
  },
  
  // Logging Levels
  LOG_LEVEL: {
    DEBUG: 'debug',
    INFO: 'info',
    WARN: 'warn',
    ERROR: 'error',
  },
  
  // Metrics
  METRICS: {
    TRACK_TURN_TIME: true,
    TRACK_MESSAGE_SIZE: true,
    TRACK_AI_PERFORMANCE: true,
    TRACK_PLAYER_LATENCY: true,
  },
};
