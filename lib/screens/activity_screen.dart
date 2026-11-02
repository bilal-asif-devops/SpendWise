import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../services/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context);

    // Filter real expenses
    final expenses = finance.expenses
        .where((e) =>
            e.type == TransactionType.expense &&
            e.amount.isFinite &&
            !e.amount.isNaN &&
            e.amount > 0)
        .toList();

    // Group real expenses by category
    final Map<String, double> categoryTotals = {};
    final Map<String, int> categoryCounts = {};
    final Map<String, String> categoryIcons = {};

    for (final exp in expenses) {
      final cat =
          exp.category.trim().isNotEmpty ? exp.category.trim() : 'Other';
      categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + exp.amount;
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      if (!categoryIcons.containsKey(cat) || categoryIcons[cat] == '💳') {
        categoryIcons[cat] = exp.icon.isNotEmpty ? exp.icon : '💳';
      }
    }

    final double totalExpensesSpent =
        categoryTotals.values.fold(0.0, (sum, val) => sum + val);

    final sortedCategories = categoryTotals.keys.toList()
      ..sort((a, b) => categoryTotals[b]!.compareTo(categoryTotals[a]!));

    final now = DateTime.now();

    // Financial Health Calculations
    final double totalIncome = finance.totalIncome;
    final double liquidBalance = finance.totalLiquidBalance;
    final double netSavings = totalIncome - totalExpensesSpent;

    String healthTitle;
    String healthMessage;
    if (totalIncome > 0 && netSavings >= 0) {
      healthTitle = "Your financial health is strong!";
      healthMessage =
          "You earned ${CurrencyFormatter.format(netSavings, finance.currency)} more than you spent. Liquid reserves stand at ${CurrencyFormatter.format(liquidBalance, finance.currency)}.";
    } else if (totalExpensesSpent > totalIncome && totalIncome > 0) {
      healthTitle = "Spending exceeded income";
      healthMessage =
          "Total expenses (${CurrencyFormatter.format(totalExpensesSpent, finance.currency)}) exceeded income by ${CurrencyFormatter.format(totalExpensesSpent - totalIncome, finance.currency)}. Liquid reserves stand at ${CurrencyFormatter.format(liquidBalance, finance.currency)}.";
    } else if (totalExpensesSpent > 0) {
      healthTitle = "Discretionary spending active";
      healthMessage =
          "Total expenses recorded: ${CurrencyFormatter.format(totalExpensesSpent, finance.currency)} across ${expenses.length} ${expenses.length == 1 ? 'transaction' : 'transactions'}. Reserves stand at ${CurrencyFormatter.format(liquidBalance, finance.currency)}.";
    } else {
      healthTitle = "Ready to build wealth!";
      healthMessage =
          "Your liquid reserve is ${CurrencyFormatter.format(liquidBalance, finance.currency)} with ${CurrencyFormatter.format(finance.safeToSpendBalance, finance.currency)} safe to spend.";
    }

    // Curve spots for Financial Health card
    final thisMonthExpenses = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();
    final List<FlSpot> healthSpots = [];
    if (thisMonthExpenses.isNotEmpty) {
      final Map<int, double> daysSpend = {};
      for (final e in thisMonthExpenses) {
        daysSpend[e.date.day] = (daysSpend[e.date.day] ?? 0.0) + e.amount;
      }
      double cum = 0;
      for (int d = 1; d <= now.day; d++) {
        cum += daysSpend[d] ?? 0.0;
        healthSpots.add(FlSpot(d.toDouble(), cum));
      }
    } else {
      healthSpots.addAll(const [
        FlSpot(0, 1.0),
        FlSpot(1, 1.5),
        FlSpot(2, 2.0),
        FlSpot(3, 2.8),
        FlSpot(4, 3.5),
      ]);
    }

    // Yesterday Insight Calculations
    final yesterdayDate = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    final yesterdayExpenses = expenses.where((e) {
      final expDay = DateTime(e.date.year, e.date.month, e.date.day);
      return expDay.isAtSameMomentAs(yesterdayDate);
    }).toList();
    final double yesterdaySpent =
        yesterdayExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final double dailyAvg = now.day > 0 ? (totalExpensesSpent / now.day) : 0.0;

    String yesterdayTitle;
    String yesterdayMessage;
    if (yesterdaySpent <= 0) {
      yesterdayTitle = "Good job!";
      yesterdayMessage =
          "Yesterday you spent ${CurrencyFormatter.format(0, finance.currency)}, keeping discretionary spending below your daily average.";
    } else if (yesterdaySpent <= dailyAvg) {
      yesterdayTitle = "On budget yesterday!";
      yesterdayMessage =
          "Yesterday you spent ${CurrencyFormatter.format(yesterdaySpent, finance.currency)}, which was ${CurrencyFormatter.format(dailyAvg - yesterdaySpent, finance.currency)} below your daily average.";
    } else {
      yesterdayTitle = "Yesterday's spending";
      yesterdayMessage =
          "Yesterday you spent ${CurrencyFormatter.format(yesterdaySpent, finance.currency)} across ${yesterdayExpenses.length} ${yesterdayExpenses.length == 1 ? 'transaction' : 'transactions'}.";
    }

    // Distinct palette for categories
    const List<Color> palette = [
      Color(0xFFF59E0B), // Amber
      Color(0xFF10B981), // Emerald
      Color(0xFF3B82F6), // Blue
      Color(0xFFEC4899), // Pink
      Color(0xFF8B5CF6), // Purple
      Color(0xFF06B6D4), // Cyan
      Color(0xFFEF4444), // Red
      Color(0xFF64748B), // Slate
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Smart insights",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 1.0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section: Today
              Text(
                "Today",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDarkOf(context),
                ),
              ),
              const SizedBox(height: 12),

              // Emerald Financial Health Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGreen.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "FINANCIAL HEALTH",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      healthTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      healthMessage,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Smooth White Spline Curve
                    SizedBox(
                      height: 65,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          minX: healthSpots.first.x,
                          maxX: healthSpots.last.x,
                          minY: 0,
                          maxY:
                              healthSpots.map((s) => s.y).fold(1.0, math.max) *
                                  1.15,
                          lineBarsData: [
                            LineChartBarData(
                              spots: healthSpots,
                              isCurved: healthSpots.length > 2,
                              color: Colors.white,
                              barWidth: 2.5,
                              dotData: const FlDotData(show: false),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _monthLabel(now.month - 2),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10),
                        ),
                        Text(
                          _monthLabel(now.month - 1),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10),
                        ),
                        Text(
                          _monthLabel(now.month),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section: Yesterday
              Text(
                "Yesterday",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDarkOf(context),
                ),
              ),
              const SizedBox(height: 12),

              // Amber Insight Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Text("🍽️", style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "INSIGHT",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            yesterdayTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            yesterdayMessage,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Amazing Fact Card based on real user spending
              _buildAmazingFactCard(
                context: context,
                sortedCategories: sortedCategories,
                categoryTotals: categoryTotals,
                categoryCounts: categoryCounts,
                categoryIcons: categoryIcons,
                totalExpensesSpent: totalExpensesSpent,
                currency: finance.currency,
              ),
              const SizedBox(height: 24),

              // Section: Money Overview (Categories)
              Text(
                "Money overview (Categories)",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDarkOf(context),
                ),
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: sortedCategories.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            const Icon(Icons.pie_chart_outline,
                                size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              "No spending activity yet",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDarkOf(context),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "Record your expenses or import statements to see your category breakdown.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 180,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 3,
                                centerSpaceRadius: 52,
                                sections: List.generate(
                                  sortedCategories.length,
                                  (i) {
                                    final cat = sortedCategories[i];
                                    final amt = categoryTotals[cat]!;
                                    final pct = totalExpensesSpent > 0
                                        ? (amt / totalExpensesSpent) * 100
                                        : 0.0;
                                    final color = palette[i % palette.length];
                                    return PieChartSectionData(
                                      color: color,
                                      value: amt,
                                      title: pct >= 6 ? "${pct.round()}%" : "",
                                      radius: 36,
                                      titleStyle: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(sortedCategories.length, (i) {
                            final cat = sortedCategories[i];
                            final amt = categoryTotals[cat]!;
                            final count = categoryCounts[cat]!;
                            final color = palette[i % palette.length];
                            final icon = categoryIcons[cat] ?? '💳';
                            return _buildCategoryRow(
                              cat,
                              "$count ${count == 1 ? 'transaction' : 'transactions'}",
                              CurrencyFormatter.formatExpense(
                                  amt, finance.currency),
                              color,
                              icon,
                            );
                          }),
                        ],
                      ),
              ),
              // Generous bottom spacing so cards never get clipped by the navigation bar
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmazingFactCard({
    required BuildContext context,
    required List<String> sortedCategories,
    required Map<String, double> categoryTotals,
    required Map<String, int> categoryCounts,
    required Map<String, String> categoryIcons,
    required double totalExpensesSpent,
    required String currency,
  }) {
    if (sortedCategories.isNotEmpty) {
      final topCat = sortedCategories.first;
      final double topAmt = categoryTotals[topCat]!;
      final int topCount = categoryCounts[topCat]!;
      final String topIcon = categoryIcons[topCat] ?? '🍗';
      final int pct = totalExpensesSpent > 0
          ? ((topAmt / totalExpensesSpent) * 100).round()
          : 0;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "AMAZING FACT",
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "This period, you've spent ${CurrencyFormatter.format(topAmt, currency)} on $topCat",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textDarkOf(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$topCat represents $pct% of your discretionary spending across $topCount ${topCount == 1 ? 'transaction' : 'transactions'}.",
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(topIcon, style: const TextStyle(fontSize: 34)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "AMAZING FACT",
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Smart budgeting can unlock 15-20% savings",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textDarkOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Tracking expenses consistently helps identify recurring subscriptions and discretionary leakages.",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Text("💡", style: TextStyle(fontSize: 34)),
        ],
      ),
    );
  }

  static String _monthLabel(int month) {
    var m = month;
    while (m <= 0) {
      m += 12;
    }
    while (m > 12) {
      m -= 12;
    }
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sept",
      "Oct",
      "Nov",
      "Dec"
    ];
    return months[m - 1];
  }

  Widget _buildCategoryRow(
      String title, String count, String amount, Color color, String icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(icon, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  count,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
