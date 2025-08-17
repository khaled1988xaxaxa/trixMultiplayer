import 'package:flutter/material.dart';
import '../models/ai_difficulty.dart';

/// Widget to display AI difficulty level with appropriate styling
class AIDifficultyIndicator extends StatelessWidget {
  final AIDifficulty difficulty;
  final bool isCompact;
  final bool showIcon;
  final bool showArabicName;

  const AIDifficultyIndicator({
    super.key,
    required this.difficulty,
    this.isCompact = false,
    this.showIcon = true,
    this.showArabicName = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 5 : 6,
        vertical: isCompact ? 3 : 3,
      ),
      decoration: BoxDecoration(
        color: _getDifficultyColor().withOpacity(0.8),
        borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
        border: Border.all(
          color: _getDifficultyColor(),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: isCompact ? 12 : 14,
            ),
            SizedBox(width: isCompact ? 2 : 4),
          ],
          Text(
            showArabicName ? difficulty.arabicName : difficulty.englishName,
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 9 : 10,
              fontWeight: FontWeight.bold,
              shadows: isCompact ? [
                Shadow(
                  color: Colors.black.withOpacity(0.8),
                  blurRadius: 1,
                ),
              ] : null,
            ),
          ),
          if (!isCompact) ...[
            const SizedBox(width: 4),
            Row(
              children: List.generate(
                difficulty.experienceLevel.clamp(1, 3),
                (index) => Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getDifficultyColor() {
    switch (difficulty) {
      case AIDifficulty.beginner:
        return Colors.green;
      case AIDifficulty.novice:
        return Colors.lightGreen;
      case AIDifficulty.amateur:
        return Colors.blue;
      case AIDifficulty.intermediate:
        return Colors.orange;
      case AIDifficulty.advanced:
        return Colors.deepOrange;
      case AIDifficulty.expert:
        return Colors.red;
      case AIDifficulty.master:
        return Colors.purple;
      case AIDifficulty.aimaster:
        return Colors.indigo;
      case AIDifficulty.perfect:
        return Colors.black;
      case AIDifficulty.khaled:
        return Colors.teal; // Custom color for Khaled
      case AIDifficulty.mohammad:
        return Colors.cyan; // Custom color for Mohammad
      case AIDifficulty.trixAgent0:
        return Colors.blueGrey; // Mobile agent - balanced
      case AIDifficulty.trixAgent1:
        return Colors.redAccent; // Mobile agent - aggressive
      case AIDifficulty.trixAgent2:
        return Colors.green.shade700; // Mobile agent - defensive
      case AIDifficulty.trixAgent3:
        return Colors.deepPurple; // Mobile agent - adaptive
      case AIDifficulty.claudeSonnet:
        return Colors.amber.shade600; // Elite AI - Claude Sonnet
      case AIDifficulty.chatGPT:
        return Colors.teal.shade600; // Elite AI - ChatGPT
      case AIDifficulty.humanEnhanced:
        return Colors.pink.shade400; // Human Enhanced AI - Supervised learning
      case AIDifficulty.strategicElite:
        return Colors.deepPurple.shade400; // Strategic Elite AI - PPO Enhanced
      case AIDifficulty.strategicEliteCorrected:
        return Colors.red.shade600; // Strategic Elite Corrected - King of Hearts protected
    }
  }
}

/// Confidence indicator for AI decisions (when available)
class AIConfidenceIndicator extends StatelessWidget {
  final double confidence;
  final bool isCompact;

  const AIConfidenceIndicator({
    super.key,
    required this.confidence,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 3 : 4,
        vertical: isCompact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: _getConfidenceColor().withOpacity(0.8),
        borderRadius: BorderRadius.circular(isCompact ? 6 : 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.psychology,
            color: Colors.white,
            size: isCompact ? 10 : 12,
          ),
          SizedBox(width: isCompact ? 2 : 3),
          Text(
            '${(confidence * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 7 : 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor() {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }
}

/// Combined AI info display
class AIPlayerInfoWidget extends StatelessWidget {
  final AIDifficulty difficulty;
  final double? confidence;
  final bool isCompact;
  final bool showDetails;

  const AIPlayerInfoWidget({
    super.key,
    required this.difficulty,
    this.confidence,
    this.isCompact = false,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AIDifficultyIndicator(
          difficulty: difficulty,
          isCompact: isCompact,
          showArabicName: true,
        ),
        if (confidence != null && showDetails && !isCompact) ...[
          const SizedBox(height: 2),
          AIConfidenceIndicator(
            confidence: confidence!,
            isCompact: true,
          ),
        ],
      ],
    );
  }
}
