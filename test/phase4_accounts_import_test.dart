import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spendwise/models/models.dart';
import 'package:spendwise/services/bank_connector.dart';
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
      expect(row2.category, 'Groceries');
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

  group(
      'Phase 4: Bank Import Improvements (Pakistani Market & Advanced Features)',
      () {
    late FinanceProvider finance;

    setUp(() {
      finance = FinanceProvider(seedSampleData: false);
      finance.startFreshGuest();
      StatementImporter.clearUserRules();
    });

    tearDown(() {
      StatementImporter.clearUserRules();
    });

    test(
        '17. HBL Preset parses Pakistani statement headers and categorizes accurately',
        () {
      final result = StatementImporter.parseCsv(
        csvContent: SampleStatements.hblCsv,
        accountId: 'acc_hbl_test',
      );

      expect(result.detectedBankPreset, 'Habib Bank Limited (HBL)');
      expect(result.records.length, 6);
      expect(result.validCount, 6);

      // Verify transactions
      final salary =
          result.records.firstWhere((r) => r.description.contains('IBFT'));
      expect(salary.type, TransactionType.income);
      expect(salary.amount, 220000.00);

      final carrefour =
          result.records.firstWhere((r) => r.description.contains('Carrefour'));
      expect(carrefour.type, TransactionType.expense);
      expect(carrefour.category, 'Groceries');

      final careem =
          result.records.firstWhere((r) => r.description.contains('Careem'));
      expect(careem.category, 'Transport');

      final ssgc =
          result.records.firstWhere((r) => r.description.contains('SSGC'));
      expect(ssgc.category, 'Bills & Fees');

      final foodpanda =
          result.records.firstWhere((r) => r.description.contains('Foodpanda'));
      expect(foodpanda.category, 'Food & Drink');

      final khaadi =
          result.records.firstWhere((r) => r.description.contains('Khaadi'));
      expect(khaadi.category, 'Shopping');
    });

    test('18. Bank Alfalah Preset handles DD-MMM-YYYY case-insensitive dates',
        () {
      final result = StatementImporter.parseCsv(
        csvContent: SampleStatements.bankAlfalahCsv,
        accountId: 'acc_alfalah_test',
      );

      expect(result.detectedBankPreset, 'Bank Alfalah');
      expect(result.records.length, 6);
      expect(result.validCount, 6);

      // Verify date parsed properly from 15-OCT-2026
      expect(result.records.first.date, DateTime(2026, 10, 15));
      expect(result.records.first.type, TransactionType.income);

      final naheed =
          result.records.firstWhere((r) => r.description.contains('Naheed'));
      expect(naheed.category, 'Groceries');

      final pso =
          result.records.firstWhere((r) => r.description.contains('PSO'));
      expect(pso.category, 'Transport');

      final iesco =
          result.records.firstWhere((r) => r.description.contains('IESCO'));
      expect(iesco.category, 'Bills & Fees');
    });

    test('19. UBL & MCB Presets parse respective column layouts', () {
      final ublResult = StatementImporter.parseCsv(
        csvContent: SampleStatements.ublCsv,
        accountId: 'acc_ubl_test',
      );
      expect(ublResult.detectedBankPreset, 'United Bank Limited (UBL)');
      expect(ublResult.validCount, 6);
      expect(
          ublResult.records
              .firstWhere((r) => r.description.contains('Bykea'))
              .category,
          'Transport');
      expect(
          ublResult.records
              .firstWhere((r) => r.description.contains('SNGPL'))
              .category,
          'Bills & Fees');

      final mcbResult = StatementImporter.parseCsv(
        csvContent: SampleStatements.mcbCsv,
        accountId: 'acc_mcb_test',
      );
      expect(mcbResult.detectedBankPreset, 'Muslim Commercial Bank (MCB)');
      expect(mcbResult.validCount, 6);
      expect(
          mcbResult.records
              .firstWhere((r) => r.description.contains('PTCL'))
              .category,
          'Bills & Fees');
      expect(
          mcbResult.records
              .firstWhere((r) => r.description.contains('McDonalds'))
              .category,
          'Food & Drink');
    });

    test(
        '20. Standard Chartered PK Preset parses Withdrawals/Deposits correctly',
        () {
      final scbResult = StatementImporter.parseCsv(
        csvContent: SampleStatements.standardCharteredPkCsv,
        accountId: 'acc_scb_test',
      );
      expect(scbResult.detectedBankPreset, 'Standard Chartered Pakistan');
      expect(scbResult.validCount, 6);
      expect(scbResult.records.first.type, TransactionType.income);
      expect(scbResult.records.first.amount, 300000.00);
      expect(
          scbResult.records
              .firstWhere((r) => r.description.contains('LESCO'))
              .category,
          'Bills & Fees');
    });

    test('21. Lightweight OFX / QFX parses SGML bank statement', () {
      final ofxResult = StatementImporter.parseCsv(
        csvContent: SampleStatements.sampleOfx,
        accountId: 'acc_ofx_test',
      );

      expect(ofxResult.records.length, 3);
      expect(ofxResult.validCount, 3);

      final creditTx =
          ofxResult.records.firstWhere((r) => r.type == TransactionType.income);
      expect(creditTx.amount, 185000.00);
      expect(creditTx.description, contains('Salary'));

      final debitTx1 = ofxResult.records
          .firstWhere((r) => r.description.contains('Carrefour'));
      expect(debitTx1.type, TransactionType.expense);
      expect(debitTx1.amount, 8500.00);
      expect(debitTx1.category, 'Groceries');

      final debitTx2 = ofxResult.records
          .firstWhere((r) => r.description.contains('Foodpanda'));
      expect(debitTx2.type, TransactionType.expense);
      expect(debitTx2.amount, 1850.00);
      expect(debitTx2.category, 'Food & Drink');
    });

    test('22. Ambiguous date detection and manual resolution override', () {
      const ambiguousCsv = '''Date,Description,Amount
05/06/2026,Coffee Shop,-450.00
07/08/2026,Pharmacy,-1200.00''';

      // Default parse flags as ambiguous
      final parsedDefault = StatementImporter.parseCsv(
        csvContent: ambiguousCsv,
        accountId: 'acc_ambig_test',
      );
      expect(parsedDefault.isDateAmbiguous, isTrue);

      // Force DD/MM/YYYY (June 5, 2026)
      final parsedDmy = StatementImporter.parseCsv(
        csvContent: ambiguousCsv,
        accountId: 'acc_ambig_test',
        forcedDateFormat: 'DD/MM/YYYY',
      );
      expect(parsedDmy.records.first.date, DateTime(2026, 6, 5));

      // Force MM/DD/YYYY (May 6, 2026)
      final parsedMdy = StatementImporter.parseCsv(
        csvContent: ambiguousCsv,
        accountId: 'acc_ambig_test',
        forcedDateFormat: 'MM/DD/YYYY',
      );
      expect(parsedMdy.records.first.date, DateTime(2026, 5, 6));
    });

    test('23. Layered categorization: user rules override Pakistani dictionary',
        () {
      // Prior to user rule: 'Daraz' categorizes as Shopping
      final initial = StatementImporter.inferCategory('Daraz Online Store');
      expect(initial.category, 'Shopping');
      expect(initial.isConfident, isTrue);

      // Add user custom rule
      StatementImporter.addUserRule('daraz', 'Entertainment');

      // Now Daraz categorizes as Entertainment
      final overridden = StatementImporter.inferCategory('Daraz Online Store');
      expect(overridden.category, 'Entertainment');
      expect(overridden.matchedRule, contains('User Rule'));

      // Unknown merchant is flagged as needsReview
      final unknown =
          StatementImporter.inferCategory('XYZ Corp Random Wire 9912');
      expect(unknown.isConfident, isFalse);
    });

    test(
        '24. Deduplication preserves legitimate identical transactions within same statement',
        () {
      finance.addAccount(
        Account(
          id: 'acc_dedup_test',
          name: 'Checking Account',
          type: AccountType.debit,
          balance: 10000.0,
          currency: 'PKR',
          icon: '🏦',
        ),
      );

      // Statement contains two identical transactions on the exact same date
      const repeatedCsv = '''Date,Description,Amount
2026-10-15,Metro Bus Ticket,-50.00
2026-10-15,Metro Bus Ticket,-50.00''';

      final parsed = StatementImporter.parseCsv(
        csvContent: repeatedCsv,
        accountId: 'acc_dedup_test',
      );

      // Both should be valid and distinct occurrence indices
      expect(parsed.records.length, 2);
      expect(parsed.validCount, 2);
      expect(parsed.records[0].importHash,
          isNot(equals(parsed.records[1].importHash)));
      expect(parsed.records[0].occurrenceIndex, 0);
      expect(parsed.records[1].occurrenceIndex, 1);

      // Import them into provider
      final summary = finance.importStatementTransactions(
        accountId: 'acc_dedup_test',
        transactions: parsed.records,
      );
      expect(summary.importedCount, 2);
      expect(summary.duplicateCount, 0);

      // Re-importing the same statement now identifies BOTH as duplicates
      final reParsed = StatementImporter.parseCsv(
        csvContent: repeatedCsv,
        accountId: 'acc_dedup_test',
        existingTransactions: finance.expenses,
      );
      expect(reParsed.duplicateCount, 2);
      expect(reParsed.validCount, 0);

      final reSummary = finance.importStatementTransactions(
        accountId: 'acc_dedup_test',
        transactions: reParsed.records,
      );
      expect(reSummary.importedCount, 0);
      expect(reSummary.duplicateCount, 2);
    });

    test(
        '25. Non-recoverable and malformed rows handled gracefully without crash',
        () {
      const corruptCsv = '''Date,Description,Debit,Credit
INVALID_DATE,Broken Row,100.00,
2026-10-15,Non Numeric Amount,NOT_A_NUMBER,
2026-10-16,Valid Transaction,500.00,''';

      final result = StatementImporter.parseCsv(
        csvContent: corruptCsv,
        accountId: 'acc_corrupt_test',
      );

      expect(result.records.length, 3);
      expect(result.validCount, 1);
      expect(result.invalidCount, 2);
      expect(result.records[0].isValid, isFalse);
      expect(
          result.records[0].errorMessage, contains('Unrecognized date format'));
      expect(result.records[1].isValid, isFalse);
      expect(result.records[1].errorMessage,
          contains('Invalid or non-positive amount'));
      expect(result.records[2].isValid, isTrue);
    });

    test(
        '26. BankConnector abstraction differentiates local file import and future SBP Open Banking',
        () {
      final fileConnector = FileStatementConnector();
      expect(fileConnector.type, BankConnectorType.fileImport);
      expect(fileConnector.isAvailableInPakistan, isTrue);
      expect(fileConnector.requiresNetwork, isFalse);

      final parsed = fileConnector.parse(
        content: SampleStatements.meezanBankCsv,
        accountId: 'acc_conn_test',
      );
      expect(parsed.validCount, 6);

      final sbpConnector = SbpOpenBankingConnector();
      expect(sbpConnector.type, BankConnectorType.openBankingApi);
      expect(sbpConnector.isAvailableInPakistan, isFalse);
      expect(sbpConnector.requiresNetwork, isTrue);
    });

    testWidgets(
        '27. ImportStatementScreen displays presets, date ambiguity banner, and privacy policy modal',
        (tester) async {
      final testFinance = FinanceProvider(seedSampleData: false);
      testFinance.startFreshGuest();
      testFinance.addAccount(
        Account(
          id: 'acc_widget_test',
          name: 'Meezan Current',
          type: AccountType.debit,
          balance: 50000.0,
          currency: 'PKR',
          icon: '🏛️',
        ),
      );

      Widget createTestWidget(Widget child) {
        return ChangeNotifierProvider<FinanceProvider>.value(
          value: testFinance,
          child: MaterialApp(home: child),
        );
      }

      await tester.pumpWidget(createTestWidget(const ImportStatementScreen(
          preselectedAccountId: 'acc_widget_test')));
      await tester.pumpAndSettle();

      // Verify bank preset chips exist
      expect(find.byKey(const Key('sample_meezan_chip')), findsOneWidget);
      expect(find.byKey(const Key('sample_hbl_chip')), findsOneWidget);
      expect(find.byKey(const Key('sample_alfalah_chip')), findsOneWidget);
      expect(find.byKey(const Key('sample_ubl_chip')), findsOneWidget);
      expect(find.byKey(const Key('sample_mcb_chip')), findsOneWidget);
      expect(find.byKey(const Key('sample_scb_chip')), findsOneWidget);

      // Tap HBL chip
      await tester.tap(find.byKey(const Key('sample_hbl_chip')));
      await tester.pumpAndSettle();

      // Check format tag
      expect(find.text('Identified Format: Habib Bank Limited (HBL)'),
          findsOneWidget);
      expect(find.text('6 Ready'), findsOneWidget);

      // Open Privacy Policy Modal
      expect(find.byTooltip('Privacy & Security Policy'), findsOneWidget);
      await tester.tap(find.byTooltip('Privacy & Security Policy'));
      await tester.pumpAndSettle();

      // Verify privacy boundary points
      expect(find.text('Privacy & Security Boundaries'), findsOneWidget);
      expect(find.text('100% On-Device Parsing'), findsOneWidget);
      expect(
          find.text('No Credentials or PINs Ever Requested'), findsOneWidget);
      expect(find.text('Local Vault Storage Transparency'), findsOneWidget);

      // Dismiss modal
      await tester.ensureVisible(find.text('I Understand'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I Understand'));
      await tester.pumpAndSettle();
    });

    test(
        '28. Uncategorized transactions import successfully without blocking or requiring review',
        () {
      final finance = FinanceProvider(seedSampleData: false);
      finance.startFreshGuest();
      finance.addAccount(
        Account(
          id: 'acc_simple_1',
          name: 'Checking Account',
          type: AccountType.debit,
          balance: 10000.0,
          currency: 'PKR',
          icon: '🏛️',
        ),
      );

      // Statement with obscure descriptions that have no merchant rules
      const obscureCsv = '''Date,Description,Amount
2026-10-01,UNKNOWN VENDOR 9821,-450.00
2026-10-02,MISC POS TRF 741,-1200.00
2026-10-03,DIRECT DEPOSIT 550,5000.00''';

      final parsed = StatementImporter.parseCsv(
        csvContent: obscureCsv,
        accountId: 'acc_simple_1',
      );

      expect(parsed.validCount, 3);
      expect(parsed.records.every((r) => !r.needsReview), isTrue);
      expect(parsed.records[0].category, 'Uncategorized');
      expect(parsed.records[1].category, 'Uncategorized');

      final summary = finance.importStatementTransactions(
        accountId: 'acc_simple_1',
        transactions: parsed.records,
      );

      expect(summary.importedCount, 3);
      expect(summary.duplicateCount, 0);
      expect(finance.expenses.length, 3);
      expect(
          finance.expenses.where((e) => e.category == 'Uncategorized').length,
          3);
      expect(
          finance.expenses
              .where((e) => e.type == TransactionType.income)
              .length,
          1);
      expect(
          finance.expenses
              .where((e) => e.type == TransactionType.expense)
              .length,
          2);
    });

    test(
        '29. Statement running balance validation succeeds when math is consistent and reports discrepancy when amounts do not match',
        () {
      // Consistent statement: Row 1 bal=8,000, Row 2 (+5,000 credit) bal=13,000. Math: 8000 + 5000 == 13000.
      const consistentCsv = '''Date,Description,Debit,Credit,Balance
2026-10-01,Groceries,2000.00,,8000.00
2026-10-02,Salary,,5000.00,13000.00''';

      final validParse = StatementImporter.parseCsv(
        csvContent: consistentCsv,
        accountId: 'acc_bal_1',
      );

      expect(validParse.balanceValidation.status,
          BalanceValidationStatus.verified);
      expect(validParse.balanceValidation.startingBalance, 8000.00);
      expect(validParse.balanceValidation.endingBalance, 13000.00);

      // Discrepant statement: Row 1 bal=8000. Row 2 (+5000 credit) -> claims 12,000 instead of 13,000 (discrepancy)
      const discrepantCsv = '''Date,Description,Debit,Credit,Balance
2026-10-01,Groceries,2000.00,,8000.00
2026-10-02,Salary,,5000.00,12000.00''';

      final invalidParse = StatementImporter.parseCsv(
        csvContent: discrepantCsv,
        accountId: 'acc_bal_2',
      );

      expect(invalidParse.balanceValidation.status,
          BalanceValidationStatus.discrepancy);
      expect(invalidParse.balanceValidation.message, contains('mismatch'));
    });

    test(
        '30. Internal transfer between user accounts adjusts both balances without distorting totalExpenses or totalIncome',
        () {
      final finance = FinanceProvider(seedSampleData: false);
      finance.startFreshGuest();
      finance.addAccount(
        Account(
          id: 'acc_source',
          name: 'Meezan Current',
          type: AccountType.debit,
          balance: 20000.0,
          currency: 'PKR',
          icon: '🏛️',
        ),
      );
      finance.addAccount(
        Account(
          id: 'acc_dest',
          name: 'Nayapay Wallet',
          type: AccountType.debit,
          balance: 5000.0,
          currency: 'PKR',
          icon: '📱',
        ),
      );

      final initialExpenses = finance.totalExpenses;
      final initialIncome = finance.totalIncome;

      // Transfer description referencing user's other account: "TRF TO Nayapay Wallet"
      const transferCsv = '''Date,Description,Debit,Credit
2026-10-10,TRF TO Nayapay Wallet,3000.00,''';

      final parsed = StatementImporter.parseCsv(
        csvContent: transferCsv,
        accountId: 'acc_source',
        userAccounts: finance.accounts,
      );

      expect(parsed.records.first.isPotentialTransfer, isTrue);
      expect(parsed.records.first.type, TransactionType.transfer);
      expect(parsed.records.first.transferTargetAccountId, 'acc_dest');

      final summary = finance.importStatementTransactions(
        accountId: 'acc_source',
        transactions: parsed.records,
      );

      expect(summary.importedCount, 1);
      expect(summary.transferCount, 1);

      // Check updated balances
      final source = finance.accounts.firstWhere((a) => a.id == 'acc_source');
      final dest = finance.accounts.firstWhere((a) => a.id == 'acc_dest');
      expect(source.balance, 17000.0); // 20000 - 3000
      expect(dest.balance, 8000.0); // 5000 + 3000

      // Invariant: Transfers do not alter income or expense totals
      expect(finance.totalExpenses, initialExpenses);
      expect(finance.totalIncome, initialIncome);
    });

    test(
        '31. Batch metadata (batchId, tags: imported_bank_record, importHash) is persisted on imported transactions',
        () {
      final finance = FinanceProvider(seedSampleData: false);
      finance.startFreshGuest();
      finance.addAccount(
        Account(
          id: 'acc_meta',
          name: 'Allied Bank',
          type: AccountType.debit,
          balance: 15000.0,
          currency: 'PKR',
          icon: '🏛️',
        ),
      );

      const sampleCsv = '''Date,Description,Debit,Credit
2026-10-12,Electricity Bill,4500.00,
2026-10-13,Consulting Fee,,12000.00''';

      final parsed = StatementImporter.parseCsv(
        csvContent: sampleCsv,
        accountId: 'acc_meta',
      );

      final summary = finance.importStatementTransactions(
        accountId: 'acc_meta',
        transactions: parsed.records,
      );

      expect(summary.batchId, startsWith('batch_'));
      expect(finance.expenses.length, 2);

      for (final exp in finance.expenses) {
        expect(exp.importHash, isNotNull);
        expect(exp.importHash!.isNotEmpty, isTrue);
        expect(exp.tags, contains('imported_bank_record'));
        expect(exp.tags, contains(summary.batchId));
        expect(exp.note, contains(summary.batchId));
      }
    });

    test(
        '32. Direction detection correctly attributes incoming to income and outgoing to expense on dashboard totals',
        () {
      final finance = FinanceProvider(seedSampleData: false);
      finance.startFreshGuest();
      finance.addAccount(
        Account(
          id: 'acc_flow',
          name: 'HBL Current',
          type: AccountType.debit,
          balance: 10000.0,
          currency: 'PKR',
          icon: '🏛️',
        ),
      );

      const flowCsv = '''Date,Description,Debit,Credit
2026-10-14,Supermarket,3200.00,
2026-10-15,Freelance Payment,,8500.00''';

      final parsed = StatementImporter.parseCsv(
        csvContent: flowCsv,
        accountId: 'acc_flow',
      );

      expect(parsed.incomingCount, 1);
      expect(parsed.outgoingCount, 1);

      final summary = finance.importStatementTransactions(
        accountId: 'acc_flow',
        transactions: parsed.records,
      );

      expect(summary.incomingCount, 1);
      expect(summary.outgoingCount, 1);
      expect(summary.netBalanceChange, 5300.0); // +8500 - 3200

      // Financial dashboard totals
      expect(finance.totalExpenses, 3200.0);
      expect(finance.totalIncome, 8500.0);
      expect(finance.totalLiquidBalance, 15300.0); // 10000 + 8500 - 3200
      expect(finance.accounts.firstWhere((a) => a.id == 'acc_flow').balance,
          15300.0);
    });
  });
}
