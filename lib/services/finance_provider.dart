import 'package:flutter/material.dart';
import '../models/models.dart';
import 'storage_service.dart';
import 'statement_importer.dart';

class StatementImportSummary {
  final int totalRows;
  final int importedCount;
  final int duplicateCount;
  final int invalidCount;
  final double netBalanceChange;
  final String accountName;
  final List<String> errorMessages;

  const StatementImportSummary({
    required this.totalRows,
    required this.importedCount,
    required this.duplicateCount,
    required this.invalidCount,
    required this.netBalanceChange,
    required this.accountName,
    this.errorMessages = const [],
  });
}

class FinanceProvider with ChangeNotifier {
  final LocalStorageService _storageService;

  String _userName = "Guest User";
  String _userEmail = "guest@spendwise.local";
  String _currency = "\$";
  double _monthlySavingsGoal = 0.0;
  bool _notificationsEnabled = true;
  bool _biometricsEnabled = true;
  bool _isDarkMode = false;
  bool _isInitialized = false;
  bool _hasCompletedOnboarding = false;
  Map<String, dynamic> _onboardingData = {};
  String? _lastErrorMessage;
  DateTime _lastUpdated = DateTime(2026, 1, 1);

  List<Account> _accounts = [];
  List<Expense> _expenses = [];
  List<Subscription> _subscriptions = [];
  List<Budget> _budgets = [];

