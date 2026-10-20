import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ExitOfferDialog extends StatefulWidget {
  final VoidCallback onDismiss;
  final VoidCallback onClaimOffer;

  const ExitOfferDialog({
    super.key,
    required this.onDismiss,
    required this.onClaimOffer,
  });

  @override
  State<ExitOfferDialog> createState() => _ExitOfferDialogState();
}

class _ExitOfferDialogState extends State<ExitOfferDialog> {
  // Fixed countdown of 4 minutes 58 seconds matching the Spendee walkthrough frame 65
  int _secondsRemaining = 4 * 60 + 58;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_secondsRemaining > 0) {
          setState(() {
            _secondsRemaining--;
          });
        } else {
          timer.cancel();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: AppColors.surfaceWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Gift Icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECEF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text('🎁', style: TextStyle(fontSize: 38)),
                  ),
                ),
                const SizedBox(height: 18),

                // Headline
                const Text(
                  'Limited Time Offer',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 12),

                // Big 20% OFF
                const Text(
                  '20% OFF',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFEF4444),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),

                // Pricing Subtitle
                const Text(
                  'SpendWise Premium only €2.58/month\nBilled annually at €30.99',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Normally €38.99',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 16),

                // Offer badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECEF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFCCD3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 15, color: Color(0xFFE11D48)),
                      SizedBox(width: 6),
                      Text(
                        'Offer ends soon',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE11D48),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Countdown Timer Boxes (Days, Hours, Min, Sec)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTimeBox('00', 'Days'),
                    const SizedBox(width: 8),
                    _buildTimeBox('00', 'Hours'),
                    const SizedBox(width: 8),
                    _buildTimeBox(_twoDigits(minutes), 'Min'),
                    const SizedBox(width: 8),
                    _buildTimeBox(_twoDigits(seconds), 'Sec'),
                  ],
                ),
                const SizedBox(height: 12),

                // Clarifying UI Prototype note
                const Text(
                  'Illustrative promotional offer (UI Prototype)',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),

                // CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: widget.onClaimOffer,
                    child: const Text(
                      'Claim Offer Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Secondary dismiss link
                TextButton(
                  onPressed: widget.onDismiss,
                  child: const Text(
                    'No thanks, continue as guest',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Close X button top right
          Positioned(
            top: 12,
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
              onPressed: widget.onDismiss,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBox(String value, String label) {
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
