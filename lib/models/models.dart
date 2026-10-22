import 'package:flutter/material.dart';

enum AccountType { debit, cash, credit }

class Account {
  final String id;
  final String name;
  final AccountType type;
  final double balance;
  final double creditLimit;
  final String? last4;
  final String icon;
  final Color color;
  final bool isLiquid;
  final bool isExcludedFromSafeToSpend;
  final bool isSample;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.creditLimit = 0.0,
    this.last4,
    required this.icon,
    this.color = const Color(0xFF1A365D),
    this.isLiquid = true,
    this.isExcludedFromSafeToSpend = false,
    this.isSample = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'balance': balance,
        'creditLimit': creditLimit,
        'last4': last4,
        'icon': icon,
        'color': color.toARGB32(),
        'isLiquid': isLiquid,
        'isExcludedFromSafeToSpend': isExcludedFromSafeToSpend,
        'isSample': isSample,
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        name: json['name'] as String,
        type: AccountType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => AccountType.debit,
        ),
        balance: (json['balance'] as num).toDouble(),
        creditLimit: (json['creditLimit'] as num?)?.toDouble() ?? 0.0,
        last4: json['last4'] as String?,
        icon: json['icon'] as String? ?? '💳',
        color: json['color'] != null
            ? Color(json['color'] as int)
            : const Color(0xFF1A365D),
        isLiquid: json['isLiquid'] as bool? ?? true,
        isExcludedFromSafeToSpend:
            json['isExcludedFromSafeToSpend'] as bool? ?? false,
        isSample: json['isSample'] as bool? ?? false,
      );

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? balance,
    double? creditLimit,
    String? last4,
    String? icon,
    Color? color,
    bool? isLiquid,
    bool? isExcludedFromSafeToSpend,
    bool? isSample,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      creditLimit: creditLimit ?? this.creditLimit,
      last4: last4 ?? this.last4,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isLiquid: isLiquid ?? this.isLiquid,
      isExcludedFromSafeToSpend:
          isExcludedFromSafeToSpend ?? this.isExcludedFromSafeToSpend,
      isSample: isSample ?? this.isSample,
    );
  }
}

enum TransactionType { expense, income, transfer }

class Expense {
  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final String icon;
  final String accountId;
  final String walletName;
  final String? note;
  final bool isSample;
  final TransactionType type;
  final String? toAccountId;
  final String? toWalletName;
  final String currency;
  final double? exchangeRate;
  final List<String> tags;

  Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.icon,
    this.accountId = '1',
    this.walletName = 'Visa Debit',
    this.note,
    this.isSample = false,
    this.type = TransactionType.expense,
    this.toAccountId,
    this.toWalletName,
    this.currency = 'USD',
    this.exchangeRate,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'date': date.toIso8601String(),
        'icon': icon,
        'accountId': accountId,
        'walletName': walletName,
        'note': note,
        'isSample': isSample,
        'type': type.name,
        'toAccountId': toAccountId,
        'toWalletName': toWalletName,
        'currency': currency,
        'exchangeRate': exchangeRate,
        'tags': tags,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        amount: (json['amount'] as num).toDouble(),
        date:
            DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        icon: json['icon'] as String? ?? '💳',
        accountId: json['accountId'] as String? ?? '1',
        walletName: json['walletName'] as String? ?? 'Visa Debit',
        note: json['note'] as String?,
        isSample: json['isSample'] as bool? ?? false,
        type: TransactionType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => TransactionType.expense,
        ),
        toAccountId: json['toAccountId'] as String?,
        toWalletName: json['toWalletName'] as String?,
        currency: json['currency'] as String? ?? 'USD',
        exchangeRate: (json['exchangeRate'] as num?)?.toDouble(),
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );

  Expense copyWith({
    String? id,
    String? title,
    String? category,
    double? amount,
    DateTime? date,
    String? icon,
    String? accountId,
    String? walletName,
    String? note,
    bool? isSample,
    TransactionType? type,
    String? toAccountId,
    String? toWalletName,
    String? currency,
    double? exchangeRate,
    List<String>? tags,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      icon: icon ?? this.icon,
      accountId: accountId ?? this.accountId,
      walletName: walletName ?? this.walletName,
      note: note ?? this.note,
      isSample: isSample ?? this.isSample,
      type: type ?? this.type,
      toAccountId: toAccountId ?? this.toAccountId,
      toWalletName: toWalletName ?? this.toWalletName,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      tags: tags ?? this.tags,
    );
  }
}

