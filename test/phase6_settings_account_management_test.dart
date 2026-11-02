import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spendwise/models/models.dart';
import 'package:spendwise/screens/auth/email_auth_sheet.dart';
import 'package:spendwise/screens/auth/logout_confirmation_dialog.dart';
import 'package:spendwise/screens/more_screen.dart';
import 'package:spendwise/screens/onboarding/auth_screen.dart';
import 'package:spendwise/screens/onboarding/onboarding_flow_screen.dart';
import 'package:spendwise/screens/profile/edit_profile_dialog.dart';
import 'package:spendwise/screens/settings_screen.dart';
import 'package:spendwise/services/auth_sync_provider.dart';
import 'package:spendwise/services/biometric_service.dart';
import 'package:spendwise/services/finance_provider.dart';
import 'package:spendwise/services/local_auth_service.dart';
import 'package:spendwise/services/storage_service.dart';
import 'package:spendwise/theme/app_theme.dart';
import 'package:spendwise/widgets/biometric_lock_guard.dart';

class MockBiometricService implements BiometricService {
  bool supported;
  bool authenticateResult;
  int authenticateCallCount = 0;
  String? lastLocalizedReason;

  MockBiometricService({
    this.supported = true,
    this.authenticateResult = true,
  });

  @override
  Future<bool> get isHardwareSupported async => supported;

  @override
  Future<bool> get canCheckBiometrics async => supported;

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    authenticateCallCount++;
    lastLocalizedReason = localizedReason;
    return authenticateResult;
  }
}

