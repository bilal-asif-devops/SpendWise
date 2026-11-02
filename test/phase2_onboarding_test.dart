import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spendwise/screens/home_screen.dart';
import 'package:spendwise/screens/onboarding/auth_screen.dart';
import 'package:spendwise/screens/onboarding/exit_offer_dialog.dart';
import 'package:spendwise/screens/onboarding/onboarding_flow_screen.dart';
import 'package:spendwise/screens/onboarding/paywall_screen.dart';
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
      final finance = FinanceProvider(
        storageService: MockStorageService(),
        seedSampleData: true,
      );
      expect(finance.expenses.isNotEmpty, isTrue); // initial sample data

      finance.startFreshGuest(surveyResponses: {'sentiment': 'unsure'});

      expect(finance.hasCompletedOnboarding, isTrue);
      expect(finance.userName, equals('Guest User'));
      expect(finance.expenses, isEmpty);
      expect(finance.accounts, isEmpty);
      expect(finance.subscriptions, isEmpty);
      expect(finance.budgets, isEmpty);
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
    testWidgets(
        '6. Fresh-install displays Screen 1: Track Every Expense headline, description, and visual',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final finance = FinanceProvider(storageService: MockStorageService());

      await tester.pumpWidget(
        ChangeNotifierProvider<FinanceProvider>.value(
          value: finance,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const OnboardingFlowScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Screen 1: Track Every Expense
      expect(find.text('Know where your money goes.'), findsOneWidget);
      expect(
        find.text(
            'Track your daily spending and keep all your expenses organized in one place.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('onboarding_skip_button')), findsOneWidget);
      expect(find.byKey(const Key('onboarding_next_button')), findsOneWidget);
      expect(find.text('SpendWise'), findsOneWidget);
    });

    testWidgets(
        '7. Next button advances through Screen 1 -> Screen 2 -> Screen 3 carousel pages',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final finance = FinanceProvider(storageService: MockStorageService());

      await tester.pumpWidget(
        ChangeNotifierProvider<FinanceProvider>.value(
          value: finance,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const OnboardingFlowScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Screen 1
      expect(find.text('Know where your money goes.'), findsOneWidget);

      // Tap Next to advance to Screen 2
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();

      // Screen 2: Build Better Budgets
      expect(find.text('Make your money go further.'), findsOneWidget);
      expect(
        find.text(
            'Set budgets, monitor your progress and stay in control of your spending.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('onboarding_skip_button')), findsOneWidget);

      // Tap Next to advance to Screen 3
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();

      // Screen 3: Understand Your Finances
      expect(find.text('Make smarter money decisions.'), findsOneWidget);
      expect(
        find.text(
            'Turn your financial activity into clear insights that help you plan ahead.'),
        findsOneWidget,
      );
      // Skip should be hidden on Screen 3
      expect(find.byKey(const Key('onboarding_skip_button')), findsNothing);
      // Prominent Get Started button appears
      expect(find.byKey(const Key('onboarding_get_started_button')),
          findsOneWidget);
    });

    testWidgets(
        '8. Skip button on Screen 1 and Screen 2 immediately opens AuthScreen and persists completion',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final storage = MockStorageService();
      final finance = FinanceProvider(storageService: storage);

      await tester.pumpWidget(
        ChangeNotifierProvider<FinanceProvider>.value(
          value: finance,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const OnboardingFlowScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Skip on Screen 1
      await tester.tap(find.byKey(const Key('onboarding_skip_button')));
      await tester.pumpAndSettle();

      // Verified: Navigated to AuthScreen immediately
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('Save your financial journey'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Sign up with Email'), findsOneWidget);
      expect(find.text('Explore as Guest'), findsOneWidget);

      // Verified: Onboarding completion persisted
      expect(finance.hasCompletedOnboarding, isTrue);

      // Verified: Back button pops back to OnboardingFlowScreen
      expect(find.byKey(const Key('auth_back_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('auth_back_button')));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingFlowScreen), findsOneWidget);
    });

    testWidgets(
        '9. Screen 3 Get Started opens AuthScreen and responsive 400x642 viewport renders without overflow',
        (tester) async {
      // Test at the exact constrained 400 x 642 viewport specified in requirements
      tester.view.physicalSize = const Size(400, 642);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final finance = FinanceProvider(storageService: MockStorageService());

      await tester.pumpWidget(
        ChangeNotifierProvider<FinanceProvider>.value(
          value: finance,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const OnboardingFlowScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified no RenderFlex overflow on Screen 1 at 400x642
      expect(tester.takeException(), isNull);
      expect(find.text('Know where your money goes.'), findsOneWidget);

      // Advance to Screen 2
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Make your money go further.'), findsOneWidget);

      // Advance to Screen 3
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Make smarter money decisions.'), findsOneWidget);

      // Tap Get Started
      await tester.tap(find.byKey(const Key('onboarding_get_started_button')));
      await tester.pumpAndSettle();

      // Reached AuthScreen
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
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
      expect(find.text('Continue with Apple'), findsNothing);
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
