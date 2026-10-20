import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../main_navigation.dart';
import 'survey_sentiment_screen.dart';
import 'survey_goals_screen.dart';
import 'survey_habits_screen.dart';
import 'reminders_screen.dart';
import 'customization_loader_screen.dart';
import 'paywall_screen.dart';
import 'exit_offer_dialog.dart';
import 'auth_screen.dart';

class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  final PageController _pageController = PageController();

  // Survey state collection
  String? _selectedSentiment;
  final Set<String> _selectedGoals = {'emergency', 'retirement'};
  String? _selectedHabit;
  bool _remindersEnabled = true;

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
    );
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _showExitOfferDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ExitOfferDialog(
        onDismiss: () {
          Navigator.pop(ctx);
          // Advance to Auth / Guest Entry (Index 6)
          _goToPage(6);
        },
        onClaimOffer: () {
          Navigator.pop(ctx);
          // Show claim notice and advance to Auth (Index 6)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '20% Promotional discount applied to your profile preview.'),
              duration: Duration(seconds: 2),
            ),
          );
          _goToPage(6);
        },
      ),
    );
  }

  void _finishAsGuest() {
    final finance = Provider.of<FinanceProvider>(context, listen: false);
    finance.completeOnboarding(
      name: "Guest User",
      email: "guest@spendwise.local",
      surveyResponses: {
        'sentiment': _selectedSentiment,
        'goals': _selectedGoals.toList(),
        'habit': _selectedHabit,
        'remindersEnabled': _remindersEnabled,
      },
      clearSampleExpenses: true,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Step 1: Sentiment Survey
            SurveySentimentScreen(
              selectedSentiment: _selectedSentiment,
              onSelect: (val) => setState(() => _selectedSentiment = val),
              onContinue: _nextPage,
            ),

            // Step 2: Goals Survey (Multi-select)
            SurveyGoalsScreen(
              selectedGoals: _selectedGoals,
              onToggleGoal: (goalId) {
                setState(() {
                  if (_selectedGoals.contains(goalId)) {
                    _selectedGoals.remove(goalId);
                  } else {
                    _selectedGoals.add(goalId);
                  }
                });
              },
              onBack: _previousPage,
              onContinue: _nextPage,
            ),

            // Step 3: Habits Survey
            SurveyHabitsScreen(
              selectedHabit: _selectedHabit,
              onSelect: (val) => setState(() => _selectedHabit = val),
              onBack: _previousPage,
              onContinue: _nextPage,
            ),

            // Step 4: Reminders Prompt
            RemindersScreen(
              onEnableReminders: () {
                setState(() => _remindersEnabled = true);
                _nextPage();
              },
              onSkip: () {
                setState(() => _remindersEnabled = false);
                _nextPage();
              },
            ),

            // Step 5: Customization Animated Loader
            CustomizationLoaderScreen(
              onComplete: _nextPage,
            ),

            // Step 6: Primary Paywall
            PaywallScreen(
              onTapClose: _showExitOfferDialog,
              onContinueAsGuest: () => _goToPage(6),
            ),

            // Step 7: Auth & Guest Entry
            AuthScreen(
              onExploreAsGuest: _finishAsGuest,
            ),
          ],
        ),
      ),
    );
  }
}
