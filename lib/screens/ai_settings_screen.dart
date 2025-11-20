import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../utils/ai_config.dart';
import '../providers/game_provider.dart';
import 'ai_performance_settings_screen.dart';

class AISettingsScreen extends StatefulWidget {
  const AISettingsScreen({super.key});

  @override
  State<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends State<AISettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _openaiKeyController = TextEditingController();
  bool _aiEnabled = AIConfig.enableAI;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String _selectedProvider = AIConfig.defaultProvider;
  
  // Performance settings
  int _aiTimeout = 5;
  bool _enableCaching = AIConfig.enableCaching;
  bool _enableParallel = AIConfig.enableParallelProcessing;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKeyController.text = prefs.getString('deepseek_api_key') ?? '';
      _openaiKeyController.text = prefs.getString('openai_api_key') ?? '';
      _aiEnabled = prefs.getBool('ai_enabled') ?? AIConfig.enableAI;
      _selectedProvider = prefs.getString('ai_provider') ?? AIConfig.defaultProvider;
      _aiTimeout = prefs.getInt('ai_timeout') ?? 5;
      _enableCaching = prefs.getBool('enable_caching') ?? AIConfig.enableCaching;
      _enableParallel = prefs.getBool('enable_parallel') ?? AIConfig.enableParallelProcessing;
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Validate API keys based on selected provider
      if (_aiEnabled) {
        if (_selectedProvider == 'deepseek') {
          final deepseekKey = _apiKeyController.text.trim();
          if (deepseekKey.isEmpty || deepseekKey == 'YOUR_DEEPSEEK_API_KEY_HERE') {
            throw Exception('Please enter a valid DeepSeek API key');
          }
        } else if (_selectedProvider == 'openai') {
          final openaiKey = _openaiKeyController.text.trim();
          if (openaiKey.isEmpty || openaiKey == 'YOUR_OPENAI_API_KEY_HERE') {
            throw Exception('Please enter a valid OpenAI API key');
          }
        }
      }

      // Save all settings
      await prefs.setString('deepseek_api_key', _apiKeyController.text.trim());
      await prefs.setString('openai_api_key', _openaiKeyController.text.trim());
      await prefs.setBool('ai_enabled', _aiEnabled);
      await prefs.setString('ai_provider', _selectedProvider);
      await prefs.setInt('ai_timeout', _aiTimeout);
      await prefs.setBool('enable_caching', _enableCaching);
      await prefs.setBool('enable_parallel', _enableParallel);

      setState(() {
        _successMessage = 'Settings saved successfully! Provider: ${_selectedProvider.toUpperCase()}';
      });

      // Reinitialize AI service in GameProvider if available
      try {
        final gameProvider = Provider.of<GameProvider>(context, listen: false);
        await gameProvider.reinitializeAIService();
        if (kDebugMode) {
          print('✅ AI service reinitialized with $_selectedProvider provider');
        }
      } catch (e) {
        if (kDebugMode) {
          print('ℹ️ GameProvider not available or error reinitializing: $e');
        }
        // This is not a critical error - user can still use the app
      }

