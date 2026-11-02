import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../services/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Shared expense categories — must stay in sync with QuickAddExpenseSheet._expenseCategories
const List<Map<String, dynamic>> kExpenseCategories = [
  {"name": "Food & Drink", "icon": "🍔", "color": Color(0xFF10B981)},
  {"name": "Shopping", "icon": "🛍️", "color": Color(0xFF3B82F6)},
  {"name": "Transport", "icon": "🚗", "color": Color(0xFFF59E0B)},
  {"name": "Home", "icon": "🏡", "color": Color(0xFF6366F1)},
  {"name": "Bills & Fees", "icon": "💡", "color": Color(0xFFEF4444)},
  {"name": "Entertainment", "icon": "🍿", "color": Color(0xFFEC4899)},
  {"name": "Car", "icon": "🚙", "color": Color(0xFF06B6D4)},
  {"name": "Travel", "icon": "✈️", "color": Color(0xFF14B8A6)},
  {"name": "Healthcare", "icon": "💊", "color": Color(0xFFF43F5E)},
  {"name": "Education", "icon": "📚", "color": Color(0xFF8B5CF6)},
  {"name": "Groceries", "icon": "🛒", "color": Color(0xFF84CC16)},
  {"name": "Personal", "icon": "👤", "color": Color(0xFF64748B)},
];

/// Sentinel value meaning "match all expense categories"
const String kAllCategories = 'General Discretionary';

String _iconForCategory(String catName) {
  final match = kExpenseCategories.firstWhere(
    (c) => c['name'] == catName,
    orElse: () => <String, dynamic>{'icon': '📊'},
  );
  return match['icon'] as String;
}

Color _colorForCategory(String catName) {
  final match = kExpenseCategories.firstWhere(
    (c) => c['name'] == catName,
    orElse: () => <String, dynamic>{'color': AppColors.primaryNavy},
  );
  return match['color'] as Color;
}

