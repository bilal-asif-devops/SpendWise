import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PaywallScreen extends StatefulWidget {
  final VoidCallback onTapClose;
  final VoidCallback onContinueAsGuest;

  const PaywallScreen({
    super.key,
    required this.onTapClose,
    required this.onContinueAsGuest,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  int _selectedPlanIndex = 1; // Default to 12 Months (Index 1)

  void _showPlansBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: const BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Plans Row matching Spendee Video Frame 55
                  Row(
                    children: [
                      // Plan 1: 1 Month
                      Expanded(
                        child: _buildPlanCard(
                          index: 0,
                          title: '1',
                          subtitle: 'Month',
                          price: '€4.99',
                          period: '',
                          badge: null,
                          isSelected: _selectedPlanIndex == 0,
                          onTap: () =>
                              setModalState(() => _selectedPlanIndex = 0),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Plan 2: 12 Months (Save 53%)
                      Expanded(
                        child: _buildPlanCard(
                          index: 1,
                          title: '12',
                          subtitle: 'Months',
                          price: '€27.99',
                          period: '€2.33 / month',
                          badge: '🧡 Save 53%',
                          isSelected: _selectedPlanIndex == 1,
                          onTap: () =>
                              setModalState(() => _selectedPlanIndex = 1),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Plan 3: Lifetime
                      Expanded(
                        child: _buildPlanCard(
                          index: 2,
                          title: '∞',
                          subtitle: 'Lifetime',
                          price: '€129.99',
                          period: 'one-off',
                          badge: null,
                          isSelected: _selectedPlanIndex == 2,
                          onTap: () =>
                              setModalState(() => _selectedPlanIndex = 2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showPrototypeNotice();
                      },
                      child: Text(
                        _selectedPlanIndex == 0
                            ? 'Start Now For €4.99'
                            : _selectedPlanIndex == 1
                                ? 'Start Now For €27.99'
                                : 'Get Lifetime For €129.99',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlanCard({
    required int index,
    required String title,
    required String subtitle,
    required String price,
    required String period,
    required String? badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? AppColors.accentGreen
                    : const Color(0xFFE2E8F0),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    price,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                if (period.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      period,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: -10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFC2410C),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPrototypeNotice() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primaryNavy),
            SizedBox(width: 8),
            Text('Billing Prototype'),
          ],
        ),
        content: const Text(
          'Google Play Billing integration is scheduled for a subsequent production release.\n\nAll core budgeting, wallet tracking, and categorization features are currently fully accessible in Guest mode.',
          style: TextStyle(fontSize: 14, height: 1.4),
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
              widget.onContinueAsGuest();
            },
            child: const Text('Continue as Guest'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Bar with Close X
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF1F5F9),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textDark, size: 20),
                    onPressed: widget.onTapClose,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Header Pie Icon Badge with $
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFD166),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD166).withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '\$',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Main Headline matching Spendee Video Frame 50
              const Text(
                'Take Control of Your\nMoney – Instantly!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              const Text(
                'Start now for €27.99 per year',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 24),

              // Value Proposition Card matching Video
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    _BenefitRow(
                      boldText: 'banks, cash & investments',
                      prefix: 'Connect your ',
                    ),
                    SizedBox(height: 16),
                    _BenefitRow(
                      boldText: 'net worth',
                      prefix: 'See your ',
                      suffix: ' in one place',
                    ),
                    SizedBox(height: 16),
                    _BenefitRow(
                      boldText: 'Auto-track',
                      suffix: ' spending, income & subscriptions',
                    ),
                    SizedBox(height: 16),
                    _BenefitRow(
                      boldText: 'Smart budgets,',
                      suffix: ' shared wallets & full customization',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Social Proof Row matching Spendee Video
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('5M+',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: AppColors.textDark)),
                        Text('Happy Users',
                            style: TextStyle(
                                fontSize: 10, color: AppColors.textMuted)),
                      ],
                    ),
                    SizedBox(
                        height: 24,
                        child: VerticalDivider(
                            width: 1, color: AppColors.borderLight)),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                size: 14, color: Color(0xFFF59E0B)),
                            SizedBox(width: 2),
                            Text('4.8',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: AppColors.textDark)),
                          ],
                        ),
                        Text('Google Play',
                            style: TextStyle(
                                fontSize: 10, color: AppColors.textMuted)),
                      ],
                    ),
                    SizedBox(
                        height: 24,
                        child: VerticalDivider(
                            width: 1, color: AppColors.borderLight)),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded,
                                size: 14, color: AppColors.textDark),
                            SizedBox(width: 2),
                            Text('Top 10',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: AppColors.textDark)),
                          ],
                        ),
                        Text('Finance app',
                            style: TextStyle(
                                fontSize: 10, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Primary Emerald CTA Button
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
                  onPressed: _showPrototypeNotice,
                  child: const Text(
                    'Start Today',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // See All Plans Text Link
              TextButton(
                onPressed: _showPlansBottomSheet,
                child: const Text(
                  'See All Plans',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String boldText;
  final String prefix;
  final String suffix;

  const _BenefitRow({
    required this.boldText,
    this.prefix = '',
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppColors.accentGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check,
            color: Colors.white,
            size: 14,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.35,
              ),
              children: [
                if (prefix.isNotEmpty) TextSpan(text: prefix),
                TextSpan(
                  text: boldText,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (suffix.isNotEmpty) TextSpan(text: suffix),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
