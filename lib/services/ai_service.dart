import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/card.dart';
import '../utils/ai_config.dart';

class AIService {
  final String _provider;
  final String _apiKey;
  final String _baseUrl;
  final String _model;
  final http.Client _httpClient;

  AIService({
    required String apiKey,
    String? provider,
  }) : _provider = provider ?? AIConfig.defaultProvider,
       _apiKey = apiKey,
       _baseUrl = AIConfig.getBaseUrl(provider ?? AIConfig.defaultProvider),
       _model = AIConfig.getModel(provider ?? AIConfig.defaultProvider),
       _httpClient = http.Client();

  // Factory constructor for different providers
  factory AIService.deepSeek({required String apiKey}) {
    return AIService(apiKey: apiKey, provider: 'deepseek');
  }

  factory AIService.openAI({required String apiKey}) {
    return AIService(apiKey: apiKey, provider: 'openai');
  }

  // Get provider name for UI display
  String get providerName {
    switch (_provider) {
      case 'openai':
        return 'OpenAI GPT';
      case 'deepseek':
        return 'DeepSeek';
      default:
        return _provider.toUpperCase();
    }
  }

  /// Optimized contract selection with caching and reduced timeouts
  Future<TrexContract?> selectContract({
    required PlayerPosition botPosition,
    required TrexGame game,
    required List<TrexContract> availableContracts,
  }) async {
    if (availableContracts.isEmpty) return null;

    final startTime = DateTime.now();
    
    // Generate cache key for this decision
    final cacheKey = _generateContractCacheKey(game, botPosition, availableContracts);
    
    // Check cache first
    final cachedResult = AIConfig.getCachedResponse(cacheKey);
    if (cachedResult != null) {
      if (kDebugMode) {
        print('🚀 Cache hit for contract selection - ${botPosition.arabicName}');
      }
      return _findContractByName(cachedResult, availableContracts);
    }
    
    if (kDebugMode) {
      print('\n🤖 AI CONTRACT SELECTION - ${botPosition.arabicName}');
      print('════════════════════════════════════════════════');
      print('Available contracts: ${availableContracts.map((c) => c.arabicName).join(', ')}');
    }

    try {
      // Get user preferences for timeout
      final prefs = await SharedPreferences.getInstance();
      final timeoutSeconds = prefs.getInt('ai_timeout') ?? 5;
      final timeout = Duration(seconds: timeoutSeconds);
      
      final gameState = _buildOptimizedGameState(game, botPosition);
      final prompt = _buildOptimizedContractPrompt(gameState, availableContracts, botPosition);

      if (kDebugMode) {
        print('📤 Optimized prompt (${prompt.length} chars)');
      }

      final response = await _callProviderAPI(prompt, timeout);
      final selectedContract = _parseContractResponse(response, availableContracts);
      
      // Cache the result
      if (selectedContract != null) {
        AIConfig.cacheResponse(cacheKey, selectedContract.arabicName);
      }
      
      final duration = DateTime.now().difference(startTime);
      if (kDebugMode) {
        print('📥 AI Response received in ${duration.inMilliseconds}ms');
        print('✅ AI selected contract: ${selectedContract?.arabicName ?? 'null'}');
        print('════════════════════════════════════════════════\n');
      }
      
      return selectedContract;
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      if (kDebugMode) {
        print('❌ AI contract selection failed after ${duration.inMilliseconds}ms: $e');
        print('🔄 Falling back to simple logic...');
      }
      return _fallbackContractSelection(game, botPosition, availableContracts);
    }
  }

  /// Optimized card selection with caching
  Future<Card?> selectCard({
    required PlayerPosition botPosition,
    required TrexGame game,
    required List<Card> hand,
    required List<Card> validCards,
  }) async {
    if (validCards.isEmpty) return null;

    final startTime = DateTime.now();
    
    // Generate cache key
    final cacheKey = _generateCardCacheKey(game, hand, validCards, botPosition);
    
    // Check cache first
    final cachedResult = AIConfig.getCachedResponse(cacheKey);
    if (cachedResult != null) {
      if (kDebugMode) {
        print('🚀 Cache hit for card selection - ${botPosition.arabicName}');
      }
      return _findCardFromCache(cachedResult, validCards);
    }

    if (kDebugMode) {
      print('\n🃏 AI CARD SELECTION - ${botPosition.arabicName}');
      print('════════════════════════════════════════════════');
    }

    try {
      // Get user preferences
      final prefs = await SharedPreferences.getInstance();
      final timeoutSeconds = prefs.getInt('ai_timeout') ?? 5;
      final timeout = Duration(seconds: timeoutSeconds);
      
      final gameState = _buildOptimizedCardGameState(game, hand, validCards);
      final prompt = _buildOptimizedCardPrompt(gameState, validCards);

      if (kDebugMode) {
        print('📤 Optimized prompt (${prompt.length} chars)');
      }

      final response = await _callProviderAPI(prompt, timeout);
      final selectedCard = _parseCardResponse(response, validCards) ?? 
                          _contractAwareFallbackCard(validCards, game.currentContract?.arabicName);
      
      // Cache the result only if we have a valid card
      if (selectedCard != null) {
        AIConfig.cacheResponse(cacheKey, '${selectedCard.suit.index}-${selectedCard.rank.value}');
      }
      
      final duration = DateTime.now().difference(startTime);
      if (kDebugMode) {
        print('📥 AI Response received in ${duration.inMilliseconds}ms');
        if (selectedCard != null) {
          print('✅ AI selected card: ${selectedCard.toString()}');
        } else {
          print('⏭️ AI passed turn (no valid moves)');
        }
        print('════════════════════════════════════════════════\n');
      }
      
      return selectedCard;
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      if (kDebugMode) {
        print('❌ AI card selection failed after ${duration.inMilliseconds}ms: $e');
        print('🔄 Falling back to simple logic...');
      }
      return _contractAwareFallbackCard(validCards, game.currentContract?.arabicName);
    }
  }

  /// Parallel processing for multiple bot decisions
  Future<List<dynamic>> selectCardsParallel(List<Map<String, dynamic>> gameStates) async {
    final prefs = await SharedPreferences.getInstance();
    final enableParallel = prefs.getBool('enable_parallel') ?? true;
    
    if (!enableParallel) {
      // Sequential processing
      final results = <dynamic>[];
      for (final state in gameStates) {
        if (state['type'] == 'card') {
          results.add(await selectCard(
            botPosition: state['botPosition'],
            game: state['game'],
            hand: state['hand'],
            validCards: state['validCards'],
          ));
        } else if (state['type'] == 'contract') {
          results.add(await selectContract(
            botPosition: state['botPosition'],
            game: state['game'],
            availableContracts: state['availableContracts'],
          ));
        }
      }
      return results;
    }
    
    // Parallel processing
    final futures = gameStates.map((state) {
      if (state['type'] == 'card') {
        return selectCard(
          botPosition: state['botPosition'],
          game: state['game'],
          hand: state['hand'],
          validCards: state['validCards'],
        );
      } else if (state['type'] == 'contract') {
        return selectContract(
          botPosition: state['botPosition'],
          game: state['game'],
          availableContracts: state['availableContracts'],
        );
      }
      return Future.value(null);
    }).toList();
    
    return await Future.wait(futures);
  }

