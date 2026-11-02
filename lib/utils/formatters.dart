import 'package:intl/intl.dart';

/// Centralized, decimal-safe currency and number formatting utility.
/// Enforces consistent symbol placement, thousands separators, and decimal notation.
class CurrencyFormatter {
  static final NumberFormat _withDecimals = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _withoutDecimals = NumberFormat('#,##0', 'en_US');

  /// Formats an amount with a consistent prefix.
  /// Multi-character symbols like "Rs" or "PKR" receive a clean trailing space ("Rs 1,284.00").
  /// Single-character symbols like "$" or "€" stay adjacent ("$1,284.00").
  static String format(
    double amount,
    String currencySymbol, {
    bool showSign = false,
    bool includeDecimals = true,
  }) {
    if (amount.isNaN || amount.isInfinite) {
      final prefix = _cleanPrefix(currencySymbol);
      return includeDecimals ? '${prefix}0.00' : '${prefix}0';
    }

    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final formattedNumber = includeDecimals
        ? _withDecimals.format(absAmount)
        : _withoutDecimals.format(absAmount);

    final prefix = _cleanPrefix(currencySymbol);

    if (isNegative) {
      return '-$prefix$formattedNumber';
    } else if (showSign && amount > 0) {
      return '+$prefix$formattedNumber';
    } else {
      return '$prefix$formattedNumber';
    }
  }

  /// Formats an expense transaction amount (always prefixed with minus sign).
  static String formatExpense(
    double amount,
    String currencySymbol, {
    bool includeDecimals = true,
  }) {
    final absAmount = amount.abs();
    return format(-absAmount, currencySymbol, includeDecimals: includeDecimals);
  }

  /// Formats an income transaction amount (prefixed with plus sign).
  static String formatIncome(
    double amount,
    String currencySymbol, {
    bool includeDecimals = true,
  }) {
    final absAmount = amount.abs();
    return format(absAmount, currencySymbol,
        showSign: true, includeDecimals: includeDecimals);
  }

  /// Compact formatting for chart axis values (e.g. "0", "500", "2.5k", "10k", "1M").
  static String formatCompact(double amount, String currencySymbol) {
    if (amount.isNaN || amount.isInfinite) {
      return '${_cleanPrefix(currencySymbol)}0';
    }

    final absAmount = amount.abs();
    final isNegative = amount < 0;
    String numStr;

    if (absAmount >= 1000000) {
      final val = absAmount / 1000000;
      numStr = '${val.toStringAsFixed(val % 1 == 0 ? 0 : 1)}M';
    } else if (absAmount >= 1000) {
      final val = absAmount / 1000;
      numStr = '${val.toStringAsFixed(val % 1 == 0 ? 0 : 1)}k';
    } else {
      numStr = absAmount.toStringAsFixed(0);
    }

    final prefix = _cleanPrefix(currencySymbol);
    return isNegative ? '-$prefix$numStr' : '$prefix$numStr';
  }

  static String _cleanPrefix(String symbol) {
    final trimmed = symbol.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length > 1) {
      return '$trimmed ';
    }
    return trimmed;
  }
}
