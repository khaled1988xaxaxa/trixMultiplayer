/// Integration helper to add King of Hearts protection to existing AI services
/// This can be added to your existing TrixAI service with minimal changes

import 'package:flutter/foundation.dart';
import '../models/card.dart';
import '../models/game.dart';

class KingOfHeartsProtectionMixin {
  /// Apply King of Hearts protection to any AI decision
  /// This method can be called on any AI choice to ensure safety
  static Card applyKingOfHeartsProtection({
    required Card originalChoice,
    required List<Card> validCards,
    required TrexContract? currentContract,
    bool enableLogging = true,
  }) {
    // Only apply protection in King of Hearts mode
    if (currentContract != TrexContract.kingOfHearts) {
      return originalChoice; // No protection needed in other modes
    }
    
    bool chosenKingOfHearts = originalChoice.isKingOfHearts;
    bool hasOtherOptions = validCards.length > 1;
    bool hasKingOfHeartsInHand = validCards.any((card) => card.isKingOfHearts);
    
    if (enableLogging && kDebugMode) {
      print('🛡️ === KING OF HEARTS PROTECTION CHECK ===');
      print('🎯 Contract: ${currentContract?.name}');
      print('🃏 Original choice: ${_cardToString(originalChoice)}');
      print('👑 Chose King of Hearts: $chosenKingOfHearts');
      print('🔢 Has other options: $hasOtherOptions');
      print('🃏 Valid cards: ${validCards.map(_cardToString).join(', ')}');
    }
    
    // CRITICAL BUG DETECTION
    if (chosenKingOfHearts && hasOtherOptions) {
      if (enableLogging && kDebugMode) {
        print('🚨 CRITICAL BUG DETECTED: AI chose King of Hearts with other options!');
        print('💰 This would cause -75 point penalty');
        print('🛡️ EMERGENCY OVERRIDE ACTIVATING...');
      }
      
      // Get safe alternatives (non-King of Hearts cards)
      List<Card> safeCards = validCards.where((card) => !card.isKingOfHearts).toList();
      
      if (safeCards.isNotEmpty) {
        // Select safest card (lowest rank to minimize risk)
        safeCards.sort((a, b) => a.rank.value.compareTo(b.rank.value));
        Card safeChoice = safeCards.first;
        
        if (enableLogging && kDebugMode) {
          print('✅ Emergency override successful');
          print('🔄 Changed from: ${_cardToString(originalChoice)}');
          print('🛡️ Changed to: ${_cardToString(safeChoice)}');
          print('💰 Avoided -75 point penalty');
        }
        
        return safeChoice;
      } else {
        if (enableLogging && kDebugMode) {
          print('⚠️ No safe alternatives found - this should not happen');
        }
      }
    } else if (chosenKingOfHearts && !hasOtherOptions) {
      if (enableLogging && kDebugMode) {
        print('👑 AI forced to play King of Hearts (only card available)');
        print('✅ This is acceptable - no override needed');
      }
    } else if (!chosenKingOfHearts && hasKingOfHeartsInHand) {
      if (enableLogging && kDebugMode) {
        print('✅ SUCCESS: AI correctly avoided King of Hearts');
        print('🎯 Chose safe card: ${_cardToString(originalChoice)}');
      }
    }
    
    if (enableLogging && kDebugMode) {
      print('=========================================');
    }
    
    return originalChoice;
  }
  
  /// Validate that a card choice is safe in King of Hearts mode
  static bool isChoiceSafe({
    required Card choice,
    required List<Card> validCards,
    required TrexContract? currentContract,
  }) {
    // Always safe in non-King of Hearts modes
    if (currentContract != TrexContract.kingOfHearts) {
      return true;
    }
    
    // Safe if not King of Hearts
    if (!choice.isKingOfHearts) {
      return true;
    }
    
    // Safe if forced to play King of Hearts (only option)
    if (validCards.length == 1 && validCards.first.isKingOfHearts) {
      return true;
    }
    
    // Unsafe if playing King of Hearts with other options
    return false;
  }
  
  /// Get safety analysis for debugging
  static Map<String, dynamic> analyzeChoice({
    required Card choice,
    required List<Card> validCards,
    required TrexContract? currentContract,
  }) {
    return {
      'chosen_card': _cardToString(choice),
      'is_king_of_hearts_mode': currentContract == TrexContract.kingOfHearts,
      'chose_king_of_hearts': choice.isKingOfHearts,
      'has_other_options': validCards.length > 1,
      'is_choice_safe': isChoiceSafe(
        choice: choice,
        validCards: validCards,
        currentContract: currentContract,
      ),
      'valid_cards_count': validCards.length,
      'valid_cards': validCards.map(_cardToString).toList(),
      'bug_detected': currentContract == TrexContract.kingOfHearts &&
                     choice.isKingOfHearts &&
                     validCards.length > 1,
    };
  }
  
  static String _cardToString(Card card) {
    return '${card.rank.englishName} of ${card.suit.englishName}';
  }
}

/// Extension to add protection to existing Card selection methods
extension KingOfHeartsProtection on Card {
  /// Apply protection to this card choice
  Card withKingOfHeartsProtection({
    required List<Card> validCards,
    required TrexContract? currentContract,
    bool enableLogging = true,
  }) {
    return KingOfHeartsProtectionMixin.applyKingOfHeartsProtection(
      originalChoice: this,
      validCards: validCards,
      currentContract: currentContract,
      enableLogging: enableLogging,
    );
  }
  
  /// Check if this card choice is safe
  bool isSafeChoice({
    required List<Card> validCards,
    required TrexContract? currentContract,
  }) {
    return KingOfHeartsProtectionMixin.isChoiceSafe(
      choice: this,
      validCards: validCards,
      currentContract: currentContract,
    );
  }
}
