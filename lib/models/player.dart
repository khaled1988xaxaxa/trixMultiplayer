import 'card.dart';

class Player {
  final String id;
  final String name;
  final List<Card> hand;
  int score;
  bool isBot;
  PlayerPosition position;

  Player({
    required this.id,
    required this.name,
    required this.position,
    List<Card>? hand,
    this.score = 0,
    this.isBot = false,
  }) : hand = hand ?? <Card>[];

  Player copyWith({
    String? id,
    String? name,
    List<Card>? hand,
    int? score,
    bool? isBot,
    PlayerPosition? position,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      hand: hand ?? this.hand,
      score: score ?? this.score,
      isBot: isBot ?? this.isBot,
      position: position ?? this.position,
    );
  }

  void addCard(Card card) {
    hand.add(card);
  }

  Card? removeCard(Card card) {
    if (hand.contains(card)) {
      hand.remove(card);
      return card;
    }
    return null;
  }

  void sortHand() {
    hand.sort((a, b) {
      if (a.suit != b.suit) {
        return a.suit.index.compareTo(b.suit.index);
      }
      return a.rank.value.compareTo(b.rank.value);
    });
  }

  bool get hasCards => hand.isNotEmpty;

  @override
  String toString() => 'Player($name, Score: $score, Cards: ${hand.length})';
}

enum PlayerPosition {
  north,
  east,
  south,
  west;

  String get arabicName {
    switch (this) {
      case PlayerPosition.north:
        return 'شمال';
      case PlayerPosition.east:
        return 'شرق';
      case PlayerPosition.south:
        return 'جنوب';
      case PlayerPosition.west:
        return 'غرب';
    }
  }

  String get englishName {
    switch (this) {
      case PlayerPosition.north:
        return 'North';
      case PlayerPosition.east:
        return 'East';
      case PlayerPosition.south:
        return 'South';
      case PlayerPosition.west:
        return 'West';
    }
  }

  PlayerPosition get next {
    switch (this) {
      case PlayerPosition.north:
        return PlayerPosition.east;
      case PlayerPosition.east:
        return PlayerPosition.south;
      case PlayerPosition.south:
        return PlayerPosition.west;
      case PlayerPosition.west:
        return PlayerPosition.north;
    }
  }

  PlayerPosition get opposite {
    switch (this) {
      case PlayerPosition.north:
        return PlayerPosition.south;
      case PlayerPosition.east:
        return PlayerPosition.west;
      case PlayerPosition.south:
        return PlayerPosition.north;
      case PlayerPosition.west:
        return PlayerPosition.east;
    }
  }
}