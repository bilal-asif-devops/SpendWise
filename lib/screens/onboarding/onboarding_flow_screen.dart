import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_sync_provider.dart';
import '../../services/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../main_navigation.dart';
import 'auth_screen.dart';

/// Premium, responsive 3-screen onboarding carousel replacing the legacy survey flow.
class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  State<OnboardingFlowScreen> createState() => OnboardingFlowScreenState();
}

class OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _openAuthScreen(skipped: false);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _goToPage(int page) {
    if (page >= 3) {
      _openAuthScreen(skipped: false);
    } else {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @visibleForTesting
  void goToPage(int page) => _goToPage(page);

  void _openAuthScreen({bool skipped = false}) {
    if (skipped) {
      final finance = Provider.of<FinanceProvider>(context, listen: false);
      finance.completeOnboarding();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuthScreen(
          onExploreAsGuest: _finishAsGuest,
          onAuthenticated: _finishAsAuthenticated,
        ),
      ),
    );
  }

  void _finishAsGuest() {
    final finance = Provider.of<FinanceProvider>(context, listen: false);
    finance.startFreshGuest();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  void _finishAsAuthenticated() {
    final finance = Provider.of<FinanceProvider>(context, listen: false);
    final authSync = Provider.of<AuthSyncProvider?>(context, listen: false);

    finance.completeOnboarding(
      name: authSync?.currentUser?.displayName,
      email: authSync?.currentUser?.email,
      clearSampleExpenses: false,
      clearAllData: false,
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentPage > 0) {
          _previousPage();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar: Brand Mark & Skip Action (Hidden on Screen 3)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Mark
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primaryNavy,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryNavy
                                    .withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.account_balance_wallet_rounded,
                              color: AppColors.accentGreen,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'SpendWise',
                          style: TextStyle(
                            color: AppColors.primaryNavy,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),

                    // Skip action on screens 1 and 2
                    if (_currentPage < 2)
                      TextButton(
                        key: const Key('onboarding_skip_button'),
                        onPressed: () => _openAuthScreen(skipped: true),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textMuted,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 48, height: 32),
                  ],
                ),
              ),

              // Responsive Carousel Body
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  children: const [
                    // Screen 1: Track Every Expense
                    _OnboardingPage(
                      headline: 'Know where your money goes.',
                      description:
                          'Track your daily spending and keep all your expenses organized in one place.',
                      visual: _TrackExpenseVisual(),
                    ),

                    // Screen 2: Build Better Budgets
                    _OnboardingPage(
                      headline: 'Make your money go further.',
                      description:
                          'Set budgets, monitor your progress and stay in control of your spending.',
                      visual: _BuildBudgetVisual(),
                    ),

                    // Screen 3: Understand Your Finances
                    _OnboardingPage(
                      headline: 'Make smarter money decisions.',
                      description:
                          'Turn your financial activity into clear insights that help you plan ahead.',
                      visual: _UnderstandFinancesVisual(),
                    ),
                  ],
                ),
              ),

              // Bottom Section: Pagination Indicators & Actions
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pagination Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        final bool isActive = _currentPage == index;
                        return GestureDetector(
                          key: Key('onboarding_dot_$index'),
                          onTap: () => _goToPage(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.accentGreen
                                  : AppColors.borderLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),

                    // Navigation Action (Next / Get Started)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: _currentPage < 2
                          ? ElevatedButton(
                              key: const Key('onboarding_next_button'),
                              onPressed: _nextPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryNavy,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Next',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                    color: AppColors.accentGreen,
                                  ),
                                ],
                              ),
                            )
                          : ElevatedButton(
                              key: const Key('onboarding_get_started_button'),
                              onPressed: () => _openAuthScreen(skipped: false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryNavy,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shadowColor: AppColors.primaryNavy
                                    .withValues(alpha: 0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Get Started',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 20,
                                    color: AppColors.accentGreen,
                                  ),
                                ],
                              ),
                            ),
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

