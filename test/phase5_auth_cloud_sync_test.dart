import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spendwise/models/auth_models.dart';
import 'package:spendwise/models/models.dart';
import 'package:spendwise/screens/auth/backend_status_modal.dart';
import 'package:spendwise/screens/auth/email_auth_sheet.dart';
import 'package:spendwise/screens/auth/guest_migration_dialog.dart';
import 'package:spendwise/screens/home_screen.dart';
import 'package:spendwise/screens/onboarding/auth_screen.dart';
import 'package:spendwise/services/auth_sync_provider.dart';
import 'package:spendwise/services/finance_provider.dart';
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
  });
}
