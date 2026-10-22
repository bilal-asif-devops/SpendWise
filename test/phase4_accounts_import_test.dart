import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spendwise/models/models.dart';
import 'package:spendwise/services/finance_provider.dart';
import 'package:spendwise/services/statement_importer.dart';
import 'package:spendwise/screens/create_account_sheet.dart';
import 'package:spendwise/screens/import_statement_screen.dart';
import 'package:spendwise/screens/wallets_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4: Manual Account Creation & Invariants', () {
    late FinanceProvider finance;

    setUp(() {
      finance = FinanceProvider(seedSampleData: false);
      finance.startFreshGuest();
    });

    test('1. Explicit manual account creation for cash, debit, and credit card',
        () {
      expect(finance.accounts, isEmpty);

      // Create Cash Wallet
      final cashSuccess = finance.addAccount(
        Account(
          id: 'acc_cash_1',
          name: 'Physical Cash',
          type: AccountType.cash,
          balance: 150.0,
          currency: 'USD',
          icon: '💵',
        ),
      );
      expect(cashSuccess, isTrue);
      expect(finance.accounts.length, 1);
      expect(finance.accounts.first.balance, 150.0);
      expect(finance.accounts.first.type, AccountType.cash);

      // Create Debit / Bank Account
      final debitSuccess = finance.addAccount(
        Account(
          id: 'acc_debit_1',
          name: 'Meezan Current',
          type: AccountType.debit,
          balance: 50000.0,
          currency: 'PKR',
          icon: '🏛️',
        ),
      );
      expect(debitSuccess, isTrue);
      expect(finance.accounts.length, 2);

      // Create Credit Card with Liability and Credit Limit
      final creditSuccess = finance.addAccount(
        Account(
          id: 'acc_credit_1',
          name: 'Chase Sapphire',
          type: AccountType.credit,
          balance: 450.0, // liability
          creditLimit: 5000.0,
          currency: 'USD',
          icon: '💳',
          isLiquid: false,
          isExcludedFromSafeToSpend: true,
        ),
      );
      expect(creditSuccess, isTrue);
      expect(finance.accounts.length, 3);
      expect(finance.creditAccounts.length, 1);
      expect(finance.creditAccounts.first.creditLimit, 5000.0);
      expect(finance.creditAccounts.first.balance, 450.0);
    });

    test('2. Opening balance does NOT alter totalExpenses or totalIncome', () {
      expect(finance.totalExpenses, 0.0);
      expect(finance.totalIncome, 0.0);

      finance.addAccount(
        Account(
          id: 'acc_test_ob',
          name: 'Big Savings',
          type: AccountType.debit,
          balance: 75000.0,
          currency: 'USD',
          icon: '🏦',
        ),
      );

      // Opening balance must never inflate income or expenses
      expect(finance.totalExpenses, 0.0);
      expect(finance.totalIncome, 0.0);
      expect(finance.expenses, isEmpty);
      expect(finance.accounts.first.balance, 75000.0);
    });

    test(
        '3. Account validation rejects empty name, NaN, Infinity, and negative asset balance',
        () {
      // Empty name
      final r1 = finance.addAccount(
        Account(
          id: 'inv_1',
          name: '   ',
          type: AccountType.debit,
          balance: 100.0,
          icon: '💳',
        ),
      );
      expect(r1, isFalse);
      expect(finance.lastErrorMessage, contains('cannot be empty'));

      // NaN balance
      final r2 = finance.addAccount(
        Account(
          id: 'inv_2',
          name: 'Bad NaN',
          type: AccountType.debit,
          balance: double.nan,
          icon: '💳',
        ),
      );
      expect(r2, isFalse);
      expect(finance.lastErrorMessage, contains('finite number'));

      // Positive Infinity balance
      final r3 = finance.addAccount(
        Account(
          id: 'inv_3',
          name: 'Bad Inf',
          type: AccountType.debit,
          balance: double.infinity,
          icon: '💳',
        ),
      );
      expect(r3, isFalse);

      // Negative asset balance
      final r4 = finance.addAccount(
        Account(
          id: 'inv_4',
          name: 'Negative Cash',
          type: AccountType.cash,
          balance: -50.0,
          icon: '💵',
        ),
      );
      expect(r4, isFalse);
      expect(finance.lastErrorMessage, contains('cannot be negative'));

      // Credit card with negative credit limit
      final r5 = finance.addAccount(
        Account(
          id: 'inv_5',
          name: 'Negative Limit Card',
          type: AccountType.credit,
          balance: 0.0,
          creditLimit: -1000.0,
          icon: '💳',
        ),
      );
      expect(r5, isFalse);
      expect(finance.lastErrorMessage, contains('cannot be negative'));

      // All invalid accounts rejected:
      expect(finance.accounts, isEmpty);
    });

    test('4. deleteAccount cleanly removes account without corrupting state',
        () {
      finance.addAccount(
        Account(
          id: 'acc_to_del',
          name: 'Temporary Account',
          type: AccountType.cash,
          balance: 200.0,
          icon: '💵',
        ),
      );
      expect(finance.accounts.length, 1);

      final deleted = finance.deleteAccount('acc_to_del');
      expect(deleted, isTrue);
      expect(finance.accounts, isEmpty);

      // Non-existent deletion returns false
      final nonExistent = finance.deleteAccount('unknown_id');
      expect(nonExistent, isFalse);
    });
  });

  group('Phase 4: Statement Parser & Delimiter Detection', () {
    test('5. Detects comma, semicolon, and tab delimiters accurately', () {
      expect(
          StatementImporter.detectDelimiter(
              'Date,Title,Amount\n2026-10-10,Item,10.0'),
          ',');
      expect(
          StatementImporter.detectDelimiter(
              'Date;Title;Amount\n2026-10-10;Item;10.0'),
          ';');
      expect(
          StatementImporter.detectDelimiter(
              'Date\tTitle\tAmount\n2026-10-10\tItem\t10.0'),
          '\t');
    });

    test('6. Parses Meezan Bank sample CSV with debit/credit separate columns',
        () {
      final result = StatementImporter.parseCsv(
        csvContent: SampleStatements.meezanBankCsv,
        accountId: 'acc_meezan',
      );

      expect(result.headers, contains('Debit'));
      expect(result.headers, contains('Credit'));
      expect(result.records.length, 6);
      expect(result.validCount, 6);
      expect(result.invalidCount, 0);

      // Row 1 is Salary (Credit -> Income)
      final row1 = result.records.first;
      expect(row1.type, TransactionType.income);
      expect(row1.amount, 250000.00);
      expect(row1.description, contains('Salary Transfer'));

      // Row 2 is Grocery (Debit -> Expense)
      final row2 = result.records[1];
      expect(row2.type, TransactionType.expense);
      expect(row2.amount, 14500.00);
      expect(row2.category, 'Food & Drink');
    });

    test('7. Parses Revolut sample CSV with signed amount and GBP currency',
        () {
      final result = StatementImporter.parseCsv(
        csvContent: SampleStatements.revolutGbpCsv,
        accountId: 'acc_revolut',
      );

      expect(result.records.length, 5);
      expect(result.validCount, 5);

      // Negative amounts are Expenses
      final row1 = result.records.first;
      expect(row1.amount, 4.25);
      expect(row1.type, TransactionType.expense);
      expect(row1.description, contains('Pret A Manger'));

      // Positive consulting fee is Income
      final row3 = result.records[2];
      expect(row3.amount, 1200.00);
      expect(row3.type, TransactionType.income);
      expect(row3.description, contains('Freelance UI Consulting'));
    });

    test(
        '8. Parses Chase sample CSV with US MM/dd/yyyy dates and negative amounts',
        () {
      final result = StatementImporter.parseCsv(
        csvContent: SampleStatements.chaseUsdCsv,
        accountId: 'acc_chase',
      );

      expect(result.records.length, 5);
      expect(result.validCount, 5);

      final row1 = result.records.first;
      expect(row1.amount, 84.50);
      expect(row1.type, TransactionType.expense);
      expect(row1.date?.month, 10);
      expect(row1.date?.day, 10);
      expect(row1.category, 'Groceries');
    });

    test('9. Robust date parsing handles diverse international formats', () {
      const csv = '''Date,Description,Amount
2026-10-01,ISO Format,10.00
15/10/2026,UK Format,20.00
10/15/2026,US Format,30.00
15.10.2026,Euro Dot Format,40.00
1-Oct-2026,Month Abbrev Format,50.00''';

      final result = StatementImporter.parseCsv(csvContent: csv);
      expect(result.validCount, 5);
      for (final rec in result.records) {
        expect(rec.isValid, isTrue);
        expect(rec.date, isNotNull);
        expect(rec.date?.year, 2026);
        expect(rec.date?.month, 10);
      }
    });

    test('10. Robust number parsing handles currency symbols and parentheses',
        () {
      const csv = '''Date,Description,Amount
2026-10-01,Dollar Symbol,\$125.50
2026-10-02,Parentheses Negative,(45.00)
2026-10-03,Rupees Prefix,"Rs. 1,500.00"
2026-10-04,Euro Symbol,€89.90''';

      final result = StatementImporter.parseCsv(csvContent: csv);
      expect(result.validCount, 4);
      expect(result.records[0].amount, 125.50);
      expect(result.records[1].amount, 45.00);
      expect(result.records[1].type, TransactionType.expense);
      expect(result.records[2].amount, 1500.00);
      expect(result.records[3].amount, 89.90);
    });
  });

  group('Phase 4: Deterministic Deduplication & Balance Mutation', () {
    late FinanceProvider finance;

    setUp(() {
      finance = FinanceProvider(seedSampleData: false);
      finance.startFreshGuest();
      finance.addAccount(
        Account(
          id: 'acc_bank_test',
          name: 'Checking Account',
          type: AccountType.debit,
          balance: 1000.00,
          currency: 'USD',
          icon: '🏛️',
        ),
      );
    });

    test(
        '11. importStatementTransactions mutates balance and updates expenses accurately',
        () {
      final parsed = StatementImporter.parseCsv(
        csvContent: SampleStatements.chaseUsdCsv,
        accountId: 'acc_bank_test',
      );

      final summary = finance.importStatementTransactions(
        accountId: 'acc_bank_test',
        transactions: parsed.records,
      );

      expect(summary.importedCount, 5);
      expect(summary.duplicateCount, 0);
      expect(summary.invalidCount, 0);
      expect(finance.expenses.length, 5);

      // Calculations:
      // Starting balance = 1000.00
      // Expenses: 84.50 + 24.15 + 15.99 + 68.20 = 192.84
      // Income: 3200.00
      // Expected balance = 1000 - 192.84 + 3200 = 4007.16
      final updatedAcc =
          finance.accounts.firstWhere((a) => a.id == 'acc_bank_test');
      expect(updatedAcc.balance, closeTo(4007.16, 0.01));
    });

    test(
        '12. Deterministic deduplication ignores previously imported transactions on re-import',
        () {
      final parsed1 = StatementImporter.parseCsv(
        csvContent: SampleStatements.revolutGbpCsv,
        accountId: 'acc_bank_test',
      );

      // First Import:
      final summary1 = finance.importStatementTransactions(
        accountId: 'acc_bank_test',
        transactions: parsed1.records,
      );
      expect(summary1.importedCount, 5);
      expect(summary1.duplicateCount, 0);
      expect(finance.expenses.length, 5);

      // Re-Import the exact same statement:
      final parsed2 = StatementImporter.parseCsv(
        csvContent: SampleStatements.revolutGbpCsv,
        accountId: 'acc_bank_test',
        existingTransactions: finance.expenses,
      );
      expect(parsed2.duplicateCount, 5);
      expect(parsed2.validCount, 0);

      final summary2 = finance.importStatementTransactions(
        accountId: 'acc_bank_test',
        transactions: parsed2.records,
      );

      // Exactly 0 new transactions created, 5 duplicates skipped
      expect(summary2.importedCount, 0);
      expect(summary2.duplicateCount, 5);
      expect(finance.expenses.length, 5);
    });

    test('13. Credit card statement import mutates liability balance correctly',
        () {
      finance.addAccount(
        Account(
          id: 'acc_cc_test',
          name: 'Credit Card',
          type: AccountType.credit,
          balance: 100.00, // starting liability
          creditLimit: 3000.00,
          currency: 'USD',
          icon: '💳',
        ),
      );

      const ccCsv = '''Date,Description,Amount
2026-10-10,Restaurant Dinner,-50.00
2026-10-12,Payment Received,30.00''';

      final parsed = StatementImporter.parseCsv(
        csvContent: ccCsv,
        accountId: 'acc_cc_test',
      );

      final summary = finance.importStatementTransactions(
        accountId: 'acc_cc_test',
        transactions: parsed.records,
      );

      expect(summary.importedCount, 2);

      // For Credit Card:
      // Expense increases liability: +50
      // Payment/Income decreases liability: -30
      // Starting liability = 100 -> Ending liability = 100 + 50 - 30 = 120
      final updatedCard =
          finance.accounts.firstWhere((a) => a.id == 'acc_cc_test');
      expect(updatedCard.balance, closeTo(120.00, 0.01));
    });
  });

  group('Phase 4: Widget Integration & Screen Flows', () {
    Widget createWidgetUnderTest(Widget child, FinanceProvider finance) {
      return ChangeNotifierProvider<FinanceProvider>.value(
        value: finance,
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets(
        '14. CreateAccountSheet validates, creates Cash and Bank accounts',
        (tester) async {
      final finance = FinanceProvider(seedSampleData: false);
      finance.startFreshGuest();

      await tester.pumpWidget(
        createWidgetUnderTest(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => CreateAccountSheet.show(ctx),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
          finance,
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify sheet title and form controls
      expect(find.text('Create Account'), findsWidgets);
      expect(
          find.byKey(const Key('create_account_name_field')), findsOneWidget);
      expect(find.byKey(const Key('create_account_balance_field')),
          findsOneWidget);
      expect(find.byKey(const Key('create_account_submit_button')),
          findsOneWidget);

      // Attempt to submit empty form -> triggers validator
      await tester.tap(find.byKey(const Key('create_account_submit_button')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter an account name'), findsOneWidget);

      // Enter valid account name and balance
      await tester.enterText(
        find.byKey(const Key('create_account_name_field')),
        'Standard Chartered',
      );
      await tester.enterText(
        find.byKey(const Key('create_account_balance_field')),
        '2500.00',
      );
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.byKey(const Key('create_account_submit_button')));
      await tester.pumpAndSettle();

      // Account created in provider
      expect(finance.accounts.length, 1);
      expect(finance.accounts.first.name, 'Standard Chartered');
      expect(finance.accounts.first.balance, 2500.00);
    });

    testWidgets(
        '15. ImportStatementScreen pastes CSV, previews rows, and imports transactions',
        (tester) async {
      final finance = FinanceProvider(seedSampleData: false);
      finance.startFreshGuest();
      finance.addAccount(
        Account(
          id: 'acc_dest_1',
          name: 'Primary Debit',
          type: AccountType.debit,
          balance: 500.00,
          currency: 'USD',
          icon: '🏛️',
        ),
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          const ImportStatementScreen(preselectedAccountId: 'acc_dest_1'),
          finance,
        ),
      );
      await tester.pumpAndSettle();

      // Verify screen elements
      expect(find.text('Import Statement'), findsOneWidget);
      expect(find.byKey(const Key('import_pick_file_button')), findsOneWidget);
      expect(find.byKey(const Key('sample_meezan_chip')), findsOneWidget);

      // Tap sample statement button
      await tester.tap(find.byKey(const Key('sample_meezan_chip')));
      await tester.pumpAndSettle();

      // Verify preview table and confirm button
      expect(find.text('STATEMENT PREVIEW'), findsOneWidget);
      expect(find.text('6 Ready'), findsOneWidget);
      expect(find.byKey(const Key('import_confirm_button')), findsOneWidget);

      // Confirm Import
      await tester
          .ensureVisible(find.byKey(const Key('import_confirm_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('import_confirm_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Completion dialog appears
      expect(find.text('Import Complete'), findsOneWidget);
      expect(
          find.byKey(const Key('import_success_done_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('import_success_done_button')));
      await tester.pumpAndSettle();

      // Verify transactions recorded in provider
      expect(finance.expenses.length, 6);
    });

    testWidgets(
        '16. WalletsScreen displays Import Statement button and navigates to flow',
        (tester) async {
      final finance = FinanceProvider(seedSampleData: false);
      finance.startFreshGuest();

      await tester.pumpWidget(
        createWidgetUnderTest(
          const WalletsScreen(),
          finance,
        ),
      );
      await tester.pumpAndSettle();

      // Verify action buttons in AppBar
      expect(find.byKey(const Key('wallets_import_statement_button')),
          findsOneWidget);
      expect(
          find.byKey(const Key('wallets_add_account_button')), findsOneWidget);
    });
  });
}
