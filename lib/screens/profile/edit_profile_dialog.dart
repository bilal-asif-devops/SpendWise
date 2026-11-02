import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_sync_provider.dart';
import '../../services/finance_provider.dart';
import '../../theme/app_theme.dart';

class EditProfileDialog extends StatefulWidget {
  final String currentName;
  final String currentEmail;

  const EditProfileDialog({
    super.key,
    required this.currentName,
    required this.currentEmail,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String currentName,
    required String currentEmail,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditProfileDialog(
        currentName: currentName,
        currentEmail: currentEmail,
      ),
    );
  }

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final newName = _nameController.text.trim();
    if (newName == widget.currentName.trim()) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authSync = Provider.of<AuthSyncProvider?>(context, listen: false);
    final finance = Provider.of<FinanceProvider>(context, listen: false);

    bool success = false;
    if (authSync != null) {
      success = await authSync.updateDisplayName(newName);
      if (!success) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              authSync.errorMessage ?? "Failed to update profile name.";
        });
        return;
      }
    } else {
      finance.updateProfile(name: newName);
      success = true;
    }

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.of(context).pop(true);
    }
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: cardBg,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: AppColors.accentGreen,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Edit Profile",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Update your display name",
                            style: TextStyle(fontSize: 12, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: textMuted),
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Display Name Field
                Text(
                  "Display Name",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  enabled: !_isLoading,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Enter your full name",
                    hintStyle: TextStyle(color: textMuted, fontSize: 14),
                    prefixIcon: Icon(Icons.person_outline_rounded,
                        color: textMuted, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.accentGreen, width: 1.8),
                    ),
                  ),
                  validator: (val) {
                    final clean = val?.trim() ?? '';
                    if (clean.isEmpty) {
                      return "Display name cannot be empty.";
                    }
                    if (clean.length < 2) {
                      return "Name must be at least 2 characters long.";
                    }
                    if (clean.length > 50) {
                      return "Name must be 50 characters or less.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email Field (Read-only)
                Text(
                  "Account Email",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  initialValue: widget.currentEmail,
                  readOnly: true,
                  enabled: false,
                  style: TextStyle(color: textMuted, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.mail_outline_rounded,
                        color: textMuted, size: 20),
                    suffixIcon: Tooltip(
                      message: "Email cannot be changed directly",
                      child: Icon(Icons.lock_outline_rounded,
                          color: textMuted, size: 18),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0B132B).withValues(alpha: 0.5)
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: borderColor.withValues(alpha: 0.5)),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: borderColor.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Email address is tied to your login credentials and cloud vault identity.",
                  style: TextStyle(fontSize: 11, color: textMuted),
                ),
                const SizedBox(height: 22),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                            color: textMuted, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Save Changes",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
