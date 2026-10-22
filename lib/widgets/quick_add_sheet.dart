import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/currency.dart';
import '../models/models.dart';
import '../services/finance_provider.dart';
import '../theme/app_theme.dart';
import 'transaction_entry/calculator_engine.dart';
import 'transaction_entry/calculator_keypad.dart';
import 'transaction_entry/currency_picker_modal.dart';
import 'transaction_entry/exchange_rate_modal.dart';

class QuickAddExpenseSheet extends StatefulWidget {
  final TransactionType initialMode;

  const QuickAddExpenseSheet({
    super.key,
    this.initialMode = TransactionType.expense,
  });

  @override
  State<QuickAddExpenseSheet> createState() => _QuickAddExpenseSheetState();
}

class _QuickAddExpenseSheetState extends State<QuickAddExpenseSheet> {
  late TransactionType _selectedMode;
  final CalculatorEngine _calc = CalculatorEngine();
  final TextEditingController _noteController = TextEditingController();

  String _selectedCategory = "Food & Drink";
  String _selectedIncomeCategory = "Salary";
  String? _selectedSourceAccountId;
  String? _selectedDestAccountId;
  late Currency _selectedCurrency;
  double? _configuredExchangeRate;
  final List<String> _selectedTags = [];

  final List<Map<String, dynamic>> _expenseCategories = const [
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

  final List<Map<String, dynamic>> _incomeCategories = const [
    {"name": "Salary", "icon": "💼", "color": Color(0xFF10B981)},
    {"name": "Freelance", "icon": "💻", "color": Color(0xFF3B82F6)},
    {"name": "Investments", "icon": "📈", "color": Color(0xFF8B5CF6)},
    {"name": "Gift", "icon": "🎁", "color": Color(0xFFEC4899)},
    {"name": "Refund", "icon": "🔄", "color": Color(0xFF06B6D4)},
    {"name": "Rental", "icon": "🏢", "color": Color(0xFFF59E0B)},
    {"name": "Other", "icon": "💰", "color": Color(0xFF64748B)},
  ];

  final List<String> _quickTags = [
    "Wants",
    "Coffee ☕",
    "Lunch",
    "Movies",
  ];

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
    // Initialize base currency
    _selectedCurrency = CurrencyData.findByCode("USD");
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final finance = Provider.of<FinanceProvider>(context, listen: false);
    // Align with finance currency if matching code exists
    if (finance.currency.isNotEmpty) {
      if (finance.currency.contains("£")) {
        _selectedCurrency = CurrencyData.findByCode("GBP");
      } else if (finance.currency.contains("€")) {
        _selectedCurrency = CurrencyData.findByCode("EUR");
      } else if (finance.currency.contains("Rs")) {
        _selectedCurrency = CurrencyData.findByCode("PKR");
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String name) {
    setState(() {
      if (_selectedMode == TransactionType.income) {
        _selectedIncomeCategory = name;
      } else {
        _selectedCategory = name;
      }
    });
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  Future<void> _openCurrencyPicker() async {
    final picked = await showModalBottomSheet<Currency>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          CurrencyPickerModal(selectedCode: _selectedCurrency.code),
    );

    if (picked != null && picked.code != _selectedCurrency.code) {
      final oldCurrency = _selectedCurrency;
      final estimatedRate =
          CurrencyData.getEstimatedRate(oldCurrency.code, picked.code);

      if (!mounted) return;

      // Show exchange rate confirmation matching frame_175s.jpg
      final rateResult = await showModalBottomSheet<ExchangeRateModalResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => ExchangeRateModal(
          baseCurrency: oldCurrency,
          targetCurrency: picked,
          initialRate: estimatedRate,
        ),
      );

      if (rateResult != null) {
        setState(() {
          _selectedCurrency = picked;
          _configuredExchangeRate = rateResult.rate;
        });

        if (rateResult.rememberCurrency && mounted) {
          final finance = Provider.of<FinanceProvider>(context, listen: false);
          finance.updateCurrency(picked.symbol);
        }
      } else {
        // User cancelled exchange rate sheet, apply currency selection with estimated rate
        setState(() {
          _selectedCurrency = picked;
          _configuredExchangeRate = estimatedRate;
        });
      }
    }
  }

  void _showReceiptScanDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("📸✨ Scan Receipt",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          "Receipt photo attachment and automated OCR itemization will be fully integrated in Phase 4.\n\nFor now, enter your transaction details directly with the keypad.",
          style:
              TextStyle(fontSize: 14, color: AppColors.textDark, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Got it"),
          ),
        ],
      ),
    );
  }

  void _submitTransaction(BuildContext context) {
    final amount = _calc.getNumericAmount();
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_calc.errorMessage ??
              "Please enter a valid amount greater than zero."),
          backgroundColor: AppColors.alertRed,
        ),
      );
      return;
    }

    final finance = Provider.of<FinanceProvider>(context, listen: false);

    if (_selectedMode == TransactionType.transfer) {
      final accounts = finance.accounts;
      if (accounts.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("At least 2 accounts are required to perform a transfer."),
            backgroundColor: AppColors.alertRed,
          ),
        );
        return;
      }

      final sourceId = _selectedSourceAccountId ?? accounts.first.id;
      final destId = _selectedDestAccountId ?? accounts[1].id;

      final success = finance.transferBetweenAccounts(
        fromAccountId: sourceId,
        toAccountId: destId,
        amount: amount,
      );

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Transferred ${_selectedCurrency.symbol}${amount.toStringAsFixed(2)} successfully!"),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(finance.lastErrorMessage ?? "Transfer failed."),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
      return;
    }

    if (_selectedMode == TransactionType.income) {
      final accountId = _selectedSourceAccountId ??
          (finance.accounts.isNotEmpty ? finance.accounts.first.id : null);

      finance.addIncome(
        title: "$_selectedIncomeCategory Income",
        category: _selectedIncomeCategory,
        amount: amount,
        accountId: accountId,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
        currency: _selectedCurrency.code,
        exchangeRate: _configuredExchangeRate,
        tags: _selectedTags,
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Recorded Income $_selectedIncomeCategory: ${_selectedCurrency.symbol}${amount.toStringAsFixed(2)}",
          ),
          backgroundColor: AppColors.accentGreen,
        ),
      );
      return;
    }

    // Default: Expense
    final accountId = _selectedSourceAccountId ??
        (finance.accounts.isNotEmpty ? finance.accounts.first.id : null);

    finance.addExpense(
      title: "$_selectedCategory Expense",
      category: _selectedCategory,
      amount: amount,
      accountId: accountId,
      note: _noteController.text.isNotEmpty ? _noteController.text : null,
      currency: _selectedCurrency.code,
      exchangeRate: _configuredExchangeRate,
      tags: _selectedTags,
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Recorded Expense $_selectedCategory: ${_selectedCurrency.symbol}${amount.toStringAsFixed(2)}",
        ),
        backgroundColor: AppColors.accentGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context);
    final accounts = finance.accounts;

    if (accounts.isNotEmpty) {
      _selectedSourceAccountId ??= accounts.first.id;
      if (accounts.length > 1) {
        _selectedDestAccountId ??= accounts[1].id;
      }
    }

    final activeCategoryInfo = _selectedMode == TransactionType.income
        ? _incomeCategories.firstWhere(
            (c) => c["name"] == _selectedIncomeCategory,
            orElse: () => _incomeCategories.first,
          )
        : _expenseCategories.firstWhere(
            (c) => c["name"] == _selectedCategory,
            orElse: () => _expenseCategories.first,
          );

    final categoryColor = activeCategoryInfo["color"] as Color;
    final categoryIcon = activeCategoryInfo["icon"] as String;
    final categoryName = activeCategoryInfo["name"] as String;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle & top bar
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 20, right: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Add transaction",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Scrollable upper content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Top Category Avatar Circle (Spendee frame_144s.jpg)
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _selectedMode == TransactionType.transfer
                          ? AppColors.primaryNavy.withValues(alpha: 0.12)
                          : categoryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _selectedMode == TransactionType.transfer
                          ? "🔄"
                          : categoryIcon,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedMode == TransactionType.transfer
                        ? "Transfer"
                        : categoryName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _selectedMode == TransactionType.transfer
                          ? AppColors.primaryNavy
                          : categoryColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Large Amount Display with Currency Dropdown (Spendee frame_144s.jpg)
                  GestureDetector(
                    onTap: _openCurrencyPicker,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _calc.expression,
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryNavy,
                              letterSpacing: -1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.chipBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${_selectedCurrency.symbol} ${_selectedCurrency.code}",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down,
                                  size: 18, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Inline calculation prompt if pending operator
                  if (_calc.hasPendingOperation) ...[
                    const SizedBox(height: 4),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 2),
                      ),
                      onPressed: () {
                        setState(() {
                          _calc.evaluate();
                        });
                      },
                      icon: const Text(
                        "=",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentGreen),
                      ),
                      label: const Text(
                        "Tap to calculate",
                        style: TextStyle(
                            fontSize: 12, color: AppColors.accentGreen),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Description / Note Card with Tag Chips & Receipt Scan (Spendee frame_144s.jpg)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.chipBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _noteController,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            hintText: "Add note...",
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ..._quickTags.map((tag) {
                              final isSelected = _selectedTags.contains(tag);
                              return InkWell(
                                onTap: () => _toggleTag(tag),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primaryNavy
                                        : AppColors.surfaceWhite,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primaryNavy
                                          : AppColors.borderLight,
                                    ),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textDark,
                                    ),
                                  ),
                                ),
                              );
                            }),
                            InkWell(
                              onTap: _showReceiptScanDialog,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accentGreen
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AppColors.accentGreen
                                          .withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "📸✨ Scan receipt",
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accentGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Wallet Selection
                  if (_selectedMode == TransactionType.transfer) ...[
                    // Transfer Source & Destination Pickers
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.chipBackground,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedSourceAccountId,
                                hint: const Text("From",
                                    style: TextStyle(fontSize: 13)),
                                items: accounts.map((acc) {
                                  return DropdownMenuItem<String>(
                                    value: acc.id,
                                    child: Text(
                                      "From: ${acc.name}",
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(
                                        () => _selectedSourceAccountId = val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.swap_horiz_rounded,
                              color: AppColors.primaryNavy),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.chipBackground,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedDestAccountId,
                                hint: const Text("To",
                                    style: TextStyle(fontSize: 13)),
                                items: accounts.map((acc) {
                                  return DropdownMenuItem<String>(
                                    value: acc.id,
                                    child: Text(
                                      "To: ${acc.name}",
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(
                                        () => _selectedDestAccountId = val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (accounts.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.chipBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedSourceAccountId,
                          items: accounts.map((acc) {
                            return DropdownMenuItem<String>(
                              value: acc.id,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedMode == TransactionType.income
                                          ? "Deposit to: ${acc.name}"
                                          : "Pay with: ${acc.name}",
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${finance.currency}${acc.balance.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryNavy,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedSourceAccountId = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // 4-Column Category Grid for Expenses & Income
                  if (_selectedMode != TransactionType.transfer) ...[
                    _buildCategoryGrid(
                      categories: _selectedMode == TransactionType.income
                          ? _incomeCategories
                          : _expenseCategories,
                      selectedName: _selectedMode == TransactionType.income
                          ? _selectedIncomeCategory
                          : _selectedCategory,
                    ),
                  ],

                  const SizedBox(height: 14),

                  // 4x4 Calculator Keypad
                  CalculatorKeypad(
                    onDigit: (d) => setState(() => _calc.inputDigit(d)),
                    onOperator: (op) => setState(() => _calc.inputOperator(op)),
                    onDecimal: () => setState(() => _calc.inputDecimal()),
                    onBackspace: () => setState(() => _calc.backspace()),
                    onClear: () => setState(() => _calc.clear()),
                    onEquals: () => setState(() => _calc.evaluate()),
                    hasPendingOperation: _calc.hasPendingOperation,
                  ),

                  const SizedBox(height: 16),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _selectedMode == TransactionType.transfer
                                ? AppColors.primaryNavy
                                : AppColors.accentGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => _submitTransaction(context),
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: Text(
                        _selectedMode == TransactionType.transfer
                            ? "Transfer Funds"
                            : _selectedMode == TransactionType.income
                                ? "Save Income"
                                : "Save Expense",
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Bottom 3-Mode Pill Switcher (Spendee frame_144s.jpg)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceWhite,
              border: Border(top: BorderSide(color: AppColors.borderLight)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.chipBackground,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          _buildModePill(
                            label: "Expenses",
                            mode: TransactionType.expense,
                          ),
                          _buildModePill(
                            label: "Income",
                            mode: TransactionType.income,
                          ),
                          _buildModePill(
                            label: "Transfer",
                            mode: TransactionType.transfer,
                          ),
                        ],
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

  Widget _buildModePill(
      {required String label, required TransactionType mode}) {
    final isSelected = _selectedMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceWhite : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.primaryNavy : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid({
    required List<Map<String, dynamic>> categories,
    required String selectedName,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (ctx, idx) {
        final cat = categories[idx];
        final name = cat["name"] as String;
        final icon = cat["icon"] as String;
        final color = cat["color"] as Color;
        final isSelected = name == selectedName;

        return InkWell(
          onTap: () => _onCategorySelected(name),
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? color : color.withValues(alpha: 0.14),
                  border: Border.all(
                    color: isSelected ? color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Text(
                  icon,
                  style: TextStyle(
                    fontSize: 22,
                    color: isSelected ? Colors.white : null,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.textDark : AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}
