import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/game_provider.dart';

class LoggingSettingsScreen extends StatefulWidget {
  const LoggingSettingsScreen({super.key});

  @override
  State<LoggingSettingsScreen> createState() => _LoggingSettingsScreenState();
}

class _LoggingSettingsScreenState extends State<LoggingSettingsScreen> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Data & Logging'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Consumer<GameProvider>(
        builder: (context, gameProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logging Status Section
                _buildSectionCard(
                  title: '📝 Logging System',
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Enable Game Logging'),
                        subtitle: const Text(
                          'Track your gameplay for AI training\n'
                          'Captures decisions, thinking time, and outcomes',
                        ),
                        value: gameProvider.isLoggingEnabled,
                        onChanged: (value) async {
                          await gameProvider.setLoggingEnabled(value);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  value 
                                    ? '✅ Logging enabled - Your games will be tracked'
                                    : '❌ Logging disabled - No data will be collected'
                                ),
                                backgroundColor: value ? Colors.green : Colors.orange,
                              ),
                            );
                          }
                        },
                        activeColor: Colors.deepPurple,
                      ),
                      if (gameProvider.isLoggingEnabled) ...[
                        const Divider(),
                        const ListTile(
                          leading: Icon(Icons.info_outline, color: Colors.blue),
                          title: Text('What gets logged?'),
                          subtitle: Text(
                            '• Card selections and valid options\n'
                            '• Contract choices and hand analysis\n'
                            '• Decision timing and complexity\n'
                            '• Game outcomes and scores\n'
                            '• Strategic patterns and mistakes'
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Export Data Section
                _buildSectionCard(
                  title: '📤 Export Training Data',
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.download, color: Colors.green),
                        title: const Text('Export for AI Training'),
                        subtitle: const Text('Create a file with all your gameplay data'),
                        trailing: _isExporting 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward_ios),
                        onTap: _isExporting ? null : () => _exportTrainingData(gameProvider),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.folder, color: Colors.orange),
                        title: const Text('View Logs Directory'),
                        subtitle: const Text('See where your data is stored'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => _showLogsDirectory(gameProvider),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // AI Training Info Section
                _buildSectionCard(
                  title: '🤖 AI Training Process',
                  child: Column(
                    children: [
                      _buildInfoTile(
                        icon: Icons.psychology,
                        title: 'Behavioral Learning',
                        description: 'AI learns from your decision patterns and strategic choices',
                      ),
                      _buildInfoTile(
                        icon: Icons.timer,
                        title: 'Thinking Time Analysis',
                        description: 'Correlates decision complexity with time spent thinking',
                      ),
                      _buildInfoTile(
                        icon: Icons.trending_up,
                        title: 'Performance Tracking',
                        description: 'Identifies successful strategies and common mistakes',
                      ),
                      _buildInfoTile(
                        icon: Icons.security,
                        title: 'Privacy First',
                        description: 'All data stays on your device until you choose to export',
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Usage Tips Section
                _buildSectionCard(
                  title: '💡 Training Tips',
                  child: Column(
                    children: [
                      _buildTipTile(
                        '🎯 Play Consistently',
                        'Regular gameplay creates better training patterns',
                      ),
                      _buildTipTile(
                        '🤔 Take Your Time',
                        'Thinking time helps AI understand decision complexity',
                      ),
                      _buildTipTile(
                        '📊 Try Different Strategies',
                        'Varied play styles create more comprehensive training data',
                      ),
                      _buildTipTile(
                        '🔄 Export Regularly',
                        'Backup your training data periodically',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipTile(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 24,
            child: Text(
              '•',
              style: TextStyle(
                color: Colors.deepPurple,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportTrainingData(GameProvider gameProvider) async {
    setState(() {
      _isExporting = true;
    });

    try {
      final exportFile = await gameProvider.exportTrainingData();
      
      if (exportFile != null && await exportFile.exists()) {
        final fileSize = await exportFile.length();
        final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
        
        if (mounted) {
          // Show success dialog with options
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('✅ Export Successful'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Training data exported successfully!'),
                  const SizedBox(height: 8),
                  Text('File size: ${fileSizeMB} MB'),
                  Text('Location: ${exportFile.path}'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _shareFile(exportFile);
                  },
                  child: const Text('Share'),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No training data available to export'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _shareFile(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Trix Game Training Data - ${DateTime.now().toIso8601String()}',
        subject: 'AI Training Data Export',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Share failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showLogsDirectory(GameProvider gameProvider) async {
    try {
      final logsDir = await gameProvider.getLogsDirectory();
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('📁 Logs Directory'),
            content: SelectableText(
              'Your training data is stored at:\n\n$logsDir',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error accessing directory: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
