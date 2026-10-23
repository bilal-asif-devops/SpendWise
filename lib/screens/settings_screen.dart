import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_models.dart';
import '../services/auth_sync_provider.dart';
import '../services/finance_provider.dart';
import '../theme/app_theme.dart';
import 'auth/backend_status_modal.dart';
import 'auth/email_auth_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _biometricsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context);
    final authSync = Provider.of<AuthSyncProvider?>(context);
    final authUser = authSync?.currentUser;
    final bool isAuthenticated = authSync?.isAuthenticated ?? false;
    final String? photoUrl = authUser?.photoUrl;

    final bool isSynced = authSync?.syncStatus == SyncStatus.synced &&
        authSync?.lastSyncTime != null;
    final bool isSyncing = authSync?.syncStatus == SyncStatus.syncing;
    final bool isOffline = authSync?.syncStatus == SyncStatus.offline;

    final String syncBadgeText;
    final IconData syncBadgeIcon;
    final Color syncBadgeColor;
    final Color syncBadgeBg;

    if (!isAuthenticated) {
      syncBadgeText = "Free Tier • Local Storage";
      syncBadgeIcon = Icons.shield_outlined;
      syncBadgeColor = AppColors.textDark;
      syncBadgeBg = AppColors.accentGreen.withValues(alpha: 0.15);
    } else if (isSynced) {
      syncBadgeText = "Cloud Synced • Firebase";
      syncBadgeIcon = Icons.cloud_done_rounded;
      syncBadgeColor = AppColors.accentGreen;
      syncBadgeBg = Colors.green.shade50;
    } else if (isSyncing) {
      syncBadgeText = "Syncing to Cloud...";
      syncBadgeIcon = Icons.sync_rounded;
      syncBadgeColor = Colors.blue.shade700;
      syncBadgeBg = Colors.blue.shade50;
    } else if (isOffline) {
      syncBadgeText = "Sync Pending • Offline";
      syncBadgeIcon = Icons.cloud_off_rounded;
      syncBadgeColor = Colors.orange.shade800;
      syncBadgeBg = Colors.orange.shade50;
    } else {
      syncBadgeText = "Account Connected • Firebase";
      syncBadgeIcon = Icons.cloud_outlined;
      syncBadgeColor = Colors.blue.shade700;
      syncBadgeBg = Colors.blue.shade50;
    }

    final String displayName = (authUser?.displayName != null &&
            authUser!.displayName!.trim().isNotEmpty)
        ? authUser.displayName!.trim()
        : finance.userName;
    final String displayEmail =
        (authUser?.email != null && authUser!.email!.trim().isNotEmpty)
            ? authUser.email!.trim()
            : finance.userEmail;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Card
              Container(
                key: const Key('settings_profile_card'),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primaryNavy,
                      backgroundImage: (photoUrl != null &&
                              photoUrl.isNotEmpty &&
                              !photoUrl.contains('default-user'))
                          ? NetworkImage(photoUrl)
                          : null,
                      onBackgroundImageError:
                          photoUrl != null ? (_, __) {} : null,
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : "G",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            key: const Key('settings_profile_name'),
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayEmail,
                            key: const Key('settings_profile_email'),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: syncBadgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  syncBadgeIcon,
                                  size: 12,
                                  color: syncBadgeColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  syncBadgeText,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: syncBadgeColor,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Account & Cloud Section
              const Text(
                "Account & Cloud Sync",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),

              Material(
                color: AppColors.surfaceWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppColors.borderLight),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (isAuthenticated) ...[
                      ListTile(
                        leading: const Icon(Icons.sync_rounded,
                            color: AppColors.accentGreen),
                        title: const Text("Sync Now",
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                          authSync?.lastSyncTime != null
                              ? "Last synced: ${authSync!.lastSyncTime!.toLocal().toString().split('.').first}"
                              : "Tap to sync with Cloud Firestore",
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.textMuted),
                        onTap: () async {
                          await authSync?.syncVaultWithCloud();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Vault synced to cloud!"),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.logout_rounded,
                            color: Colors.redAccent),
                        title: const Text("Sign Out",
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.redAccent)),
                        subtitle: Text(
                          "Sign out of $displayEmail",
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () async {
                          await authSync?.logout();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Signed out successfully"),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    ] else ...[
                      ListTile(
                        leading: const Icon(Icons.cloud_upload_outlined,
                            color: AppColors.primaryNavy),
                        title: const Text("Sign In or Register",
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text(
                          "Sync your finances with Google or Email",
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.textMuted),
                        onTap: () => EmailAuthSheet.show(context),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.info_outline_rounded,
                            color: AppColors.textMuted),
                        title: const Text("Backend Engine Status",
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text(
                          "View live Firebase configuration status",
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.textMuted),
                        onTap: () => BackendStatusModal.show(context),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Preferences Section
              const Text(
                "Preferences & Security",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),

              Material(
                color: AppColors.surfaceWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppColors.borderLight),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SwitchListTile(
                      activeThumbColor: AppColors.accentGreen,
                      title: const Text("Push Notifications",
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text(
                          "Alert 48h before auto-renew charges",
                          style: TextStyle(fontSize: 12)),
                      value: _notificationsEnabled,
                      onChanged: (val) =>
                          setState(() => _notificationsEnabled = val),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      activeThumbColor: AppColors.accentGreen,
                      title: const Text("Biometric App Lock",
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text("Fingerprint / Face ID protection",
                          style: TextStyle(fontSize: 12)),
                      value: _biometricsEnabled,
                      onChanged: (val) =>
                          setState(() => _biometricsEnabled = val),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      title: const Text("Default Currency",
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      trailing: DropdownButton<String>(
                        value: finance.currency,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                              value: "\$", child: Text("USD (\$)")),
                          DropdownMenuItem(
                              value: "Rs", child: Text("PKR (Rs)")),
                          DropdownMenuItem(value: "€", child: Text("EUR (€)")),
                        ],
                        onChanged: (val) {
                          if (val != null) finance.updateCurrency(val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Data & Backup Section
              const Text(
                "Data Management",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),

              Material(
                color: AppColors.surfaceWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppColors.borderLight),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.file_download_outlined,
                          color: AppColors.primaryNavy),
                      title: const Text("Export Financial Report",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                          "Download monthly CSV / PDF statement",
                          style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.textMuted),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Exported report successfully!"),
                            backgroundColor: AppColors.accentGreen,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
