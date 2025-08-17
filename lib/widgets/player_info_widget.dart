import 'package:flutter/material.dart';
import '../models/player.dart';

class PlayerInfoWidget extends StatelessWidget {
  final Player player;
  final bool isCurrentPlayer;
  final bool isCurrentUser;

  const PlayerInfoWidget({
    super.key,
    required this.player,
    this.isCurrentPlayer = false,
    this.isCurrentUser = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrentPlayer 
            ? Colors.amber.withOpacity(0.9)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentUser 
              ? Colors.blue 
              : isCurrentPlayer 
                  ? Colors.amber 
                  : Colors.grey.shade300,
          width: isCurrentUser ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player name
          Text(
            player.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isCurrentPlayer ? Colors.black87 : Colors.black,
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Score and cards count
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star,
                size: 16,
                color: Colors.orange,
              ),
              Text(
                '${player.score}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.credit_card,
                size: 16,
                color: Colors.blue,
              ),
              Text(
                '${player.hand.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          // Bot indicator
          if (player.isBot)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'بوت',
                style: TextStyle(fontSize: 10),
              ),
            ),
          
          // Current player indicator
          if (isCurrentPlayer)
            Container(
              margin: const EdgeInsets.only(top: 4),
              child: const Icon(
                Icons.play_arrow,
                size: 16,
                color: Colors.green,
              ),
            ),
        ],
      ),
    );
  }
}