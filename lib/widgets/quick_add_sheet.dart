import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/finance_provider.dart';
import '../theme/app_theme.dart';

class QuickAddExpenseSheet extends StatefulWidget {
  const QuickAddExpenseSheet({super.key});

  @override
  State<QuickAddExpenseSheet> createState() => _QuickAddExpenseSheetState();
}

class _QuickAddExpenseSheetState extends State<QuickAddExpenseSheet> {
  String _amountStr = "0.00";
  String _selectedCategory = "Food";
  String? _selectedAccountId;
  final TextEditingController _noteController = TextEditingController();

  final List<Map<String, String>> _categories = [
    {"name": "Food", "icon": "🍔"},
    {"name": "Shopping", "icon": "🛍️"},
    {"name": "Transport", "icon": "🚗"},
    {"name": "Utilities", "icon": "💡"},
    {"name": "Entertainment", "icon": "🍿"},
  ];

  void _onKeyPress(String val) {
    setState(() {
      if (_amountStr == "0.00" || _amountStr == "0") {
        _amountStr = val;
      } else {
        _amountStr += val;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_amountStr.length > 1) {
        _amountStr = _amountStr.substring(0, _amountStr.length - 1);
      } else {
        _amountStr = "0.00";
      }
    });
  }

  void _saveExpense(BuildContext context) {
    final double? parsed = double.tryParse(_amountStr);
    if (parsed != null && parsed > 0) {
      final finance = Provider.of<FinanceProvider>(context, listen: false);
      final accountId = _selectedAccountId ??
          (finance.accounts.isNotEmpty ? finance.accounts.first.id : "acc_1");

      finance.addExpense(
        title: "$_selectedCategory Expense",
        category: _selectedCategory,
        amount: parsed,
        accountId: accountId,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Recorded $_selectedCategory: ${finance.currency}$parsed successfully!"),
          backgroundColor: AppColors.accentGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context);
    final accounts = finance.accounts;
    _selectedAccountId ??= accounts.isNotEmpty ? accounts.first.id : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Add transaction",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 4),

            // Large Amount Display
            Text(
              "${finance.currency}$_amountStr",
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 14),

            // Category Chips (Horizontal Scrollable)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat["name"];
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedCategory = cat["name"]!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accentGreen.withValues(alpha: 0.15)
                            : AppColors.chipBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accentGreen
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(cat["icon"]!,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            cat["name"]!,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.accentGreen
                                  : AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Pay with Account Dropdown matching Figma Screen 4
            if (accounts.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.chipBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedAccountId,
                    items: accounts.map((acc) {
                      return DropdownMenuItem<String>(
                        value: acc.id,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Pay with: ${acc.name}",
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              "${finance.currency}${acc.balance.toStringAsFixed(0)}",
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryNavy),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedAccountId = val);
                    },
                  ),
                ),
              ),
            const SizedBox(height: 14),

            // Custom Numpad
            _buildNumpad(),
            const SizedBox(height: 16),

            // Save Expense Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () => _saveExpense(context),
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text(
                  "Save Transaction",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        _buildNumpadRow(["1", "2", "3"]),
        const SizedBox(height: 10),
        _buildNumpadRow(["4", "5", "6"]),
        const SizedBox(height: 10),
        _buildNumpadRow(["7", "8", "9"]),
        const SizedBox(height: 10),
        _buildNumpadRow([".", "0", "⌫"]),
      ],
    );
  }

  Widget _buildNumpadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        return InkWell(
          onTap: () {
            if (key == "⌫") {
              _onBackspace();
            } else {
              _onKeyPress(key);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 70,
            height: 40,
            alignment: Alignment.center,
            child: Text(
              key,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
