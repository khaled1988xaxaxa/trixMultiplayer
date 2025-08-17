import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/ai_provider.dart';
import '../models/player.dart'; // Import the Player model
import '../multiplayer_v2/screens/lobby_screen.dart';
import 'game_screen.dart';
import 'ai_settings_screen.dart';
import 'api_test_screen.dart';
import 'ai_logging_test_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _playerNameController = TextEditingController(text: 'Player'); // Add default for testing
  bool _isStartingGame = false; // Ensure this is false initially

  @override
  void initState() {
    super.initState();
    // Ensure the starting game flag is reset
    _isStartingGame = false;
    print('🏠 HomeScreen initialized: _isStartingGame = $_isStartingGame');
  }

  @override
  void dispose() {
    _playerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr, // Changed to left-to-right for English
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.analytics, color: Colors.green),
              onPressed: () {
                Navigator.of(context).pushNamed('/logging_settings');
              },
              tooltip: 'Training Data Settings',
            ),
            IconButton(
              icon: const Icon(Icons.smart_toy, color: Colors.orange),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AISettingsScreen(),
                  ),
                );
              },
              tooltip: 'AI Settings',
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0D1B2A),
                Color(0xFF1E3A8A),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  
                  // Game Logo/Title - Made more compact
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.casino,
                          size: 50,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'TRIX',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'The Classic Card Game',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[300],
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.03),

                  // Player name input - Made more compact
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Enter Your Name',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _playerNameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Player Name',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(
                              Icons.person,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.025),

                  // Start Game Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        print('🏠 Start New Game button pressed - checking state...');
                        print('🏠 _isStartingGame = $_isStartingGame');
                        if (kDebugMode) {
                          print('🏠 Start New Game button pressed! _isStartingGame: $_isStartingGame');
                        }
                        if (!_isStartingGame) {
                          print('🏠 About to call _startNewGame method...');
                          _startNewGame(context);
                          print('🏠 _startNewGame method call completed.');
                        } else {
                          print('🏠 Game is already starting, ignoring button press.');
                        }
                      },
                      icon: _isStartingGame 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow, size: 20),
                      label: Text(
                        _isStartingGame ? 'Creating Game...' : 'Start New Game',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                      ),
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.015),

                  // Test Button (for debugging)
                  if (kDebugMode)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _testButtonClick,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('🧪 Test Button Click'),
                      ),
                    ),

                  if (kDebugMode)
                    SizedBox(height: MediaQuery.of(context).size.height * 0.015),

                  // AI Game Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/ai-game-setup');
                      },
                      icon: const Icon(Icons.smart_toy, size: 20),
                      label: const Text(
                        'Play vs AI',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                      ),
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.015),

                  // Multiplayer Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MultiplayerLobbyScreenV2(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.people, size: 20),
                      label: const Text(
                        'Multiplayer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                      ),
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.015),

                  // Game Rules Button
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: OutlinedButton.icon(
                      onPressed: _showGameRules,
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: const Text(
                        'Game Rules',
                        style: TextStyle(fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),

                  // AI Settings Button
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AISettingsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.smart_toy, size: 18),
                      label: const Text(
                        'AI Settings',
                        style: TextStyle(fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),

                  // Training Data Settings Button
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/logging_settings');
                      },
                      icon: const Icon(Icons.analytics, size: 18),
                      label: const Text(
                        'Training Data & Logging',
                        style: TextStyle(fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),

                  // AI Data Logging Test Button (Debug Mode Only)
                  if (kDebugMode) 
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const AILoggingTestScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.memory, size: 18),
                        label: const Text(
                          'AI Logging Test',
                          style: TextStyle(fontSize: 14),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),

                  if (kDebugMode)
                    SizedBox(height: MediaQuery.of(context).size.height * 0.01),

                  // API Connection Test Button (Debug Mode Only)
                  if (kDebugMode) 
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const APITestScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.speed, size: 18),
                            label: const Text(
                              'Test API Speed',
                              style: TextStyle(fontSize: 14),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: const BorderSide(color: Colors.blue, width: 1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                      ],
                    ),

                  // Footer info - Made more compact and flexible
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Made with ❤️ for card game lovers',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startNewGame(BuildContext context) async {
    print('🎬 [HomeScreen] _startNewGame method called at the very beginning!');
    print('🎬 [HomeScreen] _startNewGame called.');
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final aiProvider = Provider.of<AIProvider>(context, listen: false);
    final playerName = _playerNameController.text.trim();

    print('🎬 [HomeScreen] Provider instances obtained: gameProvider=${gameProvider != null}, aiProvider=${aiProvider != null}');
    print('🎬 [HomeScreen] Player name: "$playerName"');

    if (playerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    try {
      print('🤖 [HomeScreen] Creating AI players from provider...');
      // Use the AIProvider to create opponents
      final aiPlayers = await aiProvider.createAIOpponents(opponentCount: 3);
      
      if (aiPlayers.length < 3) {
        print('❌ [HomeScreen] Not enough AI players created!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Not enough AI players available to start the game.')),
        );
        return;
      }
      
      print('🤖 [HomeScreen] AI players selected: ${aiPlayers.map((p) => p.name).toList()}');

      final humanPlayer = Player(id: 'human', name: playerName, isBot: false, position: PlayerPosition.south);
      print('👨 [HomeScreen] Human player created: ${humanPlayer.name}');

      print('🚀 [HomeScreen] Calling GameProvider.startNewGame...');
      print('   - Human Player: ${humanPlayer.name} (${humanPlayer.position.name})');
      print('   - AI Players: ${aiPlayers.map((p) => '${p.name} (${p.position.name})').join(', ')}');
      
      setState(() {
        _isStartingGame = true;
      });
      
      try {
        await gameProvider.startNewGame(humanPlayer, aiPlayers);
        print('✅ [HomeScreen] GameProvider.startNewGame finished successfully.');
      } catch (e, s) {
        print('❌ [HomeScreen] GameProvider.startNewGame failed: $e');
        print('   Stack trace: $s');
        rethrow;
      } finally {
        setState(() {
          _isStartingGame = false;
        });
      }

      // On success, navigate to the game screen
      if (gameProvider.hasActiveGame) {
        print('🎉 [HomeScreen] Game started! Navigating to GameScreen...');
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GameScreen()),
        );
      } else {
        print('🤔 [HomeScreen] Game did not start, staying on HomeScreen.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start the game. Please try again.')),
        );
      }
    } catch (e, s) {
      print('❌ [HomeScreen] Error in _startNewGame: $e');
      print('📄 [HomeScreen] Stack trace: $s');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  void _showGameRules() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.ltr,
        child: AlertDialog(
          title: const Text('Trix Game Rules'),
          content: const SingleChildScrollView(
            child: Text(
              '''Trix is a popular card game played with 4 players using a standard 52-card deck.

Objective:
The goal is to score the most points across different rounds.

How to Play:
• Each player receives 13 cards
• Each round starts with a bidding phase
• The player who wins the bid chooses the game type

Game Types:
1. King of Hearts: Avoid taking the King of Hearts (-75 points)
2. Queens: Avoid taking Queens (-25 points each)
3. Diamonds: Avoid taking Diamonds (-10 points each)
4. Collections: Avoid taking tricks (-15 points per trick)
5. Trex: Get rid of your cards first (+200 for first place)

Kingdom System:
• The game consists of 4 kingdoms
• Each kingdom has 5 rounds (one for each contract type)
• The player with the highest total score wins

Special Rules:
• In King of Hearts, the holder can double the penalty
• In Trex, build sequences starting with Jacks
• Follow suit when possible in trick-taking games

Points are awarded/deducted based on the contract type and performance.''',
              style: TextStyle(fontSize: 14),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }

  void _testButtonClick() {
    if (kDebugMode) {
      print('🧪 TEST BUTTON CLICKED!');
      
      // Test direct navigation to GameScreen
      print('🧪 Testing direct navigation to GameScreen...');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const GameScreen()),
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test button works!')),
    );
  }
}