  // Cache key generation methods
  String _generateContractCacheKey(TrexGame game, PlayerPosition position, List<TrexContract> contracts) {
    final key = '${game.kingdom}-${game.round}-${position.index}-${contracts.map((c) => c.arabicName).join(',')}';
    return md5.convert(utf8.encode(key)).toString();
  }

  String _generateCardCacheKey(TrexGame game, List<Card> hand, List<Card> validCards, PlayerPosition position) {
    final handStr = hand.take(5).map((c) => '${c.suit.index}${c.rank.value}').join(',');
    final validStr = validCards.map((c) => '${c.suit.index}${c.rank.value}').join(',');
    final key = '${game.currentContract?.arabicName}-$handStr-$validStr-${position.index}';
    return md5.convert(utf8.encode(key)).toString();
  }

  // Enhanced prompt builders with more context
  String _buildOptimizedContractPrompt(Map<String, dynamic> gameState, List<TrexContract> contracts, PlayerPosition position) {
    final player = gameState['player'] as Player?;
    final handAnalysis = player != null ? _analyzeHandForPrompt(player.hand) : {};
    
    return '''You are playing Trix card game. Choose the best contract.

SITUATION:
- Position: ${position.arabicName}
- Kingdom: ${gameState['kingdom']}/4
- Round: ${gameState['round']}
- Available contracts: ${contracts.map((c) => c.arabicName).join(', ')}

HAND ANALYSIS:
- Hearts: ${handAnalysis['hearts'] ?? 0} ${handAnalysis['hasKingOfHearts'] == true ? '(HAS KING!)' : ''}
- Diamonds: ${handAnalysis['diamonds'] ?? 0}
- Queens: ${handAnalysis['queens'] ?? 0}
- Jacks: ${handAnalysis['hasJacks'] == true ? 'YES' : 'NO'}
- High cards (10+): ${handAnalysis['highCards'] ?? 0}

STRATEGY:
- Avoid contracts where you have penalty cards
- King of Hearts: Dangerous if you have it (-75 points)
- Queens: Avoid if you have many (-25 each)
- Diamonds: Avoid if you have many (-10 each) 
- Collections: Good if you have low cards (-15 per trick)
- Trex: Good if you have Jacks (+200 for first)

Respond with JSON only: {"contract": "contract_name"}''';
  }

  String _buildOptimizedCardPrompt(Map<String, dynamic> gameState, List<Card> validCards) {
    final currentTrick = gameState['currentTrick'] as Map<String, String>?;
    final contract = gameState['contract'] ?? 'Unknown';
    
    // Analyze the current trick situation for context (not instructions)
    String trickAnalysis = 'No cards played yet';
    String gameContext = '';
    
    if (currentTrick != null && currentTrick.isNotEmpty) {
      trickAnalysis = currentTrick.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      
      // Provide factual context without telling the AI what to do
      final playedCards = currentTrick.values.toList();
      final isFollowing = playedCards.isNotEmpty;
      
      if (isFollowing) {
        // Provide objective information about the current trick state
        gameContext = '''Trick Status: You are FOLLOWING (${playedCards.length} cards already played)
Cards in play: ${playedCards.join(', ')}
Your position: Must follow suit rules and consider trick-taking implications''';
        
        // Add contract-specific context without giving away the strategy
        if (contract == 'King of Hearts' && playedCards.any((c) => c.contains('Hearts'))) {
          gameContext += '\nSuit Context: Hearts suit is active in this trick';
        } else if (contract == 'Queens' && playedCards.any((c) => c.contains('Queen'))) {
          gameContext += '\nDanger Alert: Queen cards are in play this trick';
        } else if (contract == 'Collections') {
          // Parse highest card for AI to consider
          final playedRanks = playedCards.map((cardStr) {
            if (cardStr.contains('Ace')) return 14;
            if (cardStr.contains('King')) return 13;
            if (cardStr.contains('Queen')) return 12;
            if (cardStr.contains('Jack')) return 11;
            if (cardStr.contains('Ten')) return 10;
            if (cardStr.contains('Nine')) return 9;
            if (cardStr.contains('Eight')) return 8;
            if (cardStr.contains('Seven')) return 7;
            if (cardStr.contains('Six')) return 6;
            if (cardStr.contains('Five')) return 5;
            if (cardStr.contains('Four')) return 4;
            if (cardStr.contains('Three')) return 3;
            if (cardStr.contains('Two')) return 2;
            return 2;
          }).toList();
          
          final highestRank = playedRanks.reduce((a, b) => a > b ? a : b);
          gameContext += '\nTrick Analysis: Current winning rank is $highestRank';
        }
      } else {
        // Leading the trick
        gameContext = 'Trick Status: You are LEADING this trick (first to play)';
      }
    }
    
    // Analyze valid cards for better recommendations
    final cardAnalysis = _analyzeValidCards(validCards, contract);
    
    return '''You are an EXPERT Trix player. Analyze the situation and make your best strategic decision.

GAME SITUATION:
- Contract: $contract
- Current trick: $trickAnalysis
- Valid cards (${validCards.length}): ${validCards.take(6).map((c) => '${c.rank.name}${c.suit.name}').join(', ')}${validCards.length > 6 ? '...' : ''}

CONTEXT:
$gameContext

CARD ANALYSIS:
$cardAnalysis

CONTRACT KNOWLEDGE:
${_getContractStrategy(contract)}

CHALLENGE: 
Consider the contract rules, current trick state, and your available cards. 
What is the most strategic card to play that best serves your objectives?

Think through:
- What are the risks and benefits of each card?
- How does the current trick situation affect your choice?
- What are the potential consequences of your decision?
- Which card best aligns with the contract strategy?

Respond with your decision in JSON format:
{"suit": [0=Hearts,1=Diamonds,2=Clubs,3=Spades], "rank": [2-10,11=J,12=Q,13=K,14=A]}

Example: {"suit": 2, "rank": 3} for Three of Clubs''';
  }

