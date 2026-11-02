import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_sync_provider.dart';
import '../../theme/app_theme.dart';
import 'guest_migration_dialog.dart';

enum AuthMode { signIn, signUp, forgotPassword }

class EmailAuthSheet extends StatefulWidget {
  final VoidCallback? onSuccess;

  const EmailAuthSheet({
    super.key,
    this.onSuccess,
  });

  static Future<void> show(BuildContext context, {VoidCallback? onSuccess}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EmailAuthSheet(onSuccess: onSuccess),
    );
  }

  @override
  State<EmailAuthSheet> createState() => _EmailAuthSheetState();
}

class _EmailAuthSheetState extends State<EmailAuthSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  AuthMode _mode = AuthMode.signIn;
  bool _obscurePassword = true;
  bool _isLoadingGoogle = false;
  String? _localError;
  String? _successBanner;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    final authProvider = context.read<AuthSyncProvider>();
    setState(() {
      _isLoadingGoogle = true;
      _localError = null;
      _successBanner = null;
    });

    final success = await authProvider.loginWithGoogle();
    if (!mounted) return;
    setState(() => _isLoadingGoogle = false);

    if (success) {
      if (authProvider.hasPendingGuestMigration) {
        final shouldMigrate = await GuestMigrationDialog.show(context);
        if (mounted && shouldMigrate != null) {
          await authProvider.resolveGuestMigration(
            mergeGuestData: shouldMigrate,
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess?.call();
      }
    } else {
      setState(() {
        _localError = authProvider.errorMessage ?? 'Google Sign-In failed.';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _localError = null;
      _successBanner = null;
    });

    final authProvider = context.read<AuthSyncProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    bool success = false;

    if (_mode == AuthMode.forgotPassword) {
      success = await authProvider.sendPasswordReset(email);
      if (mounted) {
        if (success) {
          setState(() {
            _successBanner =
                'Password reset link sent! Check your email inbox.';
          });
        } else {
          setState(() {
            _localError =
                authProvider.errorMessage ?? 'Failed to send reset email.';
          });
        }
      }
      return;
    }

    if (_mode == AuthMode.signIn) {
      success = await authProvider.loginWithEmail(email, password);
    } else {
      success = await authProvider.registerWithEmail(
        email,
        password,
        displayName: name.isNotEmpty ? name : null,
      );
    }

    if (!mounted) return;

    if (success) {
      if (authProvider.hasPendingGuestMigration) {
        // Show guest migration dialog
        final shouldMigrate = await GuestMigrationDialog.show(context);
        if (mounted && shouldMigrate != null) {
          await authProvider.resolveGuestMigration(
            mergeGuestData: shouldMigrate,
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess?.call();
      }
    } else {
      setState(() {
        _localError = authProvider.errorMessage ?? 'Authentication failed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final authProvider = context.watch<AuthSyncProvider>();
    final isLoading = authProvider.isProcessing;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : AppColors.surfaceWhite;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.textDark;
    final textMuted = isDark ? const Color(0xFF94A3B8) : AppColors.textMuted;
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.grey.shade50;
    final borderColor =
        isDark ? const Color(0xFF334155) : AppColors.borderLight;

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: bottomInset + 24,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title & Subtitle
              Text(
                _mode == AuthMode.signIn
                    ? 'Welcome Back'
                    : _mode == AuthMode.signUp
                        ? 'Create an Account'
                        : 'Reset Password',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _mode == AuthMode.signIn
                    ? 'Sign in to access your synchronized financial data.'
                    : _mode == AuthMode.signUp
                        ? 'Create a secure account to sync your finances across devices.'
                        : 'Enter your email address to receive a password reset link.',
                style: TextStyle(
                  fontSize: 13,
                  color: textMuted,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),

              // Error Banner
              if (_localError != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 18, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _localError!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Success Banner
              if (_successBanner != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 18, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successBanner!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Google Sign-In Button (for Sign In and Sign Up)
              if (_mode != AuthMode.forgotPassword) ...[
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    key: const Key('email_sheet_google_button'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: cardBg,
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: (_isLoadingGoogle || isLoading)
                        ? null
                        : _handleGoogleSignIn,
                    child: _isLoadingGoogle
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF4285F4),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: Divider(color: borderColor)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR WITH EMAIL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: borderColor)),
                  ],
                ),
                const SizedBox(height: 18),
              ],

              // Name Field (only sign up)
              if (_mode == AuthMode.signUp) ...[
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: TextStyle(color: textMuted),
                    hintText: 'e.g. John Doe',
                    hintStyle: TextStyle(color: textMuted),
                    prefixIcon:
                        Icon(Icons.person_outline_rounded, color: textMuted),
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
              ],

              // Email Field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: TextStyle(color: textMuted),
                  hintText: 'name@example.com',
                  hintStyle: TextStyle(color: textMuted),
                  prefixIcon:
                      Icon(Icons.mail_outline_rounded, color: textMuted),
                  filled: true,
                  fillColor: cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Password Field (sign in and sign up)
              if (_mode != AuthMode.forgotPassword) ...[
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: textMuted),
                    prefixIcon:
                        Icon(Icons.lock_outline_rounded, color: textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: textMuted,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (v.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
              ],

              // Forgot password link
              if (_mode == AuthMode.signIn) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() {
                      _mode = AuthMode.forgotPassword;
                      _localError = null;
                      _successBanner = null;
                    }),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Primary Action Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _mode == AuthMode.signIn
                              ? 'Sign In'
                              : _mode == AuthMode.signUp
                                  ? 'Create Account'
                                  : 'Send Reset Link',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Mode toggle link
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _localError = null;
                      _successBanner = null;
                      if (_mode == AuthMode.signIn) {
                        _mode = AuthMode.signUp;
                      } else {
                        _mode = AuthMode.signIn;
                      }
                    });
                  },
                  child: Text(
                    _mode == AuthMode.signIn
                        ? "Don't have an account? Sign Up"
                        : _mode == AuthMode.signUp
                            ? 'Already have an account? Sign In'
                            : 'Back to Sign In',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
