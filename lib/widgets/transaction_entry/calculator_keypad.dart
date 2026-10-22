import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class CalculatorKeypad extends StatelessWidget {
  final Function(String digit) onDigit;
  final Function(String operator) onOperator;
  final VoidCallback onDecimal;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onEquals;
  final bool hasPendingOperation;

  const CalculatorKeypad({
    super.key,
    required this.onDigit,
    required this.onOperator,
    required this.onDecimal,
    required this.onBackspace,
    required this.onClear,
    required this.onEquals,
    this.hasPendingOperation = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(context, ["7", "8", "9", "÷"]),
        const SizedBox(height: 8),
        _buildRow(context, ["4", "5", "6", "×"]),
        const SizedBox(height: 8),
        _buildRow(context, ["1", "2", "3", "-"]),
        const SizedBox(height: 8),
        _buildRow(context, [".", "0", "⌫", "+"]),
      ],
    );
  }

  Widget _buildRow(BuildContext context, List<String> items) {
    return Row(
      children: items.map((item) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildKey(context, item),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKey(BuildContext context, String key) {
    final isOperator = key == "÷" || key == "×" || key == "-" || key == "+";
    final isBackspace = key == "⌫";

    return Material(
      color: isOperator
          ? AppColors.primaryNavy.withValues(alpha: 0.08)
          : AppColors.chipBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey('keypad_$key'),
        onTap: () {
          if (key == "⌫") {
            onBackspace();
          } else if (key == ".") {
            onDecimal();
          } else if (isOperator) {
            onOperator(key);
          } else {
            onDigit(key);
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: isBackspace
              ? const Icon(
                  Icons.backspace_outlined,
                  size: 20,
                  color: AppColors.textDark,
                )
              : Text(
                  key,
                  style: TextStyle(
                    fontSize: isOperator ? 22 : 20,
                    fontWeight: isOperator ? FontWeight.bold : FontWeight.w600,
                    color:
                        isOperator ? AppColors.primaryNavy : AppColors.textDark,
                  ),
                ),
        ),
      ),
    );
  }
}