  String _getContractStrategy(String? contract) {
    switch (contract) {
      case 'King of Hearts':
        return '''- CRITICAL: NEVER play King of Hearts unless absolutely forced (-75 points)
- If you HAVE King♥: Avoid winning heart tricks, play low hearts when safe, duck under tricks
- If you DON'T HAVE King♥: FORCE the holder to play it by leading hearts aggressively
- Advanced offensive tactics (when you DON'T have King♥):
  * Lead Ace of Hearts to force King♥ out (highest pressure)
  * Lead Queen of Hearts or Jack of Hearts to apply pressure
  * Follow with higher hearts to make King♥ holder take tricks
  * In late game, lead any heart when King♥ is still out there
  * Track who ducked heart tricks (likely King♥ holder)
- Advanced defensive tactics (when you HAVE King♥):
  * NEVER lead hearts unless absolutely forced
  * When following hearts, play lowest possible heart that won't win
  * Duck under high heart leads (let others take those tricks)
  * Count hearts played to know when it's safer to play King♥
  * Hold King♥ until last resort or end game
- Memory tracking: Remember who avoided heart tricks - they likely have King♥
- Endgame: If King♥ still unplayed and few hearts left, be extra cautious''';
      case 'Queens':
        return '''- CRITICAL: NEVER play Queens unless absolutely forced (-25 each)
- If you HAVE Queens: Avoid leading suits where you have Queens, duck under Queen tricks
- If you DON'T HAVE Queens: Force others to play them by leading high cards
- Advanced offensive tactics (when you DON'T have Queens):
  * Lead Aces and Kings in suits where others likely have Queens
  * Force high-card battles to make Queen holders play them
  * Target players who avoided certain suits (likely have Queens there)
  * In late game, lead suits where Queens haven't appeared yet
- Advanced defensive tactics (when you HAVE Queens):
  * NEVER lead suits where you hold Queens
  * When following, duck under high cards to avoid winning with Queens
  * Play other suits first to void yourself and create escape routes
  * Track which Queens have been played (4 total) for safety assessment
- Count Queens played to know remaining danger level
- Endgame: Be extra careful with remaining Queens in final tricks''';
      case 'Diamonds':
        return '''- AVOID taking any Diamond cards (-10 each, 13 total = -130 max penalty)
- If you HAVE many Diamonds: Play other suits first, avoid winning diamond tricks
- If you have FEW/NO Diamonds: Lead diamonds aggressively to force others to take them
- Advanced offensive tactics (when you have FEW diamonds):
  * Lead high diamonds (A♦, K♦, Q♦) to force others to take penalty cards
  * Follow with more diamonds to keep pressure on diamond-heavy players
  * Force void creation - make others run out of other suits so they must take diamonds
  * Target players who seem to have many diamonds
- Advanced defensive tactics (when you HAVE many diamonds):
  * NEVER lead diamonds unless absolutely forced
  * Lead other suits aggressively to avoid diamond tricks
  * When following diamonds, play lowest possible to avoid winning
  * Create voids in other suits to have escape cards when diamonds are led
  * Count diamonds played (13 total) to assess remaining danger
- Strategic void creation: Get rid of diamonds early if possible by playing other suits
- Endgame: Be extra careful with remaining diamonds, especially high ones''';
      case 'Collections':
        return '''Collections Contract Rules & Strategy:
- Penalty: -15 points for EACH trick taken during the round
- Objective: Take as few tricks as possible (ideally zero)
- Risk Factors: High cards (J/Q/K/A) have high trick-winning potential

Key Strategic Considerations:
* Card Value Impact: Higher rank cards are more likely to win tricks
* Trick Position: Leading vs following affects optimal play
* Risk Assessment: Weigh potential gains vs penalty costs
* Card Management: Balance between clearing dangerous cards and safety

Tactical Knowledge:
* Low cards (2-7): Historically safer, lower trick-winning probability
* Medium cards (8-10): Moderate risk, context-dependent safety
* High cards (J/Q/K/A): Higher risk of winning tricks accidentally
* Following suits: Must consider what's already been played
* Leading tricks: No constraints but must avoid easy wins for others

Advanced Concepts:
* Trick Reading: Analyze played cards to assess winning probability
* Safe Disposal: Sometimes worth "wasting" a safe card vs risking a dangerous one
* Endgame Considerations: Late-round dynamics can change optimal strategy
* Player Behavior: Others' aggressive play can create opportunities

Remember: This contract rewards defensive, risk-averse play over aggressive optimization.''';
      case 'Trex':
        return '''- Goal: Get rid of all cards first (+200 points for first place)
- Jacks can ALWAYS be played to start new suit sequences (critical rule)
- Other cards can only be played if they extend existing sequences (adjacent rank)
- Advanced strategic tactics:
  * Jack placement: Play Jacks in suits where you have the most consecutive cards
  * Sequence building: Create sequences that maximize your hand reduction
  * Blocking strategy: Play cards that prevent opponents from extending their sequences
  * Hold strategic Jacks: Sometimes keep Jacks for later when you need to break deadlocks
  * Observe the layout: Play cards that help you more than they help opponents
  * Multi-suit strategy: Work on multiple sequences simultaneously
- Hand management:
  * Prioritize sequences where you have multiple consecutive cards
  * Get rid of isolated high cards early when possible
  * Keep versatile cards (Jacks, middle ranks) for flexibility
  * Plan several moves ahead to avoid getting stuck
- Competitive play:
  * Block opponents by playing cards they likely need for their sequences
  * Force opponents to use their Jacks suboptimally
  * Rush to finish when you have a clear path to empty your hand
- If no valid moves exist, you must pass your turn (this is normal in Trex)
- Endgame: Play aggressively to empty hand first, use all remaining Jacks''';
      default:
        return '- Play strategically based on current situation';
    }
  }

  Map<String, dynamic> _analyzeHandForPrompt(List<Card> hand) {
    int hearts = 0;
    int diamonds = 0;
    int queens = 0;
    bool hasJacks = false;
    bool hasKingOfHearts = false;
    int highCards = 0;
    
    for (Card card in hand) {
      if (card.suit == Suit.hearts) {
        hearts++;
        if (card.rank == Rank.king) hasKingOfHearts = true;
      } else if (card.suit == Suit.diamonds) {
        diamonds++;
      }
      
      if (card.rank == Rank.queen) queens++;
      if (card.rank == Rank.jack) hasJacks = true;
      if (card.rank.value >= 10) highCards++;
    }
    
    return {
      'hearts': hearts,
      'diamonds': diamonds,
      'queens': queens,
      'hasJacks': hasJacks,
      'hasKingOfHearts': hasKingOfHearts,
      'highCards': highCards,
    };
  }

