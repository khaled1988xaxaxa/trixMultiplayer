import 'package:flutter/material.dart';
import '../models/ai_difficulty.dart';
import '../models/player.dart';
import '../models/card.dart' as game_card;
import '../models/game.dart';
import '../models/trix_game_state.dart';
import '../services/trix_ai.dart';

class AIDemoScreen extends StatefulWidget {
  const AIDemoScreen({super.key});

  @override
  State<AIDemoScreen> createState() => _AIDemoScreenState();
}

class _AIDemoScreenState extends State<AIDemoScreen> {
  final List<String> _demoLog = [];
  bool _isRunning = false;
  TrixAI? _currentAI;
  AIDifficulty _selectedDifficulty = AIDifficulty.perfect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار الذكاء الاصطناعي'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // AI Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اختر مستوى الذكاء الاصطناعي:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AIDifficulty>(
                      value: _selectedDifficulty,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: AIDifficulty.availableDifficulties.map((difficulty) {
                        return DropdownMenuItem(
                          value: difficulty,
                          child: Row(
                            children: [
                              Icon(Icons.smart_toy, 
                                   color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              Text(difficulty.arabicName),
                              const Spacer(),
                              Row(
                                children: List.generate(
                                  difficulty.experienceLevel,
                                  (index) => const Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedDifficulty = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedDifficulty.description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Control buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _runAIDemo,
                    icon: Icon(_isRunning ? Icons.hourglass_empty : Icons.play_arrow),
                    label: Text(_isRunning ? 'جاري الاختبار...' : 'اختبار الذكاء الاصطناعي'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _clearLog,
                  icon: const Icon(Icons.clear),
                  label: const Text('مسح'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Demo log
            Expanded(
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.description, 
                               color: Theme.of(context).primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'سجل الاختبار:',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _demoLog.isEmpty
                          ? const Center(
                              child: Text(
                                'اضغط على "اختبار الذكاء الاصطناعي" لبدء الاختبار',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _demoLog.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    _demoLog[index],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'monospace',
                                    ),
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
      ),
    );
  }

  Future<void> _runAIDemo() async {
    setState(() {
      _isRunning = true;
      _demoLog.clear();
    });

    _addLog('🤖 بدء اختبار الذكاء الاصطناعي...');
    _addLog('📊 المستوى المختار: ${_selectedDifficulty.arabicName}');
    _addLog('');

    try {
      // Load AI model
      _addLog('📂 تحميل نموذج الذكاء الاصطناعي...');
      await Future.delayed(const Duration(milliseconds: 500));
      
      _currentAI = await TrixAI.loadModel(_selectedDifficulty);
      _addLog('✅ تم تحميل النموذج بنجاح');
      _addLog('📈 عدد الحالات المتعلمة: ${_currentAI!.totalStatesLearned}');
      _addLog('');

      // Simulate some game scenarios
      await _simulateGameScenarios();

      _addLog('');
      _addLog('🎯 إحصائيات الأداء:');
      Map<String, dynamic> stats = _currentAI!.getPerformanceStats();
      _addLog('   • إجمالي القرارات: ${stats['total_decisions']}');
      _addLog('   • متوسط الثقة: ${(stats['average_confidence'] * 100).toStringAsFixed(1)}%');
      _addLog('   • معدل الثقة: ${(stats['confidence_rate'] * 100).toStringAsFixed(1)}%');
      _addLog('');
      _addLog('✨ اكتمل الاختبار بنجاح!');

    } catch (e) {
      _addLog('❌ خطأ في الاختبار: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _simulateGameScenarios() async {
    _addLog('🎮 محاكاة سيناريوهات اللعب...');
    
    // Create sample cards
    List<game_card.Card> sampleHand = [
      game_card.Card(suit: game_card.Suit.hearts, rank: game_card.Rank.ace),
      game_card.Card(suit: game_card.Suit.hearts, rank: game_card.Rank.king),
      game_card.Card(suit: game_card.Suit.spades, rank: game_card.Rank.queen),
      game_card.Card(suit: game_card.Suit.diamonds, rank: game_card.Rank.ten),
      game_card.Card(suit: game_card.Suit.clubs, rank: game_card.Rank.seven),
    ];

    // Scenario 1: King of Hearts contract
    _addLog('');
    _addLog('📋 السيناريو 1: ملك القلوب');
    await _testScenario(
      sampleHand,
      [game_card.Card(suit: game_card.Suit.hearts, rank: game_card.Rank.queen)], // Current trick
      TrexContract.kingOfHearts,
      'تجنب أخذ ملك القلوب',
    );

    // Scenario 2: Queens contract
    _addLog('');
    _addLog('📋 السيناريو 2: الملكات');
    await _testScenario(
      sampleHand,
      [], // Empty trick
      TrexContract.queens,
      'تجنب أخذ الملكات',
    );

    // Scenario 3: Diamonds contract
    _addLog('');
    _addLog('📋 السيناريو 3: الديمن');
    await _testScenario(
      sampleHand,
      [game_card.Card(suit: game_card.Suit.diamonds, rank: game_card.Rank.jack)], // Current trick
      TrexContract.diamonds,
      'تجنب أخذ الديمن',
    );
  }

  Future<void> _testScenario(
    List<game_card.Card> hand,
    List<game_card.Card> currentTrick,
    TrexContract contract,
    String description,
  ) async {
    _addLog('   📝 $description');
    
    // Create game state
    TrixGameState gameState = TrixGameState(
      playerHand: hand,
      currentTrick: currentTrick,
      currentContract: contract,
      playerPosition: PlayerPosition.south,
      tricksPlayed: 5,
      scores: {
        PlayerPosition.north: 0,
        PlayerPosition.east: 0,
        PlayerPosition.south: 0,
        PlayerPosition.west: 0,
      },
      playedCards: [],
    );

    // Get valid cards
    List<game_card.Card> validCards = gameState.getValidCards();
    _addLog('   🃏 البطاقات المتاحة: ${validCards.map(_cardToString).join(', ')}');

    await Future.delayed(const Duration(milliseconds: 300));

    // Let AI choose
    game_card.Card selectedCard = _currentAI!.selectCard(
      validCards: validCards,
      gameState: gameState,
    );

    _addLog('   🤖 اختار الذكاء الاصطناعي: ${_cardToString(selectedCard)}');
    
    // Analyze the choice
    _analyzeChoice(selectedCard, contract, validCards);
  }

  void _analyzeChoice(game_card.Card selectedCard, TrexContract contract, List<game_card.Card> validCards) {
    String analysis = '';
    
    switch (contract) {
      case TrexContract.kingOfHearts:
        if (selectedCard.suit == game_card.Suit.hearts && selectedCard.rank == game_card.Rank.king) {
          analysis = '⚠️ لعب ملك القلوب (خطير!)';
        } else if (selectedCard.suit == game_card.Suit.hearts && selectedCard.rank.value > 10) {
          analysis = '⚠️ لعب قلب عالي (قد يأخذ الملك)';
        } else {
          analysis = '✅ خيار آمن';
        }
        break;
        
      case TrexContract.queens:
        if (selectedCard.rank == game_card.Rank.queen) {
          analysis = '⚠️ لعب ملكة (خطير!)';
        } else {
          analysis = '✅ خيار آمن';
        }
        break;
        
      case TrexContract.diamonds:
        if (selectedCard.suit == game_card.Suit.diamonds) {
          analysis = '⚠️ لعب ديمن (نقاط سالبة)';
        } else {
          analysis = '✅ خيار آمن';
        }
        break;
        
      default:
        analysis = '📊 خيار استراتيجي';
    }
    
    _addLog('   💡 التحليل: $analysis');
  }

  String _cardToString(game_card.Card card) {
    Map<game_card.Suit, String> suitNames = {
      game_card.Suit.hearts: '♥️',
      game_card.Suit.diamonds: '♦️',
      game_card.Suit.clubs: '♣️',
      game_card.Suit.spades: '♠️',
    };
    
    Map<game_card.Rank, String> rankNames = {
      game_card.Rank.ace: 'A',
      game_card.Rank.king: 'K',
      game_card.Rank.queen: 'Q',
      game_card.Rank.jack: 'J',
      game_card.Rank.ten: '10',
      game_card.Rank.nine: '9',
      game_card.Rank.eight: '8',
      game_card.Rank.seven: '7',
      game_card.Rank.six: '6',
      game_card.Rank.five: '5',
      game_card.Rank.four: '4',
      game_card.Rank.three: '3',
      game_card.Rank.two: '2',
    };
    
    return '${rankNames[card.rank]}${suitNames[card.suit]}';
  }

  void _addLog(String message) {
    setState(() {
      _demoLog.add(message);
    });
  }

  void _clearLog() {
    setState(() {
      _demoLog.clear();
    });
  }
}
