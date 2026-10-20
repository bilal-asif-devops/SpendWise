import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spendwise/screens/home_screen.dart';
import 'package:spendwise/screens/onboarding/auth_screen.dart';
import 'package:spendwise/screens/onboarding/exit_offer_dialog.dart';
import 'package:spendwise/screens/onboarding/paywall_screen.dart';
import 'package:spendwise/screens/onboarding/reminders_screen.dart';
import 'package:spendwise/screens/onboarding/survey_goals_screen.dart';
import 'package:spendwise/screens/onboarding/survey_habits_screen.dart';
import 'package:spendwise/screens/onboarding/survey_sentiment_screen.dart';
import 'package:spendwise/services/finance_provider.dart';
import 'package:spendwise/services/storage_service.dart';
import 'package:spendwise/theme/app_theme.dart';

class MockStorageService extends LocalStorageService {
  Map<String, dynamic>? inMemoryVault;

  @override
  Future<Map<String, dynamic>?> loadVault() async => inMemoryVault;

  @override
  Future<void> saveVault(Map<String, dynamic> vaultData) async {
    inMemoryVault = vaultData;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2: Provider State & Onboarding Persistence', () {
    test(
        '1. First launch starts with uncompleted onboarding and neutral guest profile',
        () {
      final finance = FinanceProvider(storageService: MockStorageService());

      expect(finance.hasCompletedOnboarding, isFalse);
      expect(finance.userName, equals('Guest User'));
      expect(finance.userEmail, equals('guest@spendwise.local'));
      expect(finance.onboardingData, isEmpty);
    });

    test('2. completeOnboarding saves survey responses and persists to vault',
        () async {
      final storage = MockStorageService();
      final finance = FinanceProvider(storageService: storage);

      final surveyResponses = {
        'sentiment': 'confident',
        'goals': ['emergency', 'investments', 'vacation'],
        'habit': 'reminders_help',
        'remindersEnabled': true,
      };

      finance.completeOnboarding(
        name: 'Alex Guest',
        email: 'alex@spendwise.local',
        surveyResponses: surveyResponses,
        clearSampleExpenses: true,
      );

      expect(finance.hasCompletedOnboarding, isTrue);
      expect(finance.userName, equals('Alex Guest'));
      expect(finance.userEmail, equals('alex@spendwise.local'));
      expect(finance.onboardingData['sentiment'], equals('confident'));
      expect(finance.onboardingData['goals'], contains('investments'));
      expect(finance.expenses, isEmpty);

      // Verify vault persistence
      expect(storage.inMemoryVault, isNotNull);
      final profileMap = storage.inMemoryVault!['profile'];
      expect(profileMap['hasCompletedOnboarding'], isTrue);
      expect(profileMap['onboardingData']['sentiment'], equals('confident'));
    });

    test('3. Subsequent launch restores hasCompletedOnboarding from storage',
        () async {
      final storage = MockStorageService();
      final finance1 = FinanceProvider(storageService: storage);

      finance1.completeOnboarding(
        surveyResponses: {'sentiment': 'stable'},
        clearSampleExpenses: true,
      );

      // Simulate app restart by loading new provider with same storage
      final finance2 = FinanceProvider(storageService: storage);
      // Wait for async vault load
      await Future.delayed(const Duration(milliseconds: 50));

      expect(finance2.hasCompletedOnboarding, isTrue);
      expect(finance2.onboardingData['sentiment'], equals('stable'));
    });

    test('4. startFreshGuest resets expenses for clean empty Home state', () {
      final finance = FinanceProvider(storageService: MockStorageService());
      expect(finance.expenses.isNotEmpty, isTrue); // initial sample data

      finance.startFreshGuest(surveyResponses: {'sentiment': 'unsure'});

      expect(finance.hasCompletedOnboarding, isTrue);
      expect(finance.userName, equals('Guest User'));
      expect(finance.expenses, isEmpty);
    });

    test('5. resetOnboarding reverts completion state to false', () {
      final finance = FinanceProvider(storageService: MockStorageService());
      finance.completeOnboarding(surveyResponses: {'sentiment': 'stressed'});
      expect(finance.hasCompletedOnboarding, isTrue);

      finance.resetOnboarding();
      expect(finance.hasCompletedOnboarding, isFalse);
      expect(finance.onboardingData, isEmpty);
      expect(finance.userName, equals('Guest User'));
    });
  });

  group('Phase 2: Onboarding Flow Widget Tests', () {
    testWidgets('6. SurveySentimentScreen renders all options and advances',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? selected;
      bool continued = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SurveySentimentScreen(
                  selectedSentiment: selected,
                  onSelect: (val) => setState(() => selected = val),
                  onContinue: () => continued = true,
                );
              },
            ),
          ),
        ),
      );

      // Verify header and question
      expect(find.text('How do you feel about your finances today?'),
          findsOneWidget);
      expect(find.text('Stressed'), findsOneWidget);
      expect(find.text('Unsure'), findsOneWidget);
      expect(find.text('Stable'), findsOneWidget);
      expect(find.text('Confident'), findsOneWidget);

      // Continue button should be disabled initially
      final continueButtonFinder =
          find.widgetWithText(ElevatedButton, 'Continue');
      expect(continueButtonFinder, findsOneWidget);

      // Tap 'Confident'
      await tester.tap(find.text('Confident'));
      await tester.pumpAndSettle();

      expect(selected, equals('confident'));

      // Tap Continue
      await tester.tap(continueButtonFinder);
      await tester.pumpAndSettle();

      expect(continued, isTrue);
    });

    testWidgets(
        '7. SurveyGoalsScreen supports multi-select and navigation callbacks',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final selectedGoals = <String>{'emergency'};
      bool backTapped = false;
      bool continueTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SurveyGoalsScreen(
                  selectedGoals: selectedGoals,
                  onToggleGoal: (id) {
                    setState(() {
                      if (selectedGoals.contains(id)) {
                        selectedGoals.remove(id);
                      } else {
                        selectedGoals.add(id);
                      }
                    });
                  },
                  onBack: () => backTapped = true,
                  onContinue: () => continueTapped = true,
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Are you saving, or planning to, for any of these?'),
          findsOneWidget);
      expect(find.text('Emergency fund'), findsOneWidget);
      expect(find.text('Retirement'), findsOneWidget);

      // Toggle 'Retirement' on
      await tester.tap(find.text('Retirement'));
      await tester.pumpAndSettle();
      expect(selectedGoals, contains('retirement'));
      expect(selectedGoals, contains('emergency'));

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(backTapped, isTrue);

      // Tap continue button
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(continueTapped, isTrue);
    });

    testWidgets('8. SurveyHabitsScreen selects habit and continues',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? selectedHabit;
      bool continued = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SurveyHabitsScreen(
                  selectedHabit: selectedHabit,
                  onSelect: (val) => setState(() => selectedHabit = val),
                  onBack: () {},
                  onContinue: () => continued = true,
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('How easy is it for you to stick to new habits?'),
          findsOneWidget);
      expect(find.text("I'm a habit pro"), findsOneWidget);
      expect(find.text('Reminders really help me'), findsOneWidget);

      await tester.tap(find.text('Reminders really help me'));
      await tester.pumpAndSettle();
      expect(selectedHabit, equals('reminders_help'));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(continued, isTrue);
    });

    testWidgets(
        '9. RemindersScreen explains reminders and distinguishes OS permissions',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool enabled = false;
      bool skipped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RemindersScreen(
            onEnableReminders: () => enabled = true,
            onSkip: () => skipped = true,
          ),
        ),
      );

      expect(find.text('Users who turn on reminders are 2x more consistent'),
          findsOneWidget);
      expect(
          find.textContaining(
              'This enables your reminder preference in SpendWise'),
          findsOneWidget);

      // Tap 'Turn on reminders'
      await tester.tap(find.text('Turn on reminders'));
      await tester.pumpAndSettle();
      expect(enabled, isTrue);

      // Tap 'Skip'
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(skipped, isTrue);
    });

    testWidgets('10. PaywallScreen displays value card and plan bottom sheet',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool closeTapped = false;
      bool guestTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: PaywallScreen(
            onTapClose: () => closeTapped = true,
            onContinueAsGuest: () => guestTapped = true,
          ),
        ),
      );

      expect(find.text('Take Control of Your\nMoney – Instantly!'),
          findsOneWidget);
      expect(find.text('Start now for €27.99 per year'), findsOneWidget);
      expect(find.text('5M+'), findsOneWidget);
      expect(find.text('4.8'), findsOneWidget);

      // Tap Start Today button
      await tester.tap(find.text('Start Today'));
      await tester.pumpAndSettle();

      // Billing prototype dialog appears
      expect(find.text('Billing Prototype'), findsOneWidget);
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();
      expect(guestTapped, isTrue);

      // Tap Close 'X'
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(closeTapped, isTrue);
    });

    testWidgets('11. ExitOfferDialog shows 20% discount and dismiss callback',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool dismissed = false;
      bool claimed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ExitOfferDialog(
              onDismiss: () => dismissed = true,
              onClaimOffer: () => claimed = true,
            ),
          ),
        ),
      );

      expect(find.text('Limited Time Offer'), findsOneWidget);
      expect(find.text('20% OFF'), findsOneWidget);
      expect(find.text('Claim Offer Now'), findsOneWidget);
      expect(find.text('Min'), findsOneWidget);
      expect(find.text('Sec'), findsOneWidget);

      // Tap Claim Offer
      await tester.tap(find.text('Claim Offer Now'));
      await tester.pump();
      expect(claimed, isTrue);

      // Tap dismiss
      await tester.tap(find.text('No thanks, continue as guest'));
      await tester.pump();
      expect(dismissed, isTrue);

      // Dispose dialog to cancel running periodic timer
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('12. AuthScreen provides Guest entry and explains cloud auth',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool guestTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AuthScreen(
            onExploreAsGuest: () => guestTapped = true,
          ),
        ),
      );

      expect(find.text('Save your financial journey'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Sign up with Email'), findsOneWidget);
      expect(find.text('Explore as Guest'), findsOneWidget);

      // Tap Google auth button shows prototype explanation
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text('Google Sign-In'), findsOneWidget);
      expect(find.textContaining('scheduled for Phase 3'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      // Tap Explore as Guest
      await tester.tap(find.text('Explore as Guest'));
      await tester.pumpAndSettle();
      expect(guestTapped, isTrue);
    });

    testWidgets(
        '13. Empty HomeScreen renders Spendee Frame 70 design and launches manual add',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final finance = FinanceProvider(storageService: MockStorageService());
      finance.startFreshGuest(); // clears expenses to 0

      await tester.pumpWidget(
        ChangeNotifierProvider<FinanceProvider>.value(
          value: finance,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomeScreen(),
          ),
        ),
      );

      // Verify Empty State matching Frame 70
      expect(find.text('Clear view of your finances'), findsOneWidget);
      expect(
          find.text(
              'Get a clear view of your spending, make better decisions, and save for what matters.'),
          findsOneWidget);
      expect(find.text('Connect Bank Account'), findsOneWidget);
      expect(find.text('Add Expense Manually'), findsOneWidget);
      expect(find.text('Group Wallet'), findsOneWidget);
      expect(find.text('+ €773'), findsOneWidget);

      // Tap Connect Bank Account shows Phase 5 info dialog
      await tester.ensureVisible(find.text('Connect Bank Account'));
      await tester.tap(find.text('Connect Bank Account'));
      await tester.pumpAndSettle();
      expect(find.text('Bank Connection'), findsOneWidget);
      await tester.tap(find.text('Got It'));
      await tester.pumpAndSettle();

      // Tap Add Expense Manually opens QuickAddExpenseSheet
      await tester.ensureVisible(find.text('Add Expense Manually'));
      await tester.tap(find.text('Add Expense Manually'));
      await tester.pumpAndSettle();
      expect(find.text('Add transaction'), findsOneWidget);
    });
  });
}
