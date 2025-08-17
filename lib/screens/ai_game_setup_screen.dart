import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/ai_difficulty.dart';
import '../models/ai_player.dart';
import '../providers/ai_provider.dart';
import '../widgets/ai_settings_widget.dart';

class AIGameSetupScreen extends StatefulWidget {
  const AIGameSetupScreen({super.key});

  @override
  State<AIGameSetupScreen> createState() => _AIGameSetupScreenState();
}

class _AIGameSetupScreenState extends State<AIGameSetupScreen> {
  AIDifficulty _selectedDifficulty = AIDifficulty.safeFallback;
  int _aiOpponents = 3;
  bool _adaptiveDifficulty = true;
  GameMode _gameMode = GameMode.practice;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAI();
    });
  }

  Future<void> _initializeAI() async {
    final aiProvider = Provider.of<AIProvider>(context, listen: false);
    if (!aiProvider.isInitialized) {
      await aiProvider.initialize();
    }
    if (mounted) {
      setState(() {
        _selectedDifficulty = aiProvider.preferredDifficulty;
        _adaptiveDifficulty = aiProvider.adaptiveDifficulty;
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Play vs AI',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AIProvider>(
        builder: (context, aiProvider, child) {
          if (!_isInitialized || aiProvider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing AI...'),
                ],
              ),
            );
          }

          if (aiProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'AI Loading Error',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    aiProvider.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => aiProvider.initialize(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Game mode selection
                _buildGameModeSection(),
                const SizedBox(height: 20),

                // AI settings
                AISettingsWidget(
                  selectedDifficulty: _selectedDifficulty,
                  onDifficultyChanged: (difficulty) {
                    setState(() {
                      _selectedDifficulty = difficulty;
                    });
                  },
                  playerGamesPlayed: aiProvider.playerGamesPlayed,
                  playerWinRate: aiProvider.playerWinRate,
                  showRecommendations: true,
                ),
                const SizedBox(height: 20),

                // Opponent count selection
                _buildOpponentCountSection(),
                const SizedBox(height: 20),

                // Advanced settings
                _buildAdvancedSettings(aiProvider),
                const SizedBox(height: 20),

                // Player statistics
                if (aiProvider.playerGamesPlayed > 0)
                  _buildPlayerStats(aiProvider),

                const SizedBox(height: 30),

                // Start game button
                _buildStartGameButton(aiProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGameModeSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sports_esports, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'نوع اللعبة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildGameModeOption(
                    GameMode.practice,
                    'تدريب',
                    'لعبة تدريبية لتحسين مهاراتك',
                    Icons.fitness_center,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildGameModeOption(
                    GameMode.challenge,
                    'تحدي',
                    'واجه خصوم أقوياء',
                    Icons.emoji_events,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildGameModeOption(
                    GameMode.tournament,
                    'بطولة',
                    'تدرج في مستويات الصعوبة',
                    Icons.military_tech,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildGameModeOption(
                    GameMode.custom,
                    'مخصص',
                    'إعدادات متقدمة',
                    Icons.tune,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameModeOption(GameMode mode, String title, String description, IconData icon) {
    bool isSelected = _gameMode == mode;
    
    return GestureDetector(
      onTap: () => setState(() => _gameMode = mode),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade600,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpponentCountSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.group, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'خصوم بالصعوبة المختارة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'سيتم إضافة خصوم آخرين لإكمال 4 لاعبين',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [1, 2, 3].map((count) {
                bool isSelected = _aiOpponents == count;
                return GestureDetector(
                  onTap: () => setState(() => _aiOpponents = count),
                  child: Container(
                    width: 80,
                    height: 100,
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          count == 1 ? 'خصم قوي' : 'خصوم أقوياء',
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? Colors.white70 : Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '+ ${3 - count} آخرين',
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white60 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                },
              ).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSettings(AIProvider aiProvider) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'إعدادات متقدمة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('تكيف الصعوبة تلقائياً'),
              subtitle: const Text('يتم تعديل مستوى الصعوبة بناءً على أدائك'),
              value: _adaptiveDifficulty,
              onChanged: (value) {
                setState(() => _adaptiveDifficulty = value);
                aiProvider.toggleAdaptiveDifficulty(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerStats(AIProvider aiProvider) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'إحصائياتك',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'الألعاب',
                    '${aiProvider.playerGamesPlayed}',
                    Icons.games,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'الانتصارات',
                    '${aiProvider.playerGamesWon}',
                    Icons.emoji_events,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'معدل الفوز',
                    '${(aiProvider.playerWinRate * 100).toStringAsFixed(1)}%',
                    Icons.trending_up,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildStartGameButton(AIProvider aiProvider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _startGame(aiProvider),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow, size: 28),
            const SizedBox(width: 8),
            Text(
              'بدء اللعبة',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startGame(AIProvider aiProvider) async {
    try {
      // Debug: Log the selected difficulty
      if (kDebugMode) {
        print('🎮 [AI Setup] Selected difficulty: ${_selectedDifficulty.englishName}');
        print('🎮 [AI Setup] Number of opponents: $_aiOpponents');
        print('🎮 [AI Setup] Game mode: $_gameMode');
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Creating opponents...'),
                ],
              ),
            ),
          ),
        ),
      );

      List<AIPlayer> opponents;
      
      switch (_gameMode) {
        case GameMode.practice:
          // For Trix, we need exactly 3 AI opponents (4 players total)
          // Create practice opponents with the selected difficulty as primary
          List<AIDifficulty> difficulties = [];
          
          // Add the selected difficulty for the number of opponents requested
          for (int i = 0; i < _aiOpponents; i++) {
            difficulties.add(_selectedDifficulty);
          }
          
          // Fill remaining spots with balanced difficulties for 4-player game
          while (difficulties.length < 3) {
            if (difficulties.length == 1) {
              difficulties.add(AIDifficulty.amateur); // Add a moderate opponent
            } else {
              difficulties.add(AIDifficulty.novice); // Add an easier opponent
            }
          }
          
          opponents = await aiProvider.createAIOpponents(
            opponentCount: 3, // Always create 3 AI opponents
            specificDifficulties: difficulties,
          );
          break;
          
        case GameMode.tournament:
          opponents = await aiProvider.createTournamentOpponents();
          break;
          
        default:
          // Debug: Force the selected difficulty for all opponents
          if (kDebugMode) {
            print('🎮 [AI Setup] Forcing difficulty: ${_selectedDifficulty.englishName}');
            print('🎮 [AI Setup] Creating $_aiOpponents opponents with this difficulty');
          }
          
          // For Trix, we need exactly 3 AI opponents (4 players total)
          // If user selected fewer, fill the rest with varied difficulties
          List<AIDifficulty> difficulties = [];
          
          // Add the selected difficulty for the number of opponents requested
          for (int i = 0; i < _aiOpponents; i++) {
            difficulties.add(_selectedDifficulty);
          }
          
          // Fill remaining spots with balanced difficulties
          while (difficulties.length < 3) {
            // Add varied difficulties to make it interesting
            if (difficulties.length == 1) {
              difficulties.add(AIDifficulty.amateur); // Add a moderate opponent
            } else {
              difficulties.add(AIDifficulty.novice); // Add an easier opponent
            }
          }
          
          opponents = await aiProvider.createAIOpponents(
            opponentCount: 3, // Always create 3 AI opponents for 4-player Trix
            specificDifficulties: difficulties,
          );
          
          // Debug: Verify created opponents
          if (kDebugMode) {
            for (int i = 0; i < opponents.length; i++) {
              print('🎮 [AI Setup] Created opponent ${i+1}: ${opponents[i].name} with difficulty: ${opponents[i].difficulty.englishName}');
            }
          }
      }

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Navigate to game screen
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(
          '/game',
          arguments: {
            'aiOpponents': opponents,
            'gameMode': _gameMode,
          },
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

enum GameMode {
  practice,
  challenge,
  tournament,
  custom,
}
