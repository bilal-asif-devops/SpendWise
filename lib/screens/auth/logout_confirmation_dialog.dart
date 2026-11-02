import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class LogoutConfirmationDialog extends StatelessWidget {
  final String userEmail;

  const LogoutConfirmationDialog({
    super.key,
    required this.userEmail,
  });

  static Future<bool?> show(BuildContext context, {required String userEmail}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LogoutConfirmationDialog(userEmail: userEmail),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.surfaceWhite;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.textDark;
    final textMuted = isDark ? const Color(0xFF94A3B8) : AppColors.textMuted;
    final borderColor =
        isDark ? const Color(0xFF334155) : AppColors.borderLight;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: cardBg,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      "Sign Out of SpendWise?",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                "You are currently signed in as:",
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_circle_outlined,
                        size: 16, color: textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        userEmail,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Your financial transactions, accounts, and budgets remain safely synchronized in your cloud account. Local records on this device will be preserved.",
                style: TextStyle(
                  fontSize: 12.5,
                  color: textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: borderColor),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      "Sign Out",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
