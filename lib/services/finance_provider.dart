import 'package:flutter/foundation.dart';
import '../models/models.dart';

class FinanceProvider with ChangeNotifier {
  String _userName = "Bilal";
  String _currency = "\$";
  double _totalIncome = 3200.00;
  
  // Initial subscriptions matching Figma Screen 3 & 4
  final List<Subscription> _subscriptions = [
    Subscription(
      id: "1",
      name: "Netflix",
      category: "Entertainment",
      amount: 15.99,
      nextBillingDate: DateTime.now().add(const Duration(days: 2)),
      iconLetter: "N",
      daysRemaining: 2,
      isDueSoon: true,
    ),
    Subscription(
      id: "2",
      name: "Spotify",
      category: "Music",
      amount: 9.99,
      nextBillingDate: DateTime.now().add(const Duration(days: 7)),
      iconLetter: "S",
      daysRemaining: 7,
      isDueSoon: false,
    ),
    Subscription(
      id: "3",
      name: "Gym",
      category: "Health & Fitness",
      amount: 45.00,
      nextBillingDate: DateTime.now().add(const Duration(days: 12)),
      iconLetter: "G",
      daysRemaining: 12,
      isDueSoon: false,
    ),
  ];

  // Initial expenses matching Figma Screen 1
  final List<Expense> _expenses = [
    Expense(
      id: "1",
      title: "Groceries",
      category: "Food",
      amount: 45.00,
      date: DateTime.now(),
      icon: "🛒",
    ),
    Expense(
      id: "2",
      title: "Coffee",
      category: "Food",
      amount: 4.50,
      date: DateTime.now(),
      icon: "☕",
    ),
    Expense(
      id: "3",
      title: "Fuel / Transit",
      category: "Transport",
      amount: 25.00,
      date: DateTime.now().subtract(const Duration(days: 1)),
      icon: "🚗",
    ),
  ];

  // Getters
  String get userName => _userName;
  String get currency => _currency;
  List<Subscription> get subscriptions => _subscriptions;
  List<Expense> get expenses => _expenses;

  // Monthly Subscriptions Total
  double get totalMonthlySubscriptions {
    return _subscriptions.fold(0.0, (sum, item) => sum + item.amount);
  }

  // Monthly Expenses Total
  double get totalExpenses {
    return _expenses.fold(0.0, (sum, item) => sum + item.amount);
  }

  // Safe-to-Spend Balance Calculation
  double get safeToSpendBalance {
    return _totalIncome - totalMonthlySubscriptions - totalExpenses;
  }

  // Add Expense
  void addExpense({required String title, required String category, required double amount}) {
    _expenses.insert(
      0,
      Expense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        category: category,
        amount: amount,
        date: DateTime.now(),
        icon: _getCategoryIcon(category),
      ),
    );
    notifyListeners();
  }

  // Add Subscription
  void addSubscription({required String name, required String category, required double amount, required int days}) {
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
      ),
    );
    notifyListeners();
  }

  void updateCurrency(String newCurr) {
    _currency = newCurr;
    notifyListeners();
  }

  String _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'food':
        return '🍔';
      case 'shopping':
        return '🛍️';
      case 'transport':
        return '🚗';
      case 'bills':
        return '💡';
      default:
        return '💳';
    }
  }
}
