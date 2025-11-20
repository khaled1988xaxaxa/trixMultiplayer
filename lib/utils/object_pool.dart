import 'package:flutter/material.dart';
import '../models/card.dart' as game_card;
import '../widgets/playing_card_widget.dart';

/// Object pool for reusing expensive objects to reduce garbage collection
class ObjectPool<T> {
  final List<T> _pool = [];
  final T Function() _factory;
  final void Function(T)? _reset;
  final int _maxSize;

  ObjectPool({
    required T Function() factory,
    void Function(T)? reset,
    int maxSize = 50,
  }) : _factory = factory,
       _reset = reset,
       _maxSize = maxSize;

  T acquire() {
    if (_pool.isNotEmpty) {
      return _pool.removeLast();
    }
    return _factory();
  }

  void release(T object) {
    if (_pool.length < _maxSize) {
      _reset?.call(object);
      _pool.add(object);
    }
  }

  void clear() {
    _pool.clear();
  }

  int get poolSize => _pool.length;
}

/// Widget cache for reusing card widgets
class CardWidgetCache {
  static final Map<String, Widget> _cache = {};
  static const int _maxCacheSize = 200;

  static String _generateKey({
    required game_card.Card card,
    required bool isPlayable,
    required bool isSelected,
    required bool useCardImages,
    required bool isCompact,
    required bool showValidityHighlight,
    required bool isSmall,
  }) {
    return '${card.suit.name}_${card.rank.name}_${isPlayable}_${isSelected}_${useCardImages}_${isCompact}_${showValidityHighlight}_${isSmall}';
  }

  static Widget getOrCreate({
    required game_card.Card card,
    required bool isPlayable,
    required bool isSelected,
    required bool useCardImages,
    required bool isCompact,
    required bool showValidityHighlight,
    bool isSmall = false,
  }) {
    final key = _generateKey(
      card: card,
      isPlayable: isPlayable,
      isSelected: isSelected,
      useCardImages: useCardImages,
      isCompact: isCompact,
      showValidityHighlight: showValidityHighlight,
      isSmall: isSmall,
    );

    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    // Create new widget if cache miss
    final widget = PlayingCardWidget(
      card: card,
      isPlayable: isPlayable,
      isSelected: isSelected,
      useCardImages: useCardImages,
      isCompact: isCompact,
      showValidityHighlight: showValidityHighlight,
      isSmall: isSmall,
    );

    // Add to cache if not full
    if (_cache.length < _maxCacheSize) {
      _cache[key] = widget;
    }

    return widget;
  }

  static void clear() {
    _cache.clear();
  }

  static int get cacheSize => _cache.length;
}

/// Reusable positioned widget pool
class PositionedWidgetPool {
  static final ObjectPool<_PositionedWrapper> _pool = ObjectPool<_PositionedWrapper>(
    factory: () => _PositionedWrapper(),
    reset: (wrapper) => wrapper.reset(),
    maxSize: 100,
  );

  static Widget create({
    required double left,
    double? top,
    double? right,
    double? bottom,
    required Widget child,
  }) {
    final wrapper = _pool.acquire();
    wrapper.configure(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: child,
    );
    return wrapper;
  }

  static void release(_PositionedWrapper wrapper) {
    _pool.release(wrapper);
  }

  static void clear() {
    _pool.clear();
  }
}

class _PositionedWrapper extends StatelessWidget {
  double? _left;
  double? _top;
  double? _right;
  double? _bottom;
  Widget? _child;

  _PositionedWrapper();

  void configure({
    required double left,
    double? top,
    double? right,
    double? bottom,
    required Widget child,
  }) {
    _left = left;
    _top = top;
    _right = right;
    _bottom = bottom;
    _child = child;
  }

  void reset() {
    _left = null;
    _top = null;
    _right = null;
    _bottom = null;
    _child = null;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _left,
      top: _top,
      right: _right,
      bottom: _bottom,
      child: _child!,
    );
  }
}

/// Container decoration cache for reusing common decorations
class DecorationCache {
  static final Map<String, BoxDecoration> _cache = {};
  static const int _maxCacheSize = 50;

  static String _generateKey({
    required Color color,
    required BorderRadius borderRadius,
    Border? border,
    List<BoxShadow>? boxShadow,
  }) {
    return '${color.value}_${borderRadius.toString()}_${border?.toString() ?? 'null'}_${boxShadow?.length ?? 0}';
  }

  static BoxDecoration getOrCreate({
    required Color color,
    required BorderRadius borderRadius,
    Border? border,
    List<BoxShadow>? boxShadow,
  }) {
    final key = _generateKey(
      color: color,
      borderRadius: borderRadius,
      border: border,
      boxShadow: boxShadow,
    );

    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final decoration = BoxDecoration(
      color: color,
      borderRadius: borderRadius,
      border: border,
      boxShadow: boxShadow,
    );

    if (_cache.length < _maxCacheSize) {
      _cache[key] = decoration;
    }

    return decoration;
  }

  static void clear() {
    _cache.clear();
  }

  static int get cacheSize => _cache.length;
}

/// Text style cache for reusing common text styles
class TextStyleCache {
  static final Map<String, TextStyle> _cache = {};
  static const int _maxCacheSize = 30;

  static String _generateKey({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
  }) {
    return '${fontSize}_${fontWeight.index}_${color.value}';
  }

  static TextStyle getOrCreate({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
  }) {
    final key = _generateKey(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );

    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );

    if (_cache.length < _maxCacheSize) {
      _cache[key] = style;
    }

    return style;
  }

  static void clear() {
    _cache.clear();
  }

  static int get cacheSize => _cache.length;
}

/// Global cache manager
class CacheManager {
  static void clearAll() {
    CardWidgetCache.clear();
    PositionedWidgetPool.clear();
    DecorationCache.clear();
    TextStyleCache.clear();
  }

  static Map<String, int> getCacheStats() {
    return {
      'cardWidgets': CardWidgetCache.cacheSize,
      'decorations': DecorationCache.cacheSize,
      'textStyles': TextStyleCache.cacheSize,
    };
  }
  
  /// Get statistics for all caches
  static Map<String, int> getStats() {
    return {
      'CardWidgetCache': CardWidgetCache._cache.length,
      'PositionedWidgetPool': PositionedWidgetPool._pool.poolSize,
      'DecorationCache': DecorationCache._cache.length,
      'TextStyleCache': TextStyleCache._cache.length,
    };
  }
}