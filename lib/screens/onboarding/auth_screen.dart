import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_sync_provider.dart';
import '../../theme/app_theme.dart';
import '../auth/backend_status_modal.dart';
import '../auth/email_auth_sheet.dart';
import '../auth/guest_migration_dialog.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onExploreAsGuest;
  final VoidCallback? onAuthenticated;

  const AuthScreen({
    super.key,
    required this.onExploreAsGuest,
    this.onAuthenticated,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoadingGoogle = false;

  void _showAuthPrototypeNotice(BuildContext context, String providerName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.cloud_queue_rounded, color: AppColors.primaryNavy),
            const SizedBox(width: 8),
            Text('$providerName Sign-In'),
          ],
        ),
        content: Text(
          '$providerName authentication and cloud sync are scheduled for Phase 3.\n\nYou can explore the complete application right now with full offline data storage in Guest mode.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onExploreAsGuest();
            },
            child: const Text('Continue as Guest'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignIn(AuthSyncProvider? authProvider) async {
    if (authProvider == null) {
      _showAuthPrototypeNotice(context, 'Google');
      return;
    }

    setState(() => _isLoadingGoogle = true);
    final success = await authProvider.loginWithGoogle();
    if (!mounted) return;
    setState(() => _isLoadingGoogle = false);

    if (success) {
      if (authProvider.hasPendingGuestMigration) {
        final shouldMerge = await GuestMigrationDialog.show(context);
        if (mounted && shouldMerge != null) {
          await authProvider.resolveGuestMigration(
            mergeGuestData: shouldMerge,
          );
        }
      }
      if (mounted) {
        widget.onAuthenticated?.call();
        if (widget.onAuthenticated == null) {
          widget.onExploreAsGuest();
        }
      }
    } else if (authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleEmailAuth(AuthSyncProvider? authProvider) {
    if (authProvider == null) {
      _showAuthPrototypeNotice(context, 'Email');
      return;
    }

    EmailAuthSheet.show(
      context,
      onSuccess: () {
        widget.onAuthenticated?.call();
        if (widget.onAuthenticated == null) {
          widget.onExploreAsGuest();
        }
      },
    );
  }

  void _handleGuestEntry(AuthSyncProvider? authProvider) {
    authProvider?.continueAsGuest();
    widget.onExploreAsGuest();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthSyncProvider?>(context);
    final isConfigured = authProvider?.isBackendConfigured ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  child: Column(
                    children: [
                      // Top Bar: Back button (if canPop) and Backend Status Pill
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (Navigator.canPop(context))
                            IconButton(
                              key: const Key('auth_back_button'),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: AppColors.textDark,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.maybePop(context),
                              tooltip: 'Back to onboarding',
                            )
                          else
                            const SizedBox(width: 24),
                          if (authProvider != null)
                            TextButton.icon(
                              onPressed: () => BackendStatusModal.show(context),
                              icon: Icon(
                                isConfigured
                                    ? Icons.cloud_done_rounded
                                    : Icons.info_outline_rounded,
                                size: 16,
                                color: isConfigured
                                    ? AppColors.accentGreen
                                    : AppColors.textMuted,
                              ),
                              label: Text(
                                isConfigured
                                    ? 'Cloud Connected'
                                    : 'Engine Status',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isConfigured
                                      ? AppColors.accentGreen
                                      : AppColors.textMuted,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: isConfigured
                                    ? AppColors.accentGreen
                                        .withValues(alpha: 0.1)
                                    : Colors.grey.shade100,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                        ],
                      ),

                      const Spacer(flex: 1),

                      // Brand Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavy,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.primaryNavy.withValues(alpha: 0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: AppColors.accentGreen,
                          size: 42,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Headline
                      const Text(
                        'Save your financial journey',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 10),

                      const Text(
                        'Sign in to sync your financial data securely, or explore SpendWise locally with complete offline privacy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Sign in with Google
                      _AuthButton(
                        key: const Key('auth_google_button'),
                        icon: _isLoadingGoogle
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : const Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF4285F4),
                                ),
                              ),
                        label: 'Continue with Google',
                        onPressed: _isLoadingGoogle
                            ? () {}
                            : () => _handleGoogleSignIn(authProvider),
                      ),
                      const SizedBox(height: 12),

                      // Sign in with Email
                      _AuthButton(
                        icon: const Icon(
                          Icons.mail_outline_rounded,
                          color: AppColors.textDark,
                          size: 22,
                        ),
                        label: 'Sign up with Email',
                        onPressed: () => _handleEmailAuth(authProvider),
                      ),

                      const Spacer(flex: 2),

                      // Divider
                      Row(
                        children: [
                          const Expanded(
                              child: Divider(color: AppColors.borderLight)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'OR CONTINUE PRIVATELY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color:
                                    AppColors.textMuted.withValues(alpha: 0.8),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Expanded(
                              child: Divider(color: AppColors.borderLight)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Explore as Guest Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () => _handleGuestEntry(authProvider),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_outline_rounded, size: 20),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Explore as Guest',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        '100% Private • Local-First On-Device Storage',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onPressed;

  const _AuthButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceWhite,
          side: const BorderSide(color: AppColors.borderLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
