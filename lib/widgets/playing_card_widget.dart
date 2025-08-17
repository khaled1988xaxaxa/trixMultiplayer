import 'package:flutter/material.dart';
import '../models/card.dart' as game_card;

class PlayingCardWidget extends StatelessWidget {
  final game_card.Card card;
  final bool isPlayable;
  final bool isSmall;
  final bool isSelected;
  final bool useCardImages;
  final bool isCompact; // New parameter for ultra-compact mobile layout
  final bool showValidityHighlight; // New parameter to control highlighting

  const PlayingCardWidget({
    super.key,
    required this.card,
    this.isPlayable = true,
    this.isSmall = false,
    this.isSelected = false,
    this.useCardImages = true, // Enable card images by default
    this.isCompact = false, // Default to normal size
    this.showValidityHighlight = false, // Default to no special highlighting
  });

  @override
  Widget build(BuildContext context) {
    // Multi-tier responsive sizing
    double size, height;
    
    if (isCompact) {
      // Ultra-compact for portrait mobile
      size = isSmall ? 28.0 : 45.0;
      height = isSmall ? 40.0 : 65.0;
    } else {
      // Normal responsive sizing
      size = isSmall ? 15.0 : 55.0;
      height = isSmall ? 40.0 : 85.0;
    }

    // Determine visual state based on playability and highlighting
    Color borderColor;
    double borderWidth;
    Color? overlayColor;
    double opacity = 1.0; // Default opacity for normal cards

    if (isSelected) {
      borderColor = Colors.orange;
      borderWidth = 2.0;
    } else if (showValidityHighlight) {
      if (isPlayable) {
        // Valid cards: bright green border with subtle glow
        borderColor = Colors.green.shade400;
        borderWidth = 2.0;
      } else {
        // Invalid cards: red border, dimmed appearance
        borderColor = Colors.red.shade300;
        borderWidth = 1.0;
        opacity = 1; // More dimmed for non-playable cards
overlayColor = Colors.black.withOpacity(0.25);
      }
    } else {
      // Default appearance
      borderColor = isPlayable ? Colors.grey.shade300 : Colors.grey.shade500;
      borderWidth = 1.0;
      if (!isPlayable) {
        // Dimmed appearance for non-playable cards
      opacity = 1; // More dimmed for non-playable cards
overlayColor = Colors.black.withOpacity(0.25);
      }
    }

    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: size,
        height: height,
        margin: EdgeInsets.symmetric(horizontal: isCompact ? 0.5 : 1), // Tighter margins for compact
        decoration: BoxDecoration(
          color: useCardImages ? Colors.transparent : Colors.white,
          borderRadius: BorderRadius.circular(isCompact ? 4 : 6),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 1),
              blurRadius: isCompact ? 1 : 2,
              color: Colors.black.withOpacity(0.2),
            ),
            // Add glow effect for valid cards when highlighting is enabled
            if (showValidityHighlight && isPlayable)
              BoxShadow(
                offset: const Offset(0, 0),
                blurRadius: 8,
                color: Colors.green.withOpacity(0.3),
                spreadRadius: 1,
              ),
          ],
        ),
        child: Stack(
          children: [
            // Main card content
            useCardImages 
                ? _buildCardImage()
                : _buildProgrammaticCard(),
            // Overlay for invalid cards
            if (overlayColor != null)
              Container(
                decoration: BoxDecoration(
                  color: overlayColor,
                  borderRadius: BorderRadius.circular(isCompact ? 4 : 6),
                ),
              ),
            // Valid card indicator
            if (showValidityHighlight && isPlayable)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 8,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(isCompact ? 4 : 6), // Match container radius
      child: Image.asset(
        _getCardImagePath(),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to programmatic rendering if image not found
          return _buildProgrammaticCard();
        },
      ),
    );
  }

  String _getCardImagePath() {
    // Map to your existing card image naming convention
    final rankCode = _getRankCode();
    final suitCode = _getSuitCode();
    return 'assets/cards/$rankCode$suitCode.png';
  }

  String _getRankCode() {
    switch (card.rank) {
      case game_card.Rank.ace:
        return 'A';
      case game_card.Rank.two:
        return '2';
      case game_card.Rank.three:
        return '3';
      case game_card.Rank.four:
        return '4';
      case game_card.Rank.five:
        return '5';
      case game_card.Rank.six:
        return '6';
      case game_card.Rank.seven:
        return '7';
      case game_card.Rank.eight:
        return '8';
      case game_card.Rank.nine:
        return '9';
      case game_card.Rank.ten:
        return '10';
      case game_card.Rank.jack:
        return 'J';
      case game_card.Rank.queen:
        return 'Q';
      case game_card.Rank.king:
        return 'K';
    }
  }

  String _getSuitCode() {
    switch (card.suit) {
      case game_card.Suit.hearts:
        return 'H';
      case game_card.Suit.diamonds:
        return 'D';
      case game_card.Suit.clubs:
        return 'C';
      case game_card.Suit.spades:
        return 'S';
    }
  }

  Widget _buildProgrammaticCard() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Top rank and suit
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Text(
                    _getCardSymbol(),
                    style: TextStyle(
                      fontSize: isSmall ? 10 : 14,
                      fontWeight: FontWeight.bold,
                      color: _getSuitColor(card.suit),
                    ),
                  ),
                  Icon(
                    _getSuitIcon(card.suit),
                    size: isSmall ? 8 : 12,
                    color: _getSuitColor(card.suit),
                  ),
                ],
              ),
              // Arabic rank (large)
              Text(
                card.rank.arabicName,
                style: TextStyle(
                  fontSize: isSmall ? 12 : 20,
                  fontWeight: FontWeight.bold,
                  color: _getSuitColor(card.suit),
                ),
              ),
            ],
          ),
        ),
        
        // Center suit icon (large)
        if (!isSmall)
          Icon(
            _getSuitIcon(card.suit),
            size: 30,
            color: _getSuitColor(card.suit),
          ),
        
        // Bottom rank and suit (rotated)
        if (!isSmall)
          Transform.rotate(
            angle: 3.14159, // 180 degrees
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text(
                        _getCardSymbol(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getSuitColor(card.suit),
                        ),
                      ),
                      Icon(
                        _getSuitIcon(card.suit),
                        size: 8,
                        color: _getSuitColor(card.suit),
                      ),
                    ],
                  ),
                  Text(
                    card.rank.arabicName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _getSuitColor(card.suit),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _getCardSymbol() {
    // Return English symbol for standard card appearance
    switch (card.rank) {
      case game_card.Rank.ace:
        return 'A';
      case game_card.Rank.king:
        return 'K';
      case game_card.Rank.queen:
        return 'Q';
      case game_card.Rank.jack:
        return 'J';
      default:
        return card.rank.value.toString();
    }
  }

  Color _getSuitColor(game_card.Suit suit) {
    switch (suit) {
      case game_card.Suit.hearts:
      case game_card.Suit.diamonds:
        return Colors.red;
      case game_card.Suit.clubs:
      case game_card.Suit.spades:
        return Colors.black;
    }
  }

  IconData _getSuitIcon(game_card.Suit suit) {
    switch (suit) {
      case game_card.Suit.hearts:
        return Icons.favorite;
      case game_card.Suit.diamonds:
        return Icons.diamond;
      case game_card.Suit.clubs:
        return Icons.eco; // Using eco as club alternative
      case game_card.Suit.spades:
        return Icons.spa; // Using spa as spade alternative
    }
  }
}