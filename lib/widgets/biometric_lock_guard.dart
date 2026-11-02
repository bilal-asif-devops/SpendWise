import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/biometric_service.dart';
import '../services/finance_provider.dart';
import '../theme/app_theme.dart';

class BiometricLockGuard extends StatefulWidget {
  final Widget child;
  final BiometricService? biometricService;

  /// Set to true when opening a system picker (e.g. file chooser, camera)
  /// so that SpendWise does not trigger an unexpected biometric lock when paused.
  static bool isSystemPickerActive = false;

  const BiometricLockGuard({
    super.key,
    required this.child,
    this.biometricService,
  });

  @override
  State<BiometricLockGuard> createState() => BiometricLockGuardState();
}

class BiometricLockGuardState extends State<BiometricLockGuard>
    with WidgetsBindingObserver {
  late final BiometricService _biometricService;
  bool _isLocked = false;
  bool _isAuthenticating = false;
  bool _initialCheckDone = false;

  bool get isLocked => _isLocked;

  @visibleForTesting
  void setLockedForTesting(bool locked) {
    setState(() => _isLocked = locked);
  }

  @override
  void initState() {
    super.initState();
    _biometricService = widget.biometricService ?? DeviceBiometricService();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkInitialColdLaunchLock();
  }

  void _checkInitialColdLaunchLock() {
    if (kIsWeb) return;
    if (_initialCheckDone) return;

    final finance = Provider.of<FinanceProvider?>(context, listen: true);
    if (finance == null) return;

    if (finance.biometricsEnabled) {
      _initialCheckDone = true;
      setState(() => _isLocked = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          promptBiometricUnlock();
        }
      });
    } else if (finance.isInitialized) {
      _initialCheckDone = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;
    final finance = Provider.of<FinanceProvider?>(context, listen: false);
    if (finance == null || !finance.biometricsEnabled) return;

    // Avoid locking again if the biometric prompt itself caused an inactive/paused transition
    // or if a deliberate system picker (file dialog) is currently active.
    if (_isAuthenticating || BiometricLockGuard.isSystemPickerActive) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (!_isLocked) {
        setState(() => _isLocked = true);
      }
    } else if (state == AppLifecycleState.resumed && _isLocked) {
      promptBiometricUnlock();
    }
  }

  Future<void> promptBiometricUnlock() async {
    if (_isAuthenticating) return;

    final supported = await _biometricService.isHardwareSupported;
    if (!supported) {
      if (mounted) {
        setState(() {
          _isLocked = false;
          _isAuthenticating = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isAuthenticating = true);
    }

    final success = await _biometricService.authenticate(
      localizedReason: 'Authenticate to unlock SpendWise',
    );

    if (mounted) {
      setState(() {
        _isAuthenticating = false;
        if (success) {
          _isLocked = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : AppColors.background;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.textDark;
    final textMuted = isDark ? const Color(0xFF94A3B8) : AppColors.textMuted;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Keep the child (Navigator, routes, and active async tasks) mounted in the tree
          // When locked, Offstage hides it from layout, paint, hit testing, and accessibility
          Offstage(
            offstage: _isLocked,
            child: widget.child,
          ),
          if (_isLocked)
            Positioned.fill(
              child: Scaffold(
                backgroundColor: bg,
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.accentGreen.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.fingerprint_rounded,
                            size: 64,
                            color: AppColors.accentGreen,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "SpendWise Locked",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Biometric Hardware Lock is active. Verify your fingerprint or Face ID to continue.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14, color: textMuted, height: 1.4),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          key: const Key('biometric_unlock_button'),
                          onPressed:
                              _isAuthenticating ? null : promptBiometricUnlock,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                          ),
                          icon: const Icon(Icons.lock_open_rounded),
                          label: const Text(
                            "Unlock with Biometrics",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
