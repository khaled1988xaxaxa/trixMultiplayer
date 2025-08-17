import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_logging_provider.dart';

/// Settings screen for AI data collection preferences
class AIDataSettingsScreen extends StatelessWidget {
  const AIDataSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الذكاء الاصطناعي'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AILoggingProvider>(
        builder: (context, loggingProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.psychology, color: Colors.blue.shade700, size: 28),
                          const SizedBox(width: 12),
                          const Text(
                            'تحسين الذكاء الاصطناعي',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ساعد في تطوير الذكاء الاصطناعي من خلال مشاركة بيانات أسلوب لعبك',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Main Settings
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('تفعيل جمع البيانات'),
                      subtitle: const Text('مشاركة بيانات اللعب لتحسين الذكاء الاصطناعي'),
                      value: loggingProvider.isEnabled,
                      onChanged: loggingProvider.hasConsent
                          ? (value) => loggingProvider.setLoggingEnabled(value)
                          : null,
                      secondary: const Icon(Icons.data_usage),
                    ),
                    
                    if (!loggingProvider.hasConsent)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              'لم يتم منح الموافقة على جمع البيانات',
                              style: TextStyle(color: Colors.orange),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => _showConsentDialog(context, loggingProvider),
                              child: const Text('مراجعة الموافقة'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Data Information
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ما هي البيانات المجمعة؟',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoItem(
                        Icons.casino,
                        'الأوراق المُلعبة',
                        'الأوراق التي تختار لعبها في كل دور',
                      ),
                      _buildInfoItem(
                        Icons.timer,
                        'توقيت القرارات',
                        'الوقت المستغرق لاتخاذ كل قرار',
                      ),
                      _buildInfoItem(
                        Icons.gamepad,
                        'حالة اللعبة',
                        'الأوراق المتاحة ونتائج الأدوار السابقة',
                      ),
                      _buildInfoItem(
                        Icons.analytics,
                        'نتائج القرارات',
                        'نجاح أو فشل الاستراتيجيات المختلفة',
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Privacy & Security
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'الخصوصية والأمان',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildPrivacyItem(
                        Icons.security,
                        'بيانات مجهولة الهوية',
                        'لا يتم جمع أي معلومات شخصية',
                      ),
                      _buildPrivacyItem(
                        Icons.lock,
                        'تشفير البيانات',
                        'جميع البيانات مشفرة أثناء النقل والتخزين',
                      ),
                      _buildPrivacyItem(
                        Icons.delete,
                        'حذف البيانات',
                        'يمكنك حذف جميع بياناتك في أي وقت',
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Actions
              if (loggingProvider.hasConsent) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'إجراءات البيانات',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _confirmDeleteData(context, loggingProvider),
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('حذف جميع البيانات'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'سيؤدي هذا إلى حذف جميع البيانات المجمعة محلياً وإيقاف الجمع',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.green.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showConsentDialog(BuildContext context, AILoggingProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('موافقة على جمع البيانات'),
        content: const Text(
          'هل تريد السماح بجمع بيانات أسلوب لعبك لتحسين الذكاء الاصطناعي؟\n\n'
          'يمكنك تغيير هذا القرار في أي وقت من الإعدادات.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              provider.setUserConsent(false);
              Navigator.of(context).pop();
            },
            child: const Text('رفض'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.setUserConsent(true);
              Navigator.of(context).pop();
            },
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteData(BuildContext context, AILoggingProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف البيانات'),
        content: const Text(
          'هل أنت متأكد من حذف جميع البيانات المجمعة؟\n\n'
          'لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.clearAllData();
              await provider.setUserConsent(false);
              Navigator.of(context).pop();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم حذف جميع البيانات بنجاح'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
