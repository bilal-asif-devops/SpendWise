import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_sync_provider.dart';
import '../../theme/app_theme.dart';

class BackendStatusModal extends StatelessWidget {
  const BackendStatusModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const BackendStatusModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthSyncProvider>();
    final isConfigured = authProvider.isBackendConfigured;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isConfigured
                      ? Colors.green.shade50
                      : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isConfigured
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  color: isConfigured
                      ? Colors.green.shade700
                      : Colors.amber.shade800,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConfigured
                          ? 'Firebase Cloud Backend Active'
                          : 'Local Offline Engine Active',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      isConfigured
                          ? 'Connected to live Firebase Auth & Firestore'
                          : 'Zero external cloud credentials required',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _StatusRow(
            title: 'Authentication Service',
            subtitle: isConfigured
                ? 'Firebase Auth (Google, Email/Password)'
                : 'Local Secure Vault Auth',
            isReady: true,
          ),
          const SizedBox(height: 12),
          _StatusRow(
            title: 'Cloud Synchronization',
            subtitle: isConfigured
                ? 'Cloud Firestore (/users/{uid}/vault/current)'
                : 'Local Encrypted Storage & Import/Export',
            isReady: true,
          ),
          const SizedBox(height: 12),
          const _StatusRow(
            title: 'Firestore Security Rules',
            subtitle: 'firestore.rules generated with per-user isolation',
            isReady: true,
          ),
          const SizedBox(height: 20),
          if (!isConfigured) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'To Connect Your Own Firebase Project:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Run: npx -y firebase-tools@latest login\n'
                    '2. Run: flutterfire configure\n'
                    '3. Deploy rules: npx -y firebase-tools@latest deploy --only firestore:rules\n'
                    '4. Run app with live Google & Email sync!',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: AppColors.textDark,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isReady;

  const _StatusRow({
    required this.title,
    required this.subtitle,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(
            isReady ? Icons.check_circle_rounded : Icons.pending_rounded,
            color: isReady ? AppColors.accentGreen : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
