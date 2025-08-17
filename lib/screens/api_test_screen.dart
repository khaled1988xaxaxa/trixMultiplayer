import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';

class APITestScreen extends StatefulWidget {
  const APITestScreen({super.key});

  @override
  State<APITestScreen> createState() => _APITestScreenState();
}

class _APITestScreenState extends State<APITestScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _testResults;
  final List<Map<String, dynamic>> _responseTimeHistory = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: const Text('API Speed Test'),
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D1B2A),
              Color(0xFF1E3A8A),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Test Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _runAPITest,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.speed),
                    label: Text(
                      _isLoading ? 'Testing...' : 'Test API Connection',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Multiple Tests Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _runMultipleTests,
                    icon: const Icon(Icons.repeat),
                    label: const Text('Run 5 Tests'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Latest Test Results
                if (_testResults != null) _buildTestResultCard(),

                const SizedBox(height: 20),

                // Response Time History
                if (_responseTimeHistory.isNotEmpty) _buildHistorySection(),

                const SizedBox(height: 20),

                // Help Text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📊 Response Time Guide:',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• < 1000ms: Excellent 🟢\n'
                        '• 1000-2000ms: Good 🟡\n'
                        '• 2000-5000ms: Slow 🟠\n'
                        '• > 5000ms: Very Slow 🔴\n'
                        '• Timeout: Connection Issues ❌',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestResultCard() {
    final result = _testResults!;
    final totalTime = result['totalTime'] as int;
    final success = result['success'] as bool;
    final steps = result['steps'] as List<dynamic>? ?? [];
    
    Color statusColor;
    String statusText;
    
    if (!success) {
      statusColor = Colors.red;
      statusText = 'Failed';
    } else if (totalTime < 1000) {
      statusColor = Colors.green;
      statusText = 'Excellent';
    } else if (totalTime < 2000) {
      statusColor = Colors.yellow;
      statusText = 'Good';
    } else if (totalTime < 5000) {
      statusColor = Colors.orange;
      statusText = 'Slow';
    } else {
      statusColor = Colors.red;
      statusText = 'Very Slow';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Latest Test Result',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Overall metrics
          _buildResultRow('Total Time', '${totalTime}ms', statusColor),
          _buildResultRow('Network Reachable', result['networkReachable'] ? 'Yes' : 'No', 
              result['networkReachable'] ? Colors.green : Colors.red),
          _buildResultRow('API Key Valid', result['apiKeyValid'] ? 'Yes' : 'No',
              result['apiKeyValid'] ? Colors.green : Colors.red),
          
          if (result['error'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Error Details:',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result['error'].toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Step-by-step breakdown
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Step-by-Step Breakdown:',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ...steps.map<Widget>((step) => _buildStepRow(step)),
          ],
          
          // Technical details
          if (result['details'] != null) ...[
            const SizedBox(height: 16),
            _buildTechnicalDetails(result['details']),
          ],
        ],
      ),
    );
  }

  Widget _buildStepRow(Map<String, dynamic> step) {
    final stepName = step['step'] as String;
    final duration = step['duration'] as int;
    final status = step['status'] as String;
    final error = step['error'] as String?;
    
    Color stepColor;
    IconData stepIcon;
    
    switch (status) {
      case 'success':
        stepColor = Colors.green;
        stepIcon = Icons.check_circle;
        break;
      case 'failed':
        stepColor = Colors.red;
        stepIcon = Icons.error;
        break;
      case 'timeout':
        stepColor = Colors.orange;
        stepIcon = Icons.timer_off;
        break;
      case 'partial':
        stepColor = Colors.yellow;
        stepIcon = Icons.warning;
        break;
      default:
        stepColor = Colors.grey;
        stepIcon = Icons.help;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: stepColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: stepColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(stepIcon, color: stepColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stepName,
                  style: TextStyle(
                    color: stepColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                '${duration}ms',
                style: TextStyle(
                  color: stepColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error,
              style: TextStyle(
                color: stepColor,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTechnicalDetails(Map<String, dynamic> details) {
    return ExpansionTile(
      title: const Text(
        'Technical Details',
        style: TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      iconColor: Colors.blue,
      collapsedIconColor: Colors.blue,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (details['host'] != null)
                _buildDetailRow('Host', details['host'].toString()),
              if (details['scheme'] != null)
                _buildDetailRow('Protocol', details['scheme'].toString().toUpperCase()),
              if (details['port'] != null)
                _buildDetailRow('Port', details['port'].toString()),
              if (details['requestSize'] != null)
                _buildDetailRow('Request Size', '${details['requestSize']} bytes'),
              if (details['responseSize'] != null)
                _buildDetailRow('Response Size', '${details['responseSize']} bytes'),
              if (details['httpStatusCode'] != null)
                _buildDetailRow('HTTP Status', details['httpStatusCode'].toString()),
              if (details['aiModel'] != null)
                _buildDetailRow('AI Model', details['aiModel'].toString()),
              if (details['usage'] != null)
                _buildDetailRow('Token Usage', details['usage'].toString()),
              if (details['errorType'] != null)
                _buildDetailRow('Error Type', details['errorType'].toString()),
              if (details['timeoutDuration'] != null)
                _buildDetailRow('Timeout After', '${details['timeoutDuration']}s'),
              if (details['responseContent'] != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'AI Response:',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    details['responseContent'].toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    // Filter out entries that don't have valid totalTime values
    final validEntries = _responseTimeHistory
        .where((r) => r['totalTime'] != null && r['totalTime'] is int)
        .toList();
    
    if (validEntries.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final avgResponseTime = validEntries
        .map((r) => r['totalTime'] as int)
        .reduce((a, b) => a + b) / validEntries.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Response Time History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Avg: ${avgResponseTime.round()}ms',
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _responseTimeHistory.length,
            itemBuilder: (context, index) {
              final test = _responseTimeHistory[index];
              final totalTime = test['totalTime'] as int? ?? 0;
              final success = test['success'] as bool? ?? false;
              
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: success ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: success ? Colors.green : Colors.red,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Test ${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      success ? '${totalTime}ms' : 'Failed',
                      style: TextStyle(
                        color: success ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _runAPITest() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current AI service
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final result = await gameProvider.testAIConnection();
      
      setState(() {
        _testResults = result;
        _responseTimeHistory.add(result);
        // Keep only last 10 tests
        if (_responseTimeHistory.length > 10) {
          _responseTimeHistory.removeAt(0);
        }
      });
    } catch (e) {
      setState(() {
        _testResults = {
          'success': false,
          'error': e.toString(),
          'totalTime': 0,
          'apiKeyValid': false,
          'networkReachable': false,
        };
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _runMultipleTests() async {
    setState(() {
      _isLoading = true;
    });

    for (int i = 0; i < 5; i++) {
      await _runSingleTest();
      await Future.delayed(const Duration(milliseconds: 500)); // Small delay between tests
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _runSingleTest() async {
    try {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final result = await gameProvider.testAIConnection();
      
      setState(() {
        _testResults = result;
        _responseTimeHistory.add(result);
        if (_responseTimeHistory.length > 10) {
          _responseTimeHistory.removeAt(0);
        }
      });
    } catch (e) {
      // Handle individual test failures
    }
  }
}