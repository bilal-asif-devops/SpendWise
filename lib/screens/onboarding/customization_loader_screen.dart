import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'profiling_donut_painter.dart';

class CustomizationLoaderScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const CustomizationLoaderScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<CustomizationLoaderScreen> createState() =>
      _CustomizationLoaderScreenState();
}

class _CustomizationLoaderScreenState extends State<CustomizationLoaderScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  late Animation<double> _rotationAnimation;

  int _currentStepIndex = 0;
  Timer? _textTimer;

  static const List<String> _statusSteps = [
    'Creating your profile...',
    'Polishing interface...',
    'Creating categories...',
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 3.14159 * 2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.linear,
      ),
    );

    _textTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (mounted && _currentStepIndex < _statusSteps.length - 1) {
        setState(() {
          _currentStepIndex++;
        });
      }
    });

    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _textTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // 5-Color Animated Custom Donut Loader
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(180, 180),
                      painter: ProfilingDonutPainter(
                        progress: _progressAnimation.value,
                        rotation: _rotationAnimation.value,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 48),

                // Main Heading matching Spendee
                const Text(
                  'Customizing your experience',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 14),

                // Dynamic Status Text
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: Text(
                    _statusSteps[_currentStepIndex],
                    key: ValueKey<int>(_currentStepIndex),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Transparent offline notice
                const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Text(
                    'Setting up your local offline-first database and initial category envelopes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
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