  FinanceProvider({
    LocalStorageService? storageService,
    bool seedSampleData = false,
  }) : _storageService = storageService ?? LocalStorageService() {
    if (seedSampleData) {
      seedDefaultSampleData();
    }
    _initializeData();
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  Map<String, dynamic> get onboardingData => Map.unmodifiable(_onboardingData);
  String? get lastErrorMessage => _lastErrorMessage;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get currency => _currency;
  double get monthlySavingsGoal => _monthlySavingsGoal;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get biometricsEnabled => _biometricsEnabled;
  bool get isDarkMode => _isDarkMode;

  List<Account> get accounts => List.unmodifiable(_accounts);
  List<Expense> get expenses => List.unmodifiable(_expenses);
  List<Subscription> get subscriptions => List.unmodifiable(_subscriptions);
  List<Budget> get budgets => List.unmodifiable(_budgets);

  List<Account> get liquidAccounts => _accounts
      .where((a) =>
          a.isLiquid &&
          !a.isExcludedFromSafeToSpend &&
          a.type != AccountType.credit)
      .toList();

  List<Account> get creditAccounts =>
      _accounts.where((a) => a.type == AccountType.credit).toList();

  // Financial Math & Calculations
  double get totalLiquidBalance {
    return liquidAccounts.fold(0.0, (sum, acc) => sum + acc.balance);
  }

  double get totalAllWalletsBalance {
    return _accounts
        .where((a) => a.type != AccountType.credit)
        .fold(0.0, (sum, acc) => sum + acc.balance);
  }

  double get totalCreditLiability {
    return creditAccounts.fold(0.0, (sum, acc) => sum + acc.balance);
  }

  double get totalMonthlySubscriptions {
    return _subscriptions.fold(0.0, (sum, item) => sum + item.amount);
  }

  double get totalExpenses {
    return _expenses
        .where((item) => item.type == TransactionType.expense)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get totalIncome {
    return _expenses
        .where((item) => item.type == TransactionType.income)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  // Safe-to-Spend Formula:
  // Liquid Balances ($1,850) - Pending Subscriptions ($184.50) - Planned Savings ($245.50) = $1,420.00
  double get safeToSpendBalance {
    final balance =
        totalLiquidBalance - totalMonthlySubscriptions - _monthlySavingsGoal;
    return balance < 0 ? 0.0 : balance;
  }

  double get dailySafeAllowance {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = (daysInMonth - now.day + 1).clamp(1, 31);
    return safeToSpendBalance / remainingDays;
  }

  // Data Initialization
  Future<void> _initializeData() async {
    try {
      final loadedVault = await _storageService.loadVault();
      if (loadedVault != null) {
        _loadFromVaultMap(loadedVault);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("FinanceProvider: Vault load error: $e");
    }
    _isInitialized = true;
  }

  void seedDefaultSampleData() {
    _monthlySavingsGoal = 245.50;
    _accounts = [
      Account(
        id: "acc_1",
        name: "Meezan Bank",
        type: AccountType.debit,
        balance: 1400.00,
        last4: "4821",
        icon: "🏛️",
        color: const Color(0xFF1A365D),
        isLiquid: true,
        isSample: true,
      ),
      Account(
        id: "acc_2",
        name: "Visa Debit",
        type: AccountType.debit,
        balance: 450.00,
        last4: "3092",
        icon: "💳",
        color: const Color(0xFF3182CE),
        isLiquid: true,
        isSample: true,
      ),
      Account(
        id: "acc_3",
        name: "Cash",
        type: AccountType.cash,
        balance: 250.00,
        icon: "💵",
        color: const Color(0xFF10B981),
        isLiquid: false,
        isExcludedFromSafeToSpend: true,
        isSample: true,
      ),
      Account(
        id: "acc_4",
        name: "Mastercard",
        type: AccountType.credit,
        balance: 680.00,
        creditLimit: 2500.00,
        last4: "8816",
        icon: "💳",
        color: const Color(0xFFE53E3E),
        isLiquid: false,
        isSample: true,
      ),
    ];

    _subscriptions = [
      Subscription(
        id: "sub_1",
        name: "Netflix",
        category: "Entertainment",
        amount: 15.99,
        nextBillingDate: DateTime.now().add(const Duration(days: 2)),
        iconLetter: "N",
        daysRemaining: 2,
        isDueSoon: true,
        accountId: "acc_2",
        walletName: "Visa Debit",
        isSample: true,
      ),
      Subscription(
        id: "sub_2",
        name: "Spotify",
        category: "Music",
        amount: 9.99,
        nextBillingDate: DateTime.now().add(const Duration(days: 4)),
        iconLetter: "S",
        daysRemaining: 4,
        isDueSoon: false,
        accountId: "acc_2",
        walletName: "Visa Debit",
        isSample: true,
      ),
      Subscription(
        id: "sub_3",
        name: "Gym",
        category: "Health & Fitness",
        amount: 45.00,
        nextBillingDate: DateTime.now().add(const Duration(days: 7)),
        iconLetter: "G",
        daysRemaining: 7,
        isDueSoon: false,
        accountId: "acc_1",
        walletName: "Meezan Bank",
        isSample: true,
      ),
    ];

    _expenses = [
      Expense(
        id: "exp_1",
        title: "Groceries",
        category: "Food",
        amount: 45.00,
        date: DateTime.now(),
        icon: "🛒",
        accountId: "acc_2",
        walletName: "Visa Debit",
        isSample: true,
      ),
      Expense(
        id: "exp_2",
        title: "Coffee",
        category: "Food",
        amount: 4.50,
        date: DateTime.now(),
        icon: "☕",
        accountId: "acc_1",
        walletName: "Meezan Bank",
        isSample: true,
      ),
      Expense(
        id: "exp_3",
        title: "Fuel / Transit",
        category: "Transport",
        amount: 25.00,
        date: DateTime.now().subtract(const Duration(days: 1)),
        icon: "🚗",
        accountId: "acc_2",
        walletName: "Visa Debit",
        isSample: true,
      ),
    ];

    _budgets = [
      Budget(
        id: "bgt_1",
        name: "Home Budget",
        category: "General Discretionary",
        targetAmount: 560.00,
        spentAmount: 0.0,
        startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
        endDate: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
        icon: "🏡",
        isSample: true,
      ),
    ];
    _recalculateBudgets();
  }

  static bool _isLegacySampleAccount(String id, String name) {
    if (id == "acc_1" && name == "Meezan Bank") return true;
    if (id == "acc_2" && name == "Visa Debit") return true;
    if (id == "acc_3" && name == "Cash") return true;
    if (id == "acc_4" && name == "Mastercard") return true;
    return false;
  }

  static bool _isLegacySampleSubscription(String id, String name) {
    if (id == "sub_1" || id == "sub_2" || id == "sub_3") return true;
    if (name == "Netflix" || name == "Spotify" || name == "Gym") return true;
    return false;
  }

  static bool _isLegacySampleExpense(String id) {
    return id == "exp_1" || id == "exp_2" || id == "exp_3";
  }

  static bool _isLegacySampleBudget(String id, String name) {
    return id == "bgt_1" && name == "Home Budget";
  }

  void purgeSampleData() {
    _accounts
        .removeWhere((a) => a.isSample || _isLegacySampleAccount(a.id, a.name));
    _subscriptions.removeWhere(
        (s) => s.isSample || _isLegacySampleSubscription(s.id, s.name));
    _expenses.removeWhere((e) => e.isSample || _isLegacySampleExpense(e.id));
    _budgets
        .removeWhere((b) => b.isSample || _isLegacySampleBudget(b.id, b.name));
    if (_monthlySavingsGoal == 245.50 && _accounts.isEmpty) {
      _monthlySavingsGoal = 0.0;
    }
    _recalculateBudgets();
    notifyListeners();
    _persistToStorage();
  }

  // Financial Calculations & Budgets
  double calculateBudgetSpent(Budget budget) {
    final startOfDay = DateTime(
      budget.startDate.year,
      budget.startDate.month,
      budget.startDate.day,
      0,
      0,
      0,
    );
    final endOfDay = DateTime(
      budget.endDate.year,
      budget.endDate.month,
      budget.endDate.day,
      23,
      59,
      59,
      999,
    );

    final isAllCategories = budget.category.toLowerCase() == 'all' ||
        budget.category.toLowerCase() == 'general' ||
        budget.category.toLowerCase() == 'general discretionary';

    return _expenses.where((e) {
      final inRange = !e.date.isBefore(startOfDay) && !e.date.isAfter(endOfDay);
      if (!inRange) return false;
      if (isAllCategories) return true;
      return e.category.toLowerCase() == budget.category.toLowerCase();
    }).fold(0.0, (sum, e) => sum + e.amount);
  }

  void _recalculateBudgets() {
    _budgets = _budgets.map((b) {
      final spent = calculateBudgetSpent(b);
      return b.copyWith(spentAmount: spent);
    }).toList();
  }

  // Actions & Mutations
  void addExpense({
    required String title,
    required String category,
    required double amount,
    String? accountId,
    String? note,
    String? currency,
    double? exchangeRate,
    List<String>? tags,
  }) {
    if (!amount.isFinite || amount.isNaN || amount <= 0) {
      _lastErrorMessage =
          "Expense amount must be a finite number greater than zero.";
      notifyListeners();
      return;
    }

    Account? targetAccount;
    if (accountId != null) {
      final idx = _accounts.indexWhere((a) => a.id == accountId);
      if (idx != -1) {
        targetAccount = _accounts[idx];
      }
    } else if (_accounts.isNotEmpty) {
      targetAccount = _accounts.first;
    }

    if (targetAccount != null) {
      // Deduct from paying account
      final updatedAccount = targetAccount.copyWith(
        balance: targetAccount.type == AccountType.credit
            ? targetAccount.balance + amount // credit liability increases
            : targetAccount.balance - amount, // asset balance decreases
      );

      final accIndex = _accounts.indexWhere((a) => a.id == targetAccount!.id);
      if (accIndex != -1) {
        _accounts[accIndex] = updatedAccount;
      }
    }

    _expenses.insert(
      0,
      Expense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        category: category,
        amount: amount,
        date: DateTime.now(),
        icon: _getCategoryIcon(category),
        accountId: targetAccount?.id ?? "cash_wallet",
        walletName: targetAccount?.name ?? "Cash",
        note: note,
        isSample: false,
        type: TransactionType.expense,
        currency: currency ?? _currency,
        exchangeRate: exchangeRate,
        tags: tags ?? const [],
      ),
    );

    _recalculateBudgets();
    notifyListeners();
    _persistToStorage();
  }

  void addIncome({
    required String title,
    required String category,
    required double amount,
    String? accountId,
    String? note,
    String? currency,
    double? exchangeRate,
    List<String>? tags,
  }) {
    if (!amount.isFinite || amount.isNaN || amount <= 0) {
      _lastErrorMessage =
          "Income amount must be a finite number greater than zero.";
      notifyListeners();
      return;
    }

    Account? targetAccount;
    if (accountId != null) {
      final idx = _accounts.indexWhere((a) => a.id == accountId);
      if (idx != -1) {
        targetAccount = _accounts[idx];
      }
    } else if (_accounts.isNotEmpty) {
      targetAccount = _accounts.first;
    }

    if (targetAccount != null) {
      // Deposit into receiving account
      final updatedAccount = targetAccount.copyWith(
        balance: targetAccount.type == AccountType.credit
            ? targetAccount.balance - amount // credit liability decreases
            : targetAccount.balance + amount, // asset balance increases
      );

      final accIndex = _accounts.indexWhere((a) => a.id == targetAccount!.id);
      if (accIndex != -1) {
        _accounts[accIndex] = updatedAccount;
      }
    }

    _expenses.insert(
      0,
      Expense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        category: category,
        amount: amount,
        date: DateTime.now(),
        icon: _getCategoryIcon(category),
        accountId: targetAccount?.id ?? "cash_wallet",
        walletName: targetAccount?.name ?? "Cash",
        note: note,
        isSample: false,
        type: TransactionType.income,
        currency: currency ?? _currency,
        exchangeRate: exchangeRate,
        tags: tags ?? const [],
      ),
    );

    notifyListeners();
    _persistToStorage();
  }

  bool transferBetweenAccounts({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
  }) {
    if (!amount.isFinite || amount.isNaN || amount <= 0) {
      _lastErrorMessage =
          "Transfer amount must be a finite number greater than zero.";
      notifyListeners();
      return false;
    }

    if (fromAccountId == toAccountId) {
      _lastErrorMessage = "Source and destination accounts must be different.";
      notifyListeners();
      return false;
    }

    final fromIndex = _accounts.indexWhere((a) => a.id == fromAccountId);
    final toIndex = _accounts.indexWhere((a) => a.id == toAccountId);

    if (fromIndex == -1 || toIndex == -1) {
      _lastErrorMessage = "Selected account does not exist.";
      notifyListeners();
      return false;
    }

    final fromAcc = _accounts[fromIndex];
    final toAcc = _accounts[toIndex];

    // Case 1: Paying a credit card bill (Destination is Credit Card)
    if (toAcc.type == AccountType.credit) {
      if (fromAcc.type == AccountType.credit) {
        _lastErrorMessage =
            "Cannot pay a credit card bill using another credit card.";
        notifyListeners();
        return false;
      }
      if (fromAcc.balance < amount) {
        _lastErrorMessage =
            "Insufficient funds in source account (${fromAcc.name}).";
        notifyListeners();
        return false;
      }
      if (amount > toAcc.balance) {
        _lastErrorMessage =
            "Payment amount exceeds outstanding liability of $_currency${toAcc.balance.toStringAsFixed(2)}.";
        notifyListeners();
        return false;
      }

      final updatedFrom = fromAcc.copyWith(balance: fromAcc.balance - amount);
      final updatedTo = toAcc.copyWith(balance: toAcc.balance - amount);

      _accounts[fromIndex] = updatedFrom;
      _accounts[toIndex] = updatedTo;
      _lastErrorMessage = null;
      notifyListeners();
      _persistToStorage();
      return true;
    }

    // Case 2: Cash Advance / Draw from Credit Card (Source is Credit Card)
    if (fromAcc.type == AccountType.credit) {
      final availableCredit = (fromAcc.creditLimit) - fromAcc.balance;
      if (amount > availableCredit) {
        _lastErrorMessage =
            "Transfer exceeds available credit limit of $_currency${availableCredit.toStringAsFixed(2)}.";
        notifyListeners();
        return false;
      }

      final updatedFrom = fromAcc.copyWith(balance: fromAcc.balance + amount);
      final updatedTo = toAcc.copyWith(balance: toAcc.balance + amount);

      _accounts[fromIndex] = updatedFrom;
      _accounts[toIndex] = updatedTo;
      _lastErrorMessage = null;
      notifyListeners();
      _persistToStorage();
      return true;
    }

    // Case 3: Standard transfer between liquid/asset accounts (debit, cash)
    if (fromAcc.balance < amount) {
      _lastErrorMessage =
          "Insufficient funds in source account (${fromAcc.name}).";
      notifyListeners();
      return false;
    }

    final updatedFrom = fromAcc.copyWith(balance: fromAcc.balance - amount);
    final updatedTo = toAcc.copyWith(balance: toAcc.balance + amount);

    _accounts[fromIndex] = updatedFrom;
    _accounts[toIndex] = updatedTo;
    _lastErrorMessage = null;
    notifyListeners();
    _persistToStorage();
    return true;
  }

  void addSubscription({
    required String name,
    required String category,
    required double amount,
    required int days,
    String? accountId,
  }) {
    Account? targetAccount;
    if (accountId != null) {
      final idx = _accounts.indexWhere((a) => a.id == accountId);
      if (idx != -1) {
        targetAccount = _accounts[idx];
      }
    } else if (_accounts.isNotEmpty) {
      targetAccount = _accounts.first;
    }

    _subscriptions.add(
      Subscription(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        category: category,
        amount: amount,
        nextBillingDate: DateTime.now().add(Duration(days: days)),
        iconLetter: name.isNotEmpty ? name[0].toUpperCase() : "S",
        daysRemaining: days,
        isDueSoon: days <= 3,
        accountId: targetAccount?.id ?? "cash_wallet",
        walletName: targetAccount?.name ?? "Cash",
        isSample: false,
      ),
    );

    _subscriptions.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

    notifyListeners();
    _persistToStorage();
  }

  void addBudget(Budget newBudget) {
    _budgets.add(newBudget);
    _recalculateBudgets();
    notifyListeners();
    _persistToStorage();
  }

  bool addAccount(Account newAccount) {
    if (newAccount.name.trim().isEmpty) {
      _lastErrorMessage = "Account name cannot be empty.";
      notifyListeners();
      return false;
    }
    if (!newAccount.balance.isFinite || newAccount.balance.isNaN) {
      _lastErrorMessage = "Opening balance must be a valid finite number.";
      notifyListeners();
      return false;
    }
    if (newAccount.type != AccountType.credit && newAccount.balance < 0) {
      _lastErrorMessage = "Asset account opening balance cannot be negative.";
      notifyListeners();
      return false;
    }
    if (newAccount.type == AccountType.credit) {
      if (!newAccount.creditLimit.isFinite || newAccount.creditLimit.isNaN) {
        _lastErrorMessage = "Credit limit must be a valid finite number.";
        notifyListeners();
        return false;
      }
      if (newAccount.creditLimit < 0) {
        _lastErrorMessage = "Credit limit cannot be negative.";
        notifyListeners();
        return false;
      }
      if (newAccount.balance < 0) {
        _lastErrorMessage = "Credit card liability cannot be negative.";
        notifyListeners();
        return false;
      }
    }

    _accounts.add(newAccount);
    _lastErrorMessage = null;
    notifyListeners();
    _persistToStorage();
    return true;
  }

  bool deleteAccount(String accountId) {
    final idx = _accounts.indexWhere((a) => a.id == accountId);
    if (idx == -1) return false;
    _accounts.removeAt(idx);
    _lastErrorMessage = null;
    notifyListeners();
    _persistToStorage();
    return true;
  }

  StatementImportSummary importStatementTransactions({
    required String accountId,
    required List<ImportedTransactionRecord> transactions,
  }) {
    final accIndex = _accounts.indexWhere((a) => a.id == accountId);
    if (accIndex == -1) {
      throw ArgumentError("Account with id '$accountId' was not found.");
    }
    final targetAccount = _accounts[accIndex];

    // Build fingerprint set for existing transactions in this account
    final existingHashes = <String>{};
    for (final exp in _expenses) {
      if (exp.accountId == accountId) {
        if (exp.importHash != null && exp.importHash!.isNotEmpty) {
          existingHashes.add(exp.importHash!);
        }
        existingHashes.add(
          StatementImporter.generateFingerprint(
            accountId: exp.accountId,
            date: exp.date,
            description: exp.title,
            amount: exp.amount,
            type: exp.type,
          ),
        );
      }
    }

    int importedCount = 0;
    int duplicateCount = 0;
    int invalidCount = 0;
    double netBalanceChange = 0.0;
    final errorMessages = <String>[];
    final newExpenses = <Expense>[];

    double currentBalance = targetAccount.balance;

    for (final rec in transactions) {
      if (!rec.isValid) {
        invalidCount++;
        if (rec.errorMessage != null) {
          errorMessages.add("Row ${rec.rowIndex}: ${rec.errorMessage}");
        }
        continue;
      }
      if (!rec.amount.isFinite || rec.amount <= 0 || rec.amount.isNaN) {
        invalidCount++;
        errorMessages
            .add("Row ${rec.rowIndex}: Non-positive or non-finite amount");
        continue;
      }

      final fp = rec.importHash.isNotEmpty
          ? rec.importHash
          : StatementImporter.generateFingerprint(
              accountId: accountId,
              date: rec.date ?? DateTime.now(),
              description: rec.description,
              amount: rec.amount,
              type: rec.type,
            );

      if (existingHashes.contains(fp)) {
        duplicateCount++;
        continue;
      }

      existingHashes.add(fp);

      final exp = Expense(
        id: "stmt_${DateTime.now().microsecondsSinceEpoch}_$importedCount",
        title: rec.description,
        category: rec.category.isNotEmpty
            ? rec.category
            : (rec.type == TransactionType.income ? "Salary" : "Other"),
        amount: rec.amount,
        date: rec.date ?? DateTime.now(),
        icon: _getCategoryIcon(rec.category),
        accountId: targetAccount.id,
        walletName: targetAccount.name,
        currency: targetAccount.currency,
        type: rec.type,
        note: "Imported transaction",
        importHash: fp,
      );

      newExpenses.add(exp);
      importedCount++;

      // Update account balance
      if (targetAccount.type == AccountType.credit) {
        // For credit cards: expense increases liability, income decreases liability
        if (rec.type == TransactionType.expense) {
          currentBalance += rec.amount;
          netBalanceChange += rec.amount;
        } else if (rec.type == TransactionType.income) {
          currentBalance -= rec.amount;
          netBalanceChange -= rec.amount;
        }
      } else {
        // For asset accounts (cash, debit): expense decreases asset, income increases asset
        if (rec.type == TransactionType.expense) {
          currentBalance -= rec.amount;
          netBalanceChange -= rec.amount;
        } else if (rec.type == TransactionType.income) {
          currentBalance += rec.amount;
          netBalanceChange += rec.amount;
        }
      }
    }

    if (newExpenses.isNotEmpty) {
      _expenses.addAll(newExpenses);
      _expenses.sort((a, b) => b.date.compareTo(a.date));
      _accounts[accIndex] = targetAccount.copyWith(balance: currentBalance);
      _recalculateBudgets();
      notifyListeners();
      _persistToStorage();
    }

    return StatementImportSummary(
      totalRows: transactions.length,
      importedCount: importedCount,
      duplicateCount: duplicateCount,
      invalidCount: invalidCount,
      netBalanceChange: netBalanceChange,
      accountName: targetAccount.name,
      errorMessages: errorMessages,
    );
  }

  void updateCurrency(String newCurr) {
    _currency = newCurr;
    notifyListeners();
    _persistToStorage();
  }

  void toggleNotifications(bool enabled) {
    _notificationsEnabled = enabled;
    notifyListeners();
    _persistToStorage();
  }

  void toggleBiometrics(bool enabled) {
    _biometricsEnabled = enabled;
    notifyListeners();
    _persistToStorage();
  }

  void toggleDarkMode(bool enabled) {
    _isDarkMode = enabled;
    notifyListeners();
    _persistToStorage();
  }

  void completeOnboarding({
    String? name,
    String? email,
    Map<String, dynamic>? surveyResponses,
    bool clearSampleExpenses = false,
    bool clearAllData = false,
  }) {
    _hasCompletedOnboarding = true;
    if (name != null && name.trim().isNotEmpty) {
      _userName = name.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      _userEmail = email.trim();
    }
    if (surveyResponses != null) {
      _onboardingData = Map<String, dynamic>.from(surveyResponses);
    }
    if (clearAllData || clearSampleExpenses) {
      _expenses.clear();
      _accounts.clear();
      _subscriptions.clear();
      _budgets.clear();
      _monthlySavingsGoal = 0.0;
    }
    notifyListeners();
    _persistToStorage();
  }

  void updateProfile({String? name, String? email}) {
    bool changed = false;
    if (name != null && name.trim().isNotEmpty && _userName != name.trim()) {
      _userName = name.trim();
      changed = true;
    }
    if (email != null &&
        email.trim().isNotEmpty &&
        _userEmail != email.trim()) {
      _userEmail = email.trim();
      changed = true;
    }
    if (changed) {
      notifyListeners();
      _persistToStorage();
    }
  }

  void resetOnboarding() {
    _hasCompletedOnboarding = false;
    _onboardingData.clear();
    _userName = "Guest User";
    _userEmail = "guest@spendwise.local";
    notifyListeners();
    _persistToStorage();
  }

  void startFreshGuest({Map<String, dynamic>? surveyResponses}) {
    completeOnboarding(
      name: "Guest User",
      email: "guest@spendwise.local",
      surveyResponses: surveyResponses,
      clearSampleExpenses: true,
      clearAllData: true,
    );
  }

  // Local Storage Vault Persistence
  Future<void> _persistToStorage() async {
    _lastUpdated = DateTime.now();
    final vaultData = _toVaultMap();
    await _storageService.saveVault(vaultData);
  }

  Map<String, dynamic> toVaultMap() => _toVaultMap();

  void loadFromVaultMap(Map<String, dynamic> vault) {
    _loadFromVaultMap(vault);
    notifyListeners();
  }

  Map<String, dynamic> _toVaultMap() {
    return {
      'version': 2,
      'lastUpdated': _lastUpdated.toIso8601String(),
      'profile': {
        'userName': _userName,
        'userEmail': _userEmail,
        'currency': _currency,
        'monthlySavingsGoal': _monthlySavingsGoal,
        'notificationsEnabled': _notificationsEnabled,
        'biometricsEnabled': _biometricsEnabled,
        'isDarkMode': _isDarkMode,
        'hasCompletedOnboarding': _hasCompletedOnboarding,
        'onboardingData': _onboardingData,
      },
      'accounts': _accounts.map((a) => a.toJson()).toList(),
      'expenses': _expenses.map((e) => e.toJson()).toList(),
      'subscriptions': _subscriptions.map((s) => s.toJson()).toList(),
      'budgets': _budgets.map((b) => b.toJson()).toList(),
    };
  }

  void _loadFromVaultMap(Map<String, dynamic> vault) {
    if (vault['lastUpdated'] != null) {
      _lastUpdated =
          DateTime.tryParse(vault['lastUpdated'].toString()) ?? _lastUpdated;
    }
    if (vault['profile'] != null) {
      final p = vault['profile'] as Map<String, dynamic>;
      final vaultName = p['userName'] as String?;
      final vaultEmail = p['userEmail'] as String?;

      if (vaultName != null &&
          vaultName.trim().isNotEmpty &&
          vaultName != 'Guest User') {
        _userName = vaultName.trim();
      } else if (_userName == 'Guest User' && vaultName != null) {
        _userName = vaultName.trim();
      }

      if (vaultEmail != null &&
          vaultEmail.trim().isNotEmpty &&
          vaultEmail != 'guest@spendwise.local') {
        _userEmail = vaultEmail.trim();
      } else if (_userEmail == 'guest@spendwise.local' && vaultEmail != null) {
        _userEmail = vaultEmail.trim();
      }
      _currency = p['currency'] as String? ?? _currency;
      _monthlySavingsGoal =
          (p['monthlySavingsGoal'] as num?)?.toDouble() ?? _monthlySavingsGoal;
      _notificationsEnabled =
          p['notificationsEnabled'] as bool? ?? _notificationsEnabled;
      _biometricsEnabled =
          p['biometricsEnabled'] as bool? ?? _biometricsEnabled;
      _isDarkMode = p['isDarkMode'] as bool? ?? _isDarkMode;
      _hasCompletedOnboarding = p['hasCompletedOnboarding'] as bool? ?? false;
      if (p['onboardingData'] != null && p['onboardingData'] is Map) {
        _onboardingData = Map<String, dynamic>.from(p['onboardingData'] as Map);
      }
    }

    if (vault['accounts'] != null) {
      _accounts = (vault['accounts'] as List)
          .map((a) => Account.fromJson(a as Map<String, dynamic>))
          .where((a) => !a.isSample && !_isLegacySampleAccount(a.id, a.name))
          .toList();
    }

    if (vault['expenses'] != null) {
      _expenses = (vault['expenses'] as List)
          .map((e) => Expense.fromJson(e as Map<String, dynamic>))
          .where((e) => !e.isSample && !_isLegacySampleExpense(e.id))
          .toList();
    }

    if (vault['subscriptions'] != null) {
      _subscriptions = (vault['subscriptions'] as List)
          .map((s) => Subscription.fromJson(s as Map<String, dynamic>))
          .where(
              (s) => !s.isSample && !_isLegacySampleSubscription(s.id, s.name))
          .toList();
    }

    if (vault['budgets'] != null) {
      _budgets = (vault['budgets'] as List)
          .map((b) => Budget.fromJson(b as Map<String, dynamic>))
          .where((b) => !b.isSample && !_isLegacySampleBudget(b.id, b.name))
          .toList();
      _recalculateBudgets();
    }
  }

  Future<String> exportVaultJson() async {
    return _storageService.exportVaultJson(_toVaultMap());
  }

  Future<bool> importVaultJson(String jsonString) async {
    final success = await _storageService.importVaultJson(jsonString);
    if (success) {
      final loaded = await _storageService.loadVault();
      if (loaded != null) {
        _loadFromVaultMap(loaded);
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  String _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'food':
      case 'food & drink':
      case 'groceries':
        return '🍔';
      case 'shopping':
        return '🛍️';
      case 'transport':
      case 'car':
        return '🚗';
      case 'travel':
        return '✈️';
      case 'bills':
      case 'bills & fees':
      case 'utilities':
        return '💡';
      case 'home':
        return '🏡';
      case 'entertainment':
        return '🍿';
      case 'health':
      case 'healthcare':
        return '💊';
      case 'education':
        return '📚';
      case 'personal':
        return '👤';
      case 'salary':
        return '💼';
      case 'freelance':
        return '💻';
      case 'investments':
        return '📈';
      case 'gift':
        return '🎁';
      case 'refund':
        return '🔄';
      case 'rental':
        return '🏢';
      case 'other':
        return '💰';
      default:
        return '💳';
    }
  }
}
