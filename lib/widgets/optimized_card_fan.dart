import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/card.dart' as game_card;
import '../providers/game_provider.dart';
import '../utils/object_pool.dart';
import '../widgets/playing_card_widget.dart';

/// Optimized card fan layout that uses object pooling and caching
class OptimizedCardFan extends StatefulWidget {
  final List<game_card.Card> cards;
  final Function(game_card.Card) onCardTap;
  final bool Function(game_card.Card) isCardPlayable;
  final double cardWidth;
  final double overlap;
  final bool useCardImages;
  final bool isCompact;

  const OptimizedCardFan({
    super.key,
    required this.cards,
    required this.onCardTap,
    required this.isCardPlayable,
    this.cardWidth = 48.0,
    this.overlap = 23.0,
    this.useCardImages = true,
    this.isCompact = false,
  });

  @override
  State<OptimizedCardFan> createState() => _OptimizedCardFanState();
}

class _OptimizedCardFanState extends State<OptimizedCardFan> {
  final List<Widget> _cachedCardWidgets = [];
  List<game_card.Card>? _lastCards;
  bool? _lastShouldHighlight;
  
  @override
  void dispose() {
    _cachedCardWidgets.clear();
    super.dispose();
  }

  bool _needsRebuild(List<game_card.Card> cards, bool shouldHighlight) {
    if (_lastCards == null || _lastShouldHighlight != shouldHighlight) {
      return true;
    }
    
    if (_lastCards!.length != cards.length) {
      return true;
    }
    
    for (int i = 0; i < cards.length; i++) {
      if (_lastCards![i] != cards[i]) {
        return true;
      }
    }
    
    return false;
  }

  void _buildCardWidgets(List<game_card.Card> cards, bool shouldHighlight) {
    _cachedCardWidgets.clear();
    
    for (int index = 0; index < cards.length; index++) {
      final card = cards[index];
      final isCardPlayable = widget.isCardPlayable(card);
      
      // Use cached widget from object pool
      final cardWidget = CardWidgetCache.getOrCreate(
        card: card,
        isPlayable: isCardPlayable,
        isSelected: false,
        useCardImages: widget.useCardImages,
        isCompact: widget.isCompact,
        showValidityHighlight: shouldHighlight,
      );
      
      final positionedCard = Positioned(
        left: index * (widget.cardWidth - widget.overlap),
        child: GestureDetector(
          onTap: () => widget.onCardTap(card),
          child: cardWidget,
        ),
      );
      
      _cachedCardWidgets.add(positionedCard);
    }
    
    _lastCards = List.from(cards);
    _lastShouldHighlight = shouldHighlight;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();

    final totalWidth = widget.cards.length > 1
        ? widget.cardWidth + (widget.cards.length - 1) * (widget.cardWidth - widget.overlap)
        : widget.cardWidth;

    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final shouldHighlight = gameProvider.shouldHighlightCards;
        
        // Only rebuild if cards or highlight state changed
        if (_needsRebuild(widget.cards, shouldHighlight)) {
          _buildCardWidgets(widget.cards, shouldHighlight);
        }

        return SizedBox(
          height: 100,
          width: totalWidth,
          child: Stack(
            children: _cachedCardWidgets,
          ),
        );
      },
    );
  }
}

/// Optimized player card stack for AI players
class OptimizedPlayerCardStack extends StatefulWidget {
  final List<game_card.Card> cards;
  final bool isVertical;
  final bool isSmall;

  const OptimizedPlayerCardStack({
    super.key,
    required this.cards,
    required this.isVertical,
    this.isSmall = true,
  });

  @override
  State<OptimizedPlayerCardStack> createState() => _OptimizedPlayerCardStackState();
}

class _OptimizedPlayerCardStackState extends State<OptimizedPlayerCardStack> {
  Widget? _cachedStack;
  int? _lastCardCount;
  bool? _lastIsVertical;
  bool? _lastIsSmall;

  bool _needsRebuild() {
    return _lastCardCount != widget.cards.length ||
           _lastIsVertical != widget.isVertical ||
           _lastIsSmall != widget.isSmall;
  }

  Widget _buildStack() {
    final cardCount = widget.cards.length;
    if (cardCount == 0) return const SizedBox.shrink();

    final displayCount = cardCount.clamp(0, 13);
    final spacing = widget.isSmall ? 8.0 : 12.0;
    
    final width = widget.isVertical ? 35.0 : (35 + (displayCount * spacing));
    final height = widget.isVertical ? (40 + (displayCount * spacing)) : 35.0;

    final children = <Widget>[];
    
    for (int index = 0; index < displayCount; index++) {
      final card = widget.cards[index];
      final offset = index * spacing;
      
      final cardWidget = CardWidgetCache.getOrCreate(
        card: card,
        isPlayable: false,
        isSelected: false,
        useCardImages: true,
        isCompact: true,
        showValidityHighlight: false,
        isSmall: widget.isSmall,
      );
      
      children.add(
        Positioned(
          left: widget.isVertical ? 0 : offset,
          top: widget.isVertical ? offset : 0,
          child: SizedBox(
            width: 35,
            height: 40,
            child: cardWidget,
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Stack(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_needsRebuild() || _cachedStack == null) {
      _cachedStack = _buildStack();
      _lastCardCount = widget.cards.length;
      _lastIsVertical = widget.isVertical;
      _lastIsSmall = widget.isSmall;
    }

    return _cachedStack!;
  }
}

/// Optimized container with cached decorations
class OptimizedContainer extends StatelessWidget {
  final Widget child;
  final Color color;
  final BorderRadius borderRadius;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  const OptimizedContainer({
    super.key,
    required this.child,
    required this.color,
    required this.borderRadius,
    this.border,
    this.boxShadow,
    this.padding,
    this.margin,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = DecorationCache.getOrCreate(
      color: color,
      borderRadius: borderRadius,
      border: border,
      boxShadow: boxShadow,
    );

    return Container(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      decoration: decoration,
      child: child,
    );
  }
}

/// Optimized text widget with cached styles
class OptimizedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;
  final TextAlign? textAlign;

  const OptimizedText(
    this.text, {
    super.key,
    required this.fontSize,
    required this.fontWeight,
    required this.color,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyleCache.getOrCreate(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );

    return Text(
      text,
      style: style,
      textAlign: textAlign,
    );
  }
}