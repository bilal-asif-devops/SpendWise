import 'package:flutter/material.dart';
import '../../models/currency.dart';
import '../../theme/app_theme.dart';

class ExchangeRateModalResult {
  final double rate;
  final bool rememberCurrency;

  const ExchangeRateModalResult({
    required this.rate,
    required this.rememberCurrency,
  });
}

class ExchangeRateModal extends StatefulWidget {
  final Currency baseCurrency;
  final Currency targetCurrency;
  final double initialRate;

  const ExchangeRateModal({
    super.key,
    required this.baseCurrency,
    required this.targetCurrency,
    required this.initialRate,
  });

  @override
  State<ExchangeRateModal> createState() => _ExchangeRateModalState();
}

class _ExchangeRateModalState extends State<ExchangeRateModal> {
  late TextEditingController _rateCtrl;
  bool _rememberCurrency = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rateCtrl = TextEditingController(
      text: widget.initialRate > 0
          ? widget.initialRate.toStringAsFixed(widget.initialRate < 1 ? 6 : 4)
          : "1.0000",
    );
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    super.dispose();
  }

  void _onConfirm() {
    final parsed = double.tryParse(_rateCtrl.text.trim());
    if (parsed == null || !parsed.isFinite || parsed.isNaN || parsed <= 0) {
      setState(() {
        _error = "Please enter a valid rate greater than zero.";
      });
      return;
    }

    Navigator.pop(
      context,
      ExchangeRateModalResult(
        rate: parsed,
        rememberCurrency: _rememberCurrency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Set exchange rate ${widget.baseCurrency.symbol} / ${widget.targetCurrency.code}",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon:
                    const Icon(Icons.close_rounded, color: AppColors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Rate configuration card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.chipBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Text(
                  "${widget.baseCurrency.symbol} 1.00000000",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 18, color: AppColors.textMuted),
                ),
                Text(
                  "${widget.targetCurrency.code} ",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _rateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: InputBorder.none,
                      hintText: "1.00",
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.alertRed, fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),

          const Text(
            "Rates are configured locally without mock live-market APIs.",
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),

          // Remember currency switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Remember Currency",
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Use this currency as default for next entries",
                        style:
                            TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _rememberCurrency,
                  activeTrackColor: AppColors.accentGreen,
                  onChanged: (val) {
                    setState(() => _rememberCurrency = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Confirm button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: _onConfirm,
              child: const Text(
                "Confirm",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
