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

  group('Phase 1: Model Serialization & Deserialization Tests', () {
    test('Account toJson and fromJson roundtrip', () {
      final account = Account(
        id: 'acc_test',
        name: 'Revolut Account',
        type: AccountType.debit,
        balance: 9724.00,
        last4: '1234',
        icon: '💳',
        isLiquid: true,
      );

      final jsonMap = account.toJson();
      final restored = Account.fromJson(jsonMap);

      expect(restored.id, equals('acc_test'));
      expect(restored.name, equals('Revolut Account'));
      expect(restored.type, equals(AccountType.debit));
      expect(restored.balance, equals(9724.00));
      expect(restored.last4, equals('1234'));
      expect(restored.isLiquid, isTrue);
    });

    test('Expense toJson and fromJson roundtrip', () {
      final now = DateTime.now();
      final expense = Expense(
        id: 'exp_test',
        title: 'Travel Payment',
        category: 'Travel',
        amount: 185.00,
        date: now,
        icon: '✈️',
        accountId: 'acc_1',
        walletName: 'Family Wallet',
        note: 'Flight tickets',
        isSample: false,
      );

      final jsonMap = expense.toJson();
      final restored = Expense.fromJson(jsonMap);

      expect(restored.id, equals('exp_test'));
      expect(restored.title, equals('Travel Payment'));
      expect(restored.amount, equals(185.00));
      expect(restored.walletName, equals('Family Wallet'));
      expect(restored.note, equals('Flight tickets'));
    });

    test('Subscription toJson and fromJson roundtrip', () {
      final now = DateTime.now();
      final sub = Subscription(
        id: 'sub_test',
        name: 'Netflix',
        category: 'Entertainment',
        amount: 15.99,
        nextBillingDate: now.add(const Duration(days: 2)),
        iconLetter: 'N',
        daysRemaining: 2,
        isDueSoon: true,
        accountId: 'acc_2',
        walletName: 'Visa Debit',
      );

      final jsonMap = sub.toJson();
      final restored = Subscription.fromJson(jsonMap);

      expect(restored.name, equals('Netflix'));
      expect(restored.amount, equals(15.99));
      expect(restored.daysRemaining, equals(2));
      expect(restored.isDueSoon, isTrue);
    });
  });

  group('Phase 1: Financial Math & Balance Consistency Tests', () {
    test('Safe-to-Spend formula produces exact expected balance', () {
      final provider = FinanceProvider(storageService: MockStorageService());

      // Liquid balance: Meezan Bank ($1,400) + Visa Debit ($450) = $1,850
      expect(provider.totalLiquidBalance, equals(1850.00));

      // Subscriptions: Netflix (15.99) + Spotify (9.99) + Gym (45.00) = $70.98 in sample data
      final expectedSubs = provider.totalMonthlySubscriptions;
      final expectedSavings = provider.monthlySavingsGoal;

      // Safe-to-Spend = Liquid Cash ($1,850) - Subscriptions - Savings
      final expectedSafeToSpend = 1850.00 - expectedSubs - expectedSavings;
      expect(provider.safeToSpendBalance, closeTo(expectedSafeToSpend, 0.01));
    });

    test('Transfer between wallets modifies balances without distorting expenses', () {
      final provider = FinanceProvider(storageService: MockStorageService());
      final initialExpenses = provider.totalExpenses;

      final acc1 = provider.accounts[0]; // Meezan Bank
      final acc2 = provider.accounts[1]; // Visa Debit
      final initialAcc1Bal = acc1.balance;
      final initialAcc2Bal = acc2.balance;

      provider.transferBetweenAccounts(
        fromAccountId: acc1.id,
        toAccountId: acc2.id,
        amount: 100.00,
      );

      // Verify transfer changed balances correctly
      expect(provider.accounts[0].balance, equals(initialAcc1Bal - 100.00));
      expect(provider.accounts[1].balance, equals(initialAcc2Bal + 100.00));

      // Verify transfers do NOT increment total expenses
      expect(provider.totalExpenses, equals(initialExpenses));
    });

    test('Adding an expense debits paying account balance', () {
      final provider = FinanceProvider(storageService: MockStorageService());
      final payingAccount = provider.accounts[1]; // Visa Debit
      final initialBalance = payingAccount.balance;

      provider.addExpense(
        title: 'Dinner',
        category: 'Food',
        amount: 50.00,
        accountId: payingAccount.id,
      );

      final updatedAccount = provider.accounts.firstWhere((a) => a.id == payingAccount.id);
      expect(updatedAccount.balance, equals(initialBalance - 50.00));
      expect(provider.expenses.first.title, equals('Dinner'));
    });
  });
}
