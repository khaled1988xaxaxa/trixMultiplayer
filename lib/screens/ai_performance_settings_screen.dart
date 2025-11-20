import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/ai_processing_optimizer.dart';
import '../providers/ai_provider.dart';
import '../widgets/optimized_ui_components.dart';

/// Screen for configuring AI performance and processing settings
class AIPerformanceSettingsScreen extends StatefulWidget {
  const AIPerformanceSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AIPerformanceSettingsScreen> createState() => _AIPerformanceSettingsScreenState();
}

class _AIPerformanceSettingsScreenState extends State<AIPerformanceSettingsScreen> {
  bool _fastMode = AIProcessingConfig.enableFastMode;
  bool _parallelProcessing = AIProcessingConfig.enableParallelProcessing;
  bool _adaptiveDelays = AIProcessingConfig.enableAdaptiveDelays;
  double _speedMultiplier = AIProcessingConfig.gameSpeedMultiplier;
  
  Map<String, dynamic>? _performanceStats;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPerformanceStats();
  }

  void _loadPerformanceStats() {
    setState(() {
      _performanceStats = AIProcessingOptimizer().getPerformanceStats();
    });
  }

  void _applySettings() {
    setState(() {
      _isLoading = true;
    });

    AIProcessingConfig.configure(
      fastMode: _fastMode,
      parallelProcessing: _parallelProcessing,
      adaptiveDelays: _adaptiveDelays,
      speedMultiplier: _speedMultiplier,
    );

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI performance settings applied successfully'),
        backgroundColor: Colors.green,
      ),
    );

    setState(() {
      _isLoading = false;
    });
  }

  void _resetMetrics() {
    AIProcessingOptimizer().resetMetrics();
    _loadPerformanceStats();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Performance metrics reset'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Performance Settings'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPerformanceStats,
            tooltip: 'Refresh Stats',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Performance Settings Section
            _buildSettingsSection(),
            const SizedBox(height: 24),
            
            // Performance Statistics Section
            _buildStatisticsSection(),
            const SizedBox(height: 24),
            
            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Processing Settings',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 16),
            
            // Fast Mode Toggle
            SwitchListTile(
              title: const Text('Fast Mode'),
              subtitle: const Text('Reduce AI thinking delays for faster gameplay'),
              value: _fastMode,
              onChanged: (value) {
                setState(() {
                  _fastMode = value;
                });
              },
              activeColor: Colors.green,
            ),
            
            // Parallel Processing Toggle
            SwitchListTile(
              title: const Text('Parallel Processing'),
              subtitle: const Text('Use multiple threads for AI decisions (mobile only)'),
              value: _parallelProcessing,
              onChanged: (value) {
                setState(() {
                  _parallelProcessing = value;
                });
              },
              activeColor: Colors.blue,
            ),
            
            // Adaptive Delays Toggle
            SwitchListTile(
              title: const Text('Adaptive Delays'),
              subtitle: const Text('Automatically adjust delays based on AI performance'),
              value: _adaptiveDelays,
              onChanged: (value) {
                setState(() {
                  _adaptiveDelays = value;
                });
              },
              activeColor: Colors.orange,
            ),
            
            const SizedBox(height: 16),
            
            // Speed Multiplier Slider
            Text(
              'Game Speed Multiplier: ${_speedMultiplier.toStringAsFixed(1)}x',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _speedMultiplier,
              min: 0.1,
              max: 3.0,
              divisions: 29,
              label: '${_speedMultiplier.toStringAsFixed(1)}x',
              onChanged: (value) {
                setState(() {
                  _speedMultiplier = value;
                });
              },
            ),
            Text(
              'Adjust overall game speed (0.1x = very slow, 3.0x = very fast)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Performance Statistics',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                TextButton(
                  onPressed: _resetMetrics,
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_performanceStats != null) ..._buildStatisticsTiles(),
            
            if (_performanceStats == null)
              const Center(
                child: Text(
                  'No performance data available yet.\nPlay some games to see statistics.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStatisticsTiles() {
    final stats = _performanceStats!;
    
    return [
      _buildStatTile(
        'Total AI Decisions',
        stats['total_decisions']?.toString() ?? '0',
        Icons.psychology,
        Colors.blue,
      ),
      _buildStatTile(
        'Fast Decisions',
        stats['fast_decisions']?.toString() ?? '0',
        Icons.speed,
        Colors.green,
      ),
      _buildStatTile(
        'Fast Decision Rate',
        '${((stats['fast_decision_rate'] ?? 0.0) * 100).toStringAsFixed(1)}%',
        Icons.trending_up,
        Colors.orange,
      ),
      _buildStatTile(
        'Average Decision Time',
        '${(stats['average_decision_time_ms'] ?? 0.0).toStringAsFixed(0)}ms',
        Icons.timer,
        Colors.purple,
      ),
      
      if (stats['adaptive_delays'] != null) ..._buildAdaptiveDelayStats(stats['adaptive_delays']),
    ];
  }

  Widget _buildStatTile(String title, String value, IconData icon, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 16,
        ),
      ),
    );
  }

  List<Widget> _buildAdaptiveDelayStats(Map<String, dynamic> adaptiveDelays) {
    return [
      const Divider(),
      Text(
        'Adaptive Delays by Difficulty',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),
      ...adaptiveDelays.entries.map((entry) => 
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(entry.key),
              Text(
                '${entry.value}ms',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ).toList(),
    ];
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _applySettings,
            icon: _isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_isLoading ? 'Applying...' : 'Apply Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}