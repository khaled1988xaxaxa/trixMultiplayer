import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_logging_provider.dart';

/// Dialog to get user consent for AI training data collection
class AIDataConsentDialog extends StatefulWidget {
  const AIDataConsentDialog({super.key});

  @override
  State<AIDataConsentDialog> createState() => _AIDataConsentDialogState();
}

class _AIDataConsentDialogState extends State<AIDataConsentDialog> {
  bool _agreedToTerms = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.psychology, color: Colors.blue),
          SizedBox(width: 8),
          Text(
            'تحسين الذكاء الاصطناعي',
            style: TextStyle(fontSize: 18),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'مساعدة في تطوير الذكاء الاصطناعي',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'نود جمع بيانات حول أسلوب لعبك لتحسين أداء الذكاء الاصطناعي في اللعبة.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'البيانات المجمعة:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildDataPoint('• الأوراق التي تلعبها'),
            _buildDataPoint('• توقيت اتخاذ القرارات'),
            _buildDataPoint('• حالة اللعبة عند كل قرار'),
            _buildDataPoint('• نتائج القرارات'),
            const SizedBox(height: 16),
            const Text(
              'الضمانات:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildDataPoint('• لا يتم جمع معلومات شخصية'),
            _buildDataPoint('• البيانات مشفرة ومجهولة الهوية'),
            _buildDataPoint('• يمكنك إيقاف الجمع في أي وقت'),
            _buildDataPoint('• يمكنك حذف بياناتك كاملة'),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _agreedToTerms,
                  onChanged: (value) {
                    setState(() {
                      _agreedToTerms = value ?? false;
                    });
                  },
                ),
                const Expanded(
                  child: Text(
                    'أوافق على جمع البيانات لتحسين الذكاء الاصطناعي',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _handleDecision(false);
          },
          child: const Text('رفض'),
        ),
        ElevatedButton(
          onPressed: _agreedToTerms ? () => _handleDecision(true) : null,
          child: const Text('موافق'),
        ),
      ],
    );
  }

  Widget _buildDataPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, right: 8),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }

  void _handleDecision(bool consent) {
    final loggingProvider = context.read<AILoggingProvider>();
    loggingProvider.setUserConsent(consent);
    Navigator.of(context).pop();
    
    if (consent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('شكراً لك! سيساعد هذا في تحسين أداء الذكاء الاصطناعي'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

/// Widget to show current logging status (optional indicator)
class AILoggingStatusIndicator extends StatelessWidget {
  const AILoggingStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AILoggingProvider>(
      builder: (context, loggingProvider, child) {
        if (!loggingProvider.isEnabled) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.psychology,
                size: 16,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                'تحسين الذكاء',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