class Subscription {
  final String id;
  final String name;
  final String category;
  final double amount;
  final DateTime nextBillingDate;
  final String iconLetter;
  final int daysRemaining;
  final bool isDueSoon;
  final String accountId;
  final String walletName;
  final bool advanceAlertEnabled;
  final bool isSample;

  Subscription({
    required this.id,
    required this.name,
    required this.category,
    required this.amount,
    required this.nextBillingDate,
    required this.iconLetter,
    required this.daysRemaining,
    required this.isDueSoon,
    this.accountId = '1',
    this.walletName = 'Visa Debit',
    this.advanceAlertEnabled = true,
    this.isSample = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'amount': amount,
        'nextBillingDate': nextBillingDate.toIso8601String(),
        'iconLetter': iconLetter,
        'daysRemaining': daysRemaining,
        'isDueSoon': isDueSoon,
        'accountId': accountId,
        'walletName': walletName,
        'advanceAlertEnabled': advanceAlertEnabled,
        'isSample': isSample,
      };

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        amount: (json['amount'] as num).toDouble(),
        nextBillingDate:
            DateTime.tryParse(json['nextBillingDate'] as String? ?? '') ??
                DateTime.now(),
        iconLetter: json['iconLetter'] as String? ?? 'S',
        daysRemaining: (json['daysRemaining'] as num?)?.toInt() ?? 30,
        isDueSoon: json['isDueSoon'] as bool? ?? false,
        accountId: json['accountId'] as String? ?? '1',
        walletName: json['walletName'] as String? ?? 'Visa Debit',
        advanceAlertEnabled: json['advanceAlertEnabled'] as bool? ?? true,
        isSample: json['isSample'] as bool? ?? false,
      );
}

class Budget {
  final String id;
  final String name;
  final String category;
  final double targetAmount;
  final double spentAmount;
  final DateTime startDate;
  final DateTime endDate;
  final String icon;
  final bool isSample;

  Budget({
    required this.id,
    required this.name,
    required this.category,
    required this.targetAmount,
    required this.spentAmount,
    required this.startDate,
    required this.endDate,
    this.icon = '🏡',
    this.isSample = false,
  });

  double get percentageSpent =>
      targetAmount > 0 ? (spentAmount / targetAmount).clamp(0.0, 2.0) : 0.0;
  double get remainingAmount =>
      (targetAmount - spentAmount).clamp(0.0, double.infinity);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'targetAmount': targetAmount,
        'spentAmount': spentAmount,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'icon': icon,
        'isSample': isSample,
      };

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String? ?? 'General',
        targetAmount: (json['targetAmount'] as num).toDouble(),
        spentAmount: (json['spentAmount'] as num).toDouble(),
        startDate: DateTime.tryParse(json['startDate'] as String? ?? '') ??
            DateTime.now(),
        endDate: DateTime.tryParse(json['endDate'] as String? ?? '') ??
            DateTime.now().add(const Duration(days: 30)),
        icon: json['icon'] as String? ?? '🏡',
        isSample: json['isSample'] as bool? ?? false,
      );

  Budget copyWith({
    String? id,
    String? name,
    String? category,
    double? targetAmount,
    double? spentAmount,
    DateTime? startDate,
    DateTime? endDate,
    String? icon,
    bool? isSample,
  }) {
    return Budget(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      targetAmount: targetAmount ?? this.targetAmount,
      spentAmount: spentAmount ?? this.spentAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      icon: icon ?? this.icon,
      isSample: isSample ?? this.isSample,
    );
  }
}

class ActivityInsight {
  final String id;
  final String tag;
  final String title;
  final String message;
  final String dateGroup;
  final Color cardColor;
  final String? icon;

  ActivityInsight({
    required this.id,
    required this.tag,
    required this.title,
    required this.message,
    required this.dateGroup,
    required this.cardColor,
    this.icon,
  });
}