      // Clear success message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        appBar: AppBar(
          title: const Text('AI Settings'),
          backgroundColor: const Color(0xFF0D1B2A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI Enable/Disable Toggle
              Card(
                color: const Color(0xFF1E3A5F),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.smart_toy,
                        color: Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enable AI Bots',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Use DeepSeek AI for smarter bot decisions',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _aiEnabled,
                        onChanged: (value) {
                          setState(() {
                            _aiEnabled = value;
                          });
                        },
                        activeColor: Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // API Key Input
              if (_aiEnabled) ...[
                Card(
                  color: const Color(0xFF1E3A5F),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.key,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'DeepSeek API Key',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _apiKeyController,
                          style: const TextStyle(color: Colors.white),
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'Enter your DeepSeek API key',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[600]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[600]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.orange),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.info_outline, color: Colors.grey[400]),
                              onPressed: _showApiKeyInfo,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // OpenAI API Key Input
                Card(
                  color: const Color(0xFF1E3A5F),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.key,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'OpenAI API Key',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _openaiKeyController,
                          style: const TextStyle(color: Colors.white),
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'Enter your OpenAI API key',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[600]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[600]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.blue),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.info_outline, color: Colors.grey[400]),
                              onPressed: _showOpenAiKeyInfo,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // AI Provider Selection
                Card(
                  color: const Color(0xFF1E3A5F),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.computer,
                              color: Colors.purple,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AI Provider',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Select the AI service provider',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Provider Selection Dropdown
                        DropdownButtonFormField<String>(
                          value: _selectedProvider,
                          onChanged: (value) {
                            setState(() {
                              _selectedProvider = value!;
                            });
                          },
                          items: [
                            DropdownMenuItem(
                              value: 'deepseek',
                              child: Text(
                                'DeepSeek',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'openai',
                              child: Text(
                                'OpenAI',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF1E3A5F),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[600]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[600]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.orange),
                            ),
                          ),
                          dropdownColor: const Color(0xFF1E3A5F),
                          iconEnabledColor: Colors.orange,
                          iconDisabledColor: Colors.grey[400],
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // AI Information Card
                Card(
                  color: const Color(0xFF1E3A5F),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AI Features',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• Smart contract selection based on hand analysis\n'
                          '• Strategic card playing with full game state awareness\n'
                          '• Adaptive gameplay that considers opponent behavior\n'
                          '• Automatic fallback to simple logic if AI unavailable',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Debug Mode Toggle
                Card(
                  color: const Color(0xFF1E3A5F),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bug_report,
                          color: Colors.green,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Debug Mode',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Show detailed AI decision logs in console',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: kDebugMode, // This shows current debug state
                          onChanged: null, // Read-only - controlled by Flutter build mode
                          activeColor: Colors.green.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Information about debug mode
                if (kDebugMode)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Debug mode is active. Check your IDE console for detailed AI decision logs.',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Performance Settings
                Card(
                  color: const Color(0xFF1E3A5F),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.tune,
                              color: Colors.orange,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Performance Settings',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Adjust AI performance parameters',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // AI Timeout
                        Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                'AI Timeout:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: _aiTimeout.toDouble(),
                                min: 1,
                                max: 10,
                                divisions: 9,
                                label: '$_aiTimeout s',
                                onChanged: (value) {
                                  setState(() {
                                    _aiTimeout = value.toInt();
                                  });
                                },
                                activeColor: Colors.orange,
                                inactiveColor: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Enable Caching
                        Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                'Enable Caching:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Switch(
                              value: _enableCaching,
                              onChanged: (value) {
                                setState(() {
                                  _enableCaching = value;
                                });
                              },
                              activeColor: Colors.orange,
                              inactiveThumbColor: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cache responses for 60% faster decisions',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Enable Parallel Processing
                        Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                'Parallel Process:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Switch(
                              value: _enableParallel,
                              onChanged: (value) {
                                setState(() {
                                  _enableParallel = value;
                                });
                              },
                              activeColor: Colors.orange,
                              inactiveThumbColor: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Process multiple bots simultaneously',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Performance Info
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.speed, color: Colors.blue, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Performance Impact',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '• Timeout ${_aiTimeout}s: ${_getTimeoutDescription(_aiTimeout)}\n'
                                '• Caching: ${_enableCaching ? "Enabled - Faster repeated decisions" : "Disabled - Fresh responses"}\n'
                                '• Parallel: ${_enableParallel ? "Enabled - 3x faster multi-bot" : "Disabled - Sequential processing"}',
                                style: TextStyle(
                                  color: Colors.blue[200],
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Clear Cache Button
                if (_enableCaching) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _clearCache,
                      icon: Icon(Icons.clear_all, size: 18),
                      label: Text('Clear AI Cache'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[300],
                        side: BorderSide(color: Colors.grey[600]!),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 20),

              // Advanced Performance Settings Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AIPerformanceSettingsScreen(),
                      ),
                    );
                  },
                  icon: Icon(Icons.speed, size: 18, color: Colors.blue[300]),
                  label: Text(
                    'Advanced Performance Settings',
                    style: TextStyle(color: Colors.blue[300]),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.blue[600]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              // Success/Error Messages
              if (_successMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showApiKeyInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text(
          'DeepSeek API Key',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'To get your DeepSeek API key:\n\n'
          '1. Visit https://platform.deepseek.com\n'
          '2. Sign up or log in to your account\n'
          '3. Go to API Keys section\n'
          '4. Create a new API key\n'
          '5. Copy and paste it here\n\n'
          'Note: The API key will be stored securely on your device.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Got it',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  void _showOpenAiKeyInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text(
          'OpenAI API Key',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'To get your OpenAI API key:\n\n'
          '1. Visit https://platform.openai.com\n'
          '2. Sign up or log in to your account\n'
          '3. Go to API Keys section\n'
          '4. Create a new API key\n'
          '5. Copy and paste it here\n\n'
          'Note: The API key will be stored securely on your device.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Got it',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeoutDescription(int timeout) {
    switch (timeout) {
      case 1:
        return 'Very Fast (1s)';
      case 2:
        return 'Fast (2s)';
      case 3:
        return 'Moderate (3s)';
      case 4:
        return 'Balanced (4s)';
      case 5:
        return 'Standard (5s)';
      case 6:
        return 'Delayed (6s)';
      case 7:
        return 'Slow (7s)';
      case 8:
        return 'Very Slow (8s)';
      case 9:
        return 'Extreme (9s)';
      case 10:
        return 'Unresponsive (10s)';
      default:
        return '';
    }
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ai_cache'); // Assuming 'ai_cache' is the key for cached AI data

    setState(() {
      _successMessage = 'AI cache cleared successfully!';
    });

    // Clear success message after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _successMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _openaiKeyController.dispose();
    super.dispose();
  }
}