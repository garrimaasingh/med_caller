import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/providers/theme_provider.dart';
import '../core/providers/ai_settings.dart';
import '../core/theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final user = FirebaseAuth.instance.currentUser;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final aiSettings = context.watch<AiSettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryBlue, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.person, size: 60, color: AppTheme.primaryBlue),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.edit, size: 16, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              user?.email ?? 'Doctor Anderson',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text('Cardiology Department', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 48),

            // AI Settings (Read-Only — managed by Admin Panel)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'AI SETTINGS (Managed by Admin)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.grey[800]! : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _infoTile(
                    icon: Icons.api,
                    label: 'NVIDIA API',
                    value: aiSettings.isConfigured ? 'Connected' : 'Not configured',
                    valueColor: aiSettings.isConfigured ? Colors.green : Colors.orange,
                  ),
                  const Divider(height: 1),
                  _infoTile(
                    icon: Icons.model_training,
                    label: 'Active Model',
                    value: aiSettings.model.split('/').last,
                  ),
                  const Divider(height: 1),
                  _infoTile(
                    icon: Icons.thermostat,
                    label: 'Temperature',
                    value: aiSettings.temperature.toStringAsFixed(2),
                  ),
                  const Divider(height: 1),
                  _infoTile(
                    icon: Icons.token,
                    label: 'Max Tokens',
                    value: aiSettings.maxTokens.toString(),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'AI settings are managed from the Admin Panel. Contact your admin to make changes.',
                              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            // Theme Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text('THEME', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.grey[800]! : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text('Light Mode'),
                    value: ThemeMode.light,
                    groupValue: themeProvider.themeMode,
                    onChanged: (v) => themeProvider.setThemeMode(v!),
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Dark Mode'),
                    value: ThemeMode.dark,
                    groupValue: themeProvider.themeMode,
                    onChanged: (v) => themeProvider.setThemeMode(v!),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerRed,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _infoTile({required IconData icon, required String label, required String value, Color? valueColor}) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryBlue, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      subtitle: Text(
        value,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor),
      ),
    );
  }
}
