import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/ai_logging_provider.dart';
import '../multiplayer_v2/providers/multiplayer_client.dart';
import '../multiplayer_v2/models/server_models.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/ai_player.dart';
import '../models/card.dart' as game_card;
import '../models/game_log_models.dart';
import '../widgets/playing_card_widget.dart';
import '../widgets/contract_selection_widget.dart';
import '../widgets/ai_difficulty_indicator.dart';
import '../widgets/optimized_card_fan.dart';
import '../widgets/optimized_ui_components.dart';
import '../utils/object_pool.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _showDebugHands = false; // Debug flag to show/hide AI hands
  bool _isCheckingGameState = false;

  @override
  void initState() {
    super.initState();
    // Check game state when screen first loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndFixGameState();
    });
  }

  @override
  void dispose() {
    // Clear object pools to free memory
    CacheManager.clearAll();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Check if we have arguments passed
    final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments != null) {
      // Handle multiplayer mode
      if (arguments.containsKey('isMultiplayer') && arguments['isMultiplayer'] == true) {
        if (kDebugMode) print('🎮 GameScreen: Starting multiplayer mode');
        // Use post-frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _setupMultiplayerGame(arguments);
        });
      }
      // Handle AI opponents (single player)
      else if (arguments.containsKey('aiOpponents')) {
        if (kDebugMode) print('🎮 GameScreen received AI opponents arguments');
        // Use post-frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _setupGameWithAIOpponents(arguments);
        });
      }
    }
  }

  Future<void> _setupGameWithAIOpponents(Map<String, dynamic> arguments) async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    
    // Reset any existing game to start fresh with AI opponents
    if (gameProvider.hasActiveGame) {
      if (kDebugMode) print('🎮 Resetting existing game to start new AI game');
      gameProvider.resetGame();
    }
    
    try {
      final aiOpponents = arguments['aiOpponents'] as List?;
      if (aiOpponents != null && aiOpponents.isNotEmpty) {
        if (kDebugMode) print('🎮 Setting up game with ${aiOpponents.length} AI opponents');
        
        // Create human player
        final humanPlayer = Player(
          id: 'human',
          name: 'Player',
          position: PlayerPosition.south,
          isBot: false,
        );
        
        // Use the AI opponents directly (they are already AIPlayer objects)
        final aiPlayers = <Player>[];
        final positions = [PlayerPosition.west, PlayerPosition.north, PlayerPosition.east];
        
        for (int i = 0; i < aiOpponents.length && i < 3; i++) {
          final aiOpponent = aiOpponents[i] as AIPlayer;
          
          // Update position for the AI player
          final updatedAIPlayer = AIPlayer(
            id: aiOpponent.id,
            difficulty: aiOpponent.difficulty,
            ai: aiOpponent.ai,
            position: positions[i],
          );
          
          aiPlayers.add(updatedAIPlayer);
        }
        
        if (kDebugMode) print('🎮 Starting game with human + ${aiPlayers.length} AI players');
        await gameProvider.startNewGame(humanPlayer, aiPlayers);
        
        // Start AI logging session for data collection
        final loggingProvider = Provider.of<AILoggingProvider>(context, listen: false);
        final gameId = 'game_${DateTime.now().millisecondsSinceEpoch}';
        loggingProvider.startGameSession(gameId);
        if (kDebugMode) print('📊 Started AI logging session: $gameId');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error setting up AI game: $e');
    }
  }

  Future<void> _setupMultiplayerGame(Map<String, dynamic> arguments) async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    
    // Reset any existing game to start fresh with multiplayer
    if (gameProvider.hasActiveGame) {
      if (kDebugMode) print('🎮 Resetting existing game to start new multiplayer game');
      gameProvider.resetGame();
    }
    
    try {
      final multiplayerClient = arguments['multiplayerClient'] as MultiplayerClient?;
      if (multiplayerClient != null) {
        if (kDebugMode) print('🎮 Setting up multiplayer game with server data');
        
        // Get the game state from multiplayer client
        final gameState = multiplayerClient.currentGame;
        if (gameState == null) {
          if (kDebugMode) print('❌ No game state available from multiplayer client');
          return;
        }
        
        // Convert server players to local Player objects
        final localPlayers = <Player>[];
        
        for (final entry in gameState.players.entries) {
          final serverPlayer = entry.value;
          final position = _convertServerPositionToLocal(serverPlayer.position);
          
          final localPlayer = Player(
            id: serverPlayer.id,
            name: serverPlayer.name,
            position: position,
            isBot: serverPlayer.isAI,
          );
          
          localPlayers.add(localPlayer);
          if (kDebugMode) print('🎮 Created player: ${localPlayer.name} at ${position.name} (AI: ${localPlayer.isBot})');
        }
        
        // Verify we have exactly 4 players
        if (localPlayers.length != 4) {
          throw Exception('Invalid number of players: ${localPlayers.length}. Expected 4.');
        }
        
        // Find the current user's player (should be the one at our position)
        final myPosition = multiplayerClient.myPosition;
        Player? currentUserPlayer;
        final otherPlayers = <Player>[];
        
        if (kDebugMode) print('🎮 My position from multiplayer client: "$myPosition"');
        
        for (final player in localPlayers) {
          if (kDebugMode) print('🎮 Checking player: ${player.name} at position "${player.position.name}"');
          if (player.position.name.toLowerCase() == myPosition?.toLowerCase()) {
            currentUserPlayer = player;
            if (kDebugMode) print('🎮 ✅ Found current user player: ${player.name}');
          } else {
            otherPlayers.add(player);
            if (kDebugMode) print('🎮 ➕ Added to other players: ${player.name}');
          }
        }
        
        // If we can't find our player by position, default to south position
        if (currentUserPlayer == null) {
          currentUserPlayer = localPlayers.firstWhere(
            (p) => p.position == PlayerPosition.south,
            orElse: () => localPlayers.first,
          );
          // Remove from other players list
          otherPlayers.removeWhere((p) => p.position == currentUserPlayer!.position);
        }
        
        if (kDebugMode) {
          print('🎮 Current user player: ${currentUserPlayer.name} (${currentUserPlayer.position.name})');
          print('🎮 Other players: ${otherPlayers.map((p) => '${p.name}(${p.position.name})').join(', ')}');
        }
        
        // Create the local game
        await gameProvider.startNewGame(currentUserPlayer, otherPlayers);
        
        // Set up bidirectional sync with server
        _setupMultiplayerSync(gameProvider, multiplayerClient);
        
        if (kDebugMode) print('✅ Multiplayer game created with server sync!');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error setting up multiplayer game: $e');
      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E3A8A),
          title: const Text('Multiplayer Setup Error', style: TextStyle(color: Colors.red)),
          content: Text(
            'Failed to setup multiplayer game: $e',
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Return to lobby
              },
              child: const Text('OK', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
      );
    }
  }
  
  void _setupMultiplayerSync(GameProvider gameProvider, MultiplayerClient multiplayerClient) {
    if (kDebugMode) print('🔄 Setting up bidirectional multiplayer sync');
    
    // Store the multiplayer client reference in the game provider for sending moves
    gameProvider.setMultiplayerClient(multiplayerClient);
    
    // CRITICAL: Immediately sync with current server state
    final currentServerGame = multiplayerClient.currentGame;
    if (currentServerGame != null) {
      if (kDebugMode) print('🔄 IMMEDIATE SYNC with server state');
      gameProvider.syncWithServerGameState(currentServerGame);
    }
    
    // Listen to server game state updates and sync local game
    multiplayerClient.addListener(() {
      final serverGame = multiplayerClient.currentGame;
      if (serverGame != null && gameProvider.hasActiveGame) {
        if (kDebugMode) print('🔄 LISTENER SYNC with server state');
        _syncLocalGameWithServerState(gameProvider, serverGame);
      }
    });
    
    if (kDebugMode) print('✅ Multiplayer sync established');
  }
  
  void _syncLocalGameWithServerState(GameProvider gameProvider, ServerGame serverGame) {
    final localGame = gameProvider.game;
    if (localGame == null) return;
    
    try {
      if (kDebugMode) {
        print('🔄 Syncing local game with server state');
        print('   Server phase: ${serverGame.phase}, Local phase: ${localGame.phase}');
        print('   Server current player: ${serverGame.currentPlayer}, Local current player: ${localGame.currentPlayer}');
      }
      // Sync local game state with server state
      gameProvider.syncWithServerGameState(serverGame);
    } catch (e) {
      if (kDebugMode) print('❌ Error syncing game state: $e');
    }
  }

  Future<void> _setupGameSyncWithServer(
    GameProvider gameProvider, 
    Player currentUserPlayer, 
    List<Player> otherPlayers, 
    ServerGame gameState, 
    MultiplayerClient multiplayerClient
  ) async {
    if (kDebugMode) {
      print('🔄 Setting up game sync with server...');
      print('🎮 Server game phase: ${gameState.phase}');
      print('🎮 Server current player: ${gameState.currentPlayer}');
      print('🎮 Server current contract: ${gameState.currentContract}');
    }
    
    // Create a local game that will be synced with server state
    await gameProvider.startNewGame(currentUserPlayer, otherPlayers);
    
    // Enable multiplayer sync and immediately sync with current server state
    if (gameProvider.hasActiveGame) {
      gameProvider.enableMultiplayerSync(multiplayerClient);
      
      // Convert ServerGame to Map for sync
      final serverStateMap = {
        'phase': gameState.phase,
        'currentPlayer': gameState.currentPlayer,
        'currentContract': gameState.currentContract,
        'currentKing': gameState.currentKing,
        'round': gameState.round,
        'kingdom': gameState.kingdom,
      };
      
      // Sync immediately with current server state
      gameProvider.syncWithServerState(serverStateMap);
      
      if (kDebugMode) {
        print('✅ Game created and synced with server state');
        print('🎮 Local game phase: ${gameProvider.game?.phase}');
        print('🎮 Local current player: ${gameProvider.game?.currentPlayer}');
        print('🎮 Local current king: ${gameProvider.game?.currentKing}');
      }
    }
  }
  
  void _setupServerStateSync(GameProvider gameProvider, MultiplayerClient multiplayerClient) {
    // Listen to game state updates from the multiplayer client
    multiplayerClient.addListener(() {
      final serverGame = multiplayerClient.currentGame;
      if (serverGame != null && gameProvider.hasActiveGame) {
        _syncLocalGameWithServer(gameProvider, serverGame);
      }
    });
    
    // Also sync immediately with current state
    final currentServerGame = multiplayerClient.currentGame;
    if (currentServerGame != null) {
      _syncLocalGameWithServer(gameProvider, currentServerGame);
    }
  }
  
  void _syncLocalGameWithServer(GameProvider gameProvider, ServerGame serverGame) {
    final localGame = gameProvider.game;
    if (localGame == null) return;
    
    try {
      // This is a critical method that needs to sync local game state
      // with server game state without breaking the game logic
      if (kDebugMode) {
        print('🔄 Syncing local game with server state');
        print('   Server phase: ${serverGame.phase}');
        print('   Server current player: ${serverGame.currentPlayer}');
        print('   Server current contract: ${serverGame.currentContract}');
      }
      
      // For now, just log that we need to implement this
      // The proper implementation would update the local game state
      // to match the server state
      
      if (kDebugMode) print('⚠️ Game state sync logic needs full implementation');
      
    } catch (e) {
      if (kDebugMode) print('❌ Error syncing game state: $e');
    }
  }

  PlayerPosition _convertServerPositionToLocal(String serverPosition) {
    switch (serverPosition.toLowerCase()) {
      case 'north':
        return PlayerPosition.north;
      case 'south':
        return PlayerPosition.south;
      case 'east':
        return PlayerPosition.east;
      case 'west':
        return PlayerPosition.west;
      default:
        if (kDebugMode) print('⚠️ Unknown server position: $serverPosition, defaulting to south');
        return PlayerPosition.south;
    }
  }

  /// Check if the game state is valid and fix if needed
  Future<void> _checkAndFixGameState() async {
    if (_isCheckingGameState) return;
    _isCheckingGameState = true;
    
    // Wait a bit to allow game setup to complete
    await Future.delayed(const Duration(milliseconds: 500));
    
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    
    if (!gameProvider.hasActiveGame) {
      if (kDebugMode) {
        print('❌ Game screen loaded but no active game found after delay!');
      }
      
      // Show error dialog only if we're sure there's no game being set up
      if (!gameProvider.isLoading) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Game Error'),
            content: const Text('No active game found. Would you like to return to the home screen?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Return to home screen
                },
                child: const Text('Yes'),
              ),
            ],
          ),
        );
      }
    } else if (kDebugMode) {
      // Debug game state
      print('✅ Game screen loaded with valid game state:');
      print('   Game Kingdom: ${gameProvider.game?.kingdom}');
      print('   Players: ${gameProvider.game?.players.length}');
      print('   Phase: ${gameProvider.game?.phase}');
    }
    
    _isCheckingGameState = false;
  }

  // New layout methods to match the image design
  
  Widget _buildTopBar(BuildContext context, TrexGame game) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          // Menu button
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => _showGameInfo(context),
          ),
          
          // Coins/ID display
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          //   decoration: BoxDecoration(
          //     color: Colors.black.withOpacity(0.5),
          //     borderRadius: BorderRadius.circular(15),
          //   ),
          //   child: Row(
          //     mainAxisSize: MainAxisSize.min,
          //     children: [
          //       const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
          //       const SizedBox(width: 4),
          //       Text(
          //         '${game.players.length}ID',
          //         style: const TextStyle(color: Colors.white, fontSize: 12),
          //       ),
          //     ],
          //   ),
          // ),
          
          // const Spacer(),
          
          // Game title
          const Text(
            'Trix',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const Spacer(),
          
          // Combined Kingdom and Round info on the right
          _buildKingdomAndRoundInfo(game),
          
          // Viewers count
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //   decoration: BoxDecoration(
          //     color: Colors.black.withOpacity(0.5),
          //     borderRadius: BorderRadius.circular(12),
          //   ),
          //   child: Row(
          //     mainAxisSize: MainAxisSize.min,
          //     children: [
          //       const Icon(Icons.visibility, color: Colors.white, size: 16),
          //       const SizedBox(width: 4),
          //       Text(
          //         '4',
          //         style: const TextStyle(color: Colors.white, fontSize: 12),
          //       ),
          //     ],
          //   ),
          // ),
          
          // const SizedBox(width: 8),
          
          // Add friends button
          // IconButton(
          //   icon: const Icon(Icons.person_add, color: Colors.white),
          //   onPressed: () {},
          // ),
          
          // Chat button
          // IconButton(
          //   icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
          //   onPressed: () {},
          // ),
        ],
      ),
    );
  }

  Widget _buildPlayersAroundTable(BuildContext context, TrexGame game) {
    return Stack(
      children: [
        // Top player (North)
        Positioned(
          top: 2,
          left: 0,
          right: 0,
          child: _buildPlayerWithAvatar(
            context,
            game.getPlayerByPosition(PlayerPosition.north),
            game,
            PlayerPosition.north,
          ),
        ),
        
        // Left player (West)
        Positioned(
          left: 0,
          top:75,
          bottom: 0,
          child: Center(
            child: _buildPlayerWithAvatar(
              context,
              game.getPlayerByPosition(PlayerPosition.west),
              game,
              PlayerPosition.west,
            ),
          ),
        ),
        
        // Right player (East) 
        Positioned(
          right: 0, // Right side
          top: 75, 
          bottom: 0,
          child: Center(
            child: _buildPlayerWithAvatar( // East player
              context,
              game.getPlayerByPosition(PlayerPosition.east), // Get East player
              game,
              PlayerPosition.east,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerWithAvatar(BuildContext context, Player player, TrexGame game, PlayerPosition position) {
    final isCurrentPlayer = game.currentPlayer == position;
    final showCards = position != PlayerPosition.south && _showDebugHands; // Show cards only when debug mode is active
    final isAI = player is AIPlayer;
    
    // Debug: Log AI player difficulty
    if (isAI && kDebugMode) {
      print('🤖 [Game Screen] Displaying AI player: ${player.name} with difficulty: ${(player).difficulty.englishName}');
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min, 
      children: [
        // Player info container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2), // Padding for player info
          decoration: BoxDecoration(
            color: isCurrentPlayer 
                ? Colors.green.withOpacity(0.8)  // Highlight current player
                : Colors.black.withOpacity(0.7), // Other players
            borderRadius: BorderRadius.circular(10), // Rounded corners
            border: isCurrentPlayer 
                ? Border.all(color: Colors.orange, width: 2) // Orange border for current player
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min, // Minimize width to fit content
            children: [
              // Crown icon if king
              if (game.currentKing == position)
                const Icon(
                  Icons.emoji_events,
                  color: Colors.amber,
                  size: 16,
                ),
              
              // Player avatar
              // CircleAvatar( // Use CircleAvatar for player avatar
              //   radius: 18,
              //   backgroundColor: Colors.grey[300],
              //   child: Icon(
              //     Icons.person,
              //     color: Colors.grey[600],
              //     size: 20,
              //   ),
              // ),
              
              const SizedBox(width: 4),
              
              // Player name and score
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${player.score}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              
              // AI difficulty indicator for AI players
              // if (isAI) ...[
              //   const SizedBox(width: 4),
              //   AIDifficultyIndicator(
              //     difficulty: (player).difficulty,
              //     isCompact: true,
              //     showIcon: false,
              //     showArabicName: false, // Show English for compact display
              //   ),
              // ],
            ],
          ),
        ),
        
        // Player cards (if not human player)
        if (showCards)
          Container(
            margin: const EdgeInsets.only(top: 8),
            child: _buildPlayerCards(player, position),
          ),
      ],
    );
  }

  Widget _buildPlayerCards(Player player, PlayerPosition position) {
    final cardCount = player.hand.length;
    if (cardCount == 0) return const SizedBox.shrink();
    
    // Determine layout based on position
    final isVertical = position == PlayerPosition.west || position == PlayerPosition.east;
    
    return OptimizedPlayerCardStack(
      cards: player.hand,
      isVertical: isVertical,
      isSmall: true,
    );
  }

  // Removed _buildVerticalCardStack and _buildHorizontalCardStack methods
  // These are now handled by OptimizedPlayerCardStack widget

  Widget _buildCenterGameArea(BuildContext context, TrexGame game) {
    return Center(
      child: SizedBox(
        width: 250,
        height: 850,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Center decoration circle
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 2,
                ),
              ),
            ),
            
            // Game content based on contract
            if (game.currentContract == TrexContract.trex)
              _buildTrexCenterLayout(game)
            else if (game.currentTrick != null && game.currentTrick!.cards.isNotEmpty)
              _buildTrickCards(game.currentTrick!)
            else
              _buildWaitingArea(game),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreIndicators(BuildContext context, TrexGame game) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3), // Background color
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color.fromARGB(255, 239, 4, 4).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Top left - Kingdom/Round info
          Positioned(
            top: 120,
            left: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              // child: Column(
              //   crossAxisAlignment: CrossAxisAlignment.start,
              //   mainAxisSize: MainAxisSize.min,
              //   // children: [
              //   //   // Text(
              //   //   //   'Trix',
              //   //   //   style: const TextStyle(
              //   //   //     color: Colors.white,
              //   //   //     fontSize: 12,
              //   //   //     fontWeight: FontWeight.bold,
              //   //   //   ),
              //   //   // ),
              //   //   // Text(
              //   //   //   'Kingdom ${game.kingdom}',
              //   //   //   style: const TextStyle(
              //   //   //     color: Colors.white70,
              //   //   //     fontSize: 10,
              //   //   //   ),
              //   //   // ),
              //   // ],
              // ),
            ),
          ),
          
          // Corner score indicators for each player
          // ...game.players.map((player) {
          //   return _buildCornerScore(player.position, player.score);
          // }),
        ],
      ),
    );
  }

  Widget _buildCornerScore(PlayerPosition position, int score) {
    Positioned positioned;
    
    switch (position) {
      case PlayerPosition.north:
        positioned = Positioned(
          top: 10,
          right: 100,
          child: _buildScoreChip(score),
        );
        break;
      case PlayerPosition.east:
        positioned = Positioned(
          right: 10,
          top: 210,
          child: _buildScoreChip(score),
        );
        break;
      case PlayerPosition.south:
        positioned = Positioned(
          bottom: 10,
          right: 10,
          child: _buildScoreChip(score),
        );
        break;
      case PlayerPosition.west:
        positioned = Positioned(
          left: 10,
          top: 210,
          child: _buildScoreChip(score),
        );
        break;
    }
    
    return positioned;
  }

  Widget _buildScoreChip(int score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$score',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHumanPlayerArea(BuildContext context, Player player, TrexGame game) {
    return Container(
      height: 170,
      width: MediaQuery.of(context).size.width, //
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(0),
          topRight: Radius.circular(0),
        ),
      ),
      child: Column(
        children: [
          // Player's cards in a fan layout
          Expanded(
            child: _buildHumanPlayerCards(context, player.hand),
          ),
          
          const SizedBox(height: 10),
          
          // Player info bar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Player avatar and info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: game.currentPlayer == PlayerPosition.south 
                      ? Colors.green.withOpacity(0.8)
                      : Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[300],
                      child: Icon(
                        Icons.person,
                        color: Colors.grey[600],
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      player.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 20),
              
              // Score display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Score',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${player.score}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHumanPlayerCards(BuildContext context, List<game_card.Card> cards) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final shouldHighlight = gameProvider.shouldHighlightCards;
        final validCardsCount = shouldHighlight ? gameProvider.getValidCardsForHuman().length : 0;

        return Column(
          children: [
            // Show helpful message when highlighting is active
            if (shouldHighlight)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      validCardsCount > 0
                          ? 'Valid cards highlighted ($validCardsCount available)'
                          : 'No valid moves - pass your turn',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            // Cards
            Expanded(
              child: _buildCardsFanLayout(context, cards),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrexCenterLayout(TrexGame game) {
    // Get played cards for each suit from the trex layout
    final heartsCards = game.trexLayout[game_card.Suit.hearts] ?? [];
    final diamondsCards = game.trexLayout[game_card.Suit.diamonds] ?? [];
    final clubsCards = game.trexLayout[game_card.Suit.clubs] ?? [];
    final spadesCards = game.trexLayout[game_card.Suit.spades] ?? [];

    return SizedBox(
      width: 300,  // Increased width to fix overflow
      height: 280, // BIGGER HEIGHT - WAS 300, NOW 600 FOR MORE CARD SPACE
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(child: _buildTrexSequenceColumn(heartsCards, game_card.Suit.hearts, 60)),
          Flexible(child: _buildTrexSequenceColumn(diamondsCards, game_card.Suit.diamonds, 60)),
          Flexible(child: _buildTrexSequenceColumn(clubsCards, game_card.Suit.clubs, 60)),
          Flexible(child: _buildTrexSequenceColumn(spadesCards, game_card.Suit.spades, 60)),
        ],
      ),
    );
  }

  Widget _buildTrickCards(Trick trick) {
    return Stack(
      alignment: Alignment.center,
      children: trick.cards.entries.map((entry) {
        final position = entry.key;
        final card = entry.value;
        
        Offset offset;
        switch (position) {
          case PlayerPosition.north:
            offset = const Offset(0, -50);
            break;
          case PlayerPosition.east:
            offset = const Offset(40, 0);
            break;
          case PlayerPosition.south:
            offset = const Offset(0, 50);
            break;
          case PlayerPosition.west:
            offset = const Offset(-40, 0);
            break;
        }
        
        return Transform.translate(
          offset: offset,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: PlayingCardWidget(
              card: card,
              isSmall: false,
              useCardImages: true,
              isCompact: false,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWaitingArea(TrexGame game) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _getPhaseIcon(game.phase),
          color: Colors.white.withOpacity(0.7),
          size: 40,
        ),
        const SizedBox(height: 8),
        Text(
          _getPhaseText(game.phase),
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  IconData _getPhaseIcon(GamePhase phase) {
    switch (phase) {
      case GamePhase.contractSelection:
        return Icons.gavel;
      case GamePhase.playing:
        return Icons.play_arrow;
      case GamePhase.roundEnd:
        return Icons.stop;
      case GamePhase.gameEnd:
        return Icons.emoji_events;
      default:
        return Icons.hourglass_empty;
    }
  }

  String _getPhaseText(GamePhase phase) {
    switch (phase) {
      case GamePhase.contractSelection:
        return 'Contract Selection';
      case GamePhase.playing:
        return 'Playing';
      case GamePhase.roundEnd:
        return 'Round End';
      case GamePhase.gameEnd:
        return 'Game End';
      default:
        return 'Waiting...';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        appBar: AppBar(
          title: const Text('Trix - The Original Game'),
          backgroundColor: const Color(0xFF0D1B2A),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            // Show/Hide AI Cards button - always available
            IconButton(
              icon: Icon(
                _showDebugHands ? Icons.visibility_off : Icons.visibility,
                color: _showDebugHands ? Colors.orange : Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _showDebugHands = !_showDebugHands;
                });
              },
              tooltip: _showDebugHands ? 'Hide AI Cards' : 'Show AI Cards',
            ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _showGameInfo(context),
            ),
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: () => _confirmExitGame(context),
            ),
          ],
        ),
        body: Consumer<GameProvider>(
          builder: (context, gameProvider, child) {
            if (gameProvider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            if (!gameProvider.hasActiveGame) {
              return const Center(
                child: Text(
                  'No Active Game',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              );
            }

            final game = gameProvider.game!;
            final currentUser = gameProvider.currentUser!;

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A), // Dark background like in the image
              ),
              child: SafeArea(
                child: Stack(
                  children: [
                    // Main game layout
                    Column(
                      children: [
                        // Top bar with menu, coins, viewers, etc.
                        _buildTopBar(context, game),
                        
                        // Main game area
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(0),
                            decoration: BoxDecoration(
                              // Green felt table background
                              gradient: const RadialGradient(
                                center: Alignment.center,
                                radius: 1.2,
                                colors: [
                                  Color(0xFF4CAF50), // Brighter green in center
                                  Color(0xFF2E7D32), // Darker green on edges
                                ],
                              ),
                              borderRadius: BorderRadius.circular(0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Four players positioned around the table
                                _buildPlayersAroundTable(context, game),
                                
                                // Center game area (cards/tricks)
                                _buildCenterGameArea(context, game),
                                
                                // Score indicators on the corners
                                // _buildScoreIndicators(context, game), // DISABLED
                              ],
                            ),
                          ),
                        ),
                        
                        // Bottom player area (human player)
                        _buildHumanPlayerArea(context, currentUser, game),
                      ],
                    ),

                    // Floating UI elements and overlays
                    _buildFloatingElements(context, game, gameProvider),

                    // Debug overlay - show AI cards info
                    if (_showDebugHands)
                      _buildDebugOverlay(context, game),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Widget _buildKingdomInfo(TrexGame game) {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  //     decoration: BoxDecoration(
  //       color: const Color.fromARGB(255, 240, 1, 1).withOpacity(0.7),
  //       borderRadius: BorderRadius.circular(12),
  //     ),
  //     child: Column(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         const Icon(
  //           Icons.castle,
  //           color: Color.fromARGB(255, 255, 254, 253),
  //           size: 16,
  //         ),
  //         const SizedBox(height: 2),
  //         Text(
  //           'Kingdom ${game.kingdom}',
  //           style: const TextStyle(
  //             color: Colors.white,
  //             fontSize: 10,
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //         Text(
  //           '${game.usedContracts.length}/5',
  //           style: const TextStyle(
  //             color: Colors.white70,
  //             fontSize: 8,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Combined Kingdom and Round info widget
  Widget _buildKingdomAndRoundInfo(TrexGame game) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      constraints: const BoxConstraints(maxHeight: 50), // Prevent overflow
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 0, 0).withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Kingdom info
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.castle,
                color: Colors.orange,
                size: 12,
              ),
              const SizedBox(width: 3),
              Text(
                'Kingdom ${game.kingdom}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                '${game.usedContracts.length}/5',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                ),
              ),
            ],
          ),
          // Round info with contract name - make it more compact
          Flexible(
            child: Text(
              'R${game.round} - ${game.currentContract?.arabicName ?? "No Contract"}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 8,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPlayer(BuildContext context, Player player, TrexGame game) {
    return Column(
      children: [
        // Player info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: game.currentPlayer == player.position 
                ? Colors.orange 
                : Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: Colors.grey[300],
                child: Text(
                  player.name[0],
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${player.score}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Cards (face down)
        _buildCardStack(player.hand.length, isHorizontal: true),
      ],
    );
  }

  Widget _buildBottomPlayer(BuildContext context, Player player, TrexGame game) {
    return Column(
      children: [
        // Player cards (face up) - Fan layout like Tarneeb
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _buildCardsFanLayout(context, player.hand),
          ),
        ),
        // Player info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: game.currentPlayer == player.position 
                ? Colors.orange 
                : Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: Colors.grey[300],
                child: Text(
                  player.name[0],
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${player.score}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardsFanLayout(BuildContext context, List<game_card.Card> cards) {
    return OptimizedCardFan(
      cards: cards,
      onCardTap: (card) => _playCard(context, card),
      isCardPlayable: (card) => _isCardPlayable(context, card),
      cardWidth: 48.0,
      overlap: 23.0,
      useCardImages: true,
      isCompact: false,
    );
  }

  double _calculateCardRotation(int index, int totalCards, double maxRotation) {
    if (totalCards == 1) return 0.0;
    
    // Create a fan spread with configurable max rotation
    final double rotationStep = (2 * maxRotation) / (totalCards - 1);
    return -maxRotation + (index * rotationStep);
  }

  double _calculateCardVerticalOffset(int index, int totalCards, bool isPortrait) {
    if (totalCards == 1) return 0.0;
    
    // Create a slight curve - center cards are slightly higher
    final double centerIndex = (totalCards - 1) / 2;
    final double distanceFromCenter = (index - centerIndex).abs();
    final double maxOffset = isPortrait ? 6.0 : 8.0; // Less curve in portrait
    
    // Parabolic curve - cards at edges are lower
    final double normalizedDistance = distanceFromCenter / (totalCards / 2);
    return maxOffset * normalizedDistance * normalizedDistance;
  }

  Widget _buildSidePlayer(BuildContext context, Player player, TrexGame game, {required bool isLeft}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Player info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: game.currentPlayer == player.position 
                ? Colors.orange 
                : Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[300],
                child: Text(
                  player.name[0],
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                player.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                '${player.score}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Cards (vertical stack)
        _buildCardStack(player.hand.length, isHorizontal: false),
      ],
    );
  }

  Widget _buildCardStack(int cardCount, {required bool isHorizontal}) {
    if (cardCount == 0) return const SizedBox.shrink();

    final maxCards = cardCount.clamp(0, 5); // Show max 5 cards in stack
    final stackWidth = isHorizontal ? (40.0 + (maxCards - 1) * 2.0) : 30.0;
    final stackHeight = isHorizontal ? 30.0 : (40.0 + (maxCards - 1) * 2.0);

    return SizedBox(
      width: stackWidth,
      height: stackHeight,
      child: Stack(
        children: List.generate(
          maxCards,
          (index) {
            final offset = index * 2.0;
            return Positioned(
              left: isHorizontal ? offset : 0,
              top: isHorizontal ? 0 : offset,
              child: Container(
                width: isHorizontal ? 40 : 30,
                height: isHorizontal ? 30 : 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white, width: 0.5),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGameCenter(BuildContext context, TrexGame game) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Kingdom and Contract info
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  'Kingdom ${game.kingdom}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'King: ${game.currentKing.arabicName}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                  ),
                ),
                if (game.currentContract != null)
                  Text(
                    game.currentContract!.arabicName,
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Playing area - different for Trex vs other contracts
          if (game.currentContract == TrexContract.trex)
            _buildTrexLayout(game)
          else if (game.currentContract != null)
            _buildTrickArea(game)
          else
            _buildContractSelectionArea(),

          const SizedBox(height: 20),

          // Round and phase info
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'Round ${game.round}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                Text(
                  game.phase.arabicName,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContractSelectionArea() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.gavel,
            color: Colors.orange,
            size: 40,
          ),
          SizedBox(height: 8),
          Text(
            'Contract Selection',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Waiting for the king to select a contract',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrexLayout(TrexGame game) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate available width and make layout responsive
        final availableWidth = constraints.maxWidth - 40; // Account for padding
        final columnWidth = (availableWidth / 4).clamp(60.0, 90.0);
        
        return Container(
          width: double.infinity,
          height: 180,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.transparent, // Transparent to show green table
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Hearts column
              Expanded(
                child: _buildTrexSequenceColumn(
                  game.trexLayout[game_card.Suit.hearts] ?? [],
                  game_card.Suit.hearts,
                  columnWidth,
                ),
              ),
              // Diamonds column  
              Expanded(
                child: _buildTrexSequenceColumn(
                  game.trexLayout[game_card.Suit.diamonds] ?? [],
                  game_card.Suit.diamonds,
                  columnWidth,
                ),
              ),
              // Clubs column
              Expanded(
                child: _buildTrexSequenceColumn(
                  game.trexLayout[game_card.Suit.clubs] ?? [],
                  game_card.Suit.clubs,
                  columnWidth,
                ),
              ),
              // Spades column
              Expanded(
                child: _buildTrexSequenceColumn(
                  game.trexLayout[game_card.Suit.spades] ?? [],
                  game_card.Suit.spades,
                  columnWidth,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrexSequenceColumn(List<game_card.Card> cards, game_card.Suit suit, double columnWidth) {
    if (cards.isEmpty) {
      // Show placeholder for empty suit
      return SizedBox(
        width: columnWidth,
        height: 190,
        child: Center(
          child: Container(
            width: (columnWidth * 0.8).clamp(50.0, 60.0),
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getSuitIcon(suit),
                  color: _getSuitColor(suit).withOpacity(0.7),
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  'J',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Sort cards by rank value for proper sequence display
    // We want to display from Ace (top) down to 2 (bottom) with overlapping
    List<game_card.Card> sortedCards = List.from(cards);
    
    // Sort in descending order to display Ace at top, then King, Queen, Jack, etc.
    sortedCards.sort((a, b) => b.rank.value.compareTo(a.rank.value));

    List<Widget> displayElements = [];
    
    final double cardScale = (columnWidth / 90.0).clamp(0.65, 0.85);
    const double cardOverlap = 15.0; // How much cards overlap vertically
    const double startTop = 10.0; // Starting position from top
    
    // Display all cards with overlapping from top to bottom
    for (int i = 0; i < sortedCards.length; i++) {
      final card = sortedCards[i];
      final double topPosition = startTop + (i * cardOverlap);
      
      displayElements.add(
        Positioned(
          top: topPosition,
          child: Transform.scale(
            scale: cardScale,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: PlayingCardWidget(
                card: card,
                isSmall: false,
                useCardImages: true,
                isCompact: false,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: columnWidth,
      height: 500,
      child: Stack(
        alignment: Alignment.center,
        children: displayElements,
      ),
    );
  }

  Widget _buildTrickArea(TrexGame game) {
    // Show only current trick cards in the center
    if (game.currentTrick == null || game.currentTrick!.cards.isEmpty) {
      return SizedBox(
        width: 150,
        height: 150,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                game.currentContract != null 
                    ? _getContractIcon(game.currentContract!) 
                    : Icons.control_point,
                color: Colors.white30,
                size: 30,
              ),
            ),
          ],
        ),
      );
    }
    
    // Show current trick cards positioned around center
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Center decoration
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              game.currentContract != null 
                  ? _getContractIcon(game.currentContract!) 
                  : Icons.control_point,
              color: Colors.white30,
              size: 30,
            ),
          ),
          
          // Current trick cards positioned around center
          ..._buildCurrentTrickCards(game.currentTrick!),
        ],
      ),
    );
  }
  
  List<Widget> _buildCurrentTrickCards(Trick trick) {
    return trick.cards.entries.map((entry) {
      final position = entry.key;
      final card = entry.value;

      // Positioning cards around the center
      Offset offset;
      switch (position) {
        case PlayerPosition.north:
          offset = const Offset(0, -60); // Top
          break;
        case PlayerPosition.east:
          offset = const Offset(50, 0); // Right
          break;
        case PlayerPosition.south:
          offset = const Offset(0, 60); // Bottom
          break;
        case PlayerPosition.west:
          offset = const Offset(-50, 0); // Left
          break;
      }

      return Transform.translate(
        offset: offset,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: PlayingCardWidget(
            card: card,
            isSmall: false,
            useCardImages: true,
            isCompact: false,
          ),
        ),
      );
    }).toList();
  }
  
  Widget _buildFloatingElements(BuildContext context, TrexGame game, GameProvider gameProvider) {
    // Get the current user's position (for multiplayer)
    final multiplayerClient = Provider.of<MultiplayerClient?>(context, listen: false);
    final myPosition = multiplayerClient?.myPosition != null
        ? PlayerPosition.values.firstWhere(
            (p) => p.name.toLowerCase() == multiplayerClient!.myPosition!.toLowerCase(),
            orElse: () => PlayerPosition.south)
        : PlayerPosition.south;

    return Stack(
      children: [
        // Kingdom info widget removed

        // Contract selection widget
        if (game.phase == GamePhase.contractSelection && 
            game.currentPlayer == myPosition)
          Positioned(
            bottom: 250,
            left: 20,
            right: 20,
            child: ContractSelectionWidget(
              onContractSelected: (contract) => gameProvider.selectContract(contract),
              availableContracts: game.availableContracts,
              currentKing: game.currentKing,
            ),
          ),

        // Pass button for Trex when no valid moves
        if (gameProvider.canHumanPlayerPass)
          Positioned(
            bottom: 200,
            left: 20,
            right: 20,
            child: Center(
              child: ElevatedButton(
                onPressed: () => gameProvider.passTrexTurn(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 5,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.skip_next, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Pass Turn - No Valid Moves',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // King of Hearts doubling option
        if (game.currentContract == TrexContract.kingOfHearts &&
            game.kingOfHeartsHolder == PlayerPosition.south &&
            !game.isKingOfHeartsDoubled &&
            game.phase == GamePhase.playing)
          Positioned(
            top: 100,
            right: 20,
            child: ElevatedButton(
              onPressed: () => gameProvider.doubleKingOfHearts(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Double King of Hearts'),
            ),
          ),

        // Top right - Last completed trick
        if (game.lastCompletedTrick != null)
          Positioned(
            top: 113,
            right: 0,
            child: _buildLastTrickDisplay(game.lastCompletedTrick!),
          ),

        // Score indicators
        Positioned(
          top: 60,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${game.getPlayerByPosition(PlayerPosition.south).score}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Points',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Last played round info widget removed
      ],
    );
  }

  // Helper methods for suit icons and colors
  IconData _getSuitIcon(game_card.Suit suit) {
    switch (suit) {
      case game_card.Suit.hearts:
        return Icons.favorite;
      case game_card.Suit.diamonds:
        return Icons.diamond;
      case game_card.Suit.clubs:
        return Icons.eco;
      case game_card.Suit.spades:
        return Icons.spa;
    }
  }

  Color _getSuitColor(game_card.Suit suit) {
    switch (suit) {
      case game_card.Suit.hearts:
      case game_card.Suit.diamonds:
        return Colors.red;
      case game_card.Suit.clubs:
      case game_card.Suit.spades:
        return Colors.black;
    }
  }

  IconData _getContractIcon(TrexContract contract) {
    switch (contract) {
      case TrexContract.kingOfHearts:
        return Icons.favorite;
      case TrexContract.queens:
        return Icons.face;
      case TrexContract.diamonds:
        return Icons.diamond;
      case TrexContract.collections:
        return Icons.collections;
      case TrexContract.trex:
        return Icons.star;
    }
  }

  void _playCard(BuildContext context, game_card.Card card) {
    if (!_isCardPlayable(context, card)) return;
    
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final loggingProvider = Provider.of<AILoggingProvider>(context, listen: false);
    
    // Log the human player's card play for AI training
    _logHumanCardPlay(loggingProvider, gameProvider, card);
    
    gameProvider.playCard(card);
  }

  Future<void> _logHumanCardPlay(AILoggingProvider loggingProvider, GameProvider gameProvider, game_card.Card card) async {
    if (!loggingProvider.isEnabled) return;
    
    final game = gameProvider.game;
    if (game == null) return;
    
    try {
      // Create a unique context ID for this decision
      final contextId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Convert current trick cards to CardPlay objects
      final cardsPlayedInTrick = <CardPlay>[];
      if (game.currentTrick != null) {
        var position = 0;
        for (var entry in game.currentTrick!.cards.entries) {
          cardsPlayedInTrick.add(CardPlay(
            playerId: entry.key.name,
            card: entry.value,
            position: position++,
            timestamp: DateTime.now(),
          ));
        }
      }
      
      // Get leading suit
      String? leadingSuit;
      if (game.currentTrick != null && game.currentTrick!.cards.isNotEmpty) {
        final leadCard = game.currentTrick!.cards.values.first;
        leadingSuit = leadCard.suit.name;
      }
      
      // Get current contract name for kingdom
      String kingdom = 'unknown';
      if (game.currentContract != null) {
        kingdom = game.currentContract!.name;
      }
      
      // Log the game context before the decision
      await loggingProvider.logGameContext(
        kingdom: kingdom,
        round: game.round,
        currentTrickNumber: game.tricks.length + 1,
        leadingSuit: leadingSuit,
        cardsPlayedInTrick: cardsPlayedInTrick,
        playerHand: gameProvider.currentUser?.hand ?? [],
        gameScore: {
          'south': game.players.firstWhere((p) => p.position == PlayerPosition.south).score,
          'north': game.players.firstWhere((p) => p.position == PlayerPosition.north).score,
          'east': game.players.firstWhere((p) => p.position == PlayerPosition.east).score,
          'west': game.players.firstWhere((p) => p.position == PlayerPosition.west).score,
        },
        availableCards: gameProvider.currentUser?.hand.where((c) => _isCardPlayable(context, c)).toList() ?? [],
        currentPlayer: 'human',
        playerOrder: ['south', 'east', 'north', 'west'],
      );
      
      // Log the human player's decision
      await loggingProvider.logCardPlay(
        gameContextId: contextId,
        playerId: 'human_player',
        cardPlayed: card,
      );
      
      print('📊 Logged human card play: ${card.toString()} for AI training');
      
    } catch (e) {
      print('❌ Error logging card play: $e');
    }
  }

  bool _isCardPlayable(BuildContext context, game_card.Card card) {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final game = gameProvider.game;
    final multiplayerClient = Provider.of<MultiplayerClient?>(context, listen: false);
    final myPosition = multiplayerClient?.myPosition != null
        ? PlayerPosition.values.firstWhere(
            (p) => p.name.toLowerCase() == multiplayerClient!.myPosition!.toLowerCase(),
            orElse: () => PlayerPosition.south)
        : PlayerPosition.south;

    if (game == null || game.phase != GamePhase.playing) return false;
    if (game.currentPlayer != myPosition) return false;

    // Check playability based on contract type
    if (game.currentContract == TrexContract.trex) {
      return game.canPlayTrexCard(card);
    } else {
      final currentUser = gameProvider.currentUser!;
      return game.isValidTrickPlay(currentUser, card);
    }
  }

  void _showGameInfo(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final game = gameProvider.game;
    
    if (game == null) return;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('Game Information'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kingdom: ${game.kingdom}/4'),
              Text('Round: ${game.round}'),
              Text('Phase: ${game.phase.arabicName}'),
              Text('Current King: ${game.currentKing.arabicName}'),
              if (game.currentContract != null)
                Text('Contract: ${game.currentContract!.arabicName}'),
              const SizedBox(height: 16),
              const Text('Scores:'),
              ...game.players.map((player) => Text(
                '${player.name}: ${player.score}',
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmExitGame(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('Exit Game'),
          content: const Text('Do you really want to exit the game?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close game screen
                final gameProvider = Provider.of<GameProvider>(context, listen: false);
                gameProvider.resetGame();
              },
              child: const Text('Exit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsInfo(Player player) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${player.score}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Points',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastTrickDisplay(Trick trick) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Last Trick',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: trick.cards.values.map((card) => 
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                child: Transform.scale(
                  scale: 1,
                  child: PlayingCardWidget(
                    card: card,
                    isSmall: true,
                    useCardImages: true,
                    isCompact: true,
                  ),
                ),
              ),
            ).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugOverlay(BuildContext context, TrexGame game) {
    if (!_showDebugHands) return const SizedBox.shrink();
    
    return Positioned(
      top: 100,
      right: 10,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'DEBUG: AI Hand Info',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'AI cards now visible on table!',
              style: TextStyle(
                color: Colors.yellow,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            ...game.players.where((p) => p.position != PlayerPosition.south).map((player) {
              final handSummary = _getHandSummary(player.hand);
              return Container(
                margin: const EdgeInsets.only(bottom: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${player.name}: ${player.hand.length} cards',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      handSummary,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getHandSummary(List<game_card.Card> hand) {
    final suits = <String, int>{
      '♥️': 0, '♦️': 0, '♣️': 0, '♠️': 0
    };
    
    for (final card in hand) {
      switch (card.suit) {
        case game_card.Suit.hearts:
          suits['♥️'] = suits['♥️']! + 1;
          break;
        case game_card.Suit.diamonds:
          suits['♦️'] = suits['♦️']! + 1;
          break;
        case game_card.Suit.clubs:
          suits['♣️'] = suits['♣️']! + 1;
          break;
        case game_card.Suit.spades:
          suits['♠️'] = suits['♠️']! + 1;
          break;
      }
    }
    
    return '♥️${suits['♥️']} ♦️${suits['♦️']} ♣️${suits['♣️']} ♠️${suits['♠️']}';
  }

  // Missing helper method for Trex game
  game_card.Rank _getNextPlayableRank(game_card.Rank currentRank) {
    switch (currentRank) {
      case game_card.Rank.jack:
        return game_card.Rank.queen;
      case game_card.Rank.queen:
        return game_card.Rank.king;
      case game_card.Rank.king:
        return game_card.Rank.ace;
      case game_card.Rank.ace:
        return game_card.Rank.jack; // Sequence complete, return invalid
      default:
        return game_card.Rank.jack; // Should not happen in Trex
    }
  }
}