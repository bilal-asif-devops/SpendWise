import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spendwise/screens/analytics_screen.dart';
import 'package:spendwise/screens/budgets_screen.dart';
import 'package:spendwise/screens/home_screen.dart';
import 'package:spendwise/screens/subscriptions_screen.dart';
import 'package:spendwise/screens/wallets_screen.dart';
import 'package:spendwise/services/finance_provider.dart';
import 'package:spendwise/services/storage_service.dart';

class MockStorageService extends LocalStorageService {
  Map<String, dynamic>? inMemoryVault;

  @override
  Future<Map<String, dynamic>?> loadVault() async => inMemoryVault;

  @override
  Future<void> saveVault(Map<String, dynamic> vaultData) async {
    inMemoryVault = vaultData;
  }
}

Widget createTestApp(Widget child, FinanceProvider provider) {
  return ChangeNotifierProvider<FinanceProvider>.value(
    value: provider,
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2.1: Guest Data Isolation & Contamination Guards', () {
    test(
        'Test A: Fresh guest initialization (all collections empty, 0 balances, 0 savings goal)',
        () {
      final storage = MockStorageService();
      final finance = FinanceProvider(storageService: storage);

      expect(finance.accounts, isEmpty);
      expect(finance.expenses, isEmpty);
      expect(finance.subscriptions, isEmpty);
      expect(finance.budgets, isEmpty);
      expect(finance.totalLiquidBalance, equals(0.0));
      expect(finance.totalAllWalletsBalance, equals(0.0));
      expect(finance.totalCreditLiability, equals(0.0));
      expect(finance.totalMonthlySubscriptions, equals(0.0));
      expect(finance.totalExpenses, equals(0.0));
      expect(finance.safeToSpendBalance, equals(0.0));
      expect(finance.monthlySavingsGoal, equals(0.0));
      expect(finance.creditAccounts, isEmpty);
      expect(finance.liquidAccounts, isEmpty);
    });

    test(
        'Test B: Add single expense (Food 50) -> exactly 1 expense, 0 sample subscriptions, 0 sample cards',
        () {
      final finance = FinanceProvider(storageService: MockStorageService());

      finance.addExpense(
        title: 'Food Expense',
        category: 'Food',
        amount: 50.00,
      );

      expect(finance.expenses.length, equals(1));
      expect(finance.expenses.first.title, equals('Food Expense'));
      expect(finance.expenses.first.category, equals('Food'));
      expect(finance.expenses.first.amount, equals(50.00));
      expect(finance.expenses.first.isSample, isFalse);

      // Verify zero accounts or cards were invented
      expect(finance.accounts, isEmpty);
      expect(finance.creditAccounts, isEmpty);
      expect(finance.liquidAccounts, isEmpty);

      // Verify zero subscriptions or budgets were invented
      expect(finance.subscriptions, isEmpty);
      expect(finance.budgets, isEmpty);

      // Verify financial math
      expect(finance.totalExpenses, equals(50.00));
      expect(finance.totalLiquidBalance, equals(0.0));
      expect(finance.totalCreditLiability, equals(0.0));
      expect(finance.totalMonthlySubscriptions, equals(0.0));
      expect(finance.safeToSpendBalance, equals(0.0));
    });

    test(
        'Test C: Persistence & reload (restart preserves real expense and does not resurrect sample data)',
        () async {
      final storage = MockStorageService();
      final session1 = FinanceProvider(storageService: storage);

      // Add user expense in session 1
      session1.addExpense(
        title: 'Dinner with friends',
        category: 'Food',
        amount: 50.00,
      );

      // Verify session 1 wrote to storage
      expect(storage.inMemoryVault, isNotNull);
      final storedExpenses = storage.inMemoryVault!['expenses'] as List;
      expect(storedExpenses.length, equals(1));
      expect((storage.inMemoryVault!['accounts'] as List), isEmpty);
      expect((storage.inMemoryVault!['subscriptions'] as List), isEmpty);
      expect((storage.inMemoryVault!['budgets'] as List), isEmpty);

      // Simulate app restart: instantiate session 2 with the same storage
      final session2 = FinanceProvider(storageService: storage);
      await Future.delayed(const Duration(milliseconds: 30));

      expect(session2.expenses.length, equals(1));
      expect(session2.expenses.first.title, equals('Dinner with friends'));
      expect(session2.expenses.first.amount, equals(50.00));
      expect(session2.accounts, isEmpty);
      expect(session2.subscriptions, isEmpty);
      expect(session2.budgets, isEmpty);
      expect(session2.totalExpenses, equals(50.00));
    });

    test(
        'Test E: Budget isolation (no phantom \$560 budget, adding expense does not mutate phantom budget)',
        () {
      final finance = FinanceProvider(storageService: MockStorageService());

      expect(finance.budgets, isEmpty);

      finance.addExpense(
        title: 'Lunch',
        category: 'Food',
        amount: 25.00,
      );

      expect(finance.budgets, isEmpty);
      expect(finance.expenses.length, equals(1));
    });

    test(
        'Test F: Credit card isolation (0 credit cards, transfer between non-existent accounts fails gracefully)',
        () {
      final finance = FinanceProvider(storageService: MockStorageService());

      expect(finance.creditAccounts, isEmpty);

      final success = finance.transferBetweenAccounts(
        fromAccountId: 'acc_nonexistent_1',
        toAccountId: 'acc_nonexistent_2',
        amount: 50.00,
      );

      expect(success, isFalse);
      expect(
          finance.lastErrorMessage, equals('Selected account does not exist.'));
      expect(finance.accounts, isEmpty);
      expect(finance.creditAccounts, isEmpty);
    });

    test(
        'Test G: Purge sample data cleanly handles legacy seeded state without affecting user records',
        () {
      final finance = FinanceProvider(
        storageService: MockStorageService(),
        seedSampleData: true,
      );

      expect(finance.accounts.length, equals(4));
      expect(finance.subscriptions.length, equals(3));
      expect(finance.expenses.length, equals(3));

      // Add one real user expense
      finance.addExpense(
        title: 'Genuine User Expense',
        category: 'Shopping',
        amount: 75.00,
      );

      expect(finance.expenses.length, equals(4));

      // Run purge
      finance.purgeSampleData();

      expect(finance.accounts, isEmpty);
      expect(finance.subscriptions, isEmpty);
      expect(finance.budgets, isEmpty);
      expect(finance.expenses.length, equals(1));
      expect(finance.expenses.first.title, equals('Genuine User Expense'));
      expect(finance.totalExpenses, equals(75.00));
    });
  });

  group('Phase 2.1: Empty State Screen Widget Tests', () {
    testWidgets(
        'Test D1: HomeScreen renders empty Frame 70 view when no expenses exist',
        (tester) async {
      final finance = FinanceProvider(storageService: MockStorageService());
      await tester.pumpWidget(createTestApp(const HomeScreen(), finance));
      await tester.pumpAndSettle();

      expect(find.text('Clear view of your finances'), findsOneWidget);
      expect(find.text('Connect Bank Account'), findsOneWidget);
      expect(find.text('Add Expense Manually'), findsOneWidget);
      // Ensure no commercial bank names appear
      expect(find.text('Meezan Bank'), findsNothing);
      expect(find.text('Visa Debit'), findsNothing);
      expect(find.text('Mastercard'), findsNothing);
    });

    testWidgets(
        'Test D2: HomeScreen active view with 1 expense shows no fake wallets or subscriptions',
        (tester) async {
      final finance = FinanceProvider(storageService: MockStorageService());
      finance.addExpense(
          title: 'Food Expense', category: 'Food', amount: 50.00);

      await tester.pumpWidget(createTestApp(const HomeScreen(), finance));
      await tester.pumpAndSettle();

      expect(find.text('Hello, Guest User'), findsOneWidget);
      expect(find.text('\$0.00'), findsOneWidget); // Safe to spend is 0.00
      expect(find.textContaining('No wallets added yet'), findsOneWidget);
      expect(find.text('No upcoming bills yet.'), findsOneWidget);
      expect(find.text('Food Expense'), findsOneWidget);
      expect(find.text('Meezan Bank'), findsNothing);
      expect(find.text('Netflix'), findsNothing);
    });

    testWidgets(
        'Test D3: WalletsScreen renders empty state without fake spline curve or cards',
        (tester) async {
      final finance = FinanceProvider(storageService: MockStorageService());
      await tester.pumpWidget(createTestApp(const WalletsScreen(), finance));
      await tester.pumpAndSettle();

      expect(find.text('Accounts & Wallets'), findsOneWidget);
      expect(
          find.text('Wealth trajectory will plot here as you record balances.'),
          findsOneWidget);
      expect(find.text('No liquid accounts or cash wallets created yet.'),
          findsOneWidget);
      expect(find.text('No credit cards added.'), findsOneWidget);
      expect(find.text('Aug 2026'), findsNothing);
      expect(find.text('Meezan Bank'), findsNothing);
    });

    testWidgets(
        'Test D4: SubscriptionsScreen renders clean empty state and \$0.00 total',
        (tester) async {
      final finance = FinanceProvider(storageService: MockStorageService());
      await tester
          .pumpWidget(createTestApp(const SubscriptionsScreen(), finance));
      await tester.pumpAndSettle();

      expect(find.text('Subscriptions Radar'), findsOneWidget);
      expect(find.text('\$0.00'), findsOneWidget);
      expect(find.text('Across all 0 active recurring subscriptions.'),
          findsOneWidget);
      expect(
          find.text('No recurring subscriptions tracked yet.'), findsOneWidget);
      expect(find.text('Netflix'), findsNothing);
      expect(find.text('Spotify'), findsNothing);
    });

    testWidgets(
        'Test D5: BudgetsScreen renders clean empty state and no fake \$560 Home Budget',
        (tester) async {
      final finance = FinanceProvider(storageService: MockStorageService());
      await tester.pumpWidget(createTestApp(const BudgetsScreen(), finance));
      await tester.pumpAndSettle();

      expect(find.text('Budgets'), findsOneWidget);
      expect(find.text('No budgets set yet'), findsOneWidget);
      expect(find.text('Create a Budget'), findsOneWidget);
      expect(find.text('Home Budget 🏡'), findsNothing);
      expect(find.textContaining('560.00'), findsNothing);
    });

    testWidgets(
        'Test D6: AnalyticsScreen renders empty state when 0 expenses, and exact 100% Food breakdown when 1 expense added',
        (tester) async {
      final finance = FinanceProvider(storageService: MockStorageService());
      await tester.pumpWidget(createTestApp(const AnalyticsScreen(), finance));
      await tester.pumpAndSettle();

      expect(find.text('No spending data yet'), findsOneWidget);

      // Now add 50 Food expense
      finance.addExpense(
          title: 'Food Expense', category: 'Food', amount: 50.00);
      await tester.pumpWidget(createTestApp(const AnalyticsScreen(), finance));
      await tester.pumpAndSettle();

      expect(find.text('Total Spent'), findsOneWidget);
      expect(find.text('\$50.00'), findsWidgets);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      // Ensure hardcoded 45% / 25% / 18% fake categories are absent
      expect(find.text('45%'), findsNothing);
      expect(find.text('Shopping & Essentials'), findsNothing);
    });
  });
}
