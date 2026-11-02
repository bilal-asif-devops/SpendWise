import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_sync_provider.dart';
import '../services/finance_provider.dart';
import '../theme/app_theme.dart';
import 'main_navigation.dart';
import 'onboarding/onboarding_flow_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _animationController.forward();

    // Ensure transition occurs once provider is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitializationAndNavigate();
    });

    // Fallback timer to ensure navigation if already initialized
    _fallbackTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        _navigate();
      }
    });
  }

  Future<void> _checkInitializationAndNavigate() async {
    final finance = Provider.of<FinanceProvider>(context, listen: false);
    final authSync = Provider.of<AuthSyncProvider?>(context, listen: false);

    try {
      await Future.wait([
        if (!finance.isInitialized) finance.initializationFuture,
        if (authSync != null && !authSync.isAuthInitialized)
          authSync.ensureInitialized,
      ]).timeout(const Duration(milliseconds: 1200));
    } catch (_) {
      // Safe fallback on timeout
    }

    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      _navigate();
    }
  }

  void _navigate() {
    _fallbackTimer?.cancel();
    if (!mounted) return;

    final finance = Provider.of<FinanceProvider>(context, listen: false);
    final authSync = Provider.of<AuthSyncProvider?>(context, listen: false);

    final bool isAuthenticated = authSync?.isAuthenticated ?? false;
    final bool hasCompletedOnboarding = finance.hasCompletedOnboarding;

    final Widget destination = (isAuthenticated || hasCompletedOnboarding)
        ? const MainNavigationScreen()
        : const OnboardingFlowScreen();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // SpendWise Modern Brand Icon
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.primaryNavy,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryNavy.withValues(alpha: 0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.accentGreen,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // SpendWise Title
                const Text(
                  'SpendWise',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryNavy,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),

                // Tagline
                const Text(
                  'Smart Budgeting & Financial Control',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
