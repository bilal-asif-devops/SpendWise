import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/finance_provider.dart';
import '../theme/app_theme.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context);
    final budget = finance.budgets.isNotEmpty ? finance.budgets.first : null;

    final double spent =
        budget != null ? finance.calculateBudgetSpent(budget) : 0.0;
    final double target = budget?.targetAmount ?? 560.00;
    final double percentage = target > 0 ? (spent / target) : 0.0;
    final double clampedFactor = percentage.clamp(0.001, 1.0);
    final int displayPercent = (percentage * 100).round();
    final bool isOverBudget = percentage > 1.0;
    final Color progressColor =
        isOverBudget ? AppColors.alertRed : AppColors.accentGreen;

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final double dayProgress = (now.day / daysInMonth).clamp(0.0, 1.0);
    final double alignmentX = -1.0 + (dayProgress * 2.0);

    final double dailyAllowance = finance.dailySafeAllowance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              budget != null
                  ? "${budget.name} ${budget.icon}"
                  : "Home Budget 🏡",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: AppColors.textDark),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Hero Amount Section matching unnamed (1).webp
              Text(
                "${spent.toStringAsFixed(2)} ${finance.currency}",
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: progressColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "spent out of ${target.toStringAsFixed(2)} ${finance.currency}",
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),

              // Spending Trajectory Curve Chart matching Spendee
              Container(
                height: 180,
                padding: const EdgeInsets.only(right: 14, left: 4, top: 10),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (val) => const FlLine(
                        color: AppColors.borderLight,
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                          getTitlesWidget: (val, meta) {
                            if (val == 0) {
                              return Text("0 ${finance.currency}",
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted));
                            }
                            if (val == 280) {
                              return Text("280 ${finance.currency}",
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted));
                            }
                            if (val == 560) {
                              return Text("560 ${finance.currency}",
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted));
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            switch (val.toInt()) {
                              case 1:
                                return const Text("Sept 1",
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted));
                              case 10:
                                return const Text("Sept 10",
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted));
                              case 20:
                                return const Text("Sept 20",
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted));
                              case 30:
                                return const Text("Sept 30",
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted));
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 1,
                    maxX: 30,
                    minY: 0,
                    maxY: 600,
                    lineBarsData: [
                      // Target diagonal dashed line
                      LineChartBarData(
                        spots: const [
                          FlSpot(1, 0),
                          FlSpot(30, 560),
                        ],
                        isCurved: false,
                        color: Colors.grey.shade400,
                        barWidth: 1.5,
                        dashArray: [5, 5],
                        dotData: const FlDotData(show: false),
                      ),
                      // Actual Spending Trajectory Curve
                      LineChartBarData(
                        spots: const [
                          FlSpot(1, 0),
                          FlSpot(5, 120),
                          FlSpot(10, 80),
                          FlSpot(15, 230),
                          FlSpot(20, 308),
                        ],
                        isCurved: true,
                        color: Colors.amber.shade600,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          checkToShowDot: (spot, barData) => spot.x == 20,
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(
                                  radius: 5,
                                  color: Colors.amber.shade700,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Mint Daily Allowance Card matching Spendee
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt,
                        color: AppColors.accentGreen, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Keep spending. You can spend ${dailyAllowance.toStringAsFixed(2)} ${finance.currency} each day for the rest of the period.",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF065F46),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Segmented Progress Bar with "Today" indicator
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Today Badge
                    Align(
                      alignment: Alignment(alignmentX, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.darkCard,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "Today ▼",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          Container(
                              height: 18, color: AppColors.chipBackground),
                          FractionallySizedBox(
                            widthFactor: clampedFactor,
                            child: Container(
                              height: 18,
                              color: progressColor,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                "$displayPercent%",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            budget != null
                                ? _formatDate(budget.startDate)
                                : "Sept 1, 2026",
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                        Text(
                            budget != null
                                ? _formatDate(budget.endDate)
                                : "Sept 30, 2026",
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pie_chart_outline,
                              size: 16, color: AppColors.textDark),
                          SizedBox(width: 6),
                          Text("Budget Overview >",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.textDark)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section: Previous Periods
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Previous Periods",
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark),
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Spent 616 ${finance.currency} (110%)",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const Icon(Icons.warning_amber_rounded,
                            color: AppColors.alertRed, size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: const LinearProgressIndicator(
                        value: 1.0,
                        minHeight: 8,
                        backgroundColor: AppColors.chipBackground,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.alertRed),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Aug 24, 2026",
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                        Text("Aug 30, 2026",
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Recurring Subscriptions Radar Subsection
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Subscriptions Radar (Committed Bills)",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark),
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.autorenew,
                        color: AppColors.accentGreen, size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Total Monthly Subscriptions",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          Text(
                            "${finance.currency}${finance.totalMonthlySubscriptions.toStringAsFixed(2)}/mo",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text("${finance.subscriptions.length} Active",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
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
    return "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
  }
}