  /// Analyze valid cards to provide strategic recommendations
  String _analyzeValidCards(List<Card> validCards, String contract) {
    final analysis = <String>[];
    
    // Count cards by suit
    final heartCount = validCards.where((c) => c.suit == Suit.hearts).length;
    final diamondCount = validCards.where((c) => c.suit == Suit.diamonds).length;
    final clubCount = validCards.where((c) => c.suit == Suit.clubs).length;
    final spadeCount = validCards.where((c) => c.suit == Suit.spades).length;
    
    // Check for dangerous cards
    final hasKingOfHearts = validCards.any((c) => c.suit == Suit.hearts && c.rank == Rank.king);
    final hasQueens = validCards.where((c) => c.rank == Rank.queen).toList();
    final hasDiamonds = validCards.where((c) => c.suit == Suit.diamonds).toList();
    
    // Contract-specific analysis
    switch (contract) {
      case 'King of Hearts':
        if (hasKingOfHearts) {
          analysis.add('💀 CRITICAL DANGER: You HAVE the King of Hearts! (-75 points if played)');
          analysis.add('🛡️ DEFENSIVE MODE: Avoid heart tricks at all costs');
          analysis.add('🎯 Strategy: Duck under heart leads, never lead hearts, play lowest hearts');
        } else {
          analysis.add('✅ SAFE: You DON\'T have King of Hearts');
          analysis.add('⚔️ OFFENSIVE MODE: Force the King holder to play it');
          analysis.add('🎯 Strategy: Lead high hearts to apply maximum pressure');
        }
        if (heartCount > 0) {
          final lowestHeart = validCards.where((c) => c.suit == Suit.hearts)
              .reduce((a, b) => a.rank.value < b.rank.value ? a : b);
          final highestHeart = validCards.where((c) => c.suit == Suit.hearts)
              .reduce((a, b) => a.rank.value > b.rank.value ? a : b);
          if (hasKingOfHearts) {
            analysis.add('♥️ Hearts available: $heartCount (ALWAYS play lowest: ${lowestHeart.rank.name})');
            analysis.add('🔍 King♥ in hand - duck under all heart tricks if possible');
          } else {
            analysis.add('♥️ Hearts available: $heartCount (lead highest: ${highestHeart.rank.name} to force King♥)');
            if (highestHeart.rank == Rank.ace) {
              analysis.add('🎯 ACE OF HEARTS: Maximum pressure card - lead this to force King♥!');
            } else if (highestHeart.rank == Rank.queen) {
              analysis.add('🎯 QUEEN OF HEARTS: High pressure card - lead this to force King♥');
            }
          }
        } else {
          analysis.add('♥️ No hearts in valid cards');
          if (!hasKingOfHearts) {
            analysis.add('✅ Can lead other suits safely to set up heart pressure later');
          }
        }
        break;
        
      case 'Queens':
        if (hasQueens.isNotEmpty) {
          analysis.add('⚠️ DANGER: You have ${hasQueens.length} Queens! Avoid playing them.');
          analysis.add('🛡️ Defensive strategy: Duck under Queen tricks, avoid leading Queen suits');
        } else {
          analysis.add('✅ SAFE: You don\'t have any Queens');
          analysis.add('⚔️ Offensive strategy: Force others to play Queens by leading high cards');
        }
        final nonQueens = validCards.where((c) => c.rank != Rank.queen).toList();
        if (nonQueens.isNotEmpty) {
          final lowestSafe = nonQueens.reduce((a, b) => a.rank.value < b.rank.value ? a : b);
          analysis.add('✅ Safe cards: ${nonQueens.length} (lowest: ${lowestSafe.rank.name} ${lowestSafe.suit.name})');
        }
        break;
        
      case 'Diamonds':
        if (hasDiamonds.isNotEmpty) {
          analysis.add('⚠️ DANGER: You have ${hasDiamonds.length} Diamonds! Avoid taking diamond tricks.');
          analysis.add('🛡️ Defensive strategy: Play other suits, avoid winning with diamonds');
        } else {
          analysis.add('✅ SAFE: You have no Diamonds (void)');
          analysis.add('⚔️ Offensive strategy: Lead other suits, force others to take diamonds');
        }
        final nonDiamonds = validCards.where((c) => c.suit != Suit.diamonds).toList();
        if (nonDiamonds.isNotEmpty) {
          final lowestSafe = nonDiamonds.reduce((a, b) => a.rank.value < b.rank.value ? a : b);
          analysis.add('✅ Safe cards: ${nonDiamonds.length} (lowest: ${lowestSafe.rank.name} ${lowestSafe.suit.name})');
        } else if (hasDiamonds.isNotEmpty) {
          final lowestDiamond = hasDiamonds.reduce((a, b) => a.rank.value < b.rank.value ? a : b);
          analysis.add('💎 Must play diamond (lowest: ${lowestDiamond.rank.name})');
        }
        break;
        
      case 'Collections':
        final lowestCard = validCards.reduce((a, b) => a.rank.value < b.rank.value ? a : b);
        final highestCard = validCards.reduce((a, b) => a.rank.value > b.rank.value ? a : b);
        
        // Categorize cards by risk level
        final lowCards = validCards.where((c) => c.rank.value <= 7).length;
        final midCards = validCards.where((c) => c.rank.value >= 8 && c.rank.value <= 10).length;
        final highCards = validCards.where((c) => c.rank.value >= 11).length;
        
        analysis.add('🎯 COLLECTIONS: NEVER take tricks (-15 points each)');
        analysis.add('🃏 Card distribution: Low(2-7): $lowCards, Mid(8-10): $midCards, High(J-A): $highCards');
        analysis.add('📊 Range: ${lowestCard.rank.name} to ${highestCard.rank.name}');
        
        // Critical analysis for Collections
        if (highCards > 0) {
          analysis.add('💀 CRITICAL DANGER: You have $highCards high cards (J/Q/K/A)');
          analysis.add('⚠️ HIGH CARDS ARE EXTREMELY DANGEROUS - they can easily win tricks!');
          analysis.add('�️ DEFENSIVE STRATEGY: Only play high cards if you\'re 100% sure they won\'t win');
        }
        
        // Always recommend lowest card in Collections for safety
        analysis.add('✅ SAFEST PLAY: ${lowestCard.rank.name} ${lowestCard.suit.name} (lowest available)');
        analysis.add('🎯 Collections Rule: When in doubt, ALWAYS play your lowest card');
        
        if (highestCard.rank.value >= 12) {
          analysis.add('� EXTREME CAUTION: You have Queens/Kings/Aces - these almost always win tricks!');
        }
        
        analysis.add('🔥 Remember: Even ONE trick taken = -15 points penalty!');
        break;
        
      case 'Trex':
        final jacks = validCards.where((c) => c.rank == Rank.jack).toList();
        final sequentialCards = validCards.where((c) => c.rank != Rank.jack).toList();
        
        if (jacks.isNotEmpty) {
          analysis.add('🃏 Jacks available: ${jacks.length} (can start new sequences)');
        }
        if (sequentialCards.isNotEmpty) {
          analysis.add('🔗 Sequential cards: ${sequentialCards.length} (can extend existing sequences)');
        }
        if (validCards.isEmpty) {
          analysis.add('⏭️ No valid moves - must pass turn');
        } else {
          analysis.add('🎯 Strategy: Play Jacks first, then extend sequences');
        }
        break;
    }
    
    // Add suit distribution info
    analysis.add('📊 Suits: ♥️$heartCount ♦️$diamondCount ♣️$clubCount ♠️$spadeCount');
    
    return analysis.join('\n');
  }

  // Enhanced game state builders
  Map<String, dynamic> _buildOptimizedGameState(TrexGame game, PlayerPosition position) {
    final player = game.getPlayerByPosition(position);
    return {
      'kingdom': game.kingdom,
      'round': game.round,
      'position': position.arabicName,
      'usedContracts': game.usedContracts.length,
      'player': player, // Add player for hand analysis
    };
  }

  Map<String, dynamic> _buildOptimizedCardGameState(TrexGame game, List<Card> hand, List<Card> validCards) {
    // Build current trick info
    Map<String, String>? currentTrick;
    if (game.currentTrick != null && game.currentTrick!.cards.isNotEmpty) {
      currentTrick = {};
      for (var entry in game.currentTrick!.cards.entries) {
        currentTrick[entry.key.arabicName] = '${entry.value.rank.arabicName} ${entry.value.suit.arabicName}';
      }
    }
    
    return {
      'contract': game.currentContract?.arabicName ?? 'None',
      'handSize': hand.length,
      'validCount': validCards.length,
      'currentTrick': currentTrick,
      'tricksPlayed': game.tricks.length,
    };
  }

