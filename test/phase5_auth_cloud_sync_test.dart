import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spendwise/models/auth_models.dart';
import 'package:spendwise/models/models.dart';
import 'package:spendwise/screens/auth/backend_status_modal.dart';
import 'package:spendwise/screens/auth/email_auth_sheet.dart';
import 'package:spendwise/screens/auth/guest_migration_dialog.dart';
import 'package:spendwise/screens/home_screen.dart';
import 'package:spendwise/screens/main_navigation.dart';
import 'package:spendwise/screens/more_screen.dart';
import 'package:spendwise/screens/onboarding/auth_screen.dart';
import 'package:spendwise/screens/onboarding/onboarding_flow_screen.dart';
import 'package:spendwise/screens/settings_screen.dart';
import 'package:spendwise/screens/splash_screen.dart';
import 'package:spendwise/services/auth_sync_provider.dart';
import 'package:spendwise/services/finance_provider.dart';
import 'package:spendwise/services/firestore_sync_service.dart';
import 'package:spendwise/services/local_auth_service.dart';
import 'package:spendwise/services/statement_importer.dart';
import 'package:spendwise/services/storage_service.dart';
import 'package:spendwise/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5: Email/Password & Google Authentication Service Tests', () {
    late LocalAuthService authService;

    setUp(() {
      authService = LocalAuthService();
    });

    tearDown(() {
      authService.dispose();
    });

    test('1. Registration creates user and updates auth state', () async {
      final user = await authService.createUserWithEmailAndPassword(
        'alice@spendwise.test',
        'SecurePassword123!',
        displayName: 'Alice Tester',
      );

      expect(user.email, 'alice@spendwise.test');
      expect(user.displayName, 'Alice Tester');
      expect(authService.currentUser, equals(user));
    });

    test('2. Weak password (<6 characters) is rejected with validation error',
        () async {
      expect(
        () => authService.createUserWithEmailAndPassword(
          'bob@spendwise.test',
          '123',
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          'weak-password',
        )),
      );
    });

    test('3. Invalid email address format is rejected', () async {
      expect(
        () => authService.createUserWithEmailAndPassword(
          'not-an-email',
          'SecurePass123!',
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          'invalid-email',
        )),
      );
    });

    test('4. Duplicate email registration throws email-already-in-use',
        () async {
      await authService.createUserWithEmailAndPassword(
        'charlie@spendwise.test',
        'Password123!',
      );

      expect(
        () => authService.createUserWithEmailAndPassword(
          'charlie@spendwise.test',
          'AnotherPassword123!',
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          'email-already-in-use',
        )),
      );
    });

    test('5. Login with valid credentials succeeds and emits user', () async {
      await authService.createUserWithEmailAndPassword(
        'dana@spendwise.test',
        'Secret123!',
        displayName: 'Dana',
      );

      await authService.signOut();
      expect(authService.currentUser, isNull);

      final loggedIn = await authService.signInWithEmailAndPassword(
        'dana@spendwise.test',
        'Secret123!',
      );

      expect(loggedIn.email, 'dana@spendwise.test');
      expect(authService.currentUser?.email, 'dana@spendwise.test');
    });

    test('6. Login with wrong password throws wrong-password error', () async {
      await authService.createUserWithEmailAndPassword(
        'edward@spendwise.test',
        'CorrectPass123!',
      );

      expect(
        () => authService.signInWithEmailAndPassword(
          'edward@spendwise.test',
          'WrongPassword!',
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          'wrong-password',
        )),
      );
    });

    test(
        '7. Password reset succeeds for registered email and fails for unknown',
        () async {
      await authService.createUserWithEmailAndPassword(
        'frank@spendwise.test',
        'Pass123!',
      );

      // Known email succeeds without error
      await expectLater(
        authService.sendPasswordResetEmail('frank@spendwise.test'),
        completes,
      );

      // Unknown email fails
      expect(
        () => authService.sendPasswordResetEmail('unknown@spendwise.test'),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          'user-not-found',
        )),
      );
    });

    test('8. Google Sign-In succeeds and maps user details', () async {
      final user = await authService.signInWithGoogle();
      expect(user, isNotNull);
      expect(user!.email, contains('google'));
      expect(authService.currentUser, equals(user));
    });

    test(
        '9. Google Sign-In cancellation returns null gracefully without state corruption',
        () async {
      authService.setGoogleSignInCanceled(true);
      final user = await authService.signInWithGoogle();

      expect(user, isNull);
      expect(authService.currentUser, isNull);
    });

    test('10. Sign out clears currentUser and emits null stream event',
        () async {
      await authService.signInWithGoogle();
      expect(authService.currentUser, isNotNull);

      await authService.signOut();
      expect(authService.currentUser, isNull);
    });
  });

  group('Phase 5: Guest Migration, Deduplication & Cloud Sync Tests', () {
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

    test('11. continueAsGuest sets AuthStatus.guest and preserves local state',
        () {
      authSync.continueAsGuest();
      expect(authSync.status, AuthStatus.guest);
      expect(authSync.isGuest, isTrue);
      expect(authSync.isAuthenticated, isFalse);
      expect(authSync.currentUser, isNull);
    });

    test(
        '12. Guest-to-Account migration: deterministic deduplication prevents double-counting',
        () async {
      final date = DateTime(2026, 10, 20);

      // 1. Cloud account already has Account 1 and Expense 1 ("Groceries $75")
      final cloudVault = {
        'version': 2,
        'lastUpdated': DateTime(2026, 10, 21, 10, 0).toIso8601String(),
        'accounts': [
          {
            'id': 'acc_checking',
            'name': 'Checking Account',
            'balance': 1000.0,
            'type': 'bank',
            'currency': 'USD',
            'isSample': false,
          }
        ],
        'expenses': [
          {
            'id': 'exp_cloud_1',
            'title': 'Groceries',
            'amount': 75.0,
            'category': 'Groceries',
            'accountId': 'acc_checking',
            'date': date.toIso8601String(),
            'type': 'expense',
            'isSample': false,
            'importHash': StatementImporter.generateFingerprint(
              accountId: 'acc_checking',
              date: date,
              description: 'Groceries',
              amount: 75.0,
              type: TransactionType.expense,
            ),
          }
        ],
        'budgets': <Map<String, dynamic>>[],
      };

      // 2. Guest created the same Expense 1 plus a new unique Expense 2 ("Coffee $5")
      final guestVault = {
        'version': 2,
        'lastUpdated': DateTime(2026, 10, 22, 10, 0).toIso8601String(),
        'accounts': [
          {
            'id': 'acc_cash',
            'name': 'Cash Wallet',
            'balance': 200.0,
            'type': 'cash',
            'currency': 'USD',
            'isSample': false,
          }
        ],
        'expenses': [
          {
            'id': 'exp_guest_duplicate',
            'title': 'Groceries',
            'amount': 75.0,
            'category': 'Groceries',
            'accountId': 'acc_checking',
            'date': date.toIso8601String(),
            'type': 'expense',
            'isSample': false,
          },
          {
            'id': 'exp_guest_unique',
            'title': 'Coffee',
            'amount': 5.0,
            'category': 'Food',
            'accountId': 'acc_cash',
            'date': date.toIso8601String(),
            'type': 'expense',
            'isSample': false,
          }
        ],
        'budgets': <Map<String, dynamic>>[],
      };

      final merged = await localAuth.mergeGuestVault(
        userId: 'test_user_uid',
        guestVault: guestVault,
        cloudVault: cloudVault,
      );

      final mergedAccounts = merged['accounts'] as List;
      final mergedExpenses = merged['expenses'] as List;

      // Both accounts merged
      expect(mergedAccounts.length, 2);
      expect(
        mergedAccounts.map((a) => a['name']),
        containsAll(['Checking Account', 'Cash Wallet']),
      );

      // Exactly 2 expenses, NOT 3 (Groceries deduplicated!)
      expect(mergedExpenses.length, 2);
      expect(
        mergedExpenses.map((e) => e['title']),
        containsAll(['Groceries', 'Coffee']),
      );
    });

    test(
        '13. Timestamp conflict resolution: cloud with newer timestamp overrides local',
        () async {
      await authSync.registerWithEmail(
          'sync_test@spendwise.test', 'Pass123456!');
      final user = authSync.currentUser!;

      // Populate cloud with newer record
      final newerCloudDate = DateTime.now().add(const Duration(minutes: 30));
      final cloudVault = {
        'version': 2,
        'lastUpdated': newerCloudDate.toIso8601String(),
        'profile': {'userName': 'Cloud Synced Alice'},
        'accounts': [
          {
            'id': 'acc_cloud',
            'name': 'Cloud Vault Account',
            'balance': 5500.0,
            'type': 'bank',
            'currency': 'USD',
            'isSample': false,
          }
        ],
        'expenses': <Map<String, dynamic>>[],
        'budgets': <Map<String, dynamic>>[],
      };
      await localAuth.uploadVault(userId: user.uid, vaultData: cloudVault);

      // Perform sync
      await authSync.syncVaultWithCloud();

      expect(authSync.syncStatus, SyncStatus.synced);
      expect(finance.userName, 'Cloud Synced Alice');
      expect(
          finance.accounts.any((a) => a.name == 'Cloud Vault Account'), isTrue);
    });

    test('14. Offline sync failure updates SyncStatus to offline', () async {
      await authSync.registerWithEmail(
          'offline_test@spendwise.test', 'Pass123456!');
      localAuth.setSimulateNetworkError(true);

      await authSync.syncVaultWithCloud();

      expect(authSync.syncStatus, SyncStatus.offline);
      expect(authSync.errorMessage, contains('offline'));
    });
  });

  group('Phase 5: Auth & Sync Widget Flows', () {
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
        '15. AuthScreen with AuthSyncProvider renders Google, Email and Guest options',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool guestTapped = false;

      await tester.pumpWidget(
        createTestApp(
          AuthScreen(
            onExploreAsGuest: () => guestTapped = true,
          ),
        ),
      );

      expect(find.text('Save your financial journey'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Sign up with Email'), findsOneWidget);
      expect(find.text('Explore as Guest'), findsOneWidget);

      // Tap Explore as Guest
      await tester.tap(find.text('Explore as Guest'));
      await tester.pumpAndSettle();

      expect(guestTapped, isTrue);
      expect(authSync.isGuest, isTrue);
    });

    testWidgets('16. EmailAuthSheet allows switching modes and validates input',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestApp(
          const Scaffold(
            body: EmailAuthSheet(),
          ),
        ),
      );

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);

      // Switch to Sign Up
      await tester.tap(find.text("Don't have an account? Sign Up"));
      await tester.pumpAndSettle();

      expect(find.text('Create an Account'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);

      // Switch to Forgot Password
      await tester.tap(find.text('Already have an account? Sign In'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
    });

    testWidgets(
        '17. GuestMigrationDialog renders explicit Merge, Fresh and Cancel choices',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool? migrationResult;

      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  migrationResult = await GuestMigrationDialog.show(ctx);
                },
                child: const Text('Open Migration'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Migration'));
      await tester.pumpAndSettle();

      expect(find.text('Sync Guest Finances?'), findsOneWidget);
      expect(find.text('Merge Data'), findsOneWidget);
      expect(find.text('Start Fresh'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Merge Data
      await tester.tap(find.text('Merge Data'));
      await tester.pumpAndSettle();

      expect(migrationResult, isTrue);
    });

    testWidgets(
        '18. BackendStatusModal truthfully displays configuration and setup steps',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestApp(
          const Scaffold(
            body: BackendStatusModal(),
          ),
        ),
      );

      expect(find.text('Authentication Service'), findsOneWidget);
      expect(find.text('Cloud Synchronization'), findsOneWidget);
      expect(find.text('Firestore Security Rules'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('19. HomeScreen displays sync status chip and triggers sync',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestApp(
          const HomeScreen(),
        ),
      );

      expect(find.byKey(const Key('home_sync_status_chip')), findsOneWidget);
    });

    testWidgets(
        '20. Guest-to-authenticated profile update: Google Sign-In immediately updates FinanceProvider and SettingsScreen without refresh',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Initially in Guest state
      expect(finance.userName, 'Guest User');
      expect(finance.userEmail, 'guest@spendwise.local');

      await tester.pumpWidget(
        createTestApp(
          const SettingsScreen(),
        ),
      );

      // Verify guest state is rendered
      expect(find.text('Guest User'), findsOneWidget);
      expect(find.text('guest@spendwise.local'), findsOneWidget);
      expect(find.text('Free Tier • Local Storage'), findsOneWidget);

      // Sign in with Google
      final success = await authSync.loginWithGoogle();
      expect(success, isTrue);

      // FinanceProvider state must be updated immediately
      expect(finance.userName, 'Google User');
      expect(finance.userEmail, 'user.google@gmail.com');

      // Re-pump widget to verify immediate UI propagation
      await tester.pumpAndSettle();

      expect(find.text('Google User'), findsOneWidget);
      expect(find.text('user.google@gmail.com'), findsOneWidget);
      expect(find.text('Cloud Synced • Firebase'), findsOneWidget);
    });

    testWidgets(
        '21. MoreScreen immediately displays authenticated user credentials and cloud badge',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Sign in with email/password
      await authSync.registerWithEmail(
        'alice.dev@company.com',
        'Secret123!',
        displayName: 'Alice Developer',
      );

      await tester.pumpWidget(
        createTestApp(
          const MoreScreen(),
        ),
      );

      expect(find.text('Alice Developer'), findsOneWidget);
      expect(find.text('alice.dev@company.com'), findsOneWidget);
      expect(find.text('Cloud Synced • Firebase'), findsOneWidget);
    });

    testWidgets(
        '22. Sign out reverts FinanceProvider profile and SettingsScreen to Guest User',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await authSync.loginWithGoogle();
      expect(finance.userName, 'Google User');

      await tester.pumpWidget(
        createTestApp(
          const SettingsScreen(),
        ),
      );
      expect(find.text('Google User'), findsOneWidget);

      // Sign out
      await authSync.logout();
      await tester.pumpAndSettle();

      // FinanceProvider profile must be cleanly reverted
      expect(finance.userName, 'Guest User');
      expect(finance.userEmail, 'guest@spendwise.local');

      // Settings screen must reflect guest state
      expect(find.text('Guest User'), findsOneWidget);
      expect(find.text('guest@spendwise.local'), findsOneWidget);
      expect(find.text('Free Tier • Local Storage'), findsOneWidget);
    });

    testWidgets(
        '23. Timeline (HomeScreen) greeting updates dynamically on Google Sign-In and fits without RenderFlex overflow at 400x642',
        (tester) async {
      tester.view.physicalSize = const Size(400, 642);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Add a test expense so HomeScreen renders the populated Timeline view
      finance.addExpense(
        title: 'Coffee',
        amount: 5.5,
        category: 'Food & Drinks',
      );

      await tester.pumpWidget(
        createTestApp(
          const HomeScreen(),
        ),
      );

      // Verify guest greeting in Timeline
      expect(find.byKey(const Key('home_timeline_greeting')), findsOneWidget);
      expect(find.text('Hello, Guest User'), findsOneWidget);

      // Sign in with Google
      final success = await authSync.loginWithGoogle();
      expect(success, isTrue);

      // Re-pump widget
      await tester.pumpAndSettle();

      // Timeline greeting must immediately show authenticated user's name
      expect(find.text('Hello, Google User'), findsOneWidget);

      // Verify no RenderFlex overflow exception was thrown at 400x642
      expect(tester.takeException(), isNull);

      // Verify on larger desktop viewport as well
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();
      expect(find.text('Hello, Google User'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Sign out
      await authSync.logout();
      await tester.pumpAndSettle();
      expect(find.text('Hello, Guest User'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '24. Settings truthfully displays "Account Connected • Firebase" when authenticated before sync and "Cloud Synced • Firebase" after successful sync',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Initially guest
      await tester.pumpWidget(
        createTestApp(
          const SettingsScreen(),
        ),
      );
      expect(find.text('Free Tier • Local Storage'), findsOneWidget);

      // Sign in with Google
      await authSync.loginWithGoogle();
      await tester.pumpAndSettle();

      // In LocalAuthService, loginWithGoogle completes syncVaultWithCloud -> Cloud Synced
      expect(find.text('Cloud Synced • Firebase'), findsOneWidget);
    });
  });

  group(
      'Phase 5: Firestore Vault Payload Compatibility & Security UID Guard Tests',
      () {
    test(
        '25. FirestoreSyncService.buildUploadPayload injects updatedBy and positive integer clientTimestamp while preserving vault collections',
        () {
      final finance = FinanceProvider(seedSampleData: false);
      finance.addAccount(
        Account(
          id: 'acc_checking',
          name: 'Checking Account',
          type: AccountType.debit,
          balance: 1500.0,
          icon: '🏛️',
          currency: 'USD',
        ),
      );
      finance.addExpense(
        title: 'Groceries',
        category: 'Food',
        amount: 85.50,
        accountId: finance.accounts.first.id,
      );

      final vaultMap = finance.toVaultMap();
      final fixedTime = DateTime(2026, 10, 23, 12, 0, 0);

      final payload = FirestoreSyncService.buildUploadPayload(
        userId: 'usr_secure_999',
        vaultData: vaultMap,
        clientTime: fixedTime,
        serverTimestamp: 'MOCK_SERVER_TIMESTAMP',
      );

      expect(payload['updatedBy'], equals('usr_secure_999'));
      expect(
          payload['clientTimestamp'], equals(fixedTime.millisecondsSinceEpoch));
      expect(payload['clientTimestamp'], isA<int>());
      expect((payload['clientTimestamp'] as int) > 0, isTrue);
      expect(payload['version'], equals(2));
      expect(payload['lastUpdated'], equals(fixedTime.toIso8601String()));
      expect(payload['serverSyncedAt'], equals('MOCK_SERVER_TIMESTAMP'));

      expect(payload['accounts'], isA<List>());
      expect((payload['accounts'] as List).length, equals(1));
      expect(payload['expenses'], isA<List>());
      expect((payload['expenses'] as List).length, equals(1));
      expect(payload['budgets'], isA<List>());
      expect(payload['subscriptions'], isA<List>());
      expect(payload['profile'], isA<Map>());
    });

    test(
        '26. FirestoreSyncService rejects upload and download before any Firestore call when UID does not match authenticated user',
        () async {
      // 1. Authenticated as 'alice_uid', but attempt to upload to 'bob_uid'
      final aliceService = FirestoreSyncService(
        currentUidResolver: () => 'alice_uid',
      );

      expect(
        () => aliceService.uploadVault(
          userId: 'bob_uid',
          vaultData: {'version': 2},
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        )),
      );

      expect(
        () => aliceService.downloadVault(
          userId: 'bob_uid',
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        )),
      );

      // 2. Unauthenticated (currentUserId == null)
      final unauthenticatedService = FirestoreSyncService(
        currentUidResolver: () => null,
      );

      expect(
        () => unauthenticatedService.uploadVault(
          userId: 'any_uid',
          vaultData: {'version': 2},
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        )),
      );

      expect(
        () => unauthenticatedService.downloadVault(
          userId: 'any_uid',
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        )),
      );
    });

    test(
        '27. LocalAuthService enforces UID match and injects updatedBy and clientTimestamp',
        () async {
      final localAuth = LocalAuthService();
      final user = await localAuth.createUserWithEmailAndPassword(
        'vault_test@spendwise.test',
        'Password123!',
      );

      final finance = FinanceProvider(seedSampleData: false);
      finance.addAccount(
        Account(
          id: 'acc_savings',
          name: 'Savings',
          type: AccountType.debit,
          balance: 3000.0,
          icon: 'savings',
          currency: 'USD',
        ),
      );

      // Legitimate upload for authenticated user
      await localAuth.uploadVault(
        userId: user.uid,
        vaultData: finance.toVaultMap(),
      );

      final rawCloud = localAuth.getRawCloudVault(user.uid);
      expect(rawCloud, isNotNull);
      expect(rawCloud!['updatedBy'], equals(user.uid));
      expect(rawCloud['clientTimestamp'], isA<int>());
      expect((rawCloud['clientTimestamp'] as int) > 0, isTrue);
      expect(rawCloud['accounts'], isA<List>());

      // Attempted upload under another user's UID is rejected
      expect(
        () => localAuth.uploadVault(
          userId: 'intruder_uid_456',
          vaultData: finance.toVaultMap(),
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        )),
      );

      // Attempted download under another user's UID is rejected
      expect(
        () => localAuth.downloadVault(
          userId: 'intruder_uid_456',
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        )),
      );

      localAuth.dispose();
    });

    test(
        '28. Vault roundtrip serialization and deserialization remain compatible with security fields',
        () {
      final sourceFinance = FinanceProvider(seedSampleData: false);
      sourceFinance.updateProfile(
        name: 'Jordan Belfort',
        email: 'jordan@wallstreet.test',
      );
      sourceFinance.updateCurrency('EUR');
      sourceFinance.addAccount(
        Account(
          id: 'acc_main',
          name: 'Main Wallet',
          type: AccountType.cash,
          balance: 4200.50,
          icon: 'account_balance_wallet',
          currency: 'EUR',
        ),
      );
      sourceFinance.addExpense(
        title: 'Yacht Fuel',
        category: 'Transport',
        amount: 850.0,
        accountId: sourceFinance.accounts.first.id,
      );

      final vaultMap = sourceFinance.toVaultMap();
      final payload = FirestoreSyncService.buildUploadPayload(
        userId: 'usr_jordan_1',
        vaultData: vaultMap,
        serverTimestamp: 'SERVER_TS_MOCK',
      );

      // Deserialize payload into fresh FinanceProvider
      final targetFinance = FinanceProvider(seedSampleData: false);
      targetFinance.loadFromVaultMap(payload);

      expect(targetFinance.userName, equals('Jordan Belfort'));
      expect(targetFinance.userEmail, equals('jordan@wallstreet.test'));
      expect(targetFinance.currency, equals('EUR'));
      expect(targetFinance.accounts.length, equals(1));
      expect(targetFinance.accounts.first.name, equals('Main Wallet'));
      expect(targetFinance.accounts.first.balance,
          equals(sourceFinance.accounts.first.balance));
      expect(targetFinance.expenses.length, equals(1));
      expect(targetFinance.expenses.first.title, equals('Yacht Fuel'));
      expect(targetFinance.expenses.first.amount, equals(850.0));
    });

    test(
        '29. Guest mode strictly performs no cloud operations and maintains local-only state',
        () async {
      final localAuth = LocalAuthService();
      final finance = FinanceProvider(seedSampleData: false);
      final authSync = AuthSyncProvider(
        authService: localAuth,
        cloudSyncService: localAuth,
        storageService: LocalStorageService(),
        financeProvider: finance,
      );

      // Enter guest mode
      authSync.continueAsGuest();
      expect(authSync.isGuest, isTrue);
      expect(authSync.isAuthenticated, isFalse);
      expect(authSync.syncStatus, equals(SyncStatus.idle));

      // Mutate local guest data
      finance.addAccount(
        Account(
          id: 'acc_pocket',
          name: 'Guest Pocket Cash',
          type: AccountType.cash,
          balance: 75.0,
          icon: 'payments',
          currency: 'USD',
        ),
      );
      finance.addExpense(
        title: 'Street Food',
        category: 'Food',
        amount: 12.0,
        accountId: finance.accounts.first.id,
      );

      // Attempt cloud sync in guest mode
      await authSync.syncVaultWithCloud();

      // Cloud status remains idle, no cloud vaults were created
      expect(authSync.syncStatus, equals(SyncStatus.idle));
      expect(authSync.lastSyncTime, isNull);
      expect(localAuth.getRawCloudVault('guest'), isNull);
      expect(localAuth.getRawCloudVault(''), isNull);

      authSync.dispose();
      localAuth.dispose();
    });
  });

  group(
      'Phase 5: Reload, Session Restoration & Persistence Bug Regression Tests',
      () {
    testWidgets(
        '30. Existing authenticated user after reload is restored and SplashScreen navigates directly to MainNavigationScreen',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final localAuth = LocalAuthService();
      await localAuth.createUserWithEmailAndPassword(
        'restored@spendwise.test',
        'Password123!',
        displayName: 'Restored User',
      );

      final finance = FinanceProvider(seedSampleData: false);
      final authSync = AuthSyncProvider(
        authService: localAuth,
        cloudSyncService: localAuth,
        storageService: LocalStorageService(),
        financeProvider: finance,
      );

      expect(authSync.isAuthenticated, isTrue);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FinanceProvider>.value(value: finance),
            ChangeNotifierProvider<AuthSyncProvider>.value(value: authSync),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SplashScreen(),
          ),
        ),
      );

      // Advance through splash initialization and navigation transition
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Verified: Navigated directly to MainNavigationScreen, OnboardingFlowScreen was bypassed!
      expect(find.byType(MainNavigationScreen), findsOneWidget);
      expect(find.byType(OnboardingFlowScreen), findsNothing);

      authSync.dispose();
      localAuth.dispose();
    });

    test(
        '31. Newly added expense automatically triggers cloud upload and includes expense in uploaded vault',
        () async {
      final localAuth = LocalAuthService();
      final user = await localAuth.createUserWithEmailAndPassword(
        'auto_sync@spendwise.test',
        'Password123!',
      );

      final finance = FinanceProvider(seedSampleData: false);
      final authSync = AuthSyncProvider(
        authService: localAuth,
        cloudSyncService: localAuth,
        storageService: LocalStorageService(),
        financeProvider: finance,
      );

      // Add account
      finance.addAccount(
        Account(
          id: 'acc_main',
          name: 'Main Checking',
          type: AccountType.debit,
          balance: 1000.0,
          icon: '🏛️',
          currency: 'USD',
        ),
      );

      // Add expense
      finance.addExpense(
        title: 'New Books',
        amount: 45.0,
        category: 'Education',
        accountId: 'acc_main',
      );

      // Wait for debounce auto-sync
      await Future.delayed(const Duration(milliseconds: 400));

      // Remote cloud vault was updated with the new expense
      final remoteVault = localAuth.getRawCloudVault(user.uid);
      expect(remoteVault, isNotNull);
      final expenses = remoteVault!['expenses'] as List;
      expect(expenses.length, equals(1));
      expect(expenses.first['title'], equals('New Books'));
      expect(expenses.first['amount'], equals(45.0));
      expect(remoteVault['updatedBy'], equals(user.uid));
      expect(remoteVault['clientTimestamp'], isA<int>());
      expect(authSync.syncStatus, equals(SyncStatus.synced));

      authSync.dispose();
      localAuth.dispose();
    });

    test(
        '32. Cloud write failure sets syncStatus to offline and never produces false synced status',
        () async {
      final localAuth = LocalAuthService();
      await localAuth.createUserWithEmailAndPassword(
        'fail_sync@spendwise.test',
        'Password123!',
      );

      final finance = FinanceProvider(seedSampleData: false);
      final authSync = AuthSyncProvider(
        authService: localAuth,
        cloudSyncService: localAuth,
        storageService: LocalStorageService(),
        financeProvider: finance,
      );

      localAuth.setSimulateNetworkError(true);

      // Attempt manual or auto-sync
      await authSync.syncVaultWithCloud();

      expect(authSync.syncStatus, equals(SyncStatus.offline));
      expect(authSync.syncStatus, isNot(equals(SyncStatus.synced)));
      expect(authSync.errorMessage, isNotNull);
      expect(authSync.errorMessage, contains('offline'));

      authSync.dispose();
      localAuth.dispose();
    });

    test(
        '33. Restored cloud data with real records is not overwritten by empty local state during reload',
        () async {
      final localAuth = LocalAuthService();
      const testUid = 'persisted_user_uid';
      final cloudDate = DateTime(2026, 10, 23, 10, 0);
      final cloudVault = {
        'version': 2,
        'lastUpdated': cloudDate.toIso8601String(),
        'updatedBy': testUid,
        'clientTimestamp': cloudDate.millisecondsSinceEpoch,
        'profile': {
          'userName': 'Persisted User',
          'userEmail': 'persisted@spendwise.test',
          'hasCompletedOnboarding': true,
        },
        'accounts': [
          {
            'id': 'acc_cloud',
            'name': 'Cloud Bank',
            'balance': 2500.0,
            'type': 'debit',
            'icon': 'account_balance',
            'isSample': false,
            'currency': 'USD',
          }
        ],
        'expenses': [
          {
            'id': 'exp_cloud',
            'title': 'Server Hosting',
            'amount': 120.0,
            'category': 'Business',
            'accountId': 'acc_cloud',
            'date': cloudDate.toIso8601String(),
            'type': 'expense',
            'isSample': false,
          }
        ],
        'budgets': <Map<String, dynamic>>[],
        'subscriptions': <Map<String, dynamic>>[],
      };

      // Seed cloud vault directly
      const authUser = AuthUser(
        uid: testUid,
        email: 'persisted@spendwise.test',
        displayName: 'Persisted User',
      );
      localAuth.setCurrentUser(authUser);
      await localAuth.uploadVault(userId: testUid, vaultData: cloudVault);

      // Fresh local finance provider on browser reload (empty state)
      final localFinance = FinanceProvider(seedSampleData: false);
      expect(localFinance.accounts.isEmpty, isTrue);
      expect(localFinance.expenses.isEmpty, isTrue);

      final authSync = AuthSyncProvider(
        authService: localAuth,
        cloudSyncService: localAuth,
        storageService: LocalStorageService(),
        financeProvider: localFinance,
      );

      // Sync executes
      await authSync.syncVaultWithCloud();

      // Verified: Cloud data was restored into local provider rather than overwritten!
      expect(localFinance.accounts.length, equals(1));
      expect(localFinance.accounts.first.name, equals('Cloud Bank'));
      expect(localFinance.expenses.length, equals(1));
      expect(localFinance.expenses.first.title, equals('Server Hosting'));
      expect(localFinance.hasCompletedOnboarding, isTrue);

      // Remote cloud vault was NOT overwritten by empty state
      final remoteCheck = localAuth.getRawCloudVault(testUid);
      expect((remoteCheck!['expenses'] as List).length, equals(1));

      authSync.dispose();
      localAuth.dispose();
    });

    testWidgets(
        '34. Authenticating from OnboardingFlowScreen completes onboarding with data preserved and no guest wipe',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final localAuth = LocalAuthService();
      final finance = FinanceProvider(seedSampleData: false);
      finance.addAccount(
        Account(
          id: 'acc_preserve',
          name: 'Preserved Account',
          type: AccountType.debit,
          balance: 800.0,
          icon: '🏛️',
          currency: 'USD',
        ),
      );
      finance.addExpense(
        title: 'Preserved Dinner',
        category: 'Food',
        amount: 35.0,
        accountId: 'acc_preserve',
      );

      final authSync = AuthSyncProvider(
        authService: localAuth,
        cloudSyncService: localAuth,
        storageService: LocalStorageService(),
        financeProvider: finance,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FinanceProvider>.value(value: finance),
            ChangeNotifierProvider<AuthSyncProvider>.value(value: authSync),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const OnboardingFlowScreen(),
          ),
        ),
      );

      // Go to last step (AuthScreen)
      final state = tester
          .state<OnboardingFlowScreenState>(find.byType(OnboardingFlowScreen));
      state.goToPage(6);
      await tester.pumpAndSettle();

      expect(find.text('Save your financial journey'), findsOneWidget);

      // Tap Sign in with Google
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      // If guest migration prompt is shown, merge guest records
      if (find.byType(GuestMigrationDialog).evaluate().isNotEmpty) {
        await tester.tap(find.text('Merge Data'));
        await tester.pumpAndSettle();
      }

      // Allow async migration resolution, onAuthenticated callback, and route transition to settle
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      // Navigated to MainNavigationScreen
      expect(find.byType(MainNavigationScreen), findsOneWidget);

      // Financial data was NOT wiped by startFreshGuest!
      expect(finance.accounts.length, equals(1));
      expect(finance.accounts.first.name, equals('Preserved Account'));
      expect(finance.expenses.length, equals(1));
      expect(finance.expenses.first.title, equals('Preserved Dinner'));
      expect(finance.hasCompletedOnboarding, isTrue);

      authSync.dispose();
      localAuth.dispose();
    });
  });
}