void main() {
  group('Phase 6: Profile Editing Tests', () {
    late LocalAuthService localAuth;
    late FinanceProvider finance;
    late AuthSyncProvider authSync;

    setUp(() async {
      localAuth = LocalAuthService();
      finance = FinanceProvider(seedSampleData: false);
      authSync = AuthSyncProvider(
        authService: localAuth,
        cloudSyncService: localAuth,
        storageService: LocalStorageService(),
        financeProvider: finance,
      );

      await authSync.registerWithEmail(
        'alice@spendwise.test',
        'Password123!',
        displayName: 'Alice Original',
      );
    });

    tearDown(() {
      authSync.dispose();
      localAuth.dispose();
    });

    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<FinanceProvider>.value(value: finance),
          ChangeNotifierProvider<AuthSyncProvider>.value(value: authSync),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: child,
        ),
      );
    }

    test(
        '1. updateDisplayName validates name and rejects empty or <2 char input',
        () async {
      final emptyResult = await authSync.updateDisplayName('   ');
      expect(emptyResult, isFalse);
      expect(authSync.errorMessage, contains('cannot be empty'));

      final shortResult = await authSync.updateDisplayName('A');
      expect(shortResult, isFalse);
      expect(authSync.errorMessage, contains('at least 2 characters'));

      // Original name unchanged
      expect(authSync.currentUser?.displayName, equals('Alice Original'));
      expect(finance.userName, equals('Alice Original'));
    });

    test(
        '2. updateDisplayName succeeds, updates AuthService, FinanceProvider, and cloud vault',
        () async {
      final success = await authSync.updateDisplayName('Alice Smith');
      expect(success, isTrue);
      expect(authSync.errorMessage, isNull);

      // AuthSyncProvider currentUser updated
      expect(authSync.currentUser?.displayName, equals('Alice Smith'));
      // FinanceProvider profile updated
      expect(finance.userName, equals('Alice Smith'));

      // Check raw cloud vault updated
      final rawVault = localAuth.getRawCloudVault(authSync.currentUser!.uid);
      expect(rawVault, isNotNull);
      expect(rawVault!['profile']['userName'], equals('Alice Smith'));
    });

    test(
        '3. updateDisplayName handles network errors safely without claiming success',
        () async {
      localAuth.setSimulateNetworkError(true);

      final result = await authSync.updateDisplayName('Alice Offline');
      expect(result, isFalse);
      expect(authSync.errorMessage, isNotNull);
      expect(authSync.errorMessage, contains('Network connection failed'));

      // Display name was NOT corrupted
      expect(authSync.currentUser?.displayName, equals('Alice Original'));
    });

    testWidgets(
        '4. Tapping pencil icon in MoreScreen opens EditProfileDialog and updates name',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestApp(
          const MoreScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('more_edit_profile_button')), findsOneWidget);

      // Tap edit pencil icon
      await tester.tap(find.byKey(const Key('more_edit_profile_button')));
      await tester.pumpAndSettle();

      // EditProfileDialog opened
      expect(find.byType(EditProfileDialog), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EditProfileDialog),
          matching: find.text('alice@spendwise.test'),
        ),
        findsOneWidget,
      );

      // Enter new name
      final nameField = find.widgetWithText(TextFormField, 'Alice Original');
      await tester.enterText(nameField, 'Alice Wonder');
      await tester.pump();

      // Tap Save Changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Dialog dismissed
      expect(find.byType(EditProfileDialog), findsNothing);

      // New name immediately visible in MoreScreen
      expect(find.text('Alice Wonder'), findsOneWidget);
      expect(finance.userName, equals('Alice Wonder'));
      expect(find.text('Profile updated successfully!'), findsOneWidget);
    });

    testWidgets(
        '5. Tapping pencil icon in SettingsScreen opens EditProfileDialog and validates input',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestApp(
          const SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings_edit_profile_button')),
          findsOneWidget);

      await tester.tap(find.byKey(const Key('settings_edit_profile_button')));
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileDialog), findsOneWidget);

      // Clear text to trigger validation error
      final nameField = find.widgetWithText(TextFormField, 'Alice Original');
      await tester.enterText(nameField, '');
      await tester.tap(find.text('Save Changes'));
      await tester.pump();

      expect(find.text('Display name cannot be empty.'), findsOneWidget);
      expect(find.byType(EditProfileDialog), findsOneWidget);

      // Cancel button closes dialog without changes
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileDialog), findsNothing);
      expect(finance.userName, equals('Alice Original'));
    });
  });

  group('Phase 6: Logout Confirmation & Session Clearing Tests', () {
    late LocalAuthService localAuth;
    late FinanceProvider finance;
    late AuthSyncProvider authSync;

    setUp(() async {
      localAuth = LocalAuthService();
      finance = FinanceProvider(seedSampleData: false);
      finance.addAccount(
        Account(
          id: 'acc_persist',
          name: 'Checking Account',
          type: AccountType.debit,
          balance: 1500.0,
          currency: 'USD',
          icon: '🏛️',
        ),
      );
      finance.addExpense(
        title: 'Monthly Rent',
        amount: 500.0,
        category: 'Housing',
        accountId: 'acc_persist',
      );

      authSync = AuthSyncProvider(
        authService: localAuth,
        cloudSyncService: localAuth,
        storageService: LocalStorageService(),
        financeProvider: finance,
      );

      await authSync.registerWithEmail(
        'bob@spendwise.test',
        'Password123!',
        displayName: 'Bob Tester',
      );
    });

    tearDown(() {
      authSync.dispose();
      localAuth.dispose();
    });

    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<FinanceProvider>.value(value: finance),
          ChangeNotifierProvider<AuthSyncProvider>.value(value: authSync),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: child,
        ),
      );
    }

    testWidgets(
        '6. Cancelling logout leaves session intact with authenticated user and accounts preserved',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestApp(
          const MoreScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sign Out
      await tester.tap(find.byKey(const Key('more_sign_out_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LogoutConfirmationDialog), findsOneWidget);
      expect(find.text('Sign Out of SpendWise?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LogoutConfirmationDialog),
          matching: find.text('bob@spendwise.test'),
        ),
        findsOneWidget,
      );

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(LogoutConfirmationDialog), findsNothing);
      expect(authSync.isAuthenticated, isTrue);
      expect(authSync.currentUser?.email, equals('bob@spendwise.test'));
      expect(finance.accounts.length, equals(1));
      expect(finance.expenses.length, equals(1));
    });

    testWidgets(
        '7. Confirming logout signs out, clears session, preserves financial records, and navigates',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestApp(
          const MoreScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sign Out
      await tester.tap(find.byKey(const Key('more_sign_out_button')));
      await tester.pumpAndSettle();

      // Tap Sign Out in confirmation dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Out'));
      await tester.pumpAndSettle();

      // Navigated to OnboardingFlowScreen
      expect(find.byType(OnboardingFlowScreen), findsOneWidget);

      // Session cleared
      expect(authSync.isAuthenticated, isFalse);
      expect(authSync.currentUser, isNull);

      // Financial data was NEVER wiped
      expect(finance.accounts.length, equals(1));
      expect(finance.accounts.first.name, equals('Checking Account'));
      expect(finance.expenses.length, equals(1));
      expect(finance.expenses.first.title, equals('Monthly Rent'));
    });
  });

  group('Phase 6: Dark Theme Tests', () {
    late LocalAuthService localAuth;
    late FinanceProvider finance;
    late AuthSyncProvider authSync;

    setUp(() {
      localAuth = LocalAuthService();
      finance = FinanceProvider(seedSampleData: false);
      authSync = AuthSyncProvider(
        authService: localAuth,
        cloudSyncService: localAuth,
        storageService: LocalStorageService(),
        financeProvider: finance,
      );
    });

    tearDown(() {
      authSync.dispose();
      localAuth.dispose();
    });

    Widget createThemedApp() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<FinanceProvider>.value(value: finance),
          ChangeNotifierProvider<AuthSyncProvider>.value(value: authSync),
        ],
        child: Consumer<FinanceProvider>(
          builder: (context, fin, _) {
            return MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: fin.isDarkMode ? ThemeMode.dark : ThemeMode.light,
              home: const MoreScreen(),
            );
          },
        ),
      );
    }

    testWidgets(
        '8. Dark Theme switch toggles themeMode and updates UI immediately',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createThemedApp());
      await tester.pumpAndSettle();

      expect(finance.isDarkMode, isFalse);

      // Switch to Dark Theme
      final darkSwitch = find.byKey(const Key('more_dark_theme_switch'));
      expect(darkSwitch, findsOneWidget);

      await tester.tap(darkSwitch);
      await tester.pumpAndSettle();

      expect(finance.isDarkMode, isTrue);

      // Material theme brightness updated
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(const Color(0xFF0F172A)));

      // Toggle back to Light Theme
      await tester.tap(darkSwitch);
      await tester.pumpAndSettle();

      expect(finance.isDarkMode, isFalse);
      final lightScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(lightScaffold.backgroundColor, equals(AppColors.background));
    });

    test('9. Dark theme preference is serialized and deserialized in vault map',
        () {
      finance.toggleDarkMode(true);
      final vault = finance.toVaultMap();
      expect(vault['profile']['isDarkMode'], isTrue);

      final restoredFinance = FinanceProvider(seedSampleData: false);
      restoredFinance.loadFromVaultMap(vault);
      expect(restoredFinance.isDarkMode, isTrue);
    });
  });

  group('Phase 6: Biometric Hardware Lock Tests', () {
    late LocalAuthService localAuth;
    late FinanceProvider finance;
    late AuthSyncProvider authSync;

    setUp(() {
      localAuth = LocalAuthService();
      finance = FinanceProvider(seedSampleData: false);
      authSync = AuthSyncProvider(
        authService: localAuth,
        cloudSyncService: localAuth,
        storageService: LocalStorageService(),
        financeProvider: finance,
      );
    });

    tearDown(() {
      authSync.dispose();
      localAuth.dispose();
    });

    testWidgets(
        '10. Unsupported biometric platform disables switch with clear unavailable notice',
        (tester) async {
      final mockBiometric = MockBiometricService(supported: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FinanceProvider>.value(value: finance),
            ChangeNotifierProvider<AuthSyncProvider>.value(value: authSync),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MoreScreen(biometricService: mockBiometric),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch is rendered
      final switchFinder = find.byKey(const Key('more_biometrics_switch'));
      expect(switchFinder, findsOneWidget);

      final switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.onChanged, isNull); // Disabled switch!
      expect(switchWidget.value, isFalse);

      expect(find.textContaining('not available'), findsOneWidget);
    });

    testWidgets(
        '11. Supported platform requires biometric authentication to enable lock',
        (tester) async {
      finance.toggleBiometrics(false);
      final mockBiometric = MockBiometricService(
        supported: true,
        authenticateResult: true,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FinanceProvider>.value(value: finance),
            ChangeNotifierProvider<AuthSyncProvider>.value(value: authSync),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MoreScreen(biometricService: mockBiometric),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byKey(const Key('more_biometrics_switch'));
      expect(switchFinder, findsOneWidget);

      // Tap to enable
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(mockBiometric.authenticateCallCount, equals(1));
      expect(mockBiometric.lastLocalizedReason, contains('enable Biometric'));
      expect(finance.biometricsEnabled, isTrue);
      expect(find.text('Biometric Hardware Lock enabled.'), findsOneWidget);
    });

    testWidgets(
        '12. Cancelled or failed biometric verification leaves lock setting disabled',
        (tester) async {
      finance.toggleBiometrics(false);
      final mockBiometric = MockBiometricService(
        supported: true,
        authenticateResult: false, // User cancelled or sensor failed
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FinanceProvider>.value(value: finance),
            ChangeNotifierProvider<AuthSyncProvider>.value(value: authSync),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MoreScreen(biometricService: mockBiometric),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byKey(const Key('more_biometrics_switch'));
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(mockBiometric.authenticateCallCount, equals(1));
      expect(finance.biometricsEnabled, isFalse);
      expect(find.text('Biometric verification cancelled or failed.'),
          findsOneWidget);
    });

    testWidgets(
        '13. BiometricLockGuard locks app and unlocks upon successful authentication',
        (tester) async {
      finance.toggleBiometrics(false);
      final mockBiometric = MockBiometricService(
        supported: true,
        authenticateResult: true,
      );

      final key = GlobalKey<BiometricLockGuardState>();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FinanceProvider>.value(value: finance),
          ],
          child: MaterialApp(
            home: BiometricLockGuard(
              key: key,
              biometricService: mockBiometric,
              child: const Scaffold(
                body: Center(child: Text('Protected Content')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protected Content'), findsOneWidget);

      // Trigger lock state
      key.currentState?.setLockedForTesting(true);
      await tester.pumpAndSettle();

      // Protected content hidden, lock screen shown
      expect(find.text('Protected Content'), findsNothing);
      expect(find.text('SpendWise Locked'), findsOneWidget);

      // Tap unlock button
      await tester.tap(find.byKey(const Key('biometric_unlock_button')));
      await tester.pumpAndSettle();

      expect(mockBiometric.authenticateCallCount, equals(1));
      expect(find.text('SpendWise Locked'), findsNothing);
      expect(find.text('Protected Content'), findsOneWidget);
    });

    testWidgets(
        '14. BiometricLockGuard automatically locks on cold launch when biometricsEnabled is true',
        (tester) async {
      finance.toggleBiometrics(true);
      final mockBiometric = MockBiometricService(
        supported: true,
        authenticateResult: false, // User has not authenticated yet
      );

      final key = GlobalKey<BiometricLockGuardState>();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FinanceProvider>.value(value: finance),
          ],
          child: MaterialApp(
            home: BiometricLockGuard(
              key: key,
              biometricService: mockBiometric,
              child: const Scaffold(
                body: Center(child: Text('Secret Financial Data')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Protected content hidden, SpendWise Locked shown
      expect(find.text('Secret Financial Data'), findsNothing);
      expect(find.text('SpendWise Locked'), findsOneWidget);
      expect(mockBiometric.authenticateCallCount, equals(1));

      // Now authenticate succeeds
      mockBiometric.authenticateResult = true;
      await tester.tap(find.byKey(const Key('biometric_unlock_button')));
      await tester.pumpAndSettle();

      expect(find.text('SpendWise Locked'), findsNothing);
      expect(find.text('Secret Financial Data'), findsOneWidget);
    });

    testWidgets(
        '15. BiometricLockGuard locks on AppLifecycleState.paused and re-prompts on resumed',
        (tester) async {
      finance.toggleBiometrics(true);
      final mockBiometric = MockBiometricService(
        supported: true,
        authenticateResult: true,
      );

      final key = GlobalKey<BiometricLockGuardState>();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FinanceProvider>.value(value: finance),
          ],
          child: MaterialApp(
            home: BiometricLockGuard(
              key: key,
              biometricService: mockBiometric,
              child: const Scaffold(
                body: Center(child: Text('Private Ledger')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cold launch unlocked
      expect(find.text('Private Ledger'), findsOneWidget);

      // Simulate app going to background (paused)
      key.currentState?.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      // Screen is locked
      expect(find.text('Private Ledger'), findsNothing);
      expect(find.text('SpendWise Locked'), findsOneWidget);

      // Simulate resuming app
      key.currentState?.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Auto unlocked
      expect(find.text('SpendWise Locked'), findsNothing);
      expect(find.text('Private Ledger'), findsOneWidget);
    });

    testWidgets(
        '16. EmailAuthSheet provides working Continue with Google button',
        (tester) async {
      bool successCalled = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FinanceProvider>.value(value: finance),
            ChangeNotifierProvider<AuthSyncProvider>.value(value: authSync),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EmailAuthSheet(
                onSuccess: () => successCalled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Google Sign-In button is rendered
      final googleButton = find.byKey(const Key('email_sheet_google_button'));
      expect(googleButton, findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);

      // Tap Google Sign-In
      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      // Should succeed and invoke callback
      expect(successCalled, isTrue);
    });

    testWidgets(
        '17. BiometricLockGuard keeps content locked when authentication is cancelled or fails',
        (tester) async {
      finance.toggleBiometrics(true);
      final mockBiometric = MockBiometricService(
        supported: true,
        authenticateResult: false, // User fails or cancels
      );

      final key = GlobalKey<BiometricLockGuardState>();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FinanceProvider>.value(value: finance),
          ],
          child: MaterialApp(
            home: BiometricLockGuard(
              key: key,
              biometricService: mockBiometric,
              child: const Scaffold(
                body: Center(child: Text('Super Confidential Balance')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Protected content MUST be hidden, lock screen shown
      expect(find.text('Super Confidential Balance'), findsNothing);
      expect(find.text('SpendWise Locked'), findsOneWidget);

      // User tries tapping the unlock button again, but fails again
      await tester.tap(find.byKey(const Key('biometric_unlock_button')));
      await tester.pump();

      // Content STILL hidden, lock screen STILL visible
      expect(find.text('Super Confidential Balance'), findsNothing);
      expect(find.text('SpendWise Locked'), findsOneWidget);
    });

    testWidgets(
        '18. AuthScreen provides working Continue with Google button with proper key',
        (tester) async {
      bool guestExplored = false;
      bool authenticatedCalled = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FinanceProvider>.value(value: finance),
            ChangeNotifierProvider<AuthSyncProvider>.value(value: authSync),
          ],
          child: MaterialApp(
            home: AuthScreen(
              onExploreAsGuest: () => guestExplored = true,
              onAuthenticated: () => authenticatedCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final googleButton = find.byKey(const Key('auth_google_button'));
      expect(googleButton, findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);

      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      expect(authenticatedCalled, isTrue);
      expect(guestExplored, isFalse);
    });

    testWidgets(
        '19. BiometricLockGuard preserves child state without unmounting and respects isSystemPickerActive',
        (tester) async {
      finance.toggleBiometrics(true);
      final mockBiometric = MockBiometricService(
        supported: true,
        authenticateResult: true,
      );

      final key = GlobalKey<BiometricLockGuardState>();

      // Stateful counter child to verify state is NEVER destroyed on lock/unlock
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FinanceProvider>.value(value: finance),
          ],
          child: MaterialApp(
            home: BiometricLockGuard(
              key: key,
              biometricService: mockBiometric,
              child: const _StatefulCounterTestWidget(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cold launch unlock
      expect(find.text('Counter: 0'), findsOneWidget);

      // Mutate child state
      await tester.tap(find.text('Increment'));
      await tester.pumpAndSettle();
      expect(find.text('Counter: 1'), findsOneWidget);

      // Part A: When isSystemPickerActive is true, paused does NOT lock
      BiometricLockGuard.isSystemPickerActive = true;
      key.currentState?.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(find.text('SpendWise Locked'), findsNothing);
      expect(find.text('Counter: 1'), findsOneWidget);

      // Part B: When isSystemPickerActive is false, paused locks
      BiometricLockGuard.isSystemPickerActive = false;
      key.currentState?.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(find.text('SpendWise Locked'), findsOneWidget);
      expect(find.text('Counter: 1'), findsNothing);

      // Part C: Resuming and unlocking preserves child state (Counter remains 1, not reset to 0)
      key.currentState?.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('SpendWise Locked'), findsNothing);
      expect(find.text('Counter: 1'), findsOneWidget);
    });
  });
}

class _StatefulCounterTestWidget extends StatefulWidget {
  const _StatefulCounterTestWidget();

  @override
  State<_StatefulCounterTestWidget> createState() =>
      _StatefulCounterTestWidgetState();
}

class _StatefulCounterTestWidgetState
    extends State<_StatefulCounterTestWidget> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Text('Counter: $_count'),
            ElevatedButton(
              onPressed: () => setState(() => _count++),
              child: const Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}
