import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_sync_provider.dart';
import '../services/finance_provider.dart';
import '../theme/app_theme.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  @override
  Widget build(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context);
    final authSync = Provider.of<AuthSyncProvider?>(context);
    final authUser = authSync?.currentUser;
    final bool isAuthenticated = authSync?.isAuthenticated ?? false;
    final String? photoUrl = authUser?.photoUrl;

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
        title: const Text(
          "Settings & Preferences",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Card from Figma Screen 6
              Container(
                key: const Key('more_profile_card'),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(22),
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
                            fontSize: 24,
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
                            key: const Key('more_profile_name'),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayEmail,
                            key: const Key('more_profile_email'),
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAuthenticated
                                  ? Colors.green.shade50
                                  : AppColors.accentGreen
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAuthenticated
                                      ? Icons.cloud_done_rounded
                                      : Icons.shield_outlined,
                                  size: 12,
                                  color: isAuthenticated
                                      ? AppColors.accentGreen
                                      : AppColors.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAuthenticated
                                      ? "Cloud Synced • Firebase"
                                      : "Spendee Recreation Edition • Guest",
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isAuthenticated
                                          ? AppColors.accentGreen
                                          : AppColors.textDark,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_outlined, color: AppColors.textMuted),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Preferences & Security
              const Text(
                "Notifications & Security",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),

              Material(
                color: AppColors.surfaceWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.borderLight),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SwitchListTile(
                      activeThumbColor: AppColors.accentGreen,
                      title: const Text("Advance 48h Renewal Reminders",
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text(
                          "Local alerts before next bill charge",
                          style: TextStyle(fontSize: 12)),
                      value: finance.notificationsEnabled,
                      onChanged: (val) => finance.toggleNotifications(val),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      activeThumbColor: AppColors.accentGreen,
                      title: const Text("Biometric Hardware Lock",
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text("Fingerprint / Face ID protection",
                          style: TextStyle(fontSize: 12)),
                      value: finance.biometricsEnabled,
                      onChanged: (val) => finance.toggleBiometrics(val),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      activeThumbColor: AppColors.accentGreen,
                      title: const Text("Dark Theme",
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text("OLED friendly dark mode interface",
                          style: TextStyle(fontSize: 12)),
                      value: finance.isDarkMode,
                      onChanged: (val) => finance.toggleDarkMode(val),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      title: const Text("Primary Currency",
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      trailing: DropdownButton<String>(
                        value: finance.currency,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                              value: "\$", child: Text("USD (\$)")),
                          DropdownMenuItem(value: "€", child: Text("EUR (€)")),
                          DropdownMenuItem(
                              value: "Rs", child: Text("PKR (Rs)")),
                          DropdownMenuItem(value: "£", child: Text("GBP (£)")),
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

              // Data & Local JSON Backup Section
              const Text(
                "Data & Local JSON Backup",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Keep a portable copy of your local vault.",
                      style:
                          TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 14),

                    // Export Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final jsonStr = await finance.exportVaultJson();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                  "Exported JSON Vault (${jsonStr.length} bytes) successfully!"),
                              backgroundColor: AppColors.accentGreen,
                            ),
                          );
                        },
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text("Export JSON Backup File",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Import Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.borderLight),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Vault is currently up to date."),
                            ),
                          );
                        },
                        icon: const Icon(Icons.file_upload_outlined,
                            size: 18, color: AppColors.primaryNavy),
                        label: const Text("Import JSON Backup File",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryNavy)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Warning Alert
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.amber.shade800, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Import replaces all local data. Export a backup first so you can recover your current vault.",
                              style: TextStyle(
                                  fontSize: 11, color: Colors.amber.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 100% Offline Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.accentGreen.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_outlined,
                        color: AppColors.accentGreen, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "100% offline • Local JSON vault • Private by design",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
