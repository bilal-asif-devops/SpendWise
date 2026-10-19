import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/models/models.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FinanceProvider finance;

  setUp(() {
    finance = FinanceProvider(storageService: MockStorageService());
  });

  group('Batch 1: Credit Card Bill Payment Logic', () {
    test(
        '1. Credit card bill payment decreases source cash and decreases credit liability by exact payment amount',
        () {
      // Find debit account (source) and credit card account (destination)
      final debit =
          finance.accounts.firstWhere((a) => a.type == AccountType.debit);
      final credit =
          finance.accounts.firstWhere((a) => a.type == AccountType.credit);

      final initialCash = debit.balance;
      final initialLiability = credit.balance;
      const paymentAmount = 150.00;

      final success = finance.transferBetweenAccounts(
        fromAccountId: debit.id,
        toAccountId: credit.id,
        amount: paymentAmount,
      );

      expect(success, isTrue);
      expect(finance.lastErrorMessage, isNull);

      final updatedDebit = finance.accounts.firstWhere((a) => a.id == debit.id);
      final updatedCredit =
          finance.accounts.firstWhere((a) => a.id == credit.id);

      expect(updatedDebit.balance, equals(initialCash - paymentAmount));
      expect(updatedCredit.balance, equals(initialLiability - paymentAmount));
      // Debt decreased, not increased
      expect(updatedCredit.balance, lessThan(initialLiability));
    });

    test(
        '2. Credit card bill payment is rejected if payment amount exceeds outstanding liability',
        () {
      final debit =
          finance.accounts.firstWhere((a) => a.type == AccountType.debit);
      final credit =
          finance.accounts.firstWhere((a) => a.type == AccountType.credit);

      final initialLiability = credit.balance;
      final excessiveAmount = initialLiability + 50.00;

      final success = finance.transferBetweenAccounts(
        fromAccountId: debit.id,
        toAccountId: credit.id,
        amount: excessiveAmount,
      );

      expect(success, isFalse);
      expect(
          finance.lastErrorMessage, contains('exceeds outstanding liability'));

      // Invariants preserved: balances unchanged
      final updatedCredit =
          finance.accounts.firstWhere((a) => a.id == credit.id);
      expect(updatedCredit.balance, equals(initialLiability));
      expect(updatedCredit.balance, isNonNegative);
    });

    test(
        '3. Credit card bill payment is rejected if payment amount exceeds available funds in source account',
        () {
      // Create a scenario where debit balance is lower than payment
      final debit =
          finance.accounts.firstWhere((a) => a.type == AccountType.debit);
      final credit =
          finance.accounts.firstWhere((a) => a.type == AccountType.credit);

      final excessivePayment = debit.balance + 500.00;

      final success = finance.transferBetweenAccounts(
        fromAccountId: debit.id,
        toAccountId: credit.id,
        amount: excessivePayment,
      );

      expect(success, isFalse);
      expect(finance.lastErrorMessage, contains('Insufficient funds'));
    });

    test(
        '4. Credit card payment does NOT create an expense or inflate totalExpenses',
        () {
      final debit =
          finance.accounts.firstWhere((a) => a.type == AccountType.debit);
      final credit =
          finance.accounts.firstWhere((a) => a.type == AccountType.credit);

      final initialExpenseCount = finance.expenses.length;
      final initialTotalExpenses = finance.totalExpenses;

      final success = finance.transferBetweenAccounts(
        fromAccountId: debit.id,
        toAccountId: credit.id,
        amount: 50.00,
      );

      expect(success, isTrue);
      expect(finance.expenses.length, equals(initialExpenseCount));
      expect(finance.totalExpenses, equals(initialTotalExpenses));
    });
  });

  group('Batch 1: Dynamic Budget Spending Calculations', () {
    test(
        '5. Budget spent reflects dynamic sum of matching expenses in the date window',
        () {
      final budget = finance.budgets.first;
      final initialSpent = finance.calculateBudgetSpent(budget);

      // Add a matching expense within the budget date window
      finance.addExpense(
        title: 'Supermarket Groceries',
        category: 'Food',
        amount: 80.00,
      );

      final updatedSpent = finance.calculateBudgetSpent(budget);
      expect(updatedSpent, equals(initialSpent + 80.00));

      final updatedBudget =
          finance.budgets.firstWhere((b) => b.id == budget.id);
      expect(updatedBudget.spentAmount, equals(updatedSpent));
    });

    test(
        '6. Expenses outside budget start/end date range are excluded from budget spent',
        () {
      final budget = finance.budgets.first;
      final spentBefore = finance.calculateBudgetSpent(budget);

      // Even if an expense existed in a previous month, budget calculation filters it
      final testBudget = Budget(
        id: 'test_future_bgt',
        name: 'Next Year Budget',
        category: 'All',
        targetAmount: 500.00,
        spentAmount: 0.00,
        startDate: DateTime.now().add(const Duration(days: 60)),
        endDate: DateTime.now().add(const Duration(days: 90)),
        icon: '📅',
      );

      final spentInFutureBudget = finance.calculateBudgetSpent(testBudget);
      expect(spentInFutureBudget, equals(0.00));
      expect(spentBefore, greaterThan(0.00));
    });

    test('7. Transfers and credit card payments do not distort budget spent',
        () {
      final budget = finance.budgets.first;
      final spentBefore = finance.calculateBudgetSpent(budget);

      final debit =
          finance.accounts.firstWhere((a) => a.type == AccountType.debit);
      final credit =
          finance.accounts.firstWhere((a) => a.type == AccountType.credit);

      finance.transferBetweenAccounts(
        fromAccountId: debit.id,
        toAccountId: credit.id,
        amount: 100.00,
      );

      final spentAfter = finance.calculateBudgetSpent(budget);
      expect(spentAfter, equals(spentBefore));
    });
  });

  group('Batch 1: Transfer & Account Invariants', () {
    test(
        '8. transferBetweenAccounts rejects zero or negative amounts with error message',
        () {
      final debit = finance.accounts[0];
      final cash = finance.accounts[1];

      final successZero = finance.transferBetweenAccounts(
        fromAccountId: debit.id,
        toAccountId: cash.id,
        amount: 0.0,
      );
      expect(successZero, isFalse);
      expect(finance.lastErrorMessage, contains('greater than zero'));

      final successNegative = finance.transferBetweenAccounts(
        fromAccountId: debit.id,
        toAccountId: cash.id,
        amount: -50.0,
      );
      expect(successNegative, isFalse);
      expect(finance.lastErrorMessage, contains('greater than zero'));
    });

    test(
        '9. transferBetweenAccounts rejects transfer when source account has insufficient funds',
        () {
      final debit = finance.accounts[0];
      final cash = finance.accounts[1];

      final excessiveAmount = debit.balance + 1000.0;
      final success = finance.transferBetweenAccounts(
        fromAccountId: debit.id,
        toAccountId: cash.id,
        amount: excessiveAmount,
      );

      expect(success, isFalse);
      expect(finance.lastErrorMessage, contains('Insufficient funds'));
    });

    test(
        '10. transferBetweenAccounts rejects same-account transfer (fromAccountId == toAccountId)',
        () {
      final debit = finance.accounts[0];

      final success = finance.transferBetweenAccounts(
        fromAccountId: debit.id,
        toAccountId: debit.id,
        amount: 50.0,
      );

      expect(success, isFalse);
      expect(finance.lastErrorMessage, contains('must be different'));
    });
  });
}
