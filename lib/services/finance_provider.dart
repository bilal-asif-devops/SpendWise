import 'package:flutter/material.dart';
import '../models/models.dart';
import 'storage_service.dart';

class FinanceProvider with ChangeNotifier {
  final LocalStorageService _storageService;

  String _userName = "Bilal";
  String _userEmail = "bilal@example.com";
  String _currency = "\$";
  double _monthlySavingsGoal = 245.50;
  bool _notificationsEnabled = true;
  bool _biometricsEnabled = true;
  bool _isDarkMode = false;
  bool _isInitialized = false;

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
        spentAmount: 308.00,
        startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
        endDate: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
        icon: "🏡",
      ),
    ];
  }

  // Actions & Mutations
  void addExpense({
    required String title,
    required String category,
    required double amount,
    String? accountId,
    String? note,
  }) {
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

    notifyListeners();
    _persistToStorage();
  }

  void transferBetweenAccounts({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
  }) {
    final fromIndex = _accounts.indexWhere((a) => a.id == fromAccountId);
    final toIndex = _accounts.indexWhere((a) => a.id == toAccountId);

    if (fromIndex != -1 && toIndex != -1 && amount > 0) {
      final fromAcc = _accounts[fromIndex];
      final toAcc = _accounts[toIndex];

      _accounts[fromIndex] =
          fromAcc.copyWith(balance: fromAcc.balance - amount);
      _accounts[toIndex] = toAcc.copyWith(balance: toAcc.balance + amount);

      notifyListeners();
      _persistToStorage();
    }
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