/// Generic page container with robust layout constraints preventing viewport overflow
class _OnboardingPage extends StatelessWidget {
  final String headline;
  final String description;
  final Widget visual;

  const _OnboardingPage({
    required this.headline,
    required this.description,
    required this.visual,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Center visual graphic with scale protection
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight:
                          (constraints.maxHeight * 0.44).clamp(160.0, 260.0),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: visual,
                    ),
                  ),

                  // Headline & Description
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        headline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryNavy,
                          letterSpacing: -0.6,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// SCREEN 1 VISUAL: ELEGANT WALLET & DAILY TRANSACTIONS ILLUSTRATION
// =============================================================================
class _TrackExpenseVisual extends StatelessWidget {
  const _TrackExpenseVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      height: 230,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Primary Wallet Card
          Positioned(
            top: 10,
            child: Container(
              width: 260,
              height: 140,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryNavy, Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryNavy.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_outlined,
                                color: AppColors.accentGreen, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Safe Vault',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.contactless_rounded,
                        color: Colors.white60,
                        size: 18,
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'Daily Spending',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '\$42.50',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Foreground Floating Transaction Pill (Coffee)
          Positioned(
            bottom: 44,
            left: 8,
            child: Container(
              width: 200,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('☕', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coffee & Bistro',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Personal Cash',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    '-\$4.50',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.alertRed,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Secondary Floating Transaction Pill (Grocery)
          Positioned(
            bottom: 0,
            right: 8,
            child: Container(
              width: 210,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('🛒', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fresh Mart',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Groceries',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    '-\$38.00',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.alertRed,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SCREEN 2 VISUAL: BUDGET PROGRESS CHART & SPENDING LIMITS ILLUSTRATION
// =============================================================================
class _BuildBudgetVisual extends StatelessWidget {
  const _BuildBudgetVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      height: 230,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Status Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.pie_chart_rounded,
                      color: AppColors.accentGreen,
                      size: 20,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Monthly Budget',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryNavy,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Text(
                  'On Track',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Total Spent vs Total Budget
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  '\$1,300 spent',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 6),
              Text(
                'of \$2,000 limit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Master Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(
              value: 0.65,
              minHeight: 10,
              backgroundColor: AppColors.chipBackground,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentGreen),
            ),
          ),
          const SizedBox(height: 16),

          // Category 1: Dining & Food
          _buildCategoryRow(
            label: 'Dining & Cafes',
            amount: '\$440 / \$600',
            progress: 0.73,
            color: AppColors.accentGreen,
          ),
          const SizedBox(height: 10),

          // Category 2: Shopping & Discretionary
          _buildCategoryRow(
            label: 'Shopping',
            amount: '\$280 / \$500',
            progress: 0.56,
            color: const Color(0xFF3B82F6),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow({
    required String label,
    required String amount,
    required double progress,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              amount,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: AppColors.chipBackground,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SCREEN 3 VISUAL: FINANCIAL INSIGHTS & ANALYTICS ILLUSTRATION
// =============================================================================
class _UnderstandFinancesVisual extends StatelessWidget {
  const _UnderstandFinancesVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      height: 240,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryNavy,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Insights Radar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_graph_rounded,
                      color: AppColors.accentGreen,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Smart Insights',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '+18% Savings',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Mini Multi-Bar Analytics Chart
          SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar(0.40, 'M'),
                _buildBar(0.65, 'T'),
                _buildBar(0.50, 'W'),
                _buildBar(0.85, 'T'),
                _buildBar(0.60, 'F'),
                _buildBar(0.95, 'S', isHighlight: true),
                _buildBar(0.45, 'S'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Smart Decision Recommendation Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Color(0xFFFDE047),
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Safe-to-Spend: \$840 left with bills covered.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(double heightFraction, String label,
      {bool isHighlight = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 18,
          height: 32 * heightFraction,
          decoration: BoxDecoration(
            color: isHighlight
                ? AppColors.accentGreen
                : Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            color: isHighlight ? AppColors.accentGreen : Colors.white60,
          ),
        ),
      ],
    );
  }
}
