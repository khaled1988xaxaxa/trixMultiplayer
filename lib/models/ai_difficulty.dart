/// AI difficulty levels for the Trix card game
enum AIDifficulty {
  beginner,
  novice,
  amateur,
  intermediate,
  advanced,
  expert,
  master,
  aimaster,
  perfect,
  khaled,
  mohammad,
  trixAgent0,
  trixAgent1,
  trixAgent2,
  trixAgent3,
  claudeSonnet,
  chatGPT,
  humanEnhanced,
  strategicElite,
  strategicEliteCorrected;

  /// Get Arabic name for the difficulty
  String get arabicName {
    switch (this) {
      case AIDifficulty.beginner:
        return 'مبتدئ';
      case AIDifficulty.novice:
        return 'مبتدئ متقدم';
      case AIDifficulty.amateur:
        return 'هاوي';
      case AIDifficulty.intermediate:
        return 'متوسط';
      case AIDifficulty.advanced:
        return 'متقدم';
      case AIDifficulty.expert:
        return 'خبير';
      case AIDifficulty.master:
        return 'أسطورة';
      case AIDifficulty.aimaster:
        return 'الذكي الأسطوري';
      case AIDifficulty.perfect:
        return 'مثالي';
      case AIDifficulty.khaled:
        return 'خالد';
      case AIDifficulty.mohammad:
        return 'محمد';
      case AIDifficulty.trixAgent0:
        return 'ترِكس ١';
      case AIDifficulty.trixAgent1:
        return 'ترِكس ٢';
      case AIDifficulty.trixAgent2:
        return 'ترِكس ٣';
      case AIDifficulty.trixAgent3:
        return 'ترِكس ٤';
      case AIDifficulty.claudeSonnet:
        return 'كلود سونيت';
      case AIDifficulty.chatGPT:
        return 'تشات جي بي تي';
      case AIDifficulty.humanEnhanced:
        return 'ذكي محسن بشريًا';
      case AIDifficulty.strategicElite:
        return 'الاستراتيجي المتقدم';
      case AIDifficulty.strategicEliteCorrected:
        return 'الاستراتيجي المصحح';
    }
  }

  /// Get English name for the difficulty
  String get englishName {
    switch (this) {
      case AIDifficulty.beginner:
        return 'Beginner';
      case AIDifficulty.novice:
        return 'Novice';
      case AIDifficulty.amateur:
        return 'Amateur';
      case AIDifficulty.intermediate:
        return 'Intermediate';
      case AIDifficulty.advanced:
        return 'Advanced';
      case AIDifficulty.expert:
        return 'Expert';
      case AIDifficulty.master:
        return 'Master';
      case AIDifficulty.aimaster:
        return 'AI-Master';
      case AIDifficulty.perfect:
        return 'Perfect';
      case AIDifficulty.khaled:
        return 'Khaled';
      case AIDifficulty.mohammad:
        return 'Mohammad';
      case AIDifficulty.trixAgent0:
        return 'Trix Agent 1';
      case AIDifficulty.trixAgent1:
        return 'Trix Agent 2';
      case AIDifficulty.trixAgent2:
        return 'Trix Agent 3';
      case AIDifficulty.trixAgent3:
        return 'Trix Agent 4';
      case AIDifficulty.claudeSonnet:
        return 'Claude Sonnet';
      case AIDifficulty.chatGPT:
        return 'ChatGPT';
      case AIDifficulty.humanEnhanced:
        return 'Human Enhanced';
      case AIDifficulty.strategicElite:
        return 'Strategic Elite';
      case AIDifficulty.strategicEliteCorrected:
        return 'Strategic Elite (Corrected)';
    }
  }

  /// Get description for the difficulty
  String get description {
    switch (this) {
      case AIDifficulty.beginner:
        return 'Makes basic moves, perfect for learning';
      case AIDifficulty.novice:
        return 'Understands basic rules and some strategy';
      case AIDifficulty.amateur:
        return 'Decent strategic play, suitable for casual games';
      case AIDifficulty.intermediate:
        return 'Good strategic understanding, challenging opponent';
      case AIDifficulty.advanced:
        return 'Strong strategic play with few mistakes';
      case AIDifficulty.expert:
        return 'Very strong play, near-optimal decisions';
      case AIDifficulty.master:
        return 'Master-level strategic depth, extremely challenging';
      case AIDifficulty.aimaster:
        return 'AI-Master level with advanced neural network intelligence';
      case AIDifficulty.perfect:
        return 'Mathematically optimal play, ultimate challenge';
      case AIDifficulty.khaled:
        return 'Custom trained model - Khaled\'s playing style';
      case AIDifficulty.mohammad:
        return 'Custom trained model - Mohammad\'s playing style';
      case AIDifficulty.trixAgent0:
        return 'Mobile-optimized Trix Agent 1 - Balanced strategic play';
      case AIDifficulty.trixAgent1:
        return 'Mobile-optimized Trix Agent 2 - Aggressive tactical style';
      case AIDifficulty.trixAgent2:
        return 'Mobile-optimized Trix Agent 3 - Defensive strategic style';
      case AIDifficulty.trixAgent3:
        return 'Mobile-optimized Trix Agent 4 - Advanced adaptive play';
      case AIDifficulty.claudeSonnet:
        return 'Elite AI trained with Claude Sonnet - Advanced reasoning and strategic thinking';
      case AIDifficulty.chatGPT:
        return 'Elite AI trained with ChatGPT - Dynamic gameplay and pattern recognition';
      case AIDifficulty.humanEnhanced:
        return 'Human-Enhanced PPO AI trained with supervised learning from 468 human card plays - Strategic penalty avoidance and human-like decision patterns';
      case AIDifficulty.strategicElite:
        return 'Strategic Elite AI with CORRECTED King of Hearts fix - 60-70% human performance with proper -75 point penalty avoidance';
      case AIDifficulty.strategicEliteCorrected:
        return 'Strategic Elite AI with ENHANCED King of Hearts fix - Emergency override system prevents AI from taking King of Hearts when other options exist';
    }
  }