  // Enhanced API call with provider-specific configuration and model fallback
  Future<String> _callProviderAPI(String prompt, Duration timeout) async {
    try {
      if (kDebugMode) {
        print('🌐 Making API call to $_provider...');
        print('📝 Prompt length: ${prompt.length} chars');
      }

      final providerConfig = AIConfig.getProviderConfig(_provider);
      
      // Try multiple models for DeepSeek if the first one fails
      List<String> modelsToTry = [];
      if (_provider == 'deepseek') {
        modelsToTry = [
          'deepseek-chat',
          'deepseek-coder', 
          'deepseek-reasoner',
          'gpt-3.5-turbo-instruct', // Some DeepSeek APIs use OpenAI-compatible model names
          'text-davinci-003',
        ];
      } else {
        modelsToTry = [_model];
      }

      Exception? lastException;
      
      for (String modelToTry in modelsToTry) {
        try {
          final requestBody = {
            'model': modelToTry,
            'messages': [
              {
                'role': 'system', 
                'content': 'You are an expert Trix card game player. Always respond with valid JSON only.'
              },
              {
                'role': 'user', 
                'content': prompt
              }
            ],
            'temperature': providerConfig['temperature'],
            'max_tokens': providerConfig['max_tokens'],
            'top_p': providerConfig['top_p'],
          };

          final headers = <String, String>{
            'Content-Type': 'application/json',
            'User-Agent': 'TrixGame/1.0',
          };

          // Provider-specific headers
          if (_provider == 'openai') {
            headers['Authorization'] = 'Bearer $_apiKey';
          } else {
            headers['Authorization'] = 'Bearer $_apiKey';
          }

          final response = await _httpClient.post(
            Uri.parse(_baseUrl),
            headers: headers,
            body: json.encode(requestBody),
          ).timeout(timeout);

          if (kDebugMode) {
            print('📡 $_provider API Response Status: ${response.statusCode} (model: $modelToTry)');
          }

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final content = data['choices']?[0]?['message']?['content'] ?? '';
            
            if (kDebugMode) {
              print('✅ $_provider API Success with model $modelToTry: $content');
            }
            
            return content;
          } else {
            final errorBody = response.body;
            if (kDebugMode) {
              print('❌ $_provider API Error ${response.statusCode} with model $modelToTry: $errorBody');
            }
            
            // If it's a model not found error, try the next model
            if (response.statusCode == 404 && errorBody.contains('model')) {
              if (kDebugMode) {
                print('🔄 Model $modelToTry not found, trying next model...');
              }
              lastException = Exception('Model $modelToTry not found: ${response.statusCode} - $errorBody');
              continue; // Try next model
            } else {
              // For other errors, don't retry
              throw Exception('$_provider API call failed: ${response.statusCode} - $errorBody');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('💥 $_provider API Exception with model $modelToTry: $e');
          }
          lastException = e is Exception ? e : Exception(e.toString());
          
          // If it's a timeout or network error, don't try other models
          if (e.toString().contains('TimeoutException') || 
              e.toString().contains('SocketException')) {
            rethrow;
          }
          
          // Otherwise, try next model
          continue;
        }
      }
      
      // If we get here, all models failed
      throw lastException ?? Exception('All models failed for $_provider');
      
    } catch (e) {
      if (kDebugMode) {
        print('💥 $_provider API Final Exception: $e');
      }
      rethrow;
    }
  }

  /// Test API connection and diagnose issues
  Future<Map<String, dynamic>> testConnection() async {
    final result = <String, dynamic>{
      'success': false,
      'error': null,
      'responseTime': 0,
      'apiKeyValid': false,
      'networkReachable': false,
    };

    final startTime = DateTime.now();

    try {
      if (kDebugMode) {
        print('🔍 Testing AI API connection...');
      }

      // Test with a very simple prompt
      final testPrompt = '''Test connection. Respond with JSON: {"status": "ok"}''';
      
      final requestBody = {
        'model': _model,
        'messages': [
          {'role': 'user', 'content': testPrompt}
        ],
        'max_tokens': 50,
      };

      final response = await _httpClient.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 10));

      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      result['responseTime'] = responseTime;
      result['networkReachable'] = true;

