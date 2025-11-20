import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/ai_logging_provider.dart';
import '../models/ai_player.dart';
import '../models/ai_difficulty.dart';
import '../utils/object_pool.dart';
import '../utils/performance_monitor.dart';

/// Optimized Consumer wrapper that reduces unnecessary rebuilds
class OptimizedConsumer<T extends ChangeNotifier> extends StatefulWidget {
  final Widget Function(BuildContext context, T value, Widget? child) builder;
  final Widget? child;
  final bool Function(T previous, T current)? shouldRebuild;

  const OptimizedConsumer({
    super.key,
    required this.builder,
    this.child,
    this.shouldRebuild,
  });

  @override
  State<OptimizedConsumer<T>> createState() => _OptimizedConsumerState<T>();
}

class _OptimizedConsumerState<T extends ChangeNotifier> extends State<OptimizedConsumer<T>> {
  T? _lastValue;
  Widget? _cachedWidget;

  @override
  Widget build(BuildContext context) {
    return Consumer<T>(
      child: widget.child,
      builder: (context, value, child) {
        // Check if we should rebuild
        bool shouldRebuild = true;
        if (widget.shouldRebuild != null && _lastValue != null) {
          shouldRebuild = widget.shouldRebuild!(_lastValue!, value);
        } else if (_lastValue != null) {
          shouldRebuild = _lastValue != value;
        }

        if (shouldRebuild || _cachedWidget == null) {
          PerformanceMetrics.startBuildTimer('OptimizedConsumer<$T>');
          _cachedWidget = widget.builder(context, value, child);
          PerformanceMetrics.endBuildTimer('OptimizedConsumer<$T>');
          _lastValue = value;
        }

        return _cachedWidget!;
      },
    );
  }
}

/// Optimized AI status indicator with caching
class OptimizedAIStatusIndicator extends StatefulWidget {
  final bool isCompact;
  final bool showDetails;

  const OptimizedAIStatusIndicator({
    super.key,
    this.isCompact = false,
    this.showDetails = true,
  });

  @override
  State<OptimizedAIStatusIndicator> createState() => _OptimizedAIStatusIndicatorState();
}

class _OptimizedAIStatusIndicatorState extends State<OptimizedAIStatusIndicator> {
  Widget? _cachedWidget;
  bool? _lastIsLightweight;
  bool? _lastIsLogging;

  @override
  Widget build(BuildContext context) {
    return OptimizedConsumer<GameProvider>(
      shouldRebuild: (previous, current) {
        return previous.isLightweightAIMode != current.isLightweightAIMode ||
               previous.isLoggingEnabled != current.isLoggingEnabled;
      },
      builder: (context, gameProvider, child) {
        final isLightweight = gameProvider.isLightweightAIMode;
        final isLogging = gameProvider.isLoggingEnabled;

        if (_lastIsLightweight != isLightweight || 
            _lastIsLogging != isLogging || 
            _cachedWidget == null) {
          
          _cachedWidget = Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCompact ? 6 : 12,
              vertical: widget.isCompact ? 2 : 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.smart_toy,
                  size: widget.isCompact ? 10 : 12,
                  color: isLightweight ? Colors.orange : Colors.blue,
                ),
                const SizedBox(width: 4),
                Text(
                  isLightweight ? 'Test Mode' : 'Full AI',
                  style: TextStyle(
                    fontSize: widget.isCompact ? 8 : 10,
                    fontWeight: FontWeight.normal,
                    color: Colors.black87,
                  ),
                ),
                if (widget.showDetails) ...[
                  const SizedBox(width: 8),
                  Icon(
                    isLogging ? Icons.fiber_manual_record : Icons.stop_circle_outlined,
                    size: widget.isCompact ? 10 : 12,
                    color: isLogging ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isLogging ? 'Recording' : 'Not Recording',
                    style: TextStyle(
                      fontSize: widget.isCompact ? 8 : 10,
                      fontWeight: FontWeight.normal,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          );

          _lastIsLightweight = isLightweight;
          _lastIsLogging = isLogging;
        }

        return _cachedWidget!;
      },
    );
  }
}

/// Optimized difficulty indicator with caching
class OptimizedDifficultyIndicator extends StatefulWidget {
  final AIDifficulty difficulty;
  final bool isCompact;
  final bool showIcon;
  final bool showArabicName;

  const OptimizedDifficultyIndicator({
    super.key,
    required this.difficulty,
    this.isCompact = false,
    this.showIcon = true,
    this.showArabicName = false,
  });

  @override
  State<OptimizedDifficultyIndicator> createState() => _OptimizedDifficultyIndicatorState();
}

class _OptimizedDifficultyIndicatorState extends State<OptimizedDifficultyIndicator> {
  Widget? _cachedWidget;
  AIDifficulty? _lastDifficulty;
  bool? _lastIsCompact;
  bool? _lastShowIcon;
  bool? _lastShowArabicName;

