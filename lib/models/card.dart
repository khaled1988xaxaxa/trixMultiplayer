enum Suit {
  hearts,
  diamonds,
  clubs,
  spades;

  String get arabicName {
    switch (this) {
      case Suit.hearts:
        return 'كوبا';
      case Suit.diamonds:
        return 'ديناري';
      case Suit.clubs:
        return 'سباتي';
      case Suit.spades:
        return 'بستوني';
    }
  }

  String get englishName {
    switch (this) {
      case Suit.hearts:
        return 'Hearts';
      case Suit.diamonds:
        return 'Diamonds';
      case Suit.clubs:
        return 'Clubs';
      case Suit.spades:
        return 'Spades';
    }
  }
}

enum Rank {
  two(2),
  three(3),
  four(4),
  five(5),
  six(6),
  seven(7),
  eight(8),
  nine(9),
  ten(10),
  jack(11),
  queen(12),
  king(13),
  ace(14);

  const Rank(this.value);
  final int value;

  String get arabicName {
    switch (this) {
      case Rank.ace:
        return 'آس';
      case Rank.king:
        return 'ملك';
      case Rank.queen:
        return 'كبري';
      case Rank.jack:
        return 'شايب';
      case Rank.ten:
        return '١٠';
      case Rank.nine:
        return '٩';
      case Rank.eight:
        return '٨';
      case Rank.seven:
        return '٧';
      case Rank.six:
        return '٦';
      case Rank.five:
        return '٥';
      case Rank.four:
        return '٤';
      case Rank.three:
        return '٣';
      case Rank.two:
        return '٢';
    }
  }

  String get englishName {
    switch (this) {
      case Rank.ace:
        return 'Ace';
      case Rank.king:
        return 'King';
      case Rank.queen:
        return 'Queen';
      case Rank.jack:
        return 'Jack';
      case Rank.ten:
        return 'Ten';
      case Rank.nine:
        return 'Nine';
      case Rank.eight:
        return 'Eight';
      case Rank.seven:
        return 'Seven';
      case Rank.six:
        return 'Six';
      case Rank.five:
        return 'Five';
      case Rank.four:
        return 'Four';
      case Rank.three:
        return 'Three';
      case Rank.two:
        return 'Two';
    }
  }
}

class Card {
  final String id;
  final Suit suit;
  final Rank rank;

  const Card({required this.id, required this.suit, required this.rank});

  static String generateId(Suit suit, Rank rank) {
    return '${rank.name}_of_${suit.name}';
  }

  bool get isKingOfHearts => suit == Suit.hearts && rank == Rank.king;

  @override
  String toString() => '${rank.englishName} of ${suit.englishName}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Card &&
          runtimeType == other.runtimeType &&
          suit == other.suit &&
          rank == other.rank;

  @override
  int get hashCode => suit.hashCode ^ rank.hashCode;
}