  /// Get folder name for asset loading
  String get folderName {
    switch (this) {
      case AIDifficulty.beginner:
        return 'beginner_ai';
      case AIDifficulty.novice:
        return 'novice_ai';
      case AIDifficulty.amateur:
        return 'amateur_ai';
      case AIDifficulty.intermediate:
        return 'intermediate_ai';
      case AIDifficulty.advanced:
        return 'advanced_ai';
      case AIDifficulty.expert:
        return 'expert_ai';
      case AIDifficulty.master:
        return 'master_ai';
      case AIDifficulty.aimaster:
        return 'aimaster_ai';
      case AIDifficulty.perfect:
        return 'perfect_ai';
      case AIDifficulty.khaled:
        return 'khaled_ai';
      case AIDifficulty.mohammad:
        return 'mohammad_ai';
      case AIDifficulty.trixAgent0:
        return 'trix_agent_0_ai';
      case AIDifficulty.trixAgent1:
        return 'trix_agent_1_ai';
      case AIDifficulty.trixAgent2:
        return 'trix_agent_2_ai';
      case AIDifficulty.trixAgent3:
        return 'trix_agent_3_ai';
      case AIDifficulty.claudeSonnet:
        return 'claude_sonnet_ai';
      case AIDifficulty.chatGPT:
        return 'chatgpt_ai';
      case AIDifficulty.humanEnhanced:
        return 'human_enhanced_ai';
      case AIDifficulty.strategicElite:
        return 'strategic_elite_ai';
      case AIDifficulty.strategicEliteCorrected:
        return 'strategic_elite_corrected_ai';
    }
  }

  /// Get experience level (1-9)
  int get experienceLevel {
    switch (this) {
      case AIDifficulty.beginner:
        return 1;
      case AIDifficulty.novice:
        return 2;
      case AIDifficulty.amateur:
        return 3;
      case AIDifficulty.intermediate:
        return 4;
      case AIDifficulty.advanced:
        return 5;
      case AIDifficulty.expert:
        return 6;
      case AIDifficulty.master:
        return 7;
      case AIDifficulty.aimaster:
        return 8;
      case AIDifficulty.perfect:
        return 9;
      case AIDifficulty.khaled:
        return 8; // Custom model - high level
      case AIDifficulty.mohammad:
        return 8; // Custom model - high level
      case AIDifficulty.trixAgent0:
        return 7; // Mobile agent - advanced level
      case AIDifficulty.trixAgent1:
        return 7; // Mobile agent - advanced level
      case AIDifficulty.trixAgent2:
        return 8; // Mobile agent - expert level
      case AIDifficulty.trixAgent3:
        return 8; // Mobile agent - expert level
      case AIDifficulty.claudeSonnet:
        return 9; // Elite AI - maximum level
      case AIDifficulty.chatGPT:
        return 9; // Elite AI - maximum level
      case AIDifficulty.humanEnhanced:
        return 8; // Human Enhanced AI - expert level with human patterns
      case AIDifficulty.strategicElite:
        return 8; // Strategic Elite AI - expert level (60-70% human)
      case AIDifficulty.strategicEliteCorrected:
        return 9; // Strategic Elite Corrected AI - maximum level with bug fixes
    }
  }

  /// Recommended progression order
  static List<AIDifficulty> get recommendedProgression => [
        AIDifficulty.strategicElite, // Only Strategic Elite for fast loading
      ];

  /// Get recommended difficulty based on player stats
  static AIDifficulty getRecommendedForPlayer(int gamesPlayed, double winRate) {
    if (gamesPlayed < 5) return AIDifficulty.beginner;
    if (gamesPlayed < 15 || winRate < 0.3) return AIDifficulty.novice;
    if (gamesPlayed < 50 || winRate < 0.6) return AIDifficulty.amateur;
    if (gamesPlayed < 100 || winRate < 0.7) return AIDifficulty.intermediate;
    if (gamesPlayed < 200 || winRate < 0.75) return AIDifficulty.advanced;
    if (winRate < 0.8) return AIDifficulty.expert;
    if (winRate < 0.85) return AIDifficulty.master;
    if (winRate < 0.9) return AIDifficulty.aimaster;
    return AIDifficulty.perfect;
  }

  /// Get only the AI difficulties that are currently available
  static List<AIDifficulty> get availableDifficulties => [
        AIDifficulty.strategicElite, // Strategic Elite for fast loading
        AIDifficulty.humanEnhanced, // Human Enhanced AI with 468 human gameplay samples
      ];

  /// Check if a difficulty level is currently available
  static bool isAvailable(AIDifficulty difficulty) {
    return availableDifficulties.contains(difficulty);
  }

  /// Get the strongest available difficulty
  static AIDifficulty get strongestAvailable => AIDifficulty.strategicElite;

  /// Get a safe fallback difficulty that's guaranteed to be available
  static AIDifficulty get safeFallback => AIDifficulty.strategicElite;
}