  Color _getDifficultyColor() {
    switch (widget.difficulty) {
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
        return Colors.teal;
      case AIDifficulty.mohammad:
        return Colors.cyan;
      case AIDifficulty.trixAgent0:
        return Colors.blueGrey;
      case AIDifficulty.trixAgent1:
        return Colors.redAccent;
      case AIDifficulty.trixAgent2:
        return Colors.green;
      case AIDifficulty.trixAgent3:
        return Colors.deepPurple;
      case AIDifficulty.claudeSonnet:
        return Colors.amber;
      case AIDifficulty.chatGPT:
        return Colors.teal;
      case AIDifficulty.humanEnhanced:
        return Colors.brown;
      case AIDifficulty.strategicElite:
        return Colors.deepOrange;
      case AIDifficulty.strategicEliteCorrected:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lastDifficulty != widget.difficulty ||
        _lastIsCompact != widget.isCompact ||
        _lastShowIcon != widget.showIcon ||
        _lastShowArabicName != widget.showArabicName ||
        _cachedWidget == null) {
      
      final color = _getDifficultyColor();
      
      _cachedWidget = Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.8),
          borderRadius: BorderRadius.circular(widget.isCompact ? 8 : 10),
          border: Border.all(color: color, width: 1),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: widget.isCompact ? 5 : 6,
          vertical: widget.isCompact ? 3 : 3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showIcon) ...[
              Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: widget.isCompact ? 12 : 14,
              ),
              SizedBox(width: widget.isCompact ? 2 : 4),
            ],
            Text(
              widget.showArabicName 
                  ? widget.difficulty.arabicName 
                  : widget.difficulty.englishName,
              style: TextStyle(
                fontSize: widget.isCompact ? 9 : 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (!widget.isCompact) ...[
              const SizedBox(width: 4),
              Row(
                children: List.generate(
                  widget.difficulty.experienceLevel.clamp(1, 3),
                  (index) => const Icon(
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

      _lastDifficulty = widget.difficulty;
      _lastIsCompact = widget.isCompact;
      _lastShowIcon = widget.showIcon;
      _lastShowArabicName = widget.showArabicName;
    }

    return _cachedWidget!;
  }
}

/// Optimized loading indicator with reduced animations
class OptimizedLoadingIndicator extends StatefulWidget {
  final String? message;
  final bool isCompact;
  final Color? color;

  const OptimizedLoadingIndicator({
    super.key,
    this.message,
    this.isCompact = false,
    this.color,
  });

  @override
  State<OptimizedLoadingIndicator> createState() => _OptimizedLoadingIndicatorState();
}

class _OptimizedLoadingIndicatorState extends State<OptimizedLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Widget? _cachedIndicator;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _cachedIndicator ??= Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.isCompact ? 20 : 40,
          height: widget.isCompact ? 20 : 40,
          child: CircularProgressIndicator(
            strokeWidth: widget.isCompact ? 2 : 4,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.color ?? Theme.of(context).primaryColor,
            ),
          ),
        ),
        if (widget.message != null) ...[
          SizedBox(height: widget.isCompact ? 8 : 16),
          Text(
            widget.message!,
            style: TextStyle(
              fontSize: widget.isCompact ? 12 : 14,
              fontWeight: FontWeight.normal,
              color: widget.color ?? Colors.black87,
            ),
          ),
        ],
      ],
    );

    return _cachedIndicator!;
  }
}

/// Optimized icon button with reduced rebuilds
class OptimizedIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double? size;
  final String? tooltip;
  final bool isSelected;

  const OptimizedIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.size,
    this.tooltip,
    this.isSelected = false,
  });

  @override
  State<OptimizedIconButton> createState() => _OptimizedIconButtonState();
}

class _OptimizedIconButtonState extends State<OptimizedIconButton> {
  Widget? _cachedButton;
  IconData? _lastIcon;
  Color? _lastColor;
  double? _lastSize;
  bool? _lastIsSelected;

  @override
  Widget build(BuildContext context) {
    if (_lastIcon != widget.icon ||
        _lastColor != widget.color ||
        _lastSize != widget.size ||
        _lastIsSelected != widget.isSelected ||
        _cachedButton == null) {
      
      _cachedButton = IconButton(
        icon: Icon(
          widget.icon,
          color: widget.isSelected 
              ? (widget.color ?? Colors.orange)
              : (widget.color ?? Colors.grey),
          size: widget.size,
        ),
        onPressed: widget.onPressed,
        tooltip: widget.tooltip,
      );

      _lastIcon = widget.icon;
      _lastColor = widget.color;
      _lastSize = widget.size;
      _lastIsSelected = widget.isSelected;
    }

    return _cachedButton!;
  }
}

/// Optimized card widget with better caching
class OptimizedCardWidget extends StatefulWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final Border? border;

  const OptimizedCardWidget({
    super.key,
    required this.child,
    this.color,
    this.padding,
    this.margin,
    this.borderRadius,
    this.boxShadow,
    this.border,
  });

  @override
  State<OptimizedCardWidget> createState() => _OptimizedCardWidgetState();
}

class _OptimizedCardWidgetState extends State<OptimizedCardWidget> {
  Widget? _cachedCard;
  Color? _lastColor;
  EdgeInsetsGeometry? _lastPadding;
  EdgeInsetsGeometry? _lastMargin;
  BorderRadius? _lastBorderRadius;

  @override
  Widget build(BuildContext context) {
    if (_lastColor != widget.color ||
        _lastPadding != widget.padding ||
        _lastMargin != widget.margin ||
        _lastBorderRadius != widget.borderRadius ||
        _cachedCard == null) {
      
      _cachedCard = Container(
        decoration: BoxDecoration(
          color: widget.color ?? const Color(0xFF1E3A5F),
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          border: widget.border,
          boxShadow: widget.boxShadow,
        ),
        padding: widget.padding ?? const EdgeInsets.all(16),
        margin: widget.margin,
        child: widget.child,
      );

      _lastColor = widget.color;
      _lastPadding = widget.padding;
      _lastMargin = widget.margin;
      _lastBorderRadius = widget.borderRadius;
    }

    return _cachedCard!;
  }
}