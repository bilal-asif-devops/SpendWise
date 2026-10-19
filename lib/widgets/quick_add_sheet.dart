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

  final List<Map<String, String>> _categories = [
    {"name": "Food", "icon": "🍔"},
    {"name": "Shopping", "icon": "🛍️"},
    {"name": "Transport", "icon": "🚗"},
    {"name": "Bills", "icon": "💡"},
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
      Provider.of<FinanceProvider>(context, listen: false).addExpense(
        title: "$_selectedCategory Expense",
        category: _selectedCategory,
        amount: parsed,
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Recorded $_selectedCategory: \$$parsed successfully!"),
          backgroundColor: AppColors.accentGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
          const SizedBox(height: 16),
          
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Quick add expense",
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
          const SizedBox(height: 10),

          // Large Amount Display
          Text(
            "\$$_amountStr",
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 20),

          // Category Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat["name"];
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat["name"]!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accentGreen.withOpacity(0.15) : AppColors.chipBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.accentGreen : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(cat["icon"]!, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(
                        cat["name"]!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppColors.accentGreen : AppColors.textDark,
                        ),
                      )
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Custom Numpad matching Figma Screen 2
          _buildNumpad(),
          const SizedBox(height: 20),

          // Save Expense Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () => _saveExpense(context),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text(
                "Save Expense",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        _buildNumpadRow(["1", "2", "3"]),
        const SizedBox(height: 12),
        _buildNumpadRow(["4", "5", "6"]),
        const SizedBox(height: 12),
        _buildNumpadRow(["7", "8", "9"]),
        const SizedBox(height: 12),
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
            height: 44,
            alignment: Alignment.center,
            child: Text(
              key,
              style: const TextStyle(
                fontSize: 22,
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
