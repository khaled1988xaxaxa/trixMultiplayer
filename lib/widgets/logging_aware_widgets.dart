import 'package:flutter/material.dart' hide Card;
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/card.dart';
import '../models/game.dart';
import '../models/player.dart';

/// Mixin to add thinking time tracking to game screens
mixin ThinkingTimeTracker<T extends StatefulWidget> on State<T> {
  DateTime? _thinkingStartTime;
  
  /// Start tracking thinking time when options are presented
  void startThinkingTimer() {
    _thinkingStartTime = DateTime.now();
    context.read<GameProvider>().startThinkingTimer();
  }
  
  /// Stop tracking and log the thinking time
  void stopThinkingTimer() {
    if (_thinkingStartTime != null) {
      context.read<GameProvider>().resetThinkingTimer();
      _thinkingStartTime = null;
    }
  }
  
  /// Check if we should start the thinking timer
  void checkStartThinkingTimer(TrexGame? game) {
    if (game == null) return;
    
    // Start timer when it's human player's turn and we haven't started yet
    if (game.currentPlayer == PlayerPosition.south && _thinkingStartTime == null) {
      if (game.phase == GamePhase.contractSelection || game.phase == GamePhase.playing) {
        startThinkingTimer();
      }
    }
  }
  
  /// Check if we should stop the thinking timer
  void checkStopThinkingTimer(TrexGame? game) {
    if (game == null) return;
    
    // Stop timer when it's no longer human player's turn
    if (game.currentPlayer != PlayerPosition.south && _thinkingStartTime != null) {
      stopThinkingTimer();
    }
  }
  
  @override
  void dispose() {
    if (_thinkingStartTime != null) {
      stopThinkingTimer();
    }
    super.dispose();
  }
}

/// Enhanced card widget that shows logging status
class LoggingAwareCardWidget extends StatelessWidget {
  final Card card;
  final bool isPlayable;
  final bool isHighlighted;
  final VoidCallback? onTap;
  final bool showLoggingIndicator;

  const LoggingAwareCardWidget({
    super.key,
    required this.card,
    this.isPlayable = true,
    this.isHighlighted = false,
    this.onTap,
    this.showLoggingIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        return Stack(
          children: [
            // Original card widget
            GestureDetector(
              onTap: isPlayable ? onTap : null,
              child: Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  color: isPlayable ? Colors.white : Colors.grey[300],
                  border: Border.all(
                    color: isHighlighted ? Colors.blue : Colors.black,
                    width: isHighlighted ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      card.rank.englishName.substring(0, 1),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _getSuitColor(card.suit),
                      ),
                    ),
                    Text(
                      _getSuitSymbol(card.suit),
                      style: TextStyle(
                        fontSize: 16,
                        color: _getSuitColor(card.suit),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Logging indicator
            if (showLoggingIndicator && gameProvider.isLoggingEnabled)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Color _getSuitColor(Suit suit) {
    switch (suit) {
      case Suit.hearts:
      case Suit.diamonds:
        return Colors.red;
      case Suit.clubs:
      case Suit.spades:
        return Colors.black;
    }
  }

  String _getSuitSymbol(Suit suit) {
    switch (suit) {
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
      case Suit.spades:
        return '♠';
    }
  }
}

/// Enhanced contract selection widget with logging
class LoggingAwareContractSelector extends StatelessWidget {
  final List<TrexContract> availableContracts;
  final Function(TrexContract) onContractSelected;

  const LoggingAwareContractSelector({
    super.key,
    required this.availableContracts,
    required this.onContractSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        return Column(
          children: [
            // Logging status indicator
            if (gameProvider.isLoggingEnabled)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Colors.green, size: 8),
                    SizedBox(width: 4),
                    Text(
                      'Recording decision for AI training',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Contract options
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableContracts.map((contract) {
                return ElevatedButton(
                  onPressed: () => onContractSelected(contract),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        contract.arabicName,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        contract.englishName,
                        style: const TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

/// Floating action button for quick access to logging settings
class LoggingQuickAccessFab extends StatelessWidget {
  const LoggingQuickAccessFab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        return FloatingActionButton.small(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('🤖 AI Training'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: const Text('Enable Logging'),
                      subtitle: const Text('Track gameplay for AI training'),
                      value: gameProvider.isLoggingEnabled,
                      onChanged: (value) async {
                        await gameProvider.setLoggingEnabled(value);
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.settings),
                      title: const Text('Advanced Settings'),
                      subtitle: const Text('Manage training data'),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushNamed('/logging_settings');
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
          backgroundColor: gameProvider.isLoggingEnabled 
            ? Colors.green 
            : Colors.grey,
          child: Icon(
            gameProvider.isLoggingEnabled 
              ? Icons.fiber_manual_record 
              : Icons.stop_circle_outlined,
            color: Colors.white,
          ),
        );
      },
    );
  }
}

/// Status bar widget showing current AI and logging status
class AITrainingStatusBar extends StatelessWidget {
  const AITrainingStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // AI Status
              Icon(
                Icons.smart_toy,
                size: 12,
                color: gameProvider.isLightweightAIMode 
                  ? Colors.orange 
                  : Colors.blue,
              ),
              const SizedBox(width: 4),
              Text(
                gameProvider.isLightweightAIMode 
                  ? 'Test Mode' 
                  : 'Full AI',
                style: const TextStyle(fontSize: 10),
              ),
              const SizedBox(width: 8),
              
              // Logging Status
              Icon(
                gameProvider.isLoggingEnabled 
                  ? Icons.fiber_manual_record 
                  : Icons.stop_circle_outlined,
                size: 12,
                color: gameProvider.isLoggingEnabled 
                  ? Colors.green 
                  : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                gameProvider.isLoggingEnabled 
                  ? 'Recording' 
                  : 'Not Recording',
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }
}
