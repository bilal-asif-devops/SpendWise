import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_models.dart';
import '../services/auth_sync_provider.dart';
import '../services/biometric_service.dart';
import '../services/finance_provider.dart';
import '../theme/app_theme.dart';
import 'auth/backend_status_modal.dart';
import 'auth/email_auth_sheet.dart';
import 'auth/logout_confirmation_dialog.dart';
import 'onboarding/onboarding_flow_screen.dart';
import 'profile/edit_profile_dialog.dart';

class SettingsScreen extends StatefulWidget {
  final BiometricService? biometricService;

  const SettingsScreen({
    super.key,
    this.biometricService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final BiometricService _biometricService;
  bool _notificationsEnabled = true;
  bool _isBiometricsSupported = false;
  bool _isCheckingBiometrics = true;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    _biometricService = widget.biometricService ?? DeviceBiometricService();
    _checkBiometricsCapability();
  }

  Future<void> _checkBiometricsCapability() async {
    final supported = await _biometricService.isHardwareSupported;
    if (mounted) {
      setState(() {
        _isBiometricsSupported = supported;
        _isCheckingBiometrics = false;
      });
    }
  }

  Future<void> _handleProfileEdit(
      String currentName, String currentEmail) async {
    final updated = await EditProfileDialog.show(
      context,
      currentName: currentName,
      currentEmail: currentEmail,
    );
    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile updated successfully!"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.accentGreen,
        ),
      );
    }
  }

  Future<void> _handleSignOut(
      String displayEmail, AuthSyncProvider? authSync) async {
    if (_isSigningOut) return;

    final confirmed = await LogoutConfirmationDialog.show(
      context,
      userEmail: displayEmail,
    );

    if (confirmed == true && mounted) {
      setState(() => _isSigningOut = true);
      try {
        await authSync?.logout();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Signed out successfully"),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const OnboardingFlowScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Sign out error: $e"),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSigningOut = false);
        }
      }
    }
  }

  Future<void> _handleBiometricToggle(
      bool enable, FinanceProvider finance) async {
    if (!_isBiometricsSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            kIsWeb
                ? "Biometric lock is not available in browser environments."
                : "Biometric hardware sensors are not available on this device.",
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final reason = enable
        ? "Authenticate to enable Biometric Hardware Lock"
        : "Authenticate to disable Biometric Hardware Lock";

    final success =
        await _biometricService.authenticate(localizedReason: reason);
    if (success) {
      finance.toggleBiometrics(enable);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enable
                  ? "Biometric Hardware Lock enabled."
                  : "Biometric Lock disabled.",
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.accentGreen,
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Biometric verification cancelled or failed."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context);
    final authSync = Provider.of<AuthSyncProvider?>(context);
    final authUser = authSync?.currentUser;
    final bool isAuthenticated = authSync?.isAuthenticated ?? false;
    final String? photoUrl = authUser?.photoUrl;

    final isDark =
        Theme.of(context).brightness == Brightness.dark || finance.isDarkMode;
    final bgColor = isDark ? const Color(0xFF0F172A) : AppColors.background;
    final cardBg = isDark ? AppColors.darkCard : AppColors.surfaceWhite;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.textDark;
    final textMuted = isDark ? const Color(0xFF94A3B8) : AppColors.textMuted;
    final borderColor =
        isDark ? const Color(0xFF334155) : AppColors.borderLight;

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
      syncBadgeColor = isDark ? const Color(0xFF94A3B8) : AppColors.textDark;
      syncBadgeBg = AppColors.accentGreen.withValues(alpha: 0.15);
    } else if (isSynced) {
      syncBadgeText = "Cloud Synced • Firebase";
      syncBadgeIcon = Icons.cloud_done_rounded;
      syncBadgeColor = AppColors.accentGreen;
      syncBadgeBg = isDark
          ? AppColors.accentGreen.withValues(alpha: 0.15)
          : Colors.green.shade50;
    } else if (isSyncing) {
      syncBadgeText = "Syncing to Cloud...";
      syncBadgeIcon = Icons.sync_rounded;
      syncBadgeColor = Colors.blue.shade400;
      syncBadgeBg = Colors.blue.withValues(alpha: 0.15);
    } else if (isOffline) {
      syncBadgeText = "Sync Pending • Offline";
      syncBadgeIcon = Icons.cloud_off_rounded;
      syncBadgeColor = Colors.orange.shade400;
      syncBadgeBg = Colors.orange.withValues(alpha: 0.15);
    } else {
      syncBadgeText = "Account Connected • Firebase";
      syncBadgeIcon = Icons.cloud_outlined;
      syncBadgeColor = Colors.blue.shade400;
      syncBadgeBg = Colors.blue.withValues(alpha: 0.15);
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
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text("Settings",
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
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
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
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
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayEmail,
                            key: const Key('settings_profile_email'),
                            style: TextStyle(fontSize: 12, color: textMuted),
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
                    IconButton(
                      key: const Key('settings_edit_profile_button'),
                      icon: const Icon(Icons.edit_outlined),
                      color: textMuted,
                      tooltip: "Edit Profile Name",
                      onPressed: () =>
                          _handleProfileEdit(displayName, displayEmail),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Account & Cloud Section
              Text(
                "Account & Cloud Sync",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textMuted),
              ),
              const SizedBox(height: 10),

              Material(
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (isAuthenticated) ...[
                      ListTile(
                        leading: const Icon(Icons.sync_rounded,
                            color: AppColors.accentGreen),
                        title: Text("Sync Now",
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: textPrimary)),
                        subtitle: Text(
                          authSync?.lastSyncTime != null
                              ? "Last synced: ${authSync!.lastSyncTime!.toLocal().toString().split('.').first}"
                              : "Tap to sync with Cloud Firestore",
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                        trailing: Icon(Icons.chevron_right, color: textMuted),
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
                      Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: borderColor),
                      ListTile(
                        key: const Key('settings_sign_out_button'),
                        leading: _isSigningOut
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.redAccent,
                                ),
                              )
                            : const Icon(Icons.logout_rounded,
                                color: Colors.redAccent),
                        title: const Text("Sign Out",
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.redAccent)),
                        subtitle: Text(
                          "Sign out of $displayEmail",
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                        onTap: _isSigningOut
                            ? null
                            : () => _handleSignOut(displayEmail, authSync),
                      ),
                    ] else ...[
                      ListTile(
                        key: const Key('settings_sign_in_button'),
                        leading: const Icon(Icons.cloud_upload_outlined,
                            color: AppColors.primaryNavy),
                        title: Text("Sign In or Register",
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: textPrimary)),
                        subtitle: Text(
                          "Sync your finances with Google or Email",
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                        trailing: Icon(Icons.chevron_right, color: textMuted),
                        onTap: () => EmailAuthSheet.show(context),
                      ),
                      Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: borderColor),
                      ListTile(
                        leading:
                            Icon(Icons.info_outline_rounded, color: textMuted),
                        title: Text("Backend Engine Status",
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: textPrimary)),
                        subtitle: Text(
                          "View live Firebase configuration status",
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                        trailing: Icon(Icons.chevron_right, color: textMuted),
                        onTap: () => BackendStatusModal.show(context),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Preferences Section
              Text(
                "Preferences & Security",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textMuted),
              ),
              const SizedBox(height: 10),

              Material(
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SwitchListTile(
                      activeThumbColor: AppColors.accentGreen,
                      title: Text("Push Notifications",
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: textPrimary)),
                      subtitle: Text("Alert 48h before auto-renew charges",
                          style: TextStyle(fontSize: 12, color: textMuted)),
                      value: _notificationsEnabled,
                      onChanged: (val) =>
                          setState(() => _notificationsEnabled = val),
                    ),
                    Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: borderColor),
                    SwitchListTile(
                      key: const Key('settings_biometrics_switch'),
                      activeThumbColor: AppColors.accentGreen,
                      title: Text("Biometric Hardware Lock",
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: textPrimary)),
                      subtitle: Text(
                        _isCheckingBiometrics
                            ? "Checking biometric sensor..."
                            : (_isBiometricsSupported
                                ? "Fingerprint / Face ID protection"
                                : (kIsWeb
                                    ? "Not supported in browser environment"
                                    : "Hardware sensor not available on device")),
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                      value:
                          _isBiometricsSupported && finance.biometricsEnabled,
                      onChanged: _isBiometricsSupported
                          ? (val) => _handleBiometricToggle(val, finance)
                          : null,
                    ),
                    Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: borderColor),
                    SwitchListTile(
                      key: const Key('settings_dark_theme_switch'),
                      activeThumbColor: AppColors.accentGreen,
                      title: Text("Dark Theme",
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: textPrimary)),
                      subtitle: Text("OLED friendly dark mode interface",
                          style: TextStyle(fontSize: 12, color: textMuted)),
                      value: finance.isDarkMode,
                      onChanged: (val) => finance.toggleDarkMode(val),
                    ),
                    Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: borderColor),
                    ListTile(
                      title: Text("Default Currency",
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: textPrimary)),
                      trailing: DropdownButton<String>(
                        value: finance.currency,
                        dropdownColor: cardBg,
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(
                              value: "\$",
                              child: Text("USD (\$)",
                                  style: TextStyle(color: textPrimary))),
                          DropdownMenuItem(
                              value: "Rs",
                              child: Text("PKR (Rs)",
                                  style: TextStyle(color: textPrimary))),
                          DropdownMenuItem(
                              value: "€",
                              child: Text("EUR (€)",
                                  style: TextStyle(color: textPrimary))),
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
              Text(
                "Data Management",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textMuted),
              ),
              const SizedBox(height: 10),

              Material(
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.file_download_outlined,
                          color: textPrimary),
                      title: Text("Export Financial Report",
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textPrimary)),
                      subtitle: Text("Download monthly CSV / PDF statement",
                          style: TextStyle(fontSize: 12, color: textMuted)),
                      trailing: Icon(Icons.chevron_right, color: textMuted),
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
