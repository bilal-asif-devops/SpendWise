class Expense {
  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final String icon;

  Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.icon,
  });
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

  Subscription({
    required this.id,
    required this.name,
    required this.category,
    required this.amount,
    required this.nextBillingDate,
    required this.iconLetter,
    required this.daysRemaining,
    required this.isDueSoon,
  });
}
