import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spendwise/models/currency.dart';
import 'package:spendwise/models/models.dart';
import 'package:spendwise/services/finance_provider.dart';
import 'package:spendwise/widgets/quick_add_sheet.dart';
import 'package:spendwise/widgets/transaction_entry/calculator_engine.dart';
import 'package:spendwise/widgets/transaction_entry/currency_picker_modal.dart';
import 'package:spendwise/widgets/transaction_entry/exchange_rate_modal.dart';

Widget createTestableWidget({
  required Widget child,
  required FinanceProvider financeProvider,
}) {
  return ChangeNotifierProvider<FinanceProvider>.value(
    value: financeProvider,
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

Future<void> tapKeypad(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey('keypad_$key'));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('Phase 3: Calculator Engine Unit Tests', () {
    test('1. Digit input, zero replacement, and decimal precision', () {
      final calc = CalculatorEngine();
      expect(calc.expression, equals('0'));

      calc.inputDigit('5');
      expect(calc.expression, equals('5'));

      calc.inputDigit('0');
      expect(calc.expression, equals('50'));

      calc.inputDecimal();
      expect(calc.expression, equals('50.'));

      // Rejects second decimal in same operand
      calc.inputDecimal();
      expect(calc.expression, equals('50.'));

      calc.inputDigit('2');
      calc.inputDigit('5');
      expect(calc.expression, equals('50.25'));

      // Max 2 decimal digits for currency input
      calc.inputDigit('9');
      expect(calc.expression, equals('50.25'));

      expect(calc.getNumericAmount(), equals(50.25));
    });

    test('2. Backspace removes characters, strips operators, and resets to 0',
        () {
      final calc = CalculatorEngine();
      calc.inputDigit('1');
      calc.inputDigit('2');
      calc.inputDigit('3');
      expect(calc.expression, equals('123'));

      calc.backspace();
      expect(calc.expression, equals('12'));

      calc.backspace();
      expect(calc.expression, equals('1'));

      calc.backspace();
      expect(calc.expression, equals('0'));

      // Backspacing with operator
      calc.inputDigit('8');
      calc.inputOperator('+');
      expect(calc.hasPendingOperation, isTrue);

      calc.backspace();
      expect(calc.expression, equals('8'));
      expect(calc.hasPendingOperation, isFalse);
    });

    test('3. Arithmetic addition and inline evaluation', () {
      final calc = CalculatorEngine();
      calc.inputDigit('2');
      calc.inputDigit('5');
      calc.inputOperator('+');
      calc.inputDigit('1');
      calc.inputDigit('5');
      expect(calc.expression, equals('25 + 15'));

      final success = calc.evaluate();
      expect(success, isTrue);
      expect(calc.expression, equals('40'));
      expect(calc.getNumericAmount(), equals(40.0));
    });

    test('4. Arithmetic subtraction, multiplication, and division', () {
      final calc = CalculatorEngine();

      // Subtraction
      calc.inputDigit('1');
      calc.inputDigit('0');
      calc.inputDigit('0');
      calc.inputOperator('-');
      calc.inputDigit('3');
      calc.inputDigit('5');
      calc.evaluate();
      expect(calc.getNumericAmount(), equals(65.0));

      // Multiplication
      calc.clear();
      calc.inputDigit('1');
      calc.inputDigit('2');
      calc.inputOperator('×');
      calc.inputDigit('5');
      calc.evaluate();
      expect(calc.getNumericAmount(), equals(60.0));

      // Division
      calc.clear();
      calc.inputDigit('1');
      calc.inputDigit('0');
      calc.inputDigit('0');
      calc.inputOperator('÷');
      calc.inputDigit('4');
      calc.evaluate();
      expect(calc.getNumericAmount(), equals(25.0));
    });

    test('5. Division by zero is rejected cleanly without Infinity or NaN', () {
      final calc = CalculatorEngine();
      calc.inputDigit('5');
      calc.inputDigit('0');
      calc.inputOperator('÷');
      calc.inputDigit('0');
      final ok = calc.evaluate();

      expect(ok, isFalse);
      expect(calc.errorMessage, contains('divide by zero'));
      expect(calc.getNumericAmount(), isNull);
    });

    test('6. Non-finite amounts and non-positive amounts return null', () {
      final calc = CalculatorEngine();
      calc.clear();
      expect(calc.getNumericAmount(), isNull);

      calc.inputDigit('0');
      expect(calc.getNumericAmount(), isNull);
    });
  });

  group('Phase 3: Currency & Exchange Rate Dataset Tests', () {
    test('7. Fiat currency dataset contains over 160 currencies', () {
      expect(CurrencyData.currencies.length, greaterThanOrEqualTo(160));
    });

    test('8. Currency lookup by code and case-insensitivity', () {
      final usd = CurrencyData.findByCode('USD');
      expect(usd.code, equals('USD'));
      expect(usd.symbol, equals('\$'));

      final gbp = CurrencyData.findByCode('gbp');
      expect(gbp.code, equals('GBP'));
      expect(gbp.symbol, equals('£'));

      final pkr = CurrencyData.findByCode('PKR');
      expect(pkr.code, equals('PKR'));
      expect(pkr.name, contains('Pakistani'));
    });

    test('9. Search filters currencies by code, name, and symbol', () {
      final pkrResults = CurrencyData.search('pkr');
      expect(pkrResults.any((c) => c.code == 'PKR'), isTrue);

      final euroResults = CurrencyData.search('euro');
      expect(euroResults.any((c) => c.code == 'EUR'), isTrue);

      final poundResults = CurrencyData.search('£');
      expect(poundResults.any((c) => c.code == 'GBP'), isTrue);
    });

    test('10. Estimated rate helper calculates non-zero positive conversion',
        () {
      final rateGbpToPkr = CurrencyData.getEstimatedRate('GBP', 'PKR');
      expect(rateGbpToPkr, isPositive);
      expect(rateGbpToPkr.isFinite, isTrue);
    });
  });

  group('Phase 3: Transaction Entry Widget Tests', () {
    testWidgets(
        '11. QuickAddExpenseSheet renders 3 mode pills: Expenses, Income, Transfer',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final finance = FinanceProvider();
      await tester.pumpWidget(
        createTestableWidget(
          child: const QuickAddExpenseSheet(),
          financeProvider: finance,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add transaction'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);
    });

    testWidgets('12. Mode switching alters categories and submit button text',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final finance = FinanceProvider();
      await tester.pumpWidget(
        createTestableWidget(
          child: const QuickAddExpenseSheet(),
          financeProvider: finance,
        ),
      );
      await tester.pumpAndSettle();

      // Initially Expenses mode
      expect(find.text('Save Expense'), findsOneWidget);
      expect(find.text('Food & Drink'), findsWidgets);

      // Switch to Income mode
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      expect(find.text('Save Income'), findsOneWidget);
      expect(find.text('Salary'), findsWidgets);

      // Switch to Transfer mode
      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();
      expect(find.text('Transfer Funds'), findsOneWidget);
    });

    testWidgets(
        '13. Keypad input and expense creation without phantom accounts',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final finance = FinanceProvider();
      finance.startFreshGuest();
      expect(finance.expenses, isEmpty);
      expect(finance.accounts, isEmpty);

      await tester.pumpWidget(
        createTestableWidget(
          child: const QuickAddExpenseSheet(),
          financeProvider: finance,
        ),
      );
      await tester.pumpAndSettle();

      // Enter 50 using keypad
      await tapKeypad(tester, '5');
      await tapKeypad(tester, '0');

      // Submit expense
      final submitFinder = find.text('Save Expense');
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(finance.expenses.length, equals(1));
      expect(finance.expenses.first.amount, equals(50.0));
      expect(finance.expenses.first.type, equals(TransactionType.expense));
      // Guest isolation preserved: accounts list remains 0
      expect(finance.accounts.length, equals(0));
    });

    testWidgets('14. Keypad inline arithmetic saves calculated result',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final finance = FinanceProvider();
      finance.startFreshGuest();

      await tester.pumpWidget(
        createTestableWidget(
          child: const QuickAddExpenseSheet(),
          financeProvider: finance,
        ),
      );
      await tester.pumpAndSettle();

      // Enter 30 + 20
      await tapKeypad(tester, '3');
      await tapKeypad(tester, '0');
      await tapKeypad(tester, '+');
      await tapKeypad(tester, '2');
      await tapKeypad(tester, '0');

      // Submit evaluates 30 + 20 = 50 automatically
      final submitFinder = find.text('Save Expense');
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(finance.expenses.length, equals(1));
      expect(finance.expenses.first.amount, equals(50.0));
    });

    testWidgets(
        '15. Income entry increments account balance and creates income record',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final finance = FinanceProvider();
      finance.startFreshGuest();
      finance.addAccount(
        Account(
          id: 'acc_salary',
          name: 'Main Checking',
          type: AccountType.debit,
          balance: 1000.0,
          icon: '🏛️',
        ),
      );

      await tester.pumpWidget(
        createTestableWidget(
          child:
              const QuickAddExpenseSheet(initialMode: TransactionType.income),
          financeProvider: finance,
        ),
      );
      await tester.pumpAndSettle();

      // Enter 500
      await tapKeypad(tester, '5');
      await tapKeypad(tester, '0');
      await tapKeypad(tester, '0');

      final submitFinder = find.text('Save Income');
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(finance.expenses.length, equals(1));
      expect(finance.expenses.first.type, equals(TransactionType.income));
      expect(finance.expenses.first.amount, equals(500.0));
      expect(finance.accounts.first.balance, equals(1500.0));
      expect(finance.totalIncome, equals(500.0));
      expect(finance.totalExpenses, equals(0.0));
    });

    testWidgets(
        '16. Transfer between accounts validates rules and shifts balance',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final finance = FinanceProvider();
      finance.startFreshGuest();
      finance.addAccount(
        Account(
          id: 'acc_from',
          name: 'Checking',
          type: AccountType.debit,
          balance: 500.0,
          icon: '🏛️',
        ),
      );
      finance.addAccount(
        Account(
          id: 'acc_to',
          name: 'Savings',
          type: AccountType.cash,
          balance: 100.0,
          icon: '💵',
        ),
      );

      await tester.pumpWidget(
        createTestableWidget(
          child:
              const QuickAddExpenseSheet(initialMode: TransactionType.transfer),
          financeProvider: finance,
        ),
      );
      await tester.pumpAndSettle();

      // Enter transfer 150
      await tapKeypad(tester, '1');
      await tapKeypad(tester, '5');
      await tapKeypad(tester, '0');

      final submitFinder = find.text('Transfer Funds');
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(finance.accounts[0].balance, equals(350.0));
      expect(finance.accounts[1].balance, equals(250.0));
      // Invariant: transfer does not pollute expenses
      expect(finance.expenses.length, equals(0));
    });

    testWidgets('17. Receipt scan button displays Phase 4 roadmap dialog',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final finance = FinanceProvider();
      await tester.pumpWidget(
        createTestableWidget(
          child: const QuickAddExpenseSheet(),
          financeProvider: finance,
        ),
      );
      await tester.pumpAndSettle();

      final scanFinder = find.text('📸✨ Scan receipt');
      await tester.ensureVisible(scanFinder);
      await tester.tap(scanFinder);
      await tester.pumpAndSettle();

      expect(find.text('📸✨ Scan Receipt'), findsOneWidget);
      expect(find.textContaining('Phase 4'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.text('📸✨ Scan Receipt'), findsNothing);
    });

    testWidgets('18. Currency picker modal displays search and list',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CurrencyPickerModal(selectedCode: 'USD'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select Currency'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('USD'), findsWidgets);
    });

    testWidgets('19. Exchange rate modal displays rate pair and confirm button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final gbp = CurrencyData.findByCode('GBP');
      final pkr = CurrencyData.findByCode('PKR');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExchangeRateModal(
              baseCurrency: gbp,
              targetCurrency: pkr,
              initialRate: 68.0135,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set exchange rate £ / PKR'), findsOneWidget);
      expect(find.text('Remember Currency'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
    });
  });
}
