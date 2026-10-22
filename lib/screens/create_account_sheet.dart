import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/currency.dart';
import '../models/models.dart';
import '../services/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/transaction_entry/currency_picker_modal.dart';

class CreateAccountSheet extends StatefulWidget {
  final AccountType initialType;

  const CreateAccountSheet({
    super.key,
    this.initialType = AccountType.debit,
  });

  static Future<Account?> show(
    BuildContext context, {
    AccountType initialType = AccountType.debit,
  }) {
    return showModalBottomSheet<Account>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateAccountSheet(initialType: initialType),
    );
  }

  @override
  State<CreateAccountSheet> createState() => _CreateAccountSheetState();
}

class _CreateAccountSheetState extends State<CreateAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController(text: '0.00');
  final _creditLimitCtrl = TextEditingController(text: '2000.00');
  final _last4Ctrl = TextEditingController();

  late AccountType _selectedType;
  late String _selectedCurrencyCode;
  late Color _selectedColor;
  late String _selectedIcon;
  bool _isExcludedFromSafeToSpend = false;

  final List<Color> _colorPresets = const [
    Color(0xFF1A365D), // Navy
    Color(0xFF2563EB), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFF0D9488), // Teal
    Color(0xFFF59E0B), // Amber
    Color(0xFFE11D48), // Rose
    Color(0xFF7C3AED), // Purple
    Color(0xFF334155), // Slate
  ];

  final List<String> _iconPresets = const [
    '🏛️',
    '💳',
    '💵',
    '🏦',
    '🪙',
    '💼',
    '🛒',
    '✈️',
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    final finance = Provider.of<FinanceProvider>(context, listen: false);
    _selectedCurrencyCode = finance.currency == 'Rs'
        ? 'PKR'
        : (finance.currency == '€'
            ? 'EUR'
            : (finance.currency == '£' ? 'GBP' : 'USD'));
    _selectedColor = _colorPresets.first;
    _selectedIcon = _defaultIconForType(_selectedType);
    _isExcludedFromSafeToSpend = _selectedType == AccountType.credit;
  }

  String _defaultIconForType(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return '💵';
      case AccountType.debit:
        return '🏛️';
      case AccountType.credit:
        return '💳';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _creditLimitCtrl.dispose();
    _last4Ctrl.dispose();
    super.dispose();
  }

  Future<void> _openCurrencyPicker() async {
    final picked = await showModalBottomSheet<Currency>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CurrencyPickerModal(
        selectedCode: _selectedCurrencyCode,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedCurrencyCode = picked.code;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final balanceVal = double.tryParse(_balanceCtrl.text.trim()) ?? 0.0;
    final creditLimitVal = _selectedType == AccountType.credit
        ? (double.tryParse(_creditLimitCtrl.text.trim()) ?? 0.0)
        : 0.0;

    final newAccount = Account(
      id: 'acc_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      type: _selectedType,
      balance: balanceVal,
      creditLimit: creditLimitVal,
      last4: _last4Ctrl.text.trim().isNotEmpty ? _last4Ctrl.text.trim() : null,
      icon: _selectedIcon,
      color: _selectedColor,
      isLiquid: _selectedType != AccountType.credit,
      isExcludedFromSafeToSpend: _isExcludedFromSafeToSpend,
      currency: _selectedCurrencyCode,
      isSample: false,
    );

    final finance = Provider.of<FinanceProvider>(context, listen: false);
    final success = finance.addAccount(newAccount);

    if (success) {
      Navigator.of(context).pop(newAccount);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Account '${newAccount.name}' created successfully!"),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            finance.lastErrorMessage ?? 'Failed to create account.',
          ),
          backgroundColor: AppColors.alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final curr = CurrencyData.findByCode(_selectedCurrencyCode);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: AppColors.surfaceWhite,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // Title Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.close, color: AppColors.textMuted),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: AppColors.borderLight),

                // Scrollable Form Fields
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Account Type Selector
                        const Text(
                          'ACCOUNT TYPE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildTypeOption(
                              type: AccountType.debit,
                              label: 'Bank / Debit',
                              icon: '🏛️',
                            ),
                            const SizedBox(width: 8),
                            _buildTypeOption(
                              type: AccountType.cash,
                              label: 'Cash Wallet',
                              icon: '💵',
                            ),
                            const SizedBox(width: 8),
                            _buildTypeOption(
                              type: AccountType.credit,
                              label: 'Credit Card',
                              icon: '💳',
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Account Name
                        TextFormField(
                          key: const Key('create_account_name_field'),
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Account Name',
                            hintText: _selectedType == AccountType.cash
                                ? 'e.g. Cash Wallet'
                                : (_selectedType == AccountType.credit
                                    ? 'e.g. Chase Sapphire'
                                    : 'e.g. Meezan Current'),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                _selectedIcon,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            filled: true,
                            fillColor: AppColors.chipBackground,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter an account name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Currency Selector Button
                        const Text(
                          'CURRENCY',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          key: const Key('create_account_currency_button'),
                          onTap: _openCurrencyPicker,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.chipBackground,
                              border: Border.all(color: AppColors.borderLight),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Text(curr.flag,
                                    style: const TextStyle(fontSize: 22)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${curr.code} — ${curr.name} (${curr.symbol})',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Opening Balance / Liability
                        TextFormField(
                          key: const Key('create_account_balance_field'),
                          controller: _balanceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: _selectedType == AccountType.credit
                                ? 'Current Owed Liability'
                                : 'Opening Balance',
                            helperText: _selectedType == AccountType.credit
                                ? 'Amount currently owed on this card (0.00 for no debt)'
                                : 'Starting funds in this account (never counted as income/expense)',
                            prefixText: '${curr.symbol} ',
                            prefixStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            filled: true,
                            fillColor: AppColors.chipBackground,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a starting balance';
                            }
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null ||
                                !parsed.isFinite ||
                                parsed.isNaN) {
                              return 'Please enter a valid finite number';
                            }
                            if (parsed < 0) {
                              return 'Balance cannot be negative';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Credit Limit (Credit Only)
                        if (_selectedType == AccountType.credit) ...[
                          TextFormField(
                            key: const Key('create_account_credit_limit_field'),
                            controller: _creditLimitCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Credit Limit',
                              helperText:
                                  'Total borrowing limit available on this credit card',
                              prefixText: '${curr.symbol} ',
                              prefixStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              filled: true,
                              fillColor: AppColors.chipBackground,
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter the credit limit';
                              }
                              final parsed = double.tryParse(val.trim());
                              if (parsed == null ||
                                  !parsed.isFinite ||
                                  parsed.isNaN) {
                                return 'Please enter a valid finite number';
                              }
                              if (parsed <= 0) {
                                return 'Credit limit must be greater than zero';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Last 4 Digits (Optional for cards)
                        if (_selectedType != AccountType.cash) ...[
                          TextFormField(
                            key: const Key('create_account_last4_field'),
                            controller: _last4Ctrl,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: 'Last 4 Digits (Optional)',
                              hintText: 'e.g. 4821',
                              counterText: '',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              filled: true,
                              fillColor: AppColors.chipBackground,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Color Palette
                        const Text(
                          'CARD COLOR',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: _colorPresets.map((color) {
                            final isSelected =
                                _selectedColor.toARGB32() == color.toARGB32();
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedColor = color),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(
                                          color: Colors.white, width: 3)
                                      : null,
                                  boxShadow: [
                                    if (isSelected)
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                  ],
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 20,
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // Icon Preset
                        const Text(
                          'ICON',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: _iconPresets.map((icon) {
                            final isSelected = _selectedIcon == icon;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedIcon = icon),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryNavy
                                      : AppColors.chipBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primaryNavy
                                        : AppColors.borderLight,
                                  ),
                                ),
                                child: Text(
                                  icon,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Exclude from Safe-to-Spend Switch
                        SwitchListTile(
                          key: const Key('create_account_exclude_switch'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Exclude from Safe-to-Spend',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          subtitle: const Text(
                            'Funds in this account will not be counted in your daily safe spending allowance',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          value: _isExcludedFromSafeToSpend,
                          activeThumbColor: AppColors.accentGreen,
                          onChanged: (val) {
                            setState(() => _isExcludedFromSafeToSpend = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Submit CTA
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      key: const Key('create_account_submit_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _submit,
                      child: const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeOption({
    required AccountType type,
    required String label,
    required String icon,
  }) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedType = type;
            _selectedIcon = _defaultIconForType(type);
            if (type == AccountType.credit) {
              _isExcludedFromSafeToSpend = true;
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color:
                isSelected ? AppColors.primaryNavy : AppColors.chipBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryNavy : AppColors.borderLight,
            ),
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
