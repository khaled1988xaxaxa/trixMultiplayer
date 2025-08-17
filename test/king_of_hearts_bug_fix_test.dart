import 'package:flutter_test/flutter_test.dart';
import 'package:trix/models/card.dart';
import 'package:trix/models/ai_difficulty.dart';
import 'package:trix/models/trix_game_state.dart';
import 'package:trix/models/game.dart';
import 'package:trix/models/player.dart';
import 'package:trix/services/king_of_hearts_safe_ai_service.dart';

void main() {
  group('King of Hearts Bug Fix Tests', () {
    late KingOfHeartsSafeAIService safeAI;
    
    setUp(() async {
      safeAI = KingOfHeartsSafeAIService();
      await safeAI.initialize();
    });
    
    testWidgets('AI should never play King of Hearts when other options exist', (WidgetTester tester) async {
      // Critical test case: King of Hearts + other cards in King of Hearts mode
      final testHand = [
        Card(suit: Suit.hearts, rank: Rank.king), // King of Hearts - should NOT be chosen
        Card(suit: Suit.clubs, rank: Rank.seven),  // Safe option
        Card(suit: Suit.spades, rank: Rank.ace),   // Safe option
        Card(suit: Suit.diamonds, rank: Rank.ten), // Safe option
      ];
      
      // Create minimal game state for testing
      final gameState = TrixGameState(
        playerHand: testHand,
        currentTrick: [],
        currentContract: TrexContract.kingOfHearts,
        playerPosition: PlayerPosition.south,
        tricksPlayed: 0,
        scores: {
          PlayerPosition.north: 0,
          PlayerPosition.south: 0,
          PlayerPosition.east: 0,
          PlayerPosition.west: 0,
        },
        playedCards: [],
      );
      
      // Test the AI decision
      final decision = await safeAI.makeDecisionWithProtection(
        playerCards: testHand,
        validCards: testHand,
        gameMode: 'king_of_hearts',
        gameState: gameState,
      );
      
      // Validate the decision
      final validatedDecision = safeAI.validateDecision(
        decision: decision,
        validCards: testHand,
        gameMode: 'king_of_hearts',
      );
      
      // Extract chosen card
      final chosenCard = validatedDecision['chosen_card'] as Card;
      
      // CRITICAL ASSERTION: AI must NOT choose King of Hearts
      expect(chosenCard.isKingOfHearts, false, 
        reason: 'AI chose King of Hearts despite other options - BUG NOT FIXED!');
      
      // Verify chosen card is valid
      expect(testHand.contains(chosenCard), true,
        reason: 'AI chose invalid card');
      
      // Check if emergency override was triggered
      if (validatedDecision.containsKey('emergency_override_triggered')) {
        expect(validatedDecision['emergency_override_triggered'], true,
          reason: 'Emergency override should have been triggered');
      }
      
      print('✅ Test passed: AI correctly avoided King of Hearts');
      print('🎯 AI chose: ${chosenCard.rank.englishName} of ${chosenCard.suit.englishName}');
    });
    
    testWidgets('AI should play King of Hearts when it is the only option', (WidgetTester tester) async {
      // Edge case: Only King of Hearts available
      final testHand = [
        Card(suit: Suit.hearts, rank: Rank.king), // Only option
      ];
      
      final gameState = TrixGameState(
        playerHand: testHand,
        currentTrick: [],
        currentContract: TrexContract.kingOfHearts,
        playerPosition: PlayerPosition.south,
        tricksPlayed: 0,
        scores: {
          PlayerPosition.north: 0,
          PlayerPosition.south: 0,
          PlayerPosition.east: 0,
          PlayerPosition.west: 0,
        },
        playedCards: [],
      );
      
      final decision = await safeAI.makeDecisionWithProtection(
        playerCards: testHand,
        validCards: testHand,
        gameMode: 'king_of_hearts',
        gameState: gameState,
      );
      
      final validatedDecision = safeAI.validateDecision(
        decision: decision,
        validCards: testHand,
        gameMode: 'king_of_hearts',
      );
      
      final chosenCard = validatedDecision['chosen_card'] as Card;
      
      // AI should play King of Hearts when forced
      expect(chosenCard.isKingOfHearts, true,
        reason: 'AI should play King of Hearts when it is the only option');
      
      // Emergency override should NOT be triggered
      expect(validatedDecision['emergency_override_triggered'] ?? false, false,
        reason: 'Emergency override should not trigger when forced to play King of Hearts');
      
      print('✅ Test passed: AI correctly played King of Hearts when forced');
    });
    
    testWidgets('AI can play King of Hearts in other game modes', (WidgetTester tester) async {
      // Test: King of Hearts allowed in non-King of Hearts modes
      final testHand = [
        Card(suit: Suit.hearts, rank: Rank.king), // Should be allowed
        Card(suit: Suit.clubs, rank: Rank.seven),  // Alternative
      ];
      
      final gameState = TrixGameState(
        playerHand: testHand,
        currentTrick: [],
        currentContract: TrexContract.queens, // Different mode
        playerPosition: PlayerPosition.south,
        tricksPlayed: 0,
        scores: {
          PlayerPosition.north: 0,
          PlayerPosition.south: 0,
          PlayerPosition.east: 0,
          PlayerPosition.west: 0,
        },
        playedCards: [],
      );
      
      final decision = await safeAI.makeDecisionWithProtection(
        playerCards: testHand,
        validCards: testHand,
        gameMode: 'queens', // Not king_of_hearts mode
        gameState: gameState,
      );
      
      final validatedDecision = safeAI.validateDecision(
        decision: decision,
        validCards: testHand,
        gameMode: 'queens',
      );
      
      final chosenCard = validatedDecision['chosen_card'] as Card;
      
      // AI should be able to choose any valid card
      expect(testHand.contains(chosenCard), true,
        reason: 'AI chose invalid card');
      
      // No emergency override should trigger in other modes
      expect(validatedDecision['emergency_override_triggered'] ?? false, false,
        reason: 'Emergency override should not trigger in non-King of Hearts modes');
      
      print('✅ Test passed: AI can play King of Hearts in other modes');
      print('🎯 AI chose: ${chosenCard.rank.englishName} of ${chosenCard.suit.englishName}');
    });
    
    testWidgets('Protection system test function works correctly', (WidgetTester tester) async {
      // Test the built-in protection test
      final testResult = await safeAI.testKingOfHeartsProtection();
      
      expect(testResult['test_passed'], true,
        reason: 'Built-in protection test failed');
      
      expect(testResult['protection_active'], true,
        reason: 'Protection system not active during test');
      
      expect(testResult['corrected_card'], isNot(contains('King of Hearts')),
        reason: 'Test still chose King of Hearts');
      
      print('✅ Protection system test passed');
      print('🛡️ Corrected to: ${testResult['corrected_card']}');
    });
    
    testWidgets('Service status shows correct information', (WidgetTester tester) async {
      final status = safeAI.getStatus();
      
      expect(status['initialized'], true);
      expect(status['king_of_hearts_fix_active'], true);
      expect(status['emergency_override_enabled'], true);
      expect(status['bug_fix_status'], 'ACTIVE');
      expect(status['protection_level'], 'MAXIMUM');
      
      print('✅ Service status check passed');
      print('🛡️ Protection level: ${status['protection_level']}');
    });
  });
  
  group('AI Difficulty Tests', () {
    testWidgets('New strategicEliteCorrected difficulty is available', (WidgetTester tester) async {
      // Test the new difficulty level
      final correctedDifficulty = AIDifficulty.strategicEliteCorrected;
      
      expect(correctedDifficulty.englishName, 'Strategic Elite (Corrected)');
      expect(correctedDifficulty.arabicName, 'الاستراتيجي المصحح');
      expect(correctedDifficulty.folderName, 'strategic_elite_corrected_ai');
      expect(correctedDifficulty.experienceLevel, 9);
      
      expect(correctedDifficulty.description, contains('ENHANCED King of Hearts fix'));
      expect(correctedDifficulty.description, contains('Emergency override system'));
      
      // Check it's in available difficulties
      expect(AIDifficulty.availableDifficulties.contains(correctedDifficulty), true);
      
      print('✅ New AI difficulty properly configured');
    });
  });
  
  group('Card Encoding Tests', () {
    testWidgets('King of Hearts is correctly identified', (WidgetTester tester) async {
      final kingOfHearts = Card(suit: Suit.hearts, rank: Rank.king);
      
      expect(kingOfHearts.isKingOfHearts, true);
      expect(kingOfHearts.suit, Suit.hearts);
      expect(kingOfHearts.rank, Rank.king);
      expect(kingOfHearts.rank.value, 13);
      
      // Test other cards are not King of Hearts
      final otherCard = Card(suit: Suit.clubs, rank: Rank.king);
      expect(otherCard.isKingOfHearts, false);
      
      print('✅ King of Hearts identification working correctly');
    });
  });
  
  group('Integration Tests', () {
    late KingOfHeartsSafeAIService integrationSafeAI;
    
    setUp(() async {
      integrationSafeAI = KingOfHeartsSafeAIService();
      await integrationSafeAI.initialize();
    });
    
    testWidgets('Multiple consecutive decisions maintain protection', (WidgetTester tester) async {
      // Test multiple decisions in a row
      final testHands = [
        [Card(suit: Suit.hearts, rank: Rank.king), Card(suit: Suit.clubs, rank: Rank.seven)],
        [Card(suit: Suit.hearts, rank: Rank.king), Card(suit: Suit.spades, rank: Rank.ace)],
        [Card(suit: Suit.hearts, rank: Rank.king), Card(suit: Suit.diamonds, rank: Rank.ten)],
      ];
      
      for (int i = 0; i < testHands.length; i++) {
        final gameState = TrixGameState(
          playerHand: testHands[i],
          currentTrick: [],
          currentContract: TrexContract.kingOfHearts,
          playerPosition: PlayerPosition.south,
          tricksPlayed: 0,
          scores: {
            PlayerPosition.north: 0,
            PlayerPosition.south: 0,
            PlayerPosition.east: 0,
            PlayerPosition.west: 0,
          },
          playedCards: [],
        );
        
        final decision = await integrationSafeAI.makeDecisionWithProtection(
          playerCards: testHands[i],
          validCards: testHands[i],
          gameMode: 'king_of_hearts',
          gameState: gameState,
        );
        
        final validatedDecision = integrationSafeAI.validateDecision(
          decision: decision,
          validCards: testHands[i],
          gameMode: 'king_of_hearts',
        );
        
        final chosenCard = validatedDecision['chosen_card'] as Card;
        
        expect(chosenCard.isKingOfHearts, false,
          reason: 'Decision $i: AI chose King of Hearts - protection failed');
      }
      
      print('✅ Multiple consecutive decisions protected correctly');
    });
  });
}
