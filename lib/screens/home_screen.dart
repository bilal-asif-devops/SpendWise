import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/quick_add_sheet.dart';
import 'subscriptions_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Avatar, Greeting and Notification Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor:
                            AppColors.accentGreen.withValues(alpha: 0.2),
                        child: Text(
                          finance.userName.isNotEmpty
                              ? finance.userName[0].toUpperCase()
                              : "B",
                          style: const TextStyle(
                            color: AppColors.accentGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Hello, ${finance.userName}",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const Text(
                            "Wed, 14 Oct 2026 · You're on track",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: const Icon(Icons.notifications_none,
                        color: AppColors.textDark, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Hero Card (Safe to Spend) matching Figma Blueprint
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryNavy.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
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
                          "Safe-to-Spend (Next 30 Days):",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_outlined,
                              color: AppColors.accentGreen, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${finance.currency}${finance.safeToSpendBalance.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Formula: Liquid Cash (${finance.currency}${finance.totalLiquidBalance.toStringAsFixed(0)}) - Pending Bills (${finance.currency}${finance.totalMonthlySubscriptions.toStringAsFixed(2)}) - Savings (${finance.currency}${finance.monthlySavingsGoal.toStringAsFixed(2)})",
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.75),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(
                        color: Colors.white.withValues(alpha: 0.15), height: 1),
                    const SizedBox(height: 10),
                    const Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: AppColors.accentGreen, size: 14),
                        SizedBox(width: 6),
                        Text(
                          "Bills covered. Breathe a little easier.",
                          style:
                              TextStyle(fontSize: 11.5, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Section: Your Wallets Carousel
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Your wallets",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    "Total: ${finance.currency}${finance.totalAllWalletsBalance.toStringAsFixed(0)}",
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: finance.accounts.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(width: 12),
                  itemBuilder: (ctx, idx) {
                    final acc = finance.accounts[idx];
                    return Container(
                      width: 145,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  acc.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(acc.icon,
                                  style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                          Text(
                            "${finance.currency}${acc.balance.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                          Text(
                            acc.isExcludedFromSafeToSpend
                                ? "Reserved · excluded"
                                : (acc.type == AccountType.credit
                                    ? "Liability owed"
                                    : "Liquid cash"),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: acc.isExcludedFromSafeToSpend
                                  ? AppColors.alertAmber
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),

              // Action Buttons Row: [+ Expense] [+ Sub] [Transfer]
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => const QuickAddExpenseSheet(),
                          );
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text("+ Expense",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textDark,
                          backgroundColor: AppColors.surfaceWhite,
                          side: const BorderSide(color: AppColors.borderLight),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        onPressed: () => _showAddSubDialog(context),
                        icon: const Icon(Icons.autorenew,
                            size: 17, color: AppColors.primaryNavy),
                        label: const Text("+ Sub",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textDark,
                          backgroundColor: AppColors.surfaceWhite,
                          side: const BorderSide(color: AppColors.borderLight),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        onPressed: () => _showTransferDialog(context),
                        icon: const Icon(Icons.swap_horiz,
                            size: 18, color: AppColors.primaryNavy),
                        label: const Text("Transfer",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12.5)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section: Upcoming Bills Ticker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Upcoming bills",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionsScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            "Radar (${finance.subscriptions.length})",
                            style: const TextStyle(
                                color: AppColors.accentGreen,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios,
                              size: 11, color: AppColors.accentGreen),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (finance.subscriptions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: const Center(
                    child: Text(
                      "No upcoming bills yet.",
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: finance.subscriptions.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final sub = finance.subscriptions[idx];
                    return _buildUpcomingSubCard(sub, finance.currency);
                  },
                ),
              const SizedBox(height: 24),

              // Section: Recent Transactions / Payments
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Recent transactions",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    "See all (${finance.expenses.length})",
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: finance.expenses.length,
                separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                itemBuilder: (ctx, idx) {
                  final item = finance.expenses[idx];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.chipBackground,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(item.icon,
                              style: const TextStyle(fontSize: 20)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    item.category,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppColors.chipBackground,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.walletName,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.primaryNavy,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "-${finance.currency}${item.amount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingSubCard(dynamic sub, String currency) {
    Color badgeColor;
    final nameLower = sub.name.toString().toLowerCase();
    if (nameLower.contains("netflix")) {
      badgeColor = Colors.red.shade600;
    } else if (nameLower.contains("spotify")) {
      badgeColor = const Color(0xFF1DB954);
    } else if (nameLower.contains("icloud") || nameLower.contains("apple")) {
      badgeColor = Colors.blue.shade700;
    } else if (nameLower.contains("gym") || nameLower.contains("fit")) {
      badgeColor = Colors.orange.shade700;
    } else if (nameLower.contains("amazon") || nameLower.contains("prime")) {
      badgeColor = const Color(0xFF00A8E1);
    } else if (nameLower.contains("youtube")) {
      badgeColor = const Color(0xFFFF0000);
    } else {
      badgeColor = AppColors.primaryNavy;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              sub.iconLetter,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  "${sub.walletName} · Due in ${sub.daysRemaining} days",
                  style: TextStyle(
                      fontSize: 12,
                      color: sub.daysRemaining <= 3
                          ? AppColors.alertAmber
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Text(
            "$currency${sub.amount.toStringAsFixed(2)}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showAddSubDialog(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context, listen: false);
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final daysCtrl = TextEditingController(text: "30");
    String selectedAccountId =
        finance.accounts.isNotEmpty ? finance.accounts.first.id : "acc_1";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text("New Subscription"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: "Service Name (e.g. Spotify, Gym)"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountCtrl,
                decoration:
                    const InputDecoration(labelText: "Monthly Amount (\$)"),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: daysCtrl,
                decoration:
                    const InputDecoration(labelText: "Days until next bill"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedAccountId,
                decoration: const InputDecoration(labelText: "Paying Wallet"),
                items: finance.accounts
                    .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(
                              "${a.name} (${finance.currency}${a.balance.toStringAsFixed(0)})"),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => selectedAccountId = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  foregroundColor: Colors.white),
              onPressed: () {
                final amt = double.tryParse(amountCtrl.text);
                if (nameCtrl.text.isNotEmpty && amt != null && amt > 0) {
                  finance.addSubscription(
                    name: nameCtrl.text,
                    category: "Entertainment",
                    amount: amt,
                    days: int.tryParse(daysCtrl.text) ?? 30,
                    accountId: selectedAccountId,
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransferDialog(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context, listen: false);
    if (finance.accounts.length < 2) return;

    String fromId = finance.accounts.first.id;
    String toId = finance.accounts[1].id;
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Transfer Between Wallets"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: fromId,
                decoration: const InputDecoration(labelText: "From Wallet"),
                items: finance.accounts
                    .map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(
                            "${a.name} (${finance.currency}${a.balance.toStringAsFixed(0)})")))
                    .toList(),
                onChanged: (val) => setState(() => fromId = val!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: toId,
                decoration: const InputDecoration(labelText: "To Wallet"),
                items: finance.accounts
                    .map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(
                            "${a.name} (${finance.currency}${a.balance.toStringAsFixed(0)})")))
                    .toList(),
                onChanged: (val) => setState(() => toId = val!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: "Transfer Amount"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  foregroundColor: Colors.white),
              onPressed: () {
                final amt = double.tryParse(amountCtrl.text);
                if (amt == null || amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          "Please enter a valid transfer amount greater than zero."),
                      backgroundColor: AppColors.alertRed,
                    ),
                  );
                  return;
                }
                final success = finance.transferBetweenAccounts(
                  fromAccountId: fromId,
                  toAccountId: toId,
                  amount: amt,
                );
                if (success) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          "Transferred ${finance.currency}${amt.toStringAsFixed(2)} successfully!"),
                      backgroundColor: AppColors.accentGreen,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(finance.lastErrorMessage ?? "Transfer failed."),
                      backgroundColor: AppColors.alertRed,
                    ),
                  );
                }
              },
              child: const Text("Transfer"),
            ),
          ],
        ),
      ),
    );
  }
}