bool _hasActiveBudgetForCategory(FinanceProvider finance, String categoryName) {
  final now = DateTime.now();
  return finance.budgets.any((b) =>
      !b.isSample &&
      b.category.toLowerCase() == categoryName.toLowerCase() &&
      !now.isBefore(b.startDate) &&
      !now.isAfter(b.endDate));
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Widget
// ─────────────────────────────────────────────────────────────────────────────

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  /// When non-null, we are in detail view for this budget.
  Budget? _selectedBudget;

  @override
  Widget build(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context);

    // If the selected budget was deleted, return to dashboard
    if (_selectedBudget != null) {
      final stillExists =
          finance.budgets.any((b) => b.id == _selectedBudget!.id);
      if (!stillExists) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedBudget = null);
        });
      }
    }

    if (_selectedBudget != null) {
      // Re-fetch the latest version of the budget in case it was updated
      final latestBudget = finance.budgets.firstWhere(
        (b) => b.id == _selectedBudget!.id,
        orElse: () => _selectedBudget!,
      );
      return _DetailView(
        budget: latestBudget,
        finance: finance,
        onBack: () => setState(() => _selectedBudget = null),
        onEdit: (b) => _showEditBudgetSheet(context, b),
        onDelete: (b) => _showDeleteBudgetDialog(context, b),
      );
    }

    return _DashboardView(
      finance: finance,
      onAddBudget: () => _showAddBudgetSheet(context),
      onSelectBudget: (b) => setState(() => _selectedBudget = b),
      onEditBudget: (b) => _showEditBudgetSheet(context, b),
      onDeleteBudget: (b) => _showDeleteBudgetDialog(context, b),
    );
  }

  // ─── Add Budget Bottom Sheet ──────────────────────────────────────────────

  void _showAddBudgetSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddBudgetSheet(
        onSave: (budget) {
          final finance = Provider.of<FinanceProvider>(context, listen: false);
          finance.addBudget(budget);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${budget.icon} ${budget.name} budget created!'),
              backgroundColor: AppColors.accentGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        finance: Provider.of<FinanceProvider>(context, listen: false),
      ),
    );
  }

  // ─── Edit Budget Bottom Sheet ─────────────────────────────────────────────

  void _showEditBudgetSheet(BuildContext context, Budget budget) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditBudgetSheet(
        budget: budget,
        onSave: (updated) {
          final finance = Provider.of<FinanceProvider>(context, listen: false);
          finance.updateBudget(updated);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Budget updated.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  // ─── Delete Confirmation Dialog ───────────────────────────────────────────

  void _showDeleteBudgetDialog(BuildContext context, Budget budget) {
    final finance = Provider.of<FinanceProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Budget'),
        content: Text("Are you sure you want to delete '${budget.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              finance.deleteBudget(budget.id);
              Navigator.pop(ctx);
              // Return to dashboard if we were in detail view
              if (_selectedBudget?.id == budget.id) {
                setState(() => _selectedBudget = null);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard View
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardView extends StatelessWidget {
  final FinanceProvider finance;
  final VoidCallback onAddBudget;
  final ValueChanged<Budget> onSelectBudget;
  final ValueChanged<Budget> onEditBudget;
  final ValueChanged<Budget> onDeleteBudget;

  const _DashboardView({
    required this.finance,
    required this.onAddBudget,
    required this.onSelectBudget,
    required this.onEditBudget,
    required this.onDeleteBudget,
  });

  @override
  Widget build(BuildContext context) {
    final nonSampleBudgets = finance.budgets.where((b) => !b.isSample).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 1.0,
        title: const Text(
          'Budgets',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline,
                color: AppColors.primaryNavy),
            tooltip: 'Add Category Budget',
            onPressed: onAddBudget,
          ),
        ],
      ),
      body: SafeArea(
        child: nonSampleBudgets.isEmpty
            ? _buildEmptyState(context)
            : _buildDashboard(context, nonSampleBudgets),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
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
              child: const Center(
                child: Text('🏡', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No budgets set yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textDarkOf(context),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first category budget to start tracking spending limits.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: onAddBudget,
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Create a Budget',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, List<Budget> budgets) {
    // Compute overall totals
    double totalTarget = 0;
    double totalSpent = 0;
    int overCount = 0;
    for (final b in budgets) {
      final spent = finance.calculateBudgetSpent(b);
      totalTarget += b.targetAmount;
      totalSpent += spent;
      if (spent > b.targetAmount) overCount++;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Summary Card
          _OverallSummaryCard(
            totalTarget: totalTarget,
            totalSpent: totalSpent,
            overCount: overCount,
            currency: finance.currency,
          ),
          const SizedBox(height: 20),

          Text(
            'Category Budgets',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDarkOf(context),
            ),
          ),
          const SizedBox(height: 12),

          // Budget Cards
          ...budgets.map((b) {
            final spent = finance.calculateBudgetSpent(b);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BudgetCard(
                budget: b,
                spent: spent,
                currency: finance.currency,
                onTap: () => onSelectBudget(b),
                onEdit: () => onEditBudget(b),
                onDelete: () => onDeleteBudget(b),
              ),
            );
          }),

          const SizedBox(height: 36),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overall Summary Card
// ─────────────────────────────────────────────────────────────────────────────

class _OverallSummaryCard extends StatelessWidget {
  final double totalTarget;
  final double totalSpent;
  final int overCount;
  final String currency;

  const _OverallSummaryCard({
    required this.totalTarget,
    required this.totalSpent,
    required this.overCount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final percentage =
        totalTarget > 0 ? (totalSpent / totalTarget).clamp(0.0, 1.0) : 0.0;
    final isOver = totalSpent > totalTarget;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOver
              ? [const Color(0xFF991B1B), const Color(0xFFDC2626)]
              : [AppColors.primaryNavy, const Color(0xFF1E3A5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isOver ? AppColors.alertRed : AppColors.primaryNavy)
                .withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Overall Budget',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              if (overCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.alertRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$overCount Over',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.format(totalSpent, currency),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Text(
                ' / ${CurrencyFormatter.format(totalTarget, currency)}',
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                isOver ? AppColors.alertRed : AppColors.accentGreen,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isOver
                ? 'Over by ${CurrencyFormatter.format(totalSpent - totalTarget, currency)}'
                : '${CurrencyFormatter.format(totalTarget - totalSpent, currency)} remaining',
            style: TextStyle(
              color: isOver ? const Color(0xFFFCA5A5) : AppColors.accentGreen,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Budget Card
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  final Budget budget;
  final double spent;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BudgetCard({
    required this.budget,
    required this.spent,
    required this.currency,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final target = budget.targetAmount;
    final isOverBudget = spent > target;
    final netRemaining = target - spent;
    final percentage = target > 0 ? (spent / target) : 0.0;
    final clampedPct = percentage.clamp(0.0, 1.0);
    final catColor = _colorForCategory(budget.category);

    // Status chip
    String statusLabel;
    Color statusColor;
    if (isOverBudget) {
      statusLabel = 'Over Budget';
      statusColor = AppColors.alertRed;
    } else if (percentage > 0.8) {
      statusLabel = 'Caution';
      statusColor = AppColors.alertAmber;
    } else {
      statusLabel = 'On Track';
      statusColor = AppColors.accentGreen;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isOverBudget
                ? AppColors.alertRed.withValues(alpha: 0.4)
                : AppColors.borderLight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Icon circle
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      budget.icon.isNotEmpty
                          ? budget.icon
                          : _iconForCategory(budget.category),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textDarkOf(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${CurrencyFormatter.format(target, currency)} limit',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                // Status chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: clampedPct,
                minHeight: 7,
                backgroundColor: AppColors.chipBackground,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOverBudget ? AppColors.alertRed : catColor,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Amounts row + action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spent: ${CurrencyFormatter.format(spent, currency)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isOverBudget
                            ? AppColors.alertRed
                            : AppColors.textDarkOf(context),
                      ),
                    ),
                    Text(
                      isOverBudget
                          ? 'Over by ${CurrencyFormatter.format(-netRemaining, currency)}'
                          : '${CurrencyFormatter.format(netRemaining, currency)} left',
                      style: TextStyle(
                        fontSize: 11,
                        color: isOverBudget
                            ? AppColors.alertRed
                            : AppColors.accentGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _IconAction(
                      icon: Icons.edit_outlined,
                      color: AppColors.primaryNavy,
                      tooltip: 'Edit',
                      onTap: onEdit,
                    ),
                    const SizedBox(width: 4),
                    _IconAction(
                      icon: Icons.delete_outline,
                      color: AppColors.alertRed,
                      tooltip: 'Delete',
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _IconAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail View
// ─────────────────────────────────────────────────────────────────────────────

class _DetailView extends StatelessWidget {
  final Budget budget;
  final FinanceProvider finance;
  final VoidCallback onBack;
  final ValueChanged<Budget> onEdit;
  final ValueChanged<Budget> onDelete;

  const _DetailView({
    required this.budget,
    required this.finance,
    required this.onBack,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final double spent = finance.calculateBudgetSpent(budget);
    final double target = budget.targetAmount;
    final double percentage = target > 0 ? (spent / target) : 0.0;
    final double clampedFactor = percentage.clamp(0.001, 1.0);
    final int displayPercent = (percentage * 100).round();
    final bool isOverBudget = percentage > 1.0;
    final double remaining = target - spent;

    final Color progressColor =
        isOverBudget ? AppColors.alertRed : AppColors.accentGreen;

    final now = DateTime.now();
    final int totalDays =
        budget.endDate.difference(budget.startDate).inDays + 1;
    final int elapsedDays = now.isBefore(budget.startDate)
        ? 0
        : (now.isAfter(budget.endDate)
            ? totalDays
            : now.difference(budget.startDate).inDays + 1);
    final double dayProgress =
        totalDays > 0 ? (elapsedDays / totalDays).clamp(0.0, 1.0) : 0.0;
    final double alignmentX = -1.0 + (dayProgress * 2.0);

    final int daysRemainingInBudget =
        finance.calculateBudgetDaysRemaining(budget, now);
    final double dailyAllowance =
        finance.calculateDailyBudgetAllowance(budget, now);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 1.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: onBack,
          tooltip: 'Back to Budgets',
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${budget.name} ${budget.icon.isNotEmpty ? budget.icon : _iconForCategory(budget.category)}',
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primaryNavy),
            tooltip: 'Edit Budget',
            onPressed: () => onEdit(budget),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.alertRed),
            tooltip: 'Delete Budget',
            onPressed: () => onDelete(budget),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Hero Amount Section
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  CurrencyFormatter.format(spent, finance.currency),
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: progressColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'spent out of ${CurrencyFormatter.format(target, finance.currency)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              // Spending Trajectory Curve Chart Card
              _buildTrajectoryChartCard(
                context: context,
                finance: finance,
                budget: budget,
                spent: spent,
                target: target,
                totalDays: totalDays,
                progressColor: progressColor,
                now: now,
              ),
              const SizedBox(height: 20),

              // Dynamic Daily Allowance Status Card
              _buildDailyAllowanceCard(
                finance: finance,
                budget: budget,
                spent: spent,
                target: target,
                remaining: remaining,
                isOverBudget: isOverBudget,
                displayPercent: displayPercent,
                daysRemaining: daysRemainingInBudget,
                dailyAllowance: dailyAllowance,
              ),
              const SizedBox(height: 20),

              // Segmented Progress Bar with "Today" indicator
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
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
                          'Today ▼',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
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
                              height: 20, color: AppColors.chipBackground),
                          FractionallySizedBox(
                            widthFactor: clampedFactor,
                            child: Container(
                              height: 20,
                              color: progressColor,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                '$displayPercent%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
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
                          _formatDate(budget.startDate),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                        ),
                        Text(
                          isOverBudget
                              ? 'Over by ${CurrencyFormatter.format(spent - target, finance.currency)}'
                              : '${CurrencyFormatter.format(remaining, finance.currency)} left',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isOverBudget
                                ? AppColors.alertRed
                                : AppColors.accentGreen,
                          ),
                        ),
                        Text(
                          _formatDate(budget.endDate),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pie_chart_outline,
                              size: 16, color: AppColors.textDarkOf(context)),
                          const SizedBox(width: 6),
                          Text(
                            'Category: ${budget.category}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textDarkOf(context),
                            ),
                          ),
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
                  'Previous Periods',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildPreviousPeriodCard(context, finance, budget),
              const SizedBox(height: 24),

              // Recurring Subscriptions Radar Subsection
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Subscriptions Radar (Committed Bills)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
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
                          const Text(
                            'Total Monthly Subscriptions',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Text(
                            '${CurrencyFormatter.format(finance.totalMonthlySubscriptions, finance.currency)}/mo',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
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
                      child: Text(
                        '${finance.subscriptions.length} Active',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
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

  Widget _buildTrajectoryChartCard({
    required BuildContext context,
    required FinanceProvider finance,
    required Budget budget,
    required double spent,
    required double target,
    required int totalDays,
    required Color progressColor,
    required DateTime now,
  }) {
    final cumulativeData = finance.getBudgetCumulativeSpending(budget, now);

    final List<FlSpot> actualSpots = [];
    cumulativeData.forEach((day, cumulative) {
      actualSpots.add(FlSpot(day.toDouble(), cumulative));
    });
    if (actualSpots.isEmpty) {
      actualSpots.add(const FlSpot(1, 0));
    }

    final double maxActual = actualSpots.map((s) => s.y).fold(0.0, math.max);
    final double rawMax = math.max(target, maxActual);
    final double maxY = rawMax > 0 ? (rawMax * 1.18) : 100.0;

    final targetSpots = [
      const FlSpot(1, 0),
      FlSpot(totalDays.toDouble(), target > 0 ? target : maxY * 0.8),
    ];

    final int currentDay = now.isBefore(budget.startDate)
        ? 0
        : (now.isAfter(budget.endDate)
            ? totalDays
            : now.difference(budget.startDate).inDays + 1);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Spending Trajectory',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 2,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 4),
                  const Text('Target',
                      style:
                          TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  const SizedBox(width: 10),
                  Container(
                    width: 14,
                    height: 2,
                    color: progressColor,
                  ),
                  const SizedBox(width: 4),
                  const Text('Spent',
                      style:
                          TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
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
                      reservedSize: 52,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) {
                          return Text(
                            CurrencyFormatter.formatCompact(
                                0, finance.currency),
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textMuted),
                          );
                        }
                        if (target > 0 &&
                            (val - target).abs() < (maxY * 0.08)) {
                          return Text(
                            CurrencyFormatter.formatCompact(
                                target, finance.currency),
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textMuted),
                          );
                        }
                        if ((val - (maxY * 0.5)).abs() < (maxY * 0.08)) {
                          return Text(
                            CurrencyFormatter.formatCompact(
                                maxY * 0.5, finance.currency),
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textMuted),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (val, meta) {
                        final dayInt = val.toInt();
                        if (dayInt == 1) {
                          return Text(
                            '${_shortMonth(budget.startDate.month)} 1',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textMuted),
                          );
                        }
                        if (dayInt == totalDays) {
                          return Text(
                            '${_shortMonth(budget.endDate.month)} ${budget.endDate.day}',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textMuted),
                          );
                        }
                        if (totalDays >= 20) {
                          final step1 = (totalDays * 0.33).round();
                          final step2 = (totalDays * 0.67).round();
                          if (dayInt == step1 || dayInt == step2) {
                            return Text(
                              'Day $dayInt',
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.textMuted),
                            );
                          }
                        } else if (totalDays >= 10 &&
                            dayInt == (totalDays ~/ 2)) {
                          return Text(
                            'Day $dayInt',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textMuted),
                          );
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
                maxX: totalDays.toDouble(),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  // Target guideline
                  LineChartBarData(
                    spots: targetSpots,
                    isCurved: false,
                    color: Colors.grey.shade400,
                    barWidth: 1.5,
                    dashArray: [5, 5],
                    dotData: const FlDotData(show: false),
                  ),
                  // Real spending curve
                  LineChartBarData(
                    spots: actualSpots,
                    isCurved: actualSpots.length > 2,
                    color: progressColor,
                    barWidth: 2.8,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, barData) =>
                          spot.x == currentDay.toDouble() ||
                          spot == actualSpots.last,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 4.5,
                        color: progressColor,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyAllowanceCard({
    required FinanceProvider finance,
    required Budget budget,
    required double spent,
    required double target,
    required double remaining,
    required bool isOverBudget,
    required int displayPercent,
    required int daysRemaining,
    required double dailyAllowance,
  }) {
    if (isOverBudget) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.alertRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.alertRed.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.alertRed, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Budget exceeded by ${CurrencyFormatter.format(spent - target, finance.currency)} ($displayPercent%). No daily spending allowance remains for this period.',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF991B1B),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (remaining <= 0 && target > 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.alertAmber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppColors.alertAmber.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                color: AppColors.alertAmber, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Budget limit reached (${CurrencyFormatter.format(target, finance.currency)} spent). 0 daily allowance remaining for the rest of the period.',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (target <= 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.chipBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.help_outline, color: AppColors.textMuted, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No spending limit configured. Edit this budget to set a target limit and track daily allowances.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F7F0),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.accentGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: AppColors.accentGreen, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'On track! You can spend ${CurrencyFormatter.format(dailyAllowance, finance.currency)} each day for the rest of the period ($daysRemaining ${daysRemaining == 1 ? 'day' : 'days'} left).',
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
    );
  }

  Widget _buildPreviousPeriodCard(
      BuildContext context, FinanceProvider finance, Budget budget) {
    final prevStart = DateTime(
      budget.startDate.year,
      budget.startDate.month - 1,
      budget.startDate.day,
    );
    final prevEnd = DateTime(
      budget.startDate.year,
      budget.startDate.month,
      0,
      23,
      59,
      59,
    );

    final prevBudget = budget.copyWith(startDate: prevStart, endDate: prevEnd);
    final double prevSpent = finance.calculateBudgetSpent(prevBudget);
    final double target = budget.targetAmount;
    final double prevPercent = target > 0 ? (prevSpent / target) : 0.0;
    final int prevDisplayPercent = (prevPercent * 100).round();
    final bool prevOver = prevPercent > 1.0;

    if (prevSpent <= 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            const Icon(Icons.history, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No expenses logged in previous period (${_formatDate(prevStart)} - ${_formatDate(prevEnd)}).',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
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
                'Spent ${CurrencyFormatter.format(prevSpent, finance.currency)} ($prevDisplayPercent%)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: prevOver
                      ? AppColors.alertRed
                      : AppColors.textDarkOf(context),
                ),
              ),
              if (prevOver)
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.alertRed, size: 18)
              else
                const Icon(Icons.check_circle_outline,
                    color: AppColors.accentGreen, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: prevPercent.clamp(0.001, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.chipBackground,
              valueColor: AlwaysStoppedAnimation<Color>(
                prevOver ? AppColors.alertRed : AppColors.accentGreen,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDate(prevStart),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
              Text(_formatDate(prevEnd),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  static String _shortMonth(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sept',
      'Oct',
      'Nov',
      'Dec'
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }

  static String _formatDate(DateTime dt) {
    return '${_shortMonth(dt.month)} ${dt.day}, ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Budget Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AddBudgetSheet extends StatefulWidget {
  final void Function(Budget) onSave;
  final FinanceProvider finance;

  const _AddBudgetSheet({required this.onSave, required this.finance});

  @override
  State<_AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends State<_AddBudgetSheet> {
  String _selectedCategory = kAllCategories;
  final _amountCtrl = TextEditingController(text: '');
  String? _amountError;
  bool _showDuplicateWarning = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  String _periodLabel() {
    final now = DateTime.now();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[now.month - 1]} ${now.year}';
  }

  void _handleSave(BuildContext ctx) {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      setState(
          () => _amountError = 'Please enter a valid amount greater than 0.');
      return;
    }

    final hasDuplicate =
        _hasActiveBudgetForCategory(widget.finance, _selectedCategory);
    if (hasDuplicate && !_showDuplicateWarning) {
      setState(() => _showDuplicateWarning = true);
      return;
    }

    final now = DateTime.now();
    final icon = _selectedCategory == kAllCategories
        ? '📊'
        : _iconForCategory(_selectedCategory);
    final budget = Budget(
      id: 'bgt_${DateTime.now().millisecondsSinceEpoch}',
      name: _selectedCategory == kAllCategories
          ? 'Monthly Budget'
          : _selectedCategory,
      category: _selectedCategory,
      targetAmount: amount,
      spentAmount: 0.0,
      startDate: DateTime(now.year, now.month, 1),
      endDate: DateTime(now.year, now.month + 1, 0),
      icon: icon,
      isSample: false,
    );

    widget.onSave(budget);
    Navigator.pop(ctx);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add Category Budget',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  // Period label
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined,
                            size: 16, color: AppColors.accentGreen),
                        const SizedBox(width: 8),
                        Text(
                          'Period: ${_periodLabel()}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Category',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 10),

                  // Category chips: "All Categories" first, then others
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CategoryChip(
                        emoji: '📊',
                        name: 'All Categories',
                        isSelected: _selectedCategory == kAllCategories,
                        onTap: () => setState(() {
                          _selectedCategory = kAllCategories;
                          _showDuplicateWarning = false;
                        }),
                      ),
                      ...kExpenseCategories.map((cat) {
                        final name = cat['name'] as String;
                        final icon = cat['icon'] as String;
                        return _CategoryChip(
                          emoji: icon,
                          name: name,
                          isSelected: _selectedCategory == name,
                          onTap: () => setState(() {
                            _selectedCategory = name;
                            _showDuplicateWarning = false;
                          }),
                        );
                      }),
                    ],
                  ),

                  // Duplicate warning
                  if (_showDuplicateWarning) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.alertAmber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.alertAmber.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: AppColors.alertAmber, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'A budget for "$_selectedCategory" already exists for this period. Tap Save again to replace it.',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF92400E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => setState(
                                      () => _showDuplicateWarning = false),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.alertAmber,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => _handleSave(context),
                                  child: const Text('Replace'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  const Text(
                    'Monthly Limit',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      prefixText: '${widget.finance.currency} ',
                      errorText: _amountError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppColors.accentGreen, width: 2),
                      ),
                    ),
                    onChanged: (_) {
                      if (_amountError != null) {
                        setState(() => _amountError = null);
                      }
                    },
                  ),

                  const SizedBox(height: 28),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () => _handleSave(context),
                      child: const Text(
                        'Save Budget',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Budget Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditBudgetSheet extends StatefulWidget {
  final Budget budget;
  final void Function(Budget) onSave;

  const _EditBudgetSheet({required this.budget, required this.onSave});

  @override
  State<_EditBudgetSheet> createState() => _EditBudgetSheetState();
}

class _EditBudgetSheetState extends State<_EditBudgetSheet> {
  late TextEditingController _amountCtrl;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: widget.budget.targetAmount.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _handleSave(BuildContext ctx) {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      setState(
          () => _amountError = 'Please enter a valid amount greater than 0.');
      return;
    }
    widget.onSave(widget.budget.copyWith(targetAmount: amount));
    Navigator.pop(ctx);
  }

  @override
  Widget build(BuildContext context) {
    final catIcon = widget.budget.icon.isNotEmpty
        ? widget.budget.icon
        : _iconForCategory(widget.budget.category);
    final catColor = _colorForCategory(widget.budget.category);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title row
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Edit Budget',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category display (read-only)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: catColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Text(catIcon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.budget.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      Text(
                        widget.budget.category,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.chipBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Category locked',
                      style:
                          TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Monthly Limit',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _amountCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0.00',
                errorText: _amountError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.accentGreen, width: 2),
                ),
              ),
              onChanged: (_) {
                if (_amountError != null) {
                  setState(() => _amountError = null);
                }
              },
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () => _handleSave(context),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Chip
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String emoji;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.emoji,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentGreen.withValues(alpha: 0.15)
              : AppColors.chipBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accentGreen : AppColors.borderLight,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.accentGreen
                    : AppColors.textDarkOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
