import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/finance_provider.dart';
import '../theme/app_theme.dart';

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
              // User Profile Card from Figma Screen 6
              Container(
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
                      child: Text(
                        finance.userName.isNotEmpty
                            ? finance.userName[0].toUpperCase()
                            : "B",
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
                            finance.userName,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "bilal.uet@student.taxila.edu",
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "Free Tier • Local Storage",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.accentGreen,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
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

              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderLight),
                ),
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

              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderLight),
                ),
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
