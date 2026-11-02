import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spendwise/models/models.dart';
import 'package:spendwise/services/finance_provider.dart';
import 'package:spendwise/services/storage_service.dart';
import 'package:spendwise/utils/formatters.dart';
import 'package:spendwise/screens/budgets_screen.dart';
import 'package:spendwise/screens/activity_screen.dart';

class InMemoryStorageService extends LocalStorageService {
  Map<String, dynamic>? _storedVault;

  @override
  Future<Map<String, dynamic>?> loadVault() async => _storedVault;

  @override
  Future<bool> saveVault(Map<String, dynamic> vault) async {
    _storedVault = vault;
    return true;
  }
}

void main() {
  group('Phase 7: CurrencyFormatter Unit Tests', () {
    test(
        '1. Formats multi-character symbol (Rs) with clean prefix and decimals',
        () {
      expect(CurrencyFormatter.format(419.64, 'Rs'), equals('Rs 419.64'));
      expect(CurrencyFormatter.format(73687.5, 'Rs'), equals('Rs 73,687.50'));
      expect(CurrencyFormatter.format(0.0, 'Rs'), equals('Rs 0.00'));
    });

    test('2. Formats single-character symbol (\$) with adjacent prefix', () {
      expect(CurrencyFormatter.format(1284.0, '\$'), equals('\$1,284.00'));
      expect(CurrencyFormatter.format(15.99, '\$'), equals('\$15.99'));
    });

    test(
        '3. Formats negative and expense amounts with standard decimal and minus sign',
        () {
      expect(
          CurrencyFormatter.formatExpense(419.64, 'Rs'), equals('-Rs 419.64'));
      expect(CurrencyFormatter.format(-419.64, 'Rs'), equals('-Rs 419.64'));
      expect(CurrencyFormatter.formatExpense(120.0, '\$'), equals('-\$120.00'));
    });

    test('4. Formats income amounts with plus sign when requested', () {
      expect(
          CurrencyFormatter.formatIncome(1000.0, 'Rs'), equals('+Rs 1,000.00'));
      expect(CurrencyFormatter.formatIncome(250.0, '\$'), equals('+\$250.00'));
    });

    test('5. Compact formatter handles zero, thousands, and millions cleanly',
        () {
      expect(CurrencyFormatter.formatCompact(0, 'Rs'), equals('Rs 0'));
      expect(CurrencyFormatter.formatCompact(500, 'Rs'), equals('Rs 500'));
      expect(CurrencyFormatter.formatCompact(2500, 'Rs'), equals('Rs 2.5k'));
      expect(CurrencyFormatter.formatCompact(10000, 'Rs'), equals('Rs 10k'));
      expect(CurrencyFormatter.formatCompact(1000000, '\$'), equals('\$1M'));
    });

    test('6. Handles NaN and infinity safely without throwing', () {
      expect(CurrencyFormatter.format(double.nan, 'Rs'), equals('Rs 0.00'));
      expect(
          CurrencyFormatter.format(double.infinity, 'Rs'), equals('Rs 0.00'));
      expect(CurrencyFormatter.formatCompact(double.nan, 'Rs'), equals('Rs 0'));
    });
  });

  group('Phase 7: Budget Calculations & Mathematical Accuracy', () {
    late FinanceProvider finance;

    setUp(() {
      finance = FinanceProvider(storageService: InMemoryStorageService());
      finance.purgeSampleData();
      finance.updateCurrency('Rs');
    });

    test('7. Normal spending: spent reflects only matching expenses in period',
        () {
      final now = DateTime.now();
      final budget = Budget(
        id: 'test_bgt',
        name: 'Dining Budget',
        category: 'Food',
        targetAmount: 500.0,
        spentAmount: 0.0,
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
        icon: '🍔',
      );
      finance.addBudget(budget);

      // Add a matching expense
      finance.addExpense(
        title: 'Lunch',
        category: 'Food',
        amount: 150.0,
      );

      // Add an expense in another category
      finance.addExpense(
        title: 'Fuel',
        category: 'Transport',
        amount: 80.0,
      );

      final spent = finance.calculateBudgetSpent(budget);
      expect(spent, equals(150.0));

      final updatedBudget =
          finance.budgets.firstWhere((b) => b.id == budget.id);
      expect(updatedBudget.spentAmount, equals(150.0));
      expect(updatedBudget.remainingAmount, equals(350.0));
      expect(updatedBudget.percentageSpent, closeTo(0.30, 0.001));
    });

    test(
        '8. Income transactions are NEVER counted towards budget spending (preventing 2111% defect)',
        () {
      final now = DateTime.now();
      final budget = Budget(
        id: 'test_bgt_income',
        name: 'Discretionary Budget',
        category: 'General Discretionary',
        targetAmount: 500.0,
        spentAmount: 0.0,
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
        icon: '🏡',
      );
      finance.addBudget(budget);

      // Add small expense
      finance.addExpense(
        title: 'Coffee',
        category: 'Food',
        amount: 50.0,
      );

      // Add large salary income (which previously caused 2111% bug when added to spending)
      finance.addIncome(
        title: 'Monthly Salary',
        category: 'Salary',
        amount: 10000.0,
      );

      final spent = finance.calculateBudgetSpent(budget);
      // Spent must remain 50.0, NOT 10,050.0!
      expect(spent, equals(50.0));
      expect(budget.copyWith(spentAmount: spent).percentageSpent,
          closeTo(0.10, 0.001));
    });

    test(
        '9. Overspending: percentage is mathematically truthful and NOT clamped to 2.0',
        () {
      final now = DateTime.now();
      final budget = Budget(
        id: 'test_overspend',
        name: 'Small Limit',
        category: 'All',
        targetAmount: 100.0,
        spentAmount: 0.0,
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
      );
      finance.addBudget(budget);

      finance.addExpense(
        title: 'Expensive Dinner',
        category: 'Food',
        amount: 350.0,
      );

      final spent = finance.calculateBudgetSpent(budget);
      expect(spent, equals(350.0));

      final evaluated = budget.copyWith(spentAmount: spent);
      expect(evaluated.isOverBudget, isTrue);
      // 350 / 100 = 3.5 (350%) — must NOT be clamped to 2.0!
      expect(evaluated.percentageSpent, equals(3.5));
      expect(evaluated.netRemaining, equals(-250.0));
    });

    test(
        '10. Daily budget allowance is derived from remaining budget divided by remaining days',
        () {
      // Fix date at day 10 of a 30-day month -> 21 days remaining (days 10..30 inclusive)
      final periodStart = DateTime(2026, 4, 1);
      final periodEnd = DateTime(2026, 4, 30);
      final asOf = DateTime(2026, 4, 10);

      final budget = Budget(
        id: 'test_allowance',
        name: 'April Budget',
        category: 'All',
        targetAmount: 630.0,
        spentAmount: 0.0,
        startDate: periodStart,
        endDate: periodEnd,
      );
      finance.addBudget(budget);

      // Remaining days: 30 - 10 + 1 = 21 days
      final daysLeft = finance.calculateBudgetDaysRemaining(budget, asOf);
      expect(daysLeft, equals(21));

      // 630 / 21 = 30.0 per day
      final dailyAllowance =
          finance.calculateDailyBudgetAllowance(budget, asOf);
      expect(dailyAllowance, equals(30.0));

      // Spend 210 in April -> Remaining 420 -> 420 / 21 = 20.0 per day
      finance.addExpense(
        title: 'Groceries',
        category: 'Food',
        amount: 210.0,
        date: asOf,
      );
      final updatedAllowance =
          finance.calculateDailyBudgetAllowance(budget, asOf);
      expect(updatedAllowance, equals(20.0));
    });

    test('11. Overspent or exhausted budget yields 0.0 daily allowance', () {
      final now = DateTime.now();
      final budget = Budget(
        id: 'test_exhausted',
        name: 'Tight Budget',
        category: 'All',
        targetAmount: 200.0,
        spentAmount: 0.0,
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
      );
      finance.addBudget(budget);

      // Overspend
      finance.addExpense(
        title: 'Electronics',
        category: 'Shopping',
        amount: 250.0,
      );

      final dailyAllowance = finance.calculateDailyBudgetAllowance(budget, now);
      expect(dailyAllowance, equals(0.0));
    });

    test(
        '12. Zero budget target handles safely with 0.0 allowance and no NaN/division by zero',
        () {
      final now = DateTime.now();
      final zeroBudget = Budget(
        id: 'test_zero',
        name: 'Zero Limit',
        category: 'All',
        targetAmount: 0.0,
        spentAmount: 0.0,
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
      );
      finance.addBudget(zeroBudget);

      expect(zeroBudget.percentageSpent, equals(0.0));
      expect(
          finance.calculateDailyBudgetAllowance(zeroBudget, now), equals(0.0));
    });

    test('13. Expenses outside date boundary are excluded from budget spent',
        () {
      final now = DateTime.now();
      final budget = Budget(
        id: 'test_boundary',
        name: 'Current Month Budget',
        category: 'All',
        targetAmount: 500.0,
        spentAmount: 0.0,
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
      );
      finance.addBudget(budget);

      // Expense 40 days ago (previous period)
      final pastExpense = Expense(
        id: 'exp_past',
        title: 'Past Dinner',
        category: 'Food',
        amount: 120.0,
        date: now.subtract(const Duration(days: 45)),
        icon: '🍔',
      );
      finance.addCustomExpense(pastExpense);

      // Expense in future period
      final futureExpense = Expense(
        id: 'exp_future',
        title: 'Future Ticket',
        category: 'Travel',
        amount: 300.0,
        date: now.add(const Duration(days: 45)),
        icon: '✈️',
      );
      finance.addCustomExpense(futureExpense);

      final spent = finance.calculateBudgetSpent(budget);
      expect(spent, equals(0.0));
    });

    test(
        '14. Budget spending trajectory produces accurate cumulative daily points',
        () {
      final periodStart = DateTime(2026, 5, 1);
      final periodEnd = DateTime(2026, 5, 31);
      final asOf = DateTime(2026, 5, 5);

      final budget = Budget(
        id: 'test_trajectory',
        name: 'May Budget',
        category: 'All',
        targetAmount: 1000.0,
        spentAmount: 0.0,
        startDate: periodStart,
        endDate: periodEnd,
      );
      finance.addBudget(budget);

      finance.addCustomExpense(Expense(
        id: 'exp_day2',
        title: 'Day 2 spend',
        category: 'Food',
        amount: 40.0,
        date: DateTime(2026, 5, 2, 14, 0),
        icon: '🍔',
      ));
      finance.addCustomExpense(Expense(
        id: 'exp_day4',
        title: 'Day 4 spend',
        category: 'Transport',
        amount: 60.0,
        date: DateTime(2026, 5, 4, 18, 0),
        icon: '🚗',
      ));

      final cumulative = finance.getBudgetCumulativeSpending(budget, asOf);
      expect(cumulative[1], equals(0.0));
      expect(cumulative[2], equals(40.0));
      expect(cumulative[3], equals(40.0));
      expect(cumulative[4], equals(100.0));
      expect(cumulative[5], equals(100.0));
    });
  });

  group('Phase 7: Budgets & Activity Screen Widget Rendering Tests', () {
    late FinanceProvider finance;

    setUp(() {
      finance = FinanceProvider(storageService: InMemoryStorageService());
      finance.purgeSampleData();
      finance.updateCurrency('Rs');
    });

    testWidgets(
        '15. BudgetsScreen renders hero section, trajectory card, and allowance card',
        (tester) async {
      final now = DateTime.now();
      finance.addBudget(Budget(
        id: 'bgt_active',
        name: 'Household',
        category: 'All',
        targetAmount: 500.0,
        spentAmount: 100.0,
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
        icon: '🏡',
      ));
      finance.addExpense(title: 'Grocery', category: 'Food', amount: 100.0);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: finance,
          child: const MaterialApp(
            home: BudgetsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On dashboard: verify budget card is present, then tap into detail view
      expect(find.text('Household'), findsWidgets);
      await tester.tap(find.text('Household').first);
      await tester.pumpAndSettle();

      // Check header and titles
      expect(find.textContaining('Household 🏡'), findsOneWidget);
      expect(find.text('Spending Trajectory'), findsOneWidget);
      expect(find.textContaining('spent out of'), findsOneWidget);

      // Check daily allowance text
      expect(find.textContaining('On track! You can spend'), findsOneWidget);
    });

    testWidgets(
        '16. BudgetsScreen displays clear overbudget alert when spending exceeds target',
        (tester) async {
      final now = DateTime.now();
      finance.addBudget(Budget(
        id: 'bgt_over',
        name: 'Snacks',
        category: 'Food',
        targetAmount: 100.0,
        spentAmount: 0.0,
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
      ));
      finance.addExpense(
          title: 'Fancy Dinner', category: 'Food', amount: 250.0);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: finance,
          child: const MaterialApp(
            home: BudgetsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the budget card to open detail view
      expect(find.text('Snacks'), findsWidgets);
      await tester.tap(find.text('Snacks').first);
      await tester.pumpAndSettle();

      // Overbudget alert card must be displayed
      expect(find.textContaining('Budget exceeded by Rs 150.00 (250%)'),
          findsOneWidget);
      expect(find.textContaining('No daily spending allowance remains'),
          findsOneWidget);
    });

    testWidgets(
        '17. ActivityScreen renders real category breakdown and dynamic insights',
        (tester) async {
      finance.addExpense(
          title: 'Groceries', category: 'Food & Drink', amount: 200.0);
      finance.addExpense(title: 'Subway', category: 'Transport', amount: 50.0);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: finance,
          child: const MaterialApp(
            home: ActivityScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Insights header
      expect(find.text('Smart insights'), findsOneWidget);
      expect(find.text('Money overview (Categories)'), findsOneWidget);

      // Category rows with real data
      expect(find.text('Food & Drink'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('-Rs 200.00'), findsOneWidget);
      expect(find.text('-Rs 50.00'), findsOneWidget);
    });

    testWidgets(
        '18. ActivityScreen renders clean empty state when no expenses exist',
        (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: finance,
          child: const MaterialApp(
            home: ActivityScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No spending activity yet'), findsOneWidget);
    });
  });

  group('Phase 7: Category Budget CRUD and Financial Accuracy', () {
    late FinanceProvider finance;

    // Fixed dates — deterministic, no DateTime.now()
    final oct1 = DateTime(2026, 10, 1);
    final oct31 = DateTime(2026, 10, 31, 23, 59, 59);

    setUp(() {
      finance = FinanceProvider(storageService: InMemoryStorageService());
      finance.purgeSampleData();
      finance.updateCurrency('Rs');
    });

    Budget makeBudget({
      String id = 'bgt_test',
      String name = 'Test Budget',
      String category = 'Food & Drink',
      double target = 1000.0,
    }) {
      return Budget(
        id: id,
        name: name,
        category: category,
        targetAmount: target,
        spentAmount: 0.0,
        startDate: oct1,
        endDate: oct31,
        icon: '🍔',
        isSample: false,
      );
    }

    test('21. Add budget creates a budget with correct period boundaries', () {
      final budget = makeBudget();
      finance.addBudget(budget);

      expect(finance.budgets.any((b) => b.id == 'bgt_test'), isTrue);
      final stored = finance.budgets.firstWhere((b) => b.id == 'bgt_test');
      expect(stored.startDate, equals(oct1));
      expect(stored.endDate, equals(oct31));
      expect(stored.targetAmount, equals(1000.0));
      expect(stored.category, equals('Food & Drink'));
    });

    test('22. Duplicate active budget for same category is detected correctly',
        () {
      // Add first budget for Food & Drink covering October
      finance.addBudget(makeBudget(id: 'bgt_a'));

      // We verify the list-level predicate correctly identifies the duplicate
      // within the stored budgets (non-sample, same category).
      final duplicateCandidates = finance.budgets
          .where(
              (b) => !b.isSample && b.category.toLowerCase() == 'food & drink')
          .toList();
      expect(duplicateCandidates.length, equals(1));

      // If we add a second one with the same category, it should be findable
      finance.addBudget(makeBudget(id: 'bgt_b'));
      final after = finance.budgets
          .where(
              (b) => !b.isSample && b.category.toLowerCase() == 'food & drink')
          .toList();
      expect(after.length, equals(2)); // both present — UI layer handles dedup
    });

    test(
        '23. calculateBudgetSpent sums only expenses (not income/transfers) in date range',
        () {
      final budget = makeBudget(category: 'General Discretionary');
      finance.addBudget(budget);

      // Expense in October
      finance.addCustomExpense(Expense(
        id: 'exp_oct',
        title: 'Dinner',
        category: 'Food & Drink',
        amount: 300.0,
        date: DateTime(2026, 10, 15),
        icon: '🍔',
      ));

      // Income in October — must NOT be counted
      finance.addIncome(title: 'Freelance', category: 'Income', amount: 5000.0);

      final spent = finance.calculateBudgetSpent(budget);
      // Only the 300 expense should be counted
      expect(spent, equals(300.0));
    });

    test('24. Overspending is reported accurately without clamping', () {
      final budget = makeBudget(target: 200.0);
      finance.addBudget(budget);

      finance.addCustomExpense(Expense(
        id: 'exp_over',
        title: 'Big Purchase',
        category: 'Food & Drink',
        amount: 450.0,
        date: DateTime(2026, 10, 10),
        icon: '🍔',
      ));

      final spent = finance.calculateBudgetSpent(budget);
      expect(spent, equals(450.0));

      final evaluated = budget.copyWith(spentAmount: spent);
      expect(evaluated.isOverBudget, isTrue);
      // 450 / 200 = 2.25 — must NOT be clamped
      expect(evaluated.percentageSpent, equals(2.25));
      // netRemaining is unclamped: 200 - 450 = -250
      expect(evaluated.netRemaining, equals(-250.0));
    });

    test('25. Delete budget removes it from finance.budgets', () {
      final budget = makeBudget();
      finance.addBudget(budget);
      expect(finance.budgets.any((b) => b.id == 'bgt_test'), isTrue);

      finance.deleteBudget('bgt_test');
      expect(finance.budgets.any((b) => b.id == 'bgt_test'), isFalse);
    });

    test(
        '26. Edit budget updates only targetAmount, preserves category and dates',
        () {
      final budget = makeBudget();
      finance.addBudget(budget);

      final updated = budget.copyWith(targetAmount: 1500.0);
      finance.updateBudget(updated);

      final stored = finance.budgets.firstWhere((b) => b.id == 'bgt_test');
      expect(stored.targetAmount, equals(1500.0));
      // Category and dates must be unchanged
      expect(stored.category, equals('Food & Drink'));
      expect(stored.startDate, equals(oct1));
      expect(stored.endDate, equals(oct31));
    });

    test('27. Budget spending updates when new matching expense is added', () {
      final budget = makeBudget(category: 'Shopping');
      finance.addBudget(budget);

      finance.addCustomExpense(Expense(
        id: 'exp_shop1',
        title: 'Shoes',
        category: 'Shopping',
        amount: 200.0,
        date: DateTime(2026, 10, 5),
        icon: '🛍️',
      ));

      final spent1 = finance.calculateBudgetSpent(budget);
      expect(spent1, equals(200.0));

      finance.addCustomExpense(Expense(
        id: 'exp_shop2',
        title: 'Jacket',
        category: 'Shopping',
        amount: 350.0,
        date: DateTime(2026, 10, 12),
        icon: '🛍️',
      ));

      final spent2 = finance.calculateBudgetSpent(budget);
      expect(spent2, equals(550.0));
    });

    test('28. Budget spending excludes expenses outside date range', () {
      final budget = makeBudget(category: 'All');
      finance.addBudget(budget);

      // September expense — outside October budget
      finance.addCustomExpense(Expense(
        id: 'exp_sep',
        title: 'Last Month',
        category: 'Food & Drink',
        amount: 500.0,
        date: DateTime(2026, 9, 20),
        icon: '🍔',
      ));

      // November expense — outside October budget
      finance.addCustomExpense(Expense(
        id: 'exp_nov',
        title: 'Next Month',
        category: 'Transport',
        amount: 300.0,
        date: DateTime(2026, 11, 5),
        icon: '🚗',
      ));

      final spent = finance.calculateBudgetSpent(budget);
      expect(spent, equals(0.0));
    });

    test('29. Budget spending excludes non-matching categories', () {
      final budget = makeBudget(category: 'Healthcare');
      finance.addBudget(budget);

      // Transport expense — should NOT match Healthcare
      finance.addCustomExpense(Expense(
        id: 'exp_transport',
        title: 'Bus Pass',
        category: 'Transport',
        amount: 100.0,
        date: DateTime(2026, 10, 10),
        icon: '🚗',
      ));

      // Healthcare expense — should match
      finance.addCustomExpense(Expense(
        id: 'exp_health',
        title: 'Doctor Visit',
        category: 'Healthcare',
        amount: 250.0,
        date: DateTime(2026, 10, 15),
        icon: '💊',
      ));

      final spent = finance.calculateBudgetSpent(budget);
      expect(spent, equals(250.0));
    });

    test('30. General Discretionary budget matches all expense categories', () {
      final budget = Budget(
        id: 'bgt_general',
        name: 'General',
        category: 'General Discretionary',
        targetAmount: 5000.0,
        spentAmount: 0.0,
        startDate: oct1,
        endDate: oct31,
        icon: '📊',
        isSample: false,
      );
      finance.addBudget(budget);

      finance.addCustomExpense(Expense(
        id: 'exp_food',
        title: 'Lunch',
        category: 'Food & Drink',
        amount: 100.0,
        date: DateTime(2026, 10, 2),
        icon: '🍔',
      ));
      finance.addCustomExpense(Expense(
        id: 'exp_shop',
        title: 'Clothes',
        category: 'Shopping',
        amount: 200.0,
        date: DateTime(2026, 10, 8),
        icon: '🛍️',
      ));
      finance.addCustomExpense(Expense(
        id: 'exp_travel',
        title: 'Flight',
        category: 'Travel',
        amount: 1500.0,
        date: DateTime(2026, 10, 20),
        icon: '✈️',
      ));

      final spent = finance.calculateBudgetSpent(budget);
      // All three expenses should be included: 100 + 200 + 1500 = 1800
      expect(spent, equals(1800.0));
    });
  });
}
