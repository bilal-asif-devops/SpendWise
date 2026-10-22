import 'package:flutter/material.dart';
import '../../models/currency.dart';
import '../../theme/app_theme.dart';

class CurrencyPickerModal extends StatefulWidget {
  final String selectedCode;

  const CurrencyPickerModal({
    super.key,
    required this.selectedCode,
  });

  @override
  State<CurrencyPickerModal> createState() => _CurrencyPickerModalState();
}

class _CurrencyPickerModalState extends State<CurrencyPickerModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Currency> _filteredCurrencies = CurrencyData.currencies;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredCurrencies = CurrencyData.search(_searchCtrl.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceWhite,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Select Currency",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
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
              const SizedBox(height: 8),

              // Search input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: "Search by code or country name...",
                    hintStyle: const TextStyle(
                        fontSize: 14, color: AppColors.textMuted),
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.textMuted),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.chipBackground,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // List of currencies
              Expanded(
                child: _filteredCurrencies.isEmpty
                    ? const Center(
                        child: Text(
                          "No currencies found",
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredCurrencies.length,
                        separatorBuilder: (ctx, idx) => const Divider(
                          height: 1,
                          indent: 64,
                          color: AppColors.borderLight,
                        ),
                        itemBuilder: (ctx, idx) {
                          final curr = _filteredCurrencies[idx];
                          final isSelected = curr.code.toUpperCase() ==
                              widget.selectedCode.toUpperCase();

                          return ListTile(
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Radio circle
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.accentGreen
                                          : AppColors.borderLight,
                                      width: 2,
                                    ),
                                    color: isSelected
                                        ? AppColors.accentGreen
                                        : Colors.transparent,
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check,
                                          size: 14, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                // Flag emoji
                                Text(
                                  curr.flag,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ],
                            ),
                            title: Text(
                              curr.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: AppColors.textDark,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.accentGreen
                                        .withValues(alpha: 0.12)
                                    : AppColors.chipBackground,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "${curr.symbol} ${curr.code}",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? AppColors.accentGreen
                                      : AppColors.primaryNavy,
                                ),
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context, curr);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
