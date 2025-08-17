import 'package:flutter/material.dart';
import '../models/ai_difficulty.dart';
import '../services/ai_manager.dart';

class AISettingsWidget extends StatefulWidget {
  final AIDifficulty selectedDifficulty;
  final Function(AIDifficulty) onDifficultyChanged;
  final int? playerGamesPlayed;
  final double? playerWinRate;
  final bool showRecommendations;

  const AISettingsWidget({
    super.key,
    required this.selectedDifficulty,
    required this.onDifficultyChanged,
    this.playerGamesPlayed,
    this.playerWinRate,
    this.showRecommendations = true,
  });

  @override
  State<AISettingsWidget> createState() => _AISettingsWidgetState();
}

class _AISettingsWidgetState extends State<AISettingsWidget> {
  late AIDifficulty _selectedDifficulty;
  AIDifficulty? _recommendedDifficulty;

  @override
  void initState() {
    super.initState();
    _selectedDifficulty = widget.selectedDifficulty;
    _calculateRecommendation();
  }

  void _calculateRecommendation() {
    if (widget.showRecommendations && 
        widget.playerGamesPlayed != null && 
        widget.playerWinRate != null) {
      _recommendedDifficulty = AIManager().getRecommendedDifficulty(
        playerGamesPlayed: widget.playerGamesPlayed!,
        playerWinRate: widget.playerWinRate!,
        currentDifficulty: _selectedDifficulty,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.smart_toy,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'إعدادات الذكاء الاصطناعي',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Recommendation banner
            if (_recommendedDifficulty != null && 
                _recommendedDifficulty != _selectedDifficulty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'نقترح عليك مستوى: ${_recommendedDifficulty!.arabicName}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedDifficulty = _recommendedDifficulty!;
                        });
                        widget.onDifficultyChanged(_selectedDifficulty);
                      },
                      child: const Text('تطبيق'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Difficulty selection
            Text(
              'اختر مستوى الصعوبة:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Difficulty grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 3,
              ),
              itemCount: AIDifficulty.availableDifficulties.length,
              itemBuilder: (context, index) {
                AIDifficulty difficulty = AIDifficulty.availableDifficulties[index];
                bool isSelected = difficulty == _selectedDifficulty;
                bool isRecommended = difficulty == _recommendedDifficulty;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDifficulty = difficulty;
                    });
                    widget.onDifficultyChanged(difficulty);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isRecommended
                            ? Colors.orange
                            : isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade300,
                        width: isRecommended ? 2 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                difficulty.arabicName,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  difficulty.experienceLevel,
                                  (starIndex) => Icon(
                                    Icons.star,
                                    size: 12,
                                    color: isSelected 
                                        ? Colors.white 
                                        : Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isRecommended)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.recommend,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Selected difficulty info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedDifficulty.arabicName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: List.generate(
                          _selectedDifficulty.experienceLevel,
                          (index) => const Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedDifficulty.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // Performance stats (if available)
            if (widget.playerGamesPlayed != null && widget.playerWinRate != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إحصائياتك:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('الألعاب المكتملة: ${widget.playerGamesPlayed}'),
                        Text('معدل الفوز: ${(widget.playerWinRate! * 100).toStringAsFixed(1)}%'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Quick AI difficulty selector for game setup
class QuickAIDifficultySelector extends StatelessWidget {
  final AIDifficulty selectedDifficulty;
  final Function(AIDifficulty) onChanged;
  final bool compact;

  const QuickAIDifficultySelector({
    super.key,
    required this.selectedDifficulty,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AIDifficulty>(
          value: selectedDifficulty,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          onChanged: (AIDifficulty? newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
          items: AIDifficulty.values.map<DropdownMenuItem<AIDifficulty>>(
            (AIDifficulty difficulty) {
              return DropdownMenuItem<AIDifficulty>(
                value: difficulty,
                child: Row(
                  children: [
                    Icon(
                      Icons.smart_toy,
                      size: compact ? 16 : 20,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        difficulty.arabicName,
                        style: TextStyle(
                          fontSize: compact ? 14 : 16,
                        ),
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 8),
                      Row(
                        children: List.generate(
                          difficulty.experienceLevel,
                          (index) => const Icon(
                            Icons.star,
                            size: 12,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ).toList(),
        ),
      ),
    );
  }
}
