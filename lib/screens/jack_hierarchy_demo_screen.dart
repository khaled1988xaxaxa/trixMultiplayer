import 'package:flutter/material.dart';
import '../models/card.dart' as trix_models;
import '../widgets/playing_card_widget.dart';

class JackHierarchyDemoScreen extends StatefulWidget {
  const JackHierarchyDemoScreen({super.key});

  @override
  State<JackHierarchyDemoScreen> createState() => _JackHierarchyDemoScreenState();
}

class _JackHierarchyDemoScreenState extends State<JackHierarchyDemoScreen> {
  final List<trix_models.Card> demoCards = [
    const trix_models.Card(suit: trix_models.Suit.hearts, rank: trix_models.Rank.jack),    // -50 points
    const trix_models.Card(suit: trix_models.Suit.spades, rank: trix_models.Rank.queen),   // -30 points  
    const trix_models.Card(suit: trix_models.Suit.diamonds, rank: trix_models.Rank.ten),   // -20 points
    const trix_models.Card(suit: trix_models.Suit.clubs, rank: trix_models.Rank.king),     // 0 points (not in hierarchy)
    const trix_models.Card(suit: trix_models.Suit.hearts, rank: trix_models.Rank.ace),     // 0 points (not in hierarchy)
  ];

  trix_models.Card? selectedCard1;
  trix_models.Card? selectedCard2;
  String battleResult = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jack Hierarchy Demo'),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contract explanation dsf
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jack Hierarchy Contract (الشايب والجيران)',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'In this contract, players arrange cards in sequences of 3:',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Start with Jack (شايب) - middle card'),
                    const Text('• Add Ten (١٠) below Jack (downward)'), 
                    const Text('• Add Queen (كبري) above Jack (upward)'),
                    const SizedBox(height: 8),
                    const Text(
                      'Sequence order: Ten → Jack → Queen',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Goal: Be first to play all your Jack/Queen/Ten cards by completing sequences.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Demo cards display
            Text(
              'Demo Cards:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: demoCards.length,
                itemBuilder: (context, index) {
                  final card = demoCards[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 70,
                          height: 90,
                          child: PlayingCardWidget(
                            card: card,
                            isPlayable: true,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          card.isJackHierarchyCard 
                              ? 'Seq: ${card.sequenceOrder}'
                              : 'Not used',
                          style: TextStyle(
                            fontSize: 12,
                            color: card.isJackHierarchyCard 
                                ? Colors.green 
                                : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Sequence building demo
            Text(
              'Sequence Building Demo:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text('Select cards to see sequence building:'),
            const SizedBox(height: 10),
            
            Row(
              children: [
                // Card selection 1
                Expanded(
                  child: Column(
                    children: [
                      const Text('First Card:'),
                      SizedBox(
                        height: 100,
                        child: selectedCard1 != null
                            ? SizedBox(
                                width: 70,
                                child: PlayingCardWidget(
                                  card: selectedCard1!,
                                  isPlayable: false,
                                ),
                              )
                            : Container(
                                width: 70,
                                height: 90,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.touch_app),
                              ),
                      ),
                    ],
                  ),
                ),
                
                const Text('→', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                
                // Card selection 2
                Expanded(
                  child: Column(
                    children: [
                      const Text('Next Card:'),
                      SizedBox(
                        height: 100,
                        child: selectedCard2 != null
                            ? SizedBox(
                                width: 70,
                                child: PlayingCardWidget(
                                  card: selectedCard2!,
                                  isPlayable: false,
                                ),
                              )
                            : Container(
                                width: 70,
                                height: 90,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.touch_app),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Selection buttons
            Wrap(
              spacing: 8,
              children: demoCards
                  .where((card) => card.isJackHierarchyCard)
                  .map<Widget>((card) => ElevatedButton(
                        onPressed: () => _selectCard(card),
                        child: Text('${card.rank.arabicName} ${card.suit.arabicName}'),
                      ))
                  .toList(),
            ),
            
            const SizedBox(height: 20),
            
            // Battle result
            if (battleResult.isNotEmpty)
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    battleResult,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Reset button
            Center(
              child: ElevatedButton(
                onPressed: _resetDemo,
                child: const Text('Reset Demo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectCard(trix_models.Card card) {
    setState(() {
      if (selectedCard1 == null) {
        selectedCard1 = card;
      } else if (selectedCard2 == null && card != selectedCard1) {
        selectedCard2 = card;
        _calculateBattle();
      }
    });
  }

  void _calculateBattle() {
    if (selectedCard1 == null || selectedCard2 == null) return;
    
    setState(() {
      // Check if second card can be placed after first card in sequence
      if (selectedCard2!.canPlaceAfterInSequence(selectedCard1!)) {
        battleResult = '✅ ${selectedCard2!.rank.arabicName} can be placed after ${selectedCard1!.rank.arabicName}!\n'
                     'Sequence: ${selectedCard1!.rank.arabicName} → ${selectedCard2!.rank.arabicName}';
      } else if (selectedCard1!.canPlaceAfterInSequence(selectedCard2!)) {
        battleResult = '✅ ${selectedCard1!.rank.arabicName} can be placed after ${selectedCard2!.rank.arabicName}!\n'
                     'Sequence: ${selectedCard2!.rank.arabicName} → ${selectedCard1!.rank.arabicName}';
      } else {
        battleResult = '❌ These cards cannot form a sequence.\n'
                     'Remember: Only Jack can start, then Ten (down) or Queen (up).';
      }
    });
  }

  void _resetDemo() {
    setState(() {
      selectedCard1 = null;
      selectedCard2 = null;
      battleResult = '';
    });
  }
}
