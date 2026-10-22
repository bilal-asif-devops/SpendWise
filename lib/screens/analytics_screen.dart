import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/finance_provider.dart';
import '../theme/app_theme.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context);

    if (finance.expenses.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text("Spending Analytics"),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pie_chart_outline_rounded,
                      size: 36,
                      color: AppColors.accentGreen,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "No spending data yet",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Log transactions manually or connect your accounts to view categorical spending breakdowns.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Compute dynamic category totals from actual expenses
    final Map<String, double> categoryTotals = {};
    for (final exp
        in finance.expenses.where((e) => e.type == TransactionType.expense)) {
      categoryTotals[exp.category] =
          (categoryTotals[exp.category] ?? 0.0) + exp.amount;
    }
    final totalSpent = finance.totalExpenses;

    final categoryColors = {
      "Food": const Color(0xFF10B981),
      "Shopping": const Color(0xFF3B82F6),
      "Transport": const Color(0xFFF59E0B),
      "Utilities": const Color(0xFF8B5CF6),
      "Entertainment": const Color(0xFFEC4899),
      "Health": const Color(0xFF06B6D4),
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Spending Analytics"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segmented Time Filter (Week / Month / Year)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.chipBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _buildTimeTab("Week", false),
                    _buildTimeTab("Month", true),
                    _buildTimeTab("Year", false),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Visual Donut Chart Breakdown
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Spending Breakdown",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 20),

                    // Custom Circular Visual Graphic
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        const SizedBox(
                          width: 170,
                          height: 170,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 20,
                            backgroundColor: AppColors.chipBackground,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.accentGreen),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${finance.currency}${totalSpent.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                            const Text(
                              "Total Spent",
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Dynamic Category Legend Rows
                    ...categoryTotals.entries.map((entry) {
                      final pct = totalSpent > 0
                          ? ((entry.value / totalSpent) * 100).round()
                          : 0;
                      final color =
                          categoryColors[entry.key] ?? AppColors.primaryNavy;
                      return _buildLegendRow(entry.key, "$pct%", color,
                          entry.value, finance.currency);
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Monthly Savings Target Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.savings_outlined,
                          color: AppColors.accentGreen, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Monthly Savings",
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                          if (finance.monthlySavingsGoal > 0) ...[
                            Text(
                              "${finance.currency}0.00 / ${finance.currency}${finance.monthlySavingsGoal.toStringAsFixed(0)} goal",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: const LinearProgressIndicator(
                                value: 0.0,
                                minHeight: 6,
                                backgroundColor: AppColors.chipBackground,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.accentGreen),
                              ),
                            ),
                          ] else
                            const Text(
                              "No savings goal configured.",
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeTab(String label, bool isSelected) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceWhite : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.textDark : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendRow(String label, String percent, Color dotColor,
      [double? amount, String? currency]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text(label,
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.textDark)),
            ],
          ),
          Row(
            children: [
              if (amount != null && currency != null) ...[
                Text(
                  "$currency${amount.toStringAsFixed(2)}",
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted),
                ),
                const SizedBox(width: 8),
              ],
              Text(percent,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textDark)),
            ],
          ),
        ],
      ),
    );
  }
}
