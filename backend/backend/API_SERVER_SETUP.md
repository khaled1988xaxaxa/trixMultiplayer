# AI Training Data Collection API Server

A simple Node.js Express server to collect and store AI training data from the Trix game.

## Setup Instructions

### 1. Initialize Node.js Project

```bash
mkdir trix-ai-api
cd trix-ai-api
npm init -y
```

### 2. Install Dependencies

```bash
npm install express mongoose cors helmet compression morgan dotenv
npm install -D nodemon
```

### 3. Environment Configuration

Create `.env` file:

```env
# Server Configuration
PORT=3000
NODE_ENV=development

# Database
MONGODB_URI=mongodb://localhost:27017/trix_ai_training

# Security
API_KEY=your_secure_api_key_here_change_this
JWT_SECRET=your_jwt_secret_here

# CORS
CORS_ORIGIN=http://localhost:3000

# Data Management
MAX_BATCH_SIZE=1000
DATA_RETENTION_DAYS=30
```

### 4. Server Implementation

Create `server.js`:

```javascript
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

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

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true
})
.then(() => console.log('✅ Connected to MongoDB'))
.catch(err => console.error('❌ MongoDB connection error:', err));

// Data Models
const gameContextSchema = new mongoose.Schema({
  gameId: { type: String, required: true, index: true },
  timestamp: { type: Date, required: true },
  kingdom: { type: String, required: true },
  round: { type: Number, required: true },
  currentTrickNumber: { type: Number, required: true },
  leadingSuit: { type: String },
  cardsPlayedInTrick: [mongoose.Schema.Types.Mixed],
  playerHand: [mongoose.Schema.Types.Mixed],
  gameScore: { type: Map, of: Number },
  availableCards: [mongoose.Schema.Types.Mixed],
  currentPlayer: { type: String, required: true },
  playerOrder: [String]
}, { timestamps: true });

const playerDecisionSchema = new mongoose.Schema({
  decisionId: { type: String, required: true, unique: true },
  gameContextId: { type: String, required: true, index: true },
  playerId: { type: String, required: true },
  action: { type: mongoose.Schema.Types.Mixed, required: true },
  aiSuggestion: { type: mongoose.Schema.Types.Mixed },
  outcome: { type: mongoose.Schema.Types.Mixed },
  decisionTimeMs: { type: Number, required: true },
  timestamp: { type: Date, required: true }
}, { timestamps: true });

const batchLogSchema = new mongoose.Schema({
  batchId: { type: String, required: true, unique: true },
  deviceId: { type: String, required: true, index: true },
  appVersion: { type: String, required: true },
  gameContexts: [gameContextSchema],
  playerDecisions: [playerDecisionSchema],
  processedAt: { type: Date, default: Date.now }
}, { timestamps: true });

const GameContext = mongoose.model('GameContext', gameContextSchema);
const PlayerDecision = mongoose.model('PlayerDecision', playerDecisionSchema);
const BatchLog = mongoose.model('BatchLog', batchLogSchema);

// API Key Authentication Middleware
const authenticateApiKey = (req, res, next) => {
  const authHeader = req.headers.authorization;
  const apiKey = authHeader && authHeader.startsWith('Bearer ') 
    ? authHeader.substring(7) 
    : null;
  
  if (!apiKey || apiKey !== process.env.API_KEY) {
    return res.status(401).json({ 
      error: 'Unauthorized', 
      message: 'Invalid or missing API key' 
    });
  }
  
  next();
};

// Routes

// Health check
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// Batch upload endpoint
app.post('/api/game-logs/batch', authenticateApiKey, async (req, res) => {
  try {
    const batch = req.body;
    
    // Validate batch structure
    if (!batch.batchId || !batch.deviceId || !batch.appVersion) {
      return res.status(400).json({ 
        error: 'Invalid batch format',
        message: 'Missing required fields: batchId, deviceId, or appVersion'
      });
    }
    
    // Check batch size
    const totalItems = (batch.gameContexts?.length || 0) + (batch.playerDecisions?.length || 0);
    if (totalItems > parseInt(process.env.MAX_BATCH_SIZE || '1000')) {
      return res.status(413).json({ 
        error: 'Batch too large',
        message: `Batch size exceeds maximum of ${process.env.MAX_BATCH_SIZE} items`
      });
    }
    
    // Store batch
    const batchLog = new BatchLog(batch);
    await batchLog.save();
    
    // Store individual records for easier querying
    const promises = [];
    
    // Store game contexts
    if (batch.gameContexts && batch.gameContexts.length > 0) {
      const contextPromises = batch.gameContexts.map(context => {
        const gameContext = new GameContext(context);
        return gameContext.save();
      });
      promises.push(...contextPromises);
    }
    
    // Store player decisions
    if (batch.playerDecisions && batch.playerDecisions.length > 0) {
      const decisionPromises = batch.playerDecisions.map(decision => {
        const playerDecision = new PlayerDecision(decision);
        return playerDecision.save();
      });
      promises.push(...decisionPromises);
    }
    
    await Promise.all(promises);
    
    console.log(`✅ Processed batch ${batch.batchId} from device ${batch.deviceId}`);
    console.log(`   - Game contexts: ${batch.gameContexts?.length || 0}`);
    console.log(`   - Player decisions: ${batch.playerDecisions?.length || 0}`);
    
    res.json({ 
      success: true, 
      batchId: batch.batchId,
      processed: {
        gameContexts: batch.gameContexts?.length || 0,
        playerDecisions: batch.playerDecisions?.length || 0
      },
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Error processing batch:', error);
    
    if (error.code === 11000) {
      return res.status(409).json({ 
        error: 'Duplicate data',
        message: 'Batch or decision already exists'
      });
    }
    
    res.status(500).json({ 
      error: 'Internal server error',
      message: 'Failed to process batch'
    });
  }
});

// Export data endpoint (for AI training)
app.get('/api/game-logs/export', authenticateApiKey, async (req, res) => {
  try {
    const { 
      startDate, 
      endDate, 
      kingdom, 
      deviceId, 
      limit = 1000 
    } = req.query;
    
    // Build query
    const query = {};
    
    if (startDate) {
      query.timestamp = { $gte: new Date(startDate) };
    }
    
    if (endDate) {
      query.timestamp = { 
        ...query.timestamp, 
        $lte: new Date(endDate) 
      };
    }
    
    if (kingdom) {
      query.kingdom = kingdom;
    }
    
    if (deviceId) {
      query.deviceId = deviceId;
    }
    
    // Get game contexts and decisions
    const gameContexts = await GameContext
      .find(query)
      .limit(parseInt(limit))
      .sort({ timestamp: -1 });
    
    const contextIds = gameContexts.map(ctx => ctx.gameId);
    
    const playerDecisions = await PlayerDecision
      .find({ gameContextId: { $in: contextIds } })
      .sort({ timestamp: -1 });
    
    res.json({
      success: true,
      data: {
        gameContexts,
        playerDecisions,
        totalContexts: gameContexts.length,
        totalDecisions: playerDecisions.length
      },
      query: req.query,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Error exporting data:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      message: 'Failed to export data'
    });
  }
});

// Statistics endpoint
app.get('/api/game-logs/stats', authenticateApiKey, async (req, res) => {
  try {
    const stats = await Promise.all([
      GameContext.countDocuments(),
      PlayerDecision.countDocuments(),
      BatchLog.countDocuments(),
      GameContext.distinct('deviceId').then(devices => devices.length),
      GameContext.aggregate([
        { $group: { _id: '$kingdom', count: { $sum: 1 } } }
      ])
    ]);
    
    res.json({
      success: true,
      statistics: {
        totalGameContexts: stats[0],
        totalPlayerDecisions: stats[1],
        totalBatches: stats[2],
        uniqueDevices: stats[3],
        kingdomDistribution: stats[4],
        lastUpdated: new Date().toISOString()
      }
    });
    
  } catch (error) {
    console.error('❌ Error getting stats:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      message: 'Failed to get statistics'
    });
  }
});

// Data cleanup job (remove old data)
const cleanupOldData = async () => {
  try {
    const retentionDays = parseInt(process.env.DATA_RETENTION_DAYS || '30');
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - retentionDays);
    
    const contextResult = await GameContext.deleteMany({ 
      timestamp: { $lt: cutoffDate } 
    });
    
    const decisionResult = await PlayerDecision.deleteMany({ 
      timestamp: { $lt: cutoffDate } 
    });
    
    const batchResult = await BatchLog.deleteMany({ 
      createdAt: { $lt: cutoffDate } 
    });
    
    if (contextResult.deletedCount > 0 || decisionResult.deletedCount > 0 || batchResult.deletedCount > 0) {
      console.log(`🧹 Cleanup completed:`);
      console.log(`   - Game contexts deleted: ${contextResult.deletedCount}`);
      console.log(`   - Player decisions deleted: ${decisionResult.deletedCount}`);
      console.log(`   - Batches deleted: ${batchResult.deletedCount}`);
    }
    
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
  }
};

// Run cleanup daily at 2 AM
setInterval(cleanupOldData, 24 * 60 * 60 * 1000);

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('❌ Unhandled error:', error);
  res.status(500).json({ 
    error: 'Internal server error',
    message: 'An unexpected error occurred'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ 
    error: 'Not found',
    message: 'The requested endpoint does not exist'
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Trix AI Training API server running on port ${PORT}`);
  console.log(`📊 Environment: ${process.env.NODE_ENV}`);
  console.log(`🔒 API authentication: ${process.env.API_KEY ? 'Enabled' : 'Disabled'}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('📴 Shutting down gracefully...');
  mongoose.connection.close(() => {
    console.log('✅ Database connection closed');
    process.exit(0);
  });
});

module.exports = app;
```

### 5. Package.json Scripts

Update `package.json`:

```json
{
  "name": "trix-ai-api",
  "version": "1.0.0",
  "description": "AI Training Data Collection API for Trix Game",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "keywords": ["trix", "ai", "training", "api"],
  "author": "Your Name",
  "license": "MIT"
}
```

### 6. Running the Server

```bash
# Development mode with auto-reload
npm run dev

# Production mode
npm start
```

### 7. API Usage Examples

#### Test Health Endpoint
```bash
curl http://localhost:3000/api/health
```

#### Upload Training Data
```bash
curl -X POST http://localhost:3000/api/game-logs/batch \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_secure_api_key_here_change_this" \
  -d '{
    "batchId": "test-batch-1",
    "deviceId": "test-device",
    "appVersion": "1.0.0",
    "gameContexts": [],
    "playerDecisions": []
  }'
```

#### Get Statistics
```bash
curl http://localhost:3000/api/game-logs/stats \
  -H "Authorization: Bearer your_secure_api_key_here_change_this"
```

### 8. Database Setup

Make sure MongoDB is running:

```bash
# Install MongoDB (on Ubuntu/Debian)
sudo apt-get install mongodb

# Start MongoDB
sudo systemctl start mongodb

# Or use Docker
docker run -d -p 27017:27017 --name mongodb mongo:latest
```

### 9. Security Considerations

1. **Change the default API key** in `.env`
2. **Use HTTPS** in production
3. **Implement rate limiting** for production use
4. **Set up proper firewall rules**
5. **Regular database backups**

### 10. Deployment Options

#### Option A: Railway (Recommended)
1. Push code to GitHub
2. Connect Railway to your repository
3. Set environment variables
4. Deploy automatically

#### Option B: Heroku
1. Install Heroku CLI
2. `heroku create trix-ai-api`
3. Set environment variables
4. `git push heroku main`

#### Option C: DigitalOcean App Platform
1. Connect GitHub repository
2. Configure build settings
3. Set environment variables
4. Deploy

### 11. Monitoring and Logs

Add logging and monitoring:

```javascript
// Add to server.js for production monitoring
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' })
  ]
});

if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.simple()
  }));
}
```

## Flutter Configuration

Update the API URL in your Flutter app:

```dart
// In game_logging_service.dart
static const String _baseUrl = 'https://your-deployed-api-url.com';
static const String _apiKey = 'your_actual_api_key';
```
