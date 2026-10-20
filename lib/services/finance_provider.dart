import 'package:flutter/material.dart';
import '../models/models.dart';
import 'storage_service.dart';

class FinanceProvider with ChangeNotifier {
  final LocalStorageService _storageService;

  String _userName = "Guest User";
  String _userEmail = "guest@spendwise.local";
  String _currency = "\$";
  double _monthlySavingsGoal = 245.50;
  bool _notificationsEnabled = true;
  bool _biometricsEnabled = true;
  bool _isDarkMode = false;
  bool _isInitialized = false;
  bool _hasCompletedOnboarding = false;
  Map<String, dynamic> _onboardingData = {};
  String? _lastErrorMessage;

  List<Account> _accounts = [];
  List<Expense> _expenses = [];
  List<Subscription> _subscriptions = [];
  List<Budget> _budgets = [];

  FinanceProvider({LocalStorageService? storageService})
      : _storageService = storageService ?? LocalStorageService() {
    _seedDefaultSampleData();
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
    return _expenses.fold(0.0, (sum, item) => sum + item.amount);
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

  void _seedDefaultSampleData() {
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
      ),
    ];
    _recalculateBudgets();
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
  }) {
    if (!amount.isFinite || amount.isNaN || amount <= 0) {
      _lastErrorMessage =
          "Expense amount must be a finite number greater than zero.";
      notifyListeners();
      return;
    }

    final targetAccountId =
        accountId ?? (_accounts.isNotEmpty ? _accounts.first.id : "acc_1");
    final targetAccount = _accounts.firstWhere(
      (a) => a.id == targetAccountId,
      orElse: () => _accounts.first,
    );

    // Deduct from paying account
    final updatedAccount = targetAccount.copyWith(
      balance: targetAccount.type == AccountType.credit
          ? targetAccount.balance + amount // credit liability increases
          : targetAccount.balance - amount, // asset balance decreases
    );

    final accIndex = _accounts.indexWhere((a) => a.id == targetAccountId);
    if (accIndex != -1) {
      _accounts[accIndex] = updatedAccount;
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
        accountId: targetAccountId,
        walletName: targetAccount.name,
        note: note,
        isSample: false,
      ),
    );

    _recalculateBudgets();
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
    final targetAccountId =
        accountId ?? (_accounts.isNotEmpty ? _accounts.first.id : "acc_1");
    final targetAccount = _accounts.firstWhere(
      (a) => a.id == targetAccountId,
      orElse: () => _accounts.first,
    );

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
        accountId: targetAccountId,
        walletName: targetAccount.name,
        isSample: false,
      ),
    );

    _subscriptions.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

    notifyListeners();
    _persistToStorage();
  }

  void addAccount(Account newAccount) {
    _accounts.add(newAccount);
    notifyListeners();
    _persistToStorage();
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
    if (clearSampleExpenses) {
      _expenses.clear();
      _recalculateBudgets();
    }
    notifyListeners();
    _persistToStorage();
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
    );
  }

  // Local Storage Vault Persistence
  Future<void> _persistToStorage() async {
    final vaultData = _toVaultMap();
    await _storageService.saveVault(vaultData);
  }

  Map<String, dynamic> _toVaultMap() {
    return {
      'version': 2,
      'lastUpdated': DateTime.now().toIso8601String(),
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
    if (vault['profile'] != null) {
      final p = vault['profile'] as Map<String, dynamic>;
      _userName = p['userName'] as String? ?? _userName;
      _userEmail = p['userEmail'] as String? ?? _userEmail;
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
          .toList();
    }

    if (vault['expenses'] != null) {
      _expenses = (vault['expenses'] as List)
          .map((e) => Expense.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    if (vault['subscriptions'] != null) {
      _subscriptions = (vault['subscriptions'] as List)
          .map((s) => Subscription.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    if (vault['budgets'] != null) {
      _budgets = (vault['budgets'] as List)
          .map((b) => Budget.fromJson(b as Map<String, dynamic>))
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
        return '🍔';
      case 'shopping':
        return '🛍️';
      case 'transport':
      case 'travel':
        return '🚗';
      case 'bills':
      case 'utilities':
        return '💡';
      case 'health':
        return '🏋️';
      case 'education':
        return '📚';
      default:
        return '💳';
    }
  }
}