      if (response.statusCode == 200) {
        result['success'] = true;
        result['apiKeyValid'] = true;
        
        if (kDebugMode) {
          print('✅ API connection successful (${responseTime}ms)');
        }
      } else {
        result['error'] = 'HTTP ${response.statusCode}: ${response.body}';
        result['apiKeyValid'] = response.statusCode != 401;
        
        if (kDebugMode) {
          print('❌ API error: ${result['error']}');
        }
      }

    } catch (e) {
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      result['responseTime'] = responseTime;
      result['error'] = e.toString();
      
      if (e.toString().contains('TimeoutException')) {
        result['networkReachable'] = false;
        if (kDebugMode) {
          print('❌ Connection timeout after ${responseTime}ms');
        }
      } else {
        if (kDebugMode) {
          print('❌ Connection error: $e');
        }
      }
    }

    return result;
  }

  /// Enhanced test with detailed step-by-step timing
  Future<Map<String, dynamic>> testConnectionWithDebug() async {
    final result = <String, dynamic>{
      'success': false,
      'error': null,
      'totalTime': 0,
      'steps': <Map<String, dynamic>>[],
      'apiKeyValid': false,
      'networkReachable': false,
      'details': <String, dynamic>{},
    };

    final overallStart = DateTime.now();
    
    try {
      if (kDebugMode) {
        print('🔍 Starting detailed API connection test...');
      }

      // Step 1: API Key validation
      var stepStart = DateTime.now();
      result['steps'].add({
        'step': 'API Key Validation',
        'startTime': stepStart.millisecondsSinceEpoch,
        'duration': 0,
        'status': 'running'
      });

      if (_apiKey.isEmpty || _apiKey == 'YOUR_DEEPSEEK_API_KEY_HERE') {
        result['steps'].last['duration'] = DateTime.now().difference(stepStart).inMilliseconds;
        result['steps'].last['status'] = 'failed';
        result['steps'].last['error'] = 'Invalid or missing API key';
        result['error'] = 'API key is not configured properly';
        return result;
      }

      result['steps'].last['duration'] = DateTime.now().difference(stepStart).inMilliseconds;
      result['steps'].last['status'] = 'success';
      result['apiKeyValid'] = true;

      // Step 2: Request preparation
      stepStart = DateTime.now();
      result['steps'].add({
        'step': 'Request Preparation',
        'startTime': stepStart.millisecondsSinceEpoch,
        'duration': 0,
        'status': 'running'
      });

      final testPrompt = '''Test connection. Respond with JSON: {"status": "ok", "message": "Connection successful"}''';
      
      // Use the correct model based on the provider
      final modelToUse = _provider == 'openai' ? 'gpt-3.5-turbo' : 'deepseek-chat';
      
      final requestBody = {
        'model': modelToUse,
        'messages': [
          {'role': 'user', 'content': testPrompt}
        ],
        'max_tokens': 50,
        'temperature': 0.1,
      };

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
        'User-Agent': 'TrixGame/1.0-Debug',
      };

      result['steps'].last['duration'] = DateTime.now().difference(stepStart).inMilliseconds;
      result['steps'].last['status'] = 'success';
      result['details']['requestSize'] = json.encode(requestBody).length;
      result['details']['headers'] = headers.keys.toList();

      // Step 3: DNS Resolution simulation (check if we can reach the host)
      stepStart = DateTime.now();
      result['steps'].add({
        'step': 'Network Check',
        'startTime': stepStart.millisecondsSinceEpoch,
        'duration': 0,
        'status': 'running'
      });

      try {
        // Try to parse the URL to check if it's valid
        final uri = Uri.parse(_baseUrl);
        result['details']['host'] = uri.host;
        result['details']['scheme'] = uri.scheme;
        result['details']['port'] = uri.port;
        
        result['steps'].last['duration'] = DateTime.now().difference(stepStart).inMilliseconds;
        result['steps'].last['status'] = 'success';
        result['networkReachable'] = true;
      } catch (e) {
        result['steps'].last['duration'] = DateTime.now().difference(stepStart).inMilliseconds;
        result['steps'].last['status'] = 'failed';
        result['steps'].last['error'] = 'Invalid URL: $e';
        result['error'] = 'Network configuration error';
        return result;
      }

      // Step 4: HTTP Request
      stepStart = DateTime.now();
      result['steps'].add({
        'step': 'HTTP Request',
        'startTime': stepStart.millisecondsSinceEpoch,
        'duration': 0,
        'status': 'running'
      });

      final response = await _httpClient.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: json.encode(requestBody),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out after 10 seconds', const Duration(seconds: 10));
        },
      );

      final requestDuration = DateTime.now().difference(stepStart).inMilliseconds;
      result['steps'].last['duration'] = requestDuration;
      result['details']['httpStatusCode'] = response.statusCode;
      result['details']['responseHeaders'] = response.headers.keys.toList();
      result['details']['responseSize'] = response.body.length;

      // Step 5: Response Processing
      stepStart = DateTime.now();
      result['steps'].add({
        'step': 'Response Processing',
        'startTime': stepStart.millisecondsSinceEpoch,
        'duration': 0,
        'status': 'running'
      });

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          final content = data['choices']?[0]?['message']?['content'] ?? '';
          
          result['details']['responseContent'] = content;
          result['details']['aiModel'] = data['model'];
          result['details']['usage'] = data['usage'];
          
          result['steps'].last['duration'] = DateTime.now().difference(stepStart).inMilliseconds;
          result['steps'].last['status'] = 'success';
          result['steps'][3]['status'] = 'success'; // HTTP request was successful
          result['success'] = true;

          if (kDebugMode) {
            print('✅ API test successful - Response: $content');
          }
        } catch (e) {
          result['steps'].last['duration'] = DateTime.now().difference(stepStart).inMilliseconds;
          result['steps'].last['status'] = 'failed';
          result['steps'].last['error'] = 'JSON parsing failed: $e';
          result['steps'][3]['status'] = 'partial'; // HTTP succeeded but parsing failed
          result['error'] = 'Response parsing error: $e';
        }
      } else {
        result['steps'].last['duration'] = DateTime.now().difference(stepStart).inMilliseconds;
        result['steps'].last['status'] = 'failed';
        result['steps'][3]['status'] = 'failed'; // HTTP request failed
        
        final errorBody = response.body;
        result['error'] = 'HTTP ${response.statusCode}: $errorBody';
        result['details']['errorResponse'] = errorBody;
        
        // Determine if it's an auth issue
        result['apiKeyValid'] = response.statusCode != 401 && response.statusCode != 403;
        
        if (kDebugMode) {
          print('❌ API error ${response.statusCode}: $errorBody');
        }
      }

    } catch (e) {
      final errorType = e.runtimeType.toString();
      result['details']['errorType'] = errorType;
      
      if (e is TimeoutException) {
        result['error'] = 'Request timed out after ${e.duration?.inSeconds ?? 10} seconds';
        result['details']['timeoutDuration'] = e.duration?.inSeconds ?? 10;
        if (result['steps'].isNotEmpty) {
          result['steps'].last['status'] = 'timeout';
          result['steps'].last['error'] = 'Request timed out';
        }
      } else if (e.toString().contains('SocketException')) {
        result['error'] = 'Network connection failed - check internet connection';
        result['networkReachable'] = false;
        result['details']['networkError'] = e.toString();
      } else if (e.toString().contains('HandshakeException')) {
        result['error'] = 'SSL/TLS handshake failed - possible certificate issue';
        result['details']['sslError'] = e.toString();
      } else if (e.toString().contains('FormatException')) {
        result['error'] = 'Invalid response format received';
        result['details']['formatError'] = e.toString();
      } else {
        result['error'] = 'Unexpected error: $e';
        result['details']['unexpectedError'] = e.toString();
      }

      if (result['steps'].isNotEmpty) {
        result['steps'].last['duration'] = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(result['steps'].last['startTime'])
        ).inMilliseconds;
        if (result['steps'].last['status'] == 'running') {
          result['steps'].last['status'] = 'failed';
          result['steps'].last['error'] = result['error'];
        }
      }

      if (kDebugMode) {
        print('💥 API test exception ($errorType): $e');
      }
    }

    result['totalTime'] = DateTime.now().difference(overallStart).inMilliseconds;
    
    if (kDebugMode) {
      print('🏁 API test completed in ${result['totalTime']}ms');
      print('📊 Steps breakdown:');
      for (var step in result['steps']) {
        print('  ${step['step']}: ${step['duration']}ms [${step['status']}]');
      }
    }

    return result;
  }

  /// Reduce timeout for faster fallbacks during gameplay
  Future<TrexContract?> selectContractWithFastFallback({
    required PlayerPosition botPosition,
    required TrexGame game,
    required List<TrexContract> availableContracts,
  }) async {
    if (availableContracts.isEmpty) return null;

    try {
      // Use longer timeout for contract selection (6 seconds)
      final gameState = _buildOptimizedGameState(game, botPosition);
      final prompt = _buildOptimizedContractPrompt(gameState, availableContracts, botPosition);
      
      final response = await _callProviderAPI(prompt, const Duration(seconds: 6));
      final selectedContract = _parseContractResponse(response, availableContracts);
      
      if (selectedContract != null) {
        if (kDebugMode) {
          print('⚡ Fast AI contract selection: ${selectedContract.arabicName}');
        }
        return selectedContract;
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚡ Fast AI failed, using fallback: $e');
      }
    }
    
    return _fallbackContractSelection(game, botPosition, availableContracts);
  }

  /// Fast card selection with quick fallback
  Future<Card?> selectCardWithFastFallback({
    required PlayerPosition botPosition,
    required TrexGame game,
    required List<Card> hand,
    required List<Card> validCards,
  }) async {
    if (validCards.isEmpty) return null;

    try {
      // Use shorter timeout for gameplay (4 seconds for better success rate)
      final gameState = _buildOptimizedCardGameState(game, hand, validCards);
      final prompt = _buildOptimizedCardPrompt(gameState, validCards);
      
      final response = await _callProviderAPI(prompt, const Duration(seconds: 4));
      final selectedCard = _parseCardResponse(response, validCards) ?? 
                          _contractAwareFallbackCard(validCards, game.currentContract?.arabicName);
      
      if (kDebugMode) {
        if (selectedCard != null) {
          print('⚡ Fast AI card selection: ${selectedCard.rank.arabicName} ${selectedCard.suit.arabicName}');
        } else {
          print('⏭️ Fast AI passed turn (no valid moves)');
        }
      }
      return selectedCard;
    } catch (e) {
      if (kDebugMode) {
        print('⚡ Fast AI failed, using contract-aware fallback: $e');
      }
    }
    
    // Use contract-aware fallback instead of basic fallback
    return _contractAwareFallbackCard(validCards, game.currentContract?.arabicName);
  }

  // Helper methods for cache lookup
  TrexContract? _findContractByName(String name, List<TrexContract> contracts) {
    return contracts.firstWhere(
      (c) => c.arabicName == name,
      orElse: () => contracts.first,
    );
  }

  Card? _findCardFromCache(String cacheData, List<Card> validCards) {
    final parts = cacheData.split('-');
    if (parts.length != 2) return validCards.first;
    
    final suitIndex = int.tryParse(parts[0]);
    final rankValue = int.tryParse(parts[1]);
    
    return validCards.firstWhere(
      (c) => c.suit.index == suitIndex && c.rank.value == rankValue,
      orElse: () => validCards.first,
    );
  }

  // Parse AI response for contract selection
  TrexContract? _parseContractResponse(String response, List<TrexContract> availableContracts) {
    try {
      if (kDebugMode) {
        print('🔍 Parsing AI contract response: ${response.trim()}');
      }
      
      // Try to extract JSON from response
      final jsonMatch = RegExp(r'\{[^}]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        final data = json.decode(jsonStr);
        
        if (data['contract'] != null) {
          final contractName = data['contract'].toString();
          
          // Find matching contract by name (flexible matching)
          for (final contract in availableContracts) {
            if (contract.arabicName.toLowerCase().contains(contractName.toLowerCase()) ||
                contractName.toLowerCase().contains(contract.arabicName.toLowerCase())) {
              if (kDebugMode) {
                print('✅ Successfully parsed contract: ${contract.arabicName}');
              }
              return contract;
            }
          }
        }
      }
      
      // Try to match contract names directly in response text
      for (final contract in availableContracts) {
        if (response.toLowerCase().contains(contract.arabicName.toLowerCase())) {
          if (kDebugMode) {
            print('✅ Found contract in text: ${contract.arabicName}');
          }
          return contract;
        }
      }
      
      if (kDebugMode) {
        print('⚠️ Could not parse contract response, using fallback');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error parsing contract response: $e');
      }
    }
    
    // Fallback to first available
    return availableContracts.first;
  }

  // Parse AI response for card selection
  Card? _parseCardResponse(String response, List<Card> validCards) {
    try {
      if (kDebugMode) {
        print('🔍 Parsing AI card response: ${response.trim()}');
        print('🎯 Valid cards available: ${validCards.map((c) => '${c.rank.name} ${c.suit.name}').join(', ')}');
      }
      
      // Try to extract JSON from response
      final jsonMatch = RegExp(r'\{[^}]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        final data = json.decode(jsonStr);
        
        if (data['suit'] != null && data['rank'] != null) {
          final suitIndex = int.tryParse(data['suit'].toString());
          final rankValue = int.tryParse(data['rank'].toString());
          
          if (suitIndex != null && rankValue != null) {
            // Validate the suit index and rank value are reasonable
            if (suitIndex >= 0 && suitIndex <= 3 && rankValue >= 2 && rankValue <= 14) {
              // Find matching card from valid cards
              final matchingCards = validCards.where(
                (card) => card.suit.index == suitIndex && card.rank.value == rankValue,
              ).toList();
              
              if (matchingCards.isNotEmpty) {
                final targetCard = matchingCards.first;
                if (kDebugMode) {
                  print('✅ Successfully parsed card: ${targetCard.rank.name} ${targetCard.suit.name}');
                }
                return targetCard;
              } else {
                if (kDebugMode) {
                  print('❌ AI chose invalid card: Suit=$suitIndex (${_getSuitName(suitIndex)}), Rank=$rankValue (${_getRankName(rankValue)})');
                  print('   Available options: ${validCards.map((c) => '${c.rank.name} ${c.suit.name}').join(', ')}');
                  print('   This suggests the AI is not understanding the game rules correctly.');
                  print('   For Trex: Only Jacks can start new sequences, other cards must be sequential.');
                  print('   For other contracts: Must follow suit or play appropriate penalty-avoiding cards.');
                }
              }
            } else {
              if (kDebugMode) {
                print('⚠️ Invalid suit/rank values: Suit=$suitIndex, Rank=$rankValue');
                print('   Expected: Suit 0-3, Rank 2-14');
              }
            }
          }
        }
      }
      
      // Try to match card notation like "H4", "S7", "C9"
      final cardMatch = RegExp(r'([HDCS])(\d+|[JQKA])').firstMatch(response);
      if (cardMatch != null) {
        final suitChar = cardMatch.group(1)!;
        final rankStr = cardMatch.group(2)!;
        
        Suit? targetSuit;
        switch (suitChar) {
          case 'H': targetSuit = Suit.hearts; break;
          case 'D': targetSuit = Suit.diamonds; break;
          case 'C': targetSuit = Suit.clubs; break;
          case 'S': targetSuit = Suit.spades; break;
        }
        
        if (targetSuit != null) {
          int? rankValue;
          switch (rankStr) {
            case 'J': rankValue = 11; break;
            case 'Q': rankValue = 12; break;
            case 'K': rankValue = 13; break;
            case 'A': rankValue = 14; break;
            default: rankValue = int.tryParse(rankStr); break;
          }
          
          if (rankValue != null) {
            final matchingCards = validCards.where(
              (card) => card.suit == targetSuit && card.rank.value == rankValue,
            ).toList();
            
            if (matchingCards.isNotEmpty) {
              final targetCard = matchingCards.first;
              if (kDebugMode) {
                print('✅ Parsed card from notation: ${targetCard.rank.name} ${targetCard.suit.name}');
              }
              return targetCard;
            }
          }
        }
      }
      
      if (kDebugMode) {
        print('⚠️ Could not parse card response, using fallback');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error parsing card response: $e');
      }
    }
    
    // Fallback: use contract-aware strategy
    return null; // Let the caller handle fallback
  }

  /// Simple fallback contract selection
  TrexContract? _fallbackContractSelection(TrexGame game, PlayerPosition position, List<TrexContract> contracts) {
    if (contracts.isEmpty) return null;
    
    if (kDebugMode) {
      print('🔄 Using fallback contract selection');
    }
    
    // Simple strategy: avoid penalty contracts, prefer safe ones
    final player = game.getPlayerByPosition(position);
    final hand = player.hand;
    
    // Check for dangerous cards
    final hasKingOfHearts = hand.any((c) => c.suit == Suit.hearts && c.rank == Rank.king);
    final queenCount = hand.where((c) => c.rank == Rank.queen).length;
    final diamondCount = hand.where((c) => c.suit == Suit.diamonds).length;
    final jackCount = hand.where((c) => c.rank == Rank.jack).length;
    final lowCardCount = hand.where((c) => c.rank.value <= 7).length;
    
    // Avoid dangerous contracts
    for (final contract in contracts) {
      switch (contract.arabicName) {
        case 'King of Hearts':
          if (!hasKingOfHearts) return contract; // Safe if we don't have King
          break;
        case 'Queens':
          if (queenCount == 0) return contract; // Safe if no Queens
          break;
        case 'Diamonds':
          if (diamondCount <= 2) return contract; // Safe if few diamonds
          break;
        case 'Collections':
          if (lowCardCount >= 8) return contract; // Good if many low cards
          break;
        case 'Trex':
          if (jackCount >= 2) return contract; // Good if have Jacks
          break;
      }
    }
    
    // Fallback to first available
    return contracts.first;
  }

  /// Contract-aware fallback for card selection with full game context
  Card? _contractAwareFallbackCard(List<Card> validCards, String? contract) {
    if (validCards.isEmpty) return null;
    
    if (kDebugMode) {
      print('🧠 Using contract-aware fallback for card selection');
      print('   Contract: $contract');
      print('   Valid cards: ${validCards.map((c) => '${c.rank.name}${c.suit.name}').join(', ')}');
    }
    
    final sortedCards = List<Card>.from(validCards)
      ..sort((a, b) => a.rank.value.compareTo(b.rank.value));
    
    Card? selectedCard;
    
    switch (contract) {
      case 'King of Hearts':
        // Check if we have King of Hearts
        final hasKingOfHearts = validCards.any((c) => c.suit == Suit.hearts && c.rank == Rank.king);
        final hearts = validCards.where((c) => c.suit == Suit.hearts).toList();
        
        if (hasKingOfHearts) {
          // DEFENSIVE: We have the dangerous card
          final nonKingHearts = hearts.where((c) => c.rank != Rank.king).toList();
          if (nonKingHearts.isNotEmpty) {
            // Play lowest heart that's not the King
            selectedCard = nonKingHearts.reduce((a, b) => a.rank.value < b.rank.value ? a : b);
            if (kDebugMode) {
              print('Defensive: Playing lowest heart (not King): ${selectedCard.rank.name} ${selectedCard.suit.name}');
            }
          } else {
            // Only have King of Hearts in hearts - play other suits
            final nonHearts = validCards.where((c) => c.suit != Suit.hearts).toList();
            if (nonHearts.isNotEmpty) {
              selectedCard = nonHearts.reduce((a, b) => a.rank.value < b.rank.value ? a : b);
              if (kDebugMode) {
                print('Avoiding hearts entirely: ${selectedCard.rank.name} ${selectedCard.suit.name}');
              }
            } else {
              // Forced to play King of Hearts
              selectedCard = validCards.firstWhere((c) => c.suit == Suit.hearts && c.rank == Rank.king);
              if (kDebugMode) {
                print('FORCED to play King of Hearts - no other choice!');
              }
            }
          }
        } else {
          // OFFENSIVE: We don't have King of Hearts
          if (hearts.isNotEmpty) {
            // Play highest heart to force the King out
            selectedCard = hearts.reduce((a, b) => a.rank.value > b.rank.value ? a : b);
            if (kDebugMode) {
              print('Offensive: Playing highest heart to force King: ${selectedCard.rank.name} ${selectedCard.suit.name}');
            }
          } else {
            // No hearts - play lowest card
            selectedCard = sortedCards.first;
            if (kDebugMode) {
              print('No hearts available: ${selectedCard.rank.name} ${selectedCard.suit.name}');
            }
          }
        }
        break;
        
      case 'Queens':
        // Avoid playing Queens
        final nonQueens = validCards.where((c) => c.rank != Rank.queen).toList();
        if (nonQueens.isNotEmpty) {
          selectedCard = nonQueens.reduce((a, b) => a.rank.value < b.rank.value ? a : b);
        } else {
          selectedCard = validCards.first; // Forced to play Queen
        }
        if (kDebugMode) {
          final hasQueen = selectedCard.rank == Rank.queen;
          print('${hasQueen ? 'FORCED to play Queen' : 'Safe play'}: ${selectedCard.rank.name} ${selectedCard.suit.name}');
        }
        break;
        
      case 'Diamonds':
        // Avoid playing Diamonds
        final nonDiamonds = validCards.where((c) => c.suit != Suit.diamonds).toList();
        if (nonDiamonds.isNotEmpty) {
          selectedCard = nonDiamonds.reduce((a, b) => a.rank.value < b.rank.value ? a : b);
        } else {
          selectedCard = validCards.reduce((a, b) => a.rank.value < b.rank.value ? a : b);
        }
        if (kDebugMode) {
          final isDiamond = selectedCard.suit == Suit.diamonds;
          print('${isDiamond ? 'FORCED to play Diamond' : 'Safe play'}: ${selectedCard.rank.name} ${selectedCard.suit.name}');
        }
        break;
        
      case 'Collections':
        // Always play lowest card to minimize trick-taking risk
        selectedCard = sortedCards.first;
        if (kDebugMode) {
          print('Collections: Playing lowest card: ${selectedCard.rank.name} ${selectedCard.suit.name}');
        }
        break;
        
      case 'Trex':
        // In Trex, we need to play sequential cards or Jacks
        final jacks = validCards.where((c) => c.rank == Rank.jack).toList();
        if (jacks.isNotEmpty) {
          selectedCard = jacks.first;
          if (kDebugMode) {
            print('TREX: Playing Jack to start sequence: ${selectedCard.rank.name} ${selectedCard.suit.name}');
          }
        } else {
          // Play sequential card (this is simplified - real logic would check existing sequences)
          selectedCard = sortedCards.first;
          if (kDebugMode) {
            print('TREX: Playing sequential card to extend');
          }
        }
        break;
        
      default:
        // Generic safe strategy
        selectedCard = sortedCards.first;
        if (kDebugMode) {
          print('Generic strategy: Playing lowest card: ${selectedCard.rank.name} ${selectedCard.suit.name}');
        }
    }
    
    return selectedCard;
  }

  // Helper methods for debug output
  String _getSuitName(int suitIndex) {
    switch (suitIndex) {
      case 0: return 'Hearts';
      case 1: return 'Diamonds';
      case 2: return 'Clubs';
      case 3: return 'Spades';
      default: return 'Unknown($suitIndex)';
    }
  }

  String _getRankName(int rankValue) {
    switch (rankValue) {
      case 11: return 'Jack';
      case 12: return 'Queen';
      case 13: return 'King';
      case 14: return 'Ace';
      default: return rankValue.toString();
    }
  }

  /// Dispose of resources and close HTTP client
  void dispose() {
    try {
      _httpClient.close();
      if (kDebugMode) {
        print('🔌 AIService disposed - HTTP client closed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error disposing AIService: $e');
      }
    }
  }
}