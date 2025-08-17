import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_logging_provider.dart';
import '../models/game_log_models.dart';
import '../models/card.dart' as game_card;

/// Simple test screen to demonstrate AI logging functionality
class AILoggingTestScreen extends StatefulWidget {
  const AILoggingTestScreen({super.key});

  @override
  State<AILoggingTestScreen> createState() => _AILoggingTestScreenState();
}

class _AILoggingTestScreenState extends State<AILoggingTestScreen> {
  final List<String> _logMessages = [];
  bool _isLoggingEnabled = false;
  
  @override
  void initState() {
    super.initState();
    _initializeLogging();
  }

  Future<void> _initializeLogging() async {
    final loggingProvider = context.read<AILoggingProvider>();
    await loggingProvider.initialize();
    
    setState(() {
      _isLoggingEnabled = loggingProvider.isEnabled;
      _logMessages.add('AI Logging Provider initialized');
    });
    
    // Show consent dialog if needed
    if (loggingProvider.shouldShowConsentDialog() && mounted) {
      _showConsentDialog();
    }
  }

  void _showConsentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Data Collection'),
        content: const Text(
          'Would you like to help improve the AI by sharing your gameplay data?\n\n'
          'This data is anonymous and helps make the AI opponents more challenging.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _setConsent(false);
            },
            child: const Text('No, Thanks'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _setConsent(true);
            },
            child: const Text('Yes, Help Improve AI'),
          ),
        ],
      ),
    );
  }

  Future<void> _setConsent(bool consent) async {
    final loggingProvider = context.read<AILoggingProvider>();
    await loggingProvider.setUserConsent(consent);
    
    setState(() {
      _isLoggingEnabled = loggingProvider.isEnabled;
      _logMessages.add(consent ? 'User gave consent ✅' : 'User declined consent ❌');
    });
  }

  Future<void> _testGameSession() async {
    final loggingProvider = context.read<AILoggingProvider>();
    
    if (!loggingProvider.isEnabled) {
      setState(() {
        _logMessages.add('❌ Logging not enabled - cannot test game session');
      });
      return;
    }

    try {
      // Start a test game session
      loggingProvider.startGameSession('test-game-${DateTime.now().millisecondsSinceEpoch}');
      setState(() {
        _logMessages.add('🎮 Started test game session');
      });

      // Create test game context
      final contextId = await _logTestGameContext(loggingProvider);
      if (contextId != null) {
        setState(() {
          _logMessages.add('📊 Logged game context: ${contextId.substring(0, 8)}...');
        });

        // Log test player decision
        await _logTestPlayerDecision(loggingProvider, contextId);
        setState(() {
          _logMessages.add('🎯 Logged player decision');
        });
      }

      // End the test session
      loggingProvider.endGameSession();
      setState(() {
        _logMessages.add('🏁 Ended test game session');
      });

    } catch (e) {
      setState(() {
        _logMessages.add('❌ Error during test: $e');
      });
    }
  }

  Future<String?> _logTestGameContext(AILoggingProvider provider) async {
    try {
      // Create test cards
      final testHand = [
        const game_card.Card(suit: game_card.Suit.hearts, rank: game_card.Rank.ace),
        const game_card.Card(suit: game_card.Suit.diamonds, rank: game_card.Rank.king),
        const game_card.Card(suit: game_card.Suit.clubs, rank: game_card.Rank.queen),
      ];

      final testAvailableCards = [
        const game_card.Card(suit: game_card.Suit.hearts, rank: game_card.Rank.ace),
        const game_card.Card(suit: game_card.Suit.diamonds, rank: game_card.Rank.king),
      ];

      final testCardsInTrick = [
        CardPlay(
          playerId: 'ai_1',
          card: const game_card.Card(suit: game_card.Suit.spades, rank: game_card.Rank.jack),
          position: 1,
          timestamp: DateTime.now(),
        ),
      ];

      // Log game context
      await provider.logGameContext(
        kingdom: 'hearts',
        round: 1,
        currentTrickNumber: 3,
        leadingSuit: 'spades',
        cardsPlayedInTrick: testCardsInTrick,
        playerHand: testHand,
        gameScore: {
          'human': 50,
          'ai_1': 30,
          'ai_2': 40,
          'ai_3': 35,
        },
        availableCards: testAvailableCards,
        currentPlayer: 'human',
        playerOrder: ['human', 'ai_1', 'ai_2', 'ai_3'],
      );

      return 'test-context-${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      print('Error logging test game context: $e');
      return null;
    }
  }

  Future<void> _logTestPlayerDecision(AILoggingProvider provider, String contextId) async {
    try {
      // Create test AI recommendation
      final aiRecommendation = AIRecommendation(
        recommendedCard: const game_card.Card(suit: game_card.Suit.hearts, rank: game_card.Rank.ace),
        confidence: 0.85,
        reasoning: 'Best strategic choice for current game state',
        alternativeOptions: {
          'diamonds_king': 0.6,
          'clubs_queen': 0.3,
        },
      );

      // Log card play decision
      await provider.logCardPlay(
        gameContextId: contextId,
        playerId: 'human',
        cardPlayed: const game_card.Card(suit: game_card.Suit.diamonds, rank: game_card.Rank.king),
        aiSuggestion: aiRecommendation,
        trickWon: true,
        pointsGained: 10,
        strategicValue: 'high',
      );
    } catch (e) {
      print('Error logging test player decision: $e');
    }
  }

  void _clearLogs() {
    setState(() {
      _logMessages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Logging Test'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _clearLogs,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isLoggingEnabled ? Icons.check_circle : Icons.cancel,
                        color: _isLoggingEnabled ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI Logging Status: ${_isLoggingEnabled ? "Enabled" : "Disabled"}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Consumer<AILoggingProvider>(
                    builder: (context, provider, child) {
                      return Text(
                        'Current Game: ${provider.currentGameId ?? "None"}',
                        style: TextStyle(color: Colors.grey.shade600),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _testGameSession,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Test Game Session'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _setConsent(true),
                        icon: const Icon(Icons.thumb_up),
                        label: const Text('Enable Logging'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _setConsent(false),
                        icon: const Icon(Icons.thumb_down),
                        label: const Text('Disable Logging'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Logs Section
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Activity Log',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _logMessages.length,
                      itemBuilder: (context, index) {
                        final message = _logMessages[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '${_logMessages.length - index}. $message',
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
