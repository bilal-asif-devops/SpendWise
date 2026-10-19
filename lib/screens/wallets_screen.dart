import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/finance_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Accounts & Wallets",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              "Cash is cash. Credit is a liability.",
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primaryNavy),
            onPressed: () => _showAddAccountDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner matching Figma Screen 2
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "LIQUID CASH · SAFE-TO-SPEND ENGINE",
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          "${finance.currency}${finance.totalLiquidBalance.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          "All wallets: ${finance.currency}${finance.totalAllWalletsBalance.toStringAsFixed(0)}",
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Spendee Total Wealth Spline Curve Graphic (Aug to Jan)
                    SizedBox(
                      height: 70,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: 5,
                          minY: 0,
                          maxY: 6,
                          lineBarsData: [
                            LineChartBarData(
                              spots: const [
                                FlSpot(0, 1.2),
                                FlSpot(1, 1.5),
                                FlSpot(2, 4.0),
                                FlSpot(3, 3.2),
                                FlSpot(4, 5.2),
                                FlSpot(5, 5.0),
                              ],
                              isCurved: true,
                              color: AppColors.accentGreen,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                checkToShowDot: (spot, barData) => spot.x == 5,
                                getDotPainter:
                                    (spot, percent, barData, index) =>
                                        FlDotCirclePainter(
                                            radius: 4,
                                            color: AppColors.accentGreen,
                                            strokeWidth: 2,
                                            strokeColor: Colors.white),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: AppColors.accentGreen.withValues(alpha: 0.15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Aug 2026",
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 10)),
                        Text("Oct 2026",
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 10)),
                        Text("Jan 2027 (Projected)",
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Liquid Accounts Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Liquid Accounts",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark),
                  ),
                  Text(
                    "${finance.liquidAccounts.length} accounts",
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.accentGreen,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: finance.liquidAccounts.length,
                  separatorBuilder: (ctx, idx) =>
                      const Divider(height: 1, indent: 64, endIndent: 16),
                  itemBuilder: (ctx, idx) {
                    final acc = finance.liquidAccounts[idx];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      leading: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(acc.icon,
                            style: const TextStyle(fontSize: 20)),
                      ),
                      title: Text(
                        acc.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      subtitle: Text(
                        acc.last4 != null
                            ? "Debit ·· ${acc.last4} · included"
                            : "Cash · included",
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                      trailing: Text(
                        "${finance.currency}${acc.balance.toStringAsFixed(0)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primaryNavy),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Credit Cards Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Credit Cards",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark),
                  ),
                  Text(
                    "${finance.creditAccounts.length} card",
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.alertRed,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (finance.creditAccounts.isNotEmpty) ...[
                ...finance.creditAccounts.map(
                    (card) => _buildCreditCardItem(context, card, finance)),
              ] else
                const Text("No credit cards added",
                    style: TextStyle(color: AppColors.textMuted)),

              const SizedBox(height: 14),

              // Caution Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.amber.shade800, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Available credit is borrowed capacity, not cash available to spend.",
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w500),
                      ),
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

  Widget _buildCreditCardItem(
      BuildContext context, Account card, FinanceProvider finance) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${card.name} ·· ${card.last4 ?? '0000'}",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Icon(Icons.credit_card, color: AppColors.primaryNavy),
            ],
          ),
          const SizedBox(height: 6),
          const Text("Current Liability / Owed Balance",
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(
            "${finance.currency}${card.balance.toStringAsFixed(2)}",
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          Text(
            "Available Credit Limit: ${finance.currency}${(card.creditLimit - card.balance).toStringAsFixed(0)} / ${finance.currency}${card.creditLimit.toStringAsFixed(0)}",
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.borderLight),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _showPayCreditCardDialog(context, card),
              icon: const Icon(Icons.swap_horiz,
                  size: 18, color: AppColors.primaryNavy),
              label: const Text("Pay Card Bill (Transfer)",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.primaryNavy)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();
    final last4Ctrl = TextEditingController();
    AccountType selectedType = AccountType.debit;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text("Add New Wallet"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: "Account Name (e.g. Revolut)")),
              TextField(
                  controller: balanceCtrl,
                  decoration:
                      const InputDecoration(labelText: "Opening Balance"),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: last4Ctrl,
                  decoration: const InputDecoration(
                      labelText: "Last 4 Digits (optional)"),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountType>(
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: "Account Type"),
                items: const [
                  DropdownMenuItem(
                      value: AccountType.debit,
                      child: Text("Debit Card / Bank")),
                  DropdownMenuItem(
                      value: AccountType.cash, child: Text("Cash Reserve")),
                  DropdownMenuItem(
                      value: AccountType.credit,
                      child: Text("Credit Card (Liability)")),
                ],
                onChanged: (val) => setState(() => selectedType = val!),
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
                final balance = double.tryParse(balanceCtrl.text) ?? 0.0;
                if (nameCtrl.text.isNotEmpty) {
                  Provider.of<FinanceProvider>(context, listen: false)
                      .addAccount(
                    Account(
                      id: "acc_${DateTime.now().millisecondsSinceEpoch}",
                      name: nameCtrl.text,
                      type: selectedType,
                      balance: balance,
                      creditLimit:
                          selectedType == AccountType.credit ? 2000.0 : 0.0,
                      last4: last4Ctrl.text.isNotEmpty ? last4Ctrl.text : null,
                      icon: selectedType == AccountType.cash ? "💵" : "💳",
                      isLiquid: selectedType != AccountType.credit,
                    ),
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text("Create"),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayCreditCardDialog(BuildContext context, Account creditCard) {
    final finance = Provider.of<FinanceProvider>(context, listen: false);
    final liquidAccounts = finance.liquidAccounts;
    if (liquidAccounts.isEmpty) return;

    String fromAccountId = liquidAccounts.first.id;
    final amountCtrl =
        TextEditingController(text: creditCard.balance.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text("Pay ${creditCard.name} Bill"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: fromAccountId,
                decoration:
                    const InputDecoration(labelText: "Pay from Account"),
                items: liquidAccounts
                    .map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(
                            "${a.name} (${finance.currency}${a.balance.toStringAsFixed(0)})")))
                    .toList(),
                onChanged: (val) => setState(() => fromAccountId = val!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: "Payment Amount"),
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
                if (amt != null && amt > 0) {
                  finance.transferBetweenAccounts(
                    fromAccountId: fromAccountId,
                    toAccountId: creditCard.id,
                    amount: amt,
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text("Pay Bill"),
            ),
          ],
        ),
      ),
    );
  }
}
