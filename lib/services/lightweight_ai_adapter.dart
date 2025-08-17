import '../models/game.dart';
import '../models/player.dart';
import '../models/card.dart';
import 'ai_service.dart';
import 'lightweight_ai_service.dart';

/// Adapter to make LightweightAIService compatible with AIService interface
class LightweightAIAdapter extends AIService {
  final LightweightAIService _lightweightAI = LightweightAIService();

  LightweightAIAdapter() : super(apiKey: 'lightweight');

  @override
  String get providerName => _lightweightAI.providerName;

  @override
  Future<TrexContract?> selectContractWithFastFallback({
    required PlayerPosition botPosition,
    required TrexGame game,
    required List<TrexContract> availableContracts,
  }) async {
    return await _lightweightAI.selectContract(
      botPosition: botPosition,
      game: game,
      availableContracts: availableContracts,
    );
  }

  @override
  Future<Card?> selectCardWithFastFallback({
    required PlayerPosition botPosition,
    required TrexGame game,
    required List<Card> hand,
    required List<Card> validCards,
  }) async {
    return await _lightweightAI.selectCard(
      botPosition: botPosition,
      game: game,
      hand: hand,
      validCards: validCards,
    );
  }

  @override
  Future<Map<String, dynamic>> testConnectionWithDebug() async {
    return await _lightweightAI.testConnectionWithDebug();
  }

  @override
  void dispose() {
    _lightweightAI.dispose();
    super.dispose();
  }
}
