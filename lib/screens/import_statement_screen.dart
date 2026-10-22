import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/finance_provider.dart';
import '../services/statement_importer.dart';
import '../theme/app_theme.dart';
import 'create_account_sheet.dart';

class ImportStatementScreen extends StatefulWidget {
  final String? preselectedAccountId;

  const ImportStatementScreen({super.key, this.preselectedAccountId});

  @override
  State<ImportStatementScreen> createState() => _ImportStatementScreenState();
}

class _ImportStatementScreenState extends State<ImportStatementScreen> {
  String? _selectedAccountId;
  String _rawCsvContent = '';
  String? _loadedFileName;
  StatementParseResult? _parseResult;
  bool _isProcessing = false;
  final TextEditingController _pasteCtrl = TextEditingController();

  ColumnMapping? _customMapping;

  @override
  void initState() {
    super.initState();
    final finance = Provider.of<FinanceProvider>(context, listen: false);
    if (widget.preselectedAccountId != null &&
        finance.accounts.any((a) => a.id == widget.preselectedAccountId)) {
      _selectedAccountId = widget.preselectedAccountId;
    } else if (finance.accounts.isNotEmpty) {
      _selectedAccountId = finance.accounts.first.id;
    }
  }

  @override
  void dispose() {
    _pasteCtrl.dispose();
    super.dispose();
  }

  void _loadCsvString(String content, {String? fileName}) {
    setState(() {
      _rawCsvContent = content;
      _loadedFileName = fileName;
      _customMapping = null;
    });
    _reparse();
  }

  void _reparse() {
    if (_rawCsvContent.trim().isEmpty) {
      setState(() {
        _parseResult = null;
      });
      return;
    }

    final finance = Provider.of<FinanceProvider>(context, listen: false);
    final result = StatementImporter.parseCsv(
      csvContent: _rawCsvContent,
      accountId: _selectedAccountId,
      explicitMapping: _customMapping,
      existingTransactions: finance.expenses,
    );

    setState(() {
      _parseResult = result;
      _customMapping ??= result.mapping;
    });
  }

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final content = utf8.decode(bytes, allowMalformed: true);
        if (content.isNotEmpty) {
          _loadCsvString(content, fileName: file.name);
        } else {
          _showSnack('Selected file was empty.', isError: true);
        }
      }
    } catch (e) {
      _showSnack('Could not open file picker: $e', isError: true);
    }
  }

  void _loadSample(String sampleName, String csv) {
    _loadCsvString(csv, fileName: sampleName);
  }

  void _executeImport() {
    if (_selectedAccountId == null) {
      _showSnack('Please select a destination account first.', isError: true);
      return;
    }
    if (_parseResult == null || _parseResult!.records.isEmpty) {
      _showSnack('No statement data to import.', isError: true);
      return;
    }

    setState(() => _isProcessing = true);

    final finance = Provider.of<FinanceProvider>(context, listen: false);
    try {
      final summary = finance.importStatementTransactions(
        accountId: _selectedAccountId!,
        transactions: _parseResult!.records,
      );

      setState(() => _isProcessing = false);
      _showImportSuccessDialog(summary);
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnack('Import error: $e', isError: true);
    }
  }

  void _showImportSuccessDialog(StatementImportSummary summary) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.accentGreen, size: 28),
            SizedBox(width: 10),
            Text('Import Complete',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Statement imported into '${summary.accountName}'.",
              style: const TextStyle(fontSize: 14, color: AppColors.textDark),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow(
              'Imported Transactions',
              '${summary.importedCount}',
              AppColors.accentGreen,
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Duplicates Skipped',
              '${summary.duplicateCount}',
              AppColors.alertAmber,
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Invalid Rows',
              '${summary.invalidCount}',
              summary.invalidCount > 0
                  ? AppColors.alertRed
                  : AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Net Balance Effect:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  (summary.netBalanceChange >= 0 ? '+' : '') +
                      summary.netBalanceChange.toStringAsFixed(2),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: summary.netBalanceChange >= 0
                        ? AppColors.accentGreen
                        : AppColors.alertRed,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            key: const Key('import_success_done_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop(); // dismiss dialog
              Navigator.of(context).pop(true); // pop import screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.alertRed : AppColors.accentGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showBankingBoundaryModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shield_outlined,
                    color: AppColors.primaryNavy, size: 28),
                SizedBox(width: 10),
                Text(
                  'Privacy & Banking Boundaries',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'SpendWise is built with strict privacy and truthful banking boundaries:\n\n'
              '• No credentials requested: We never ask for your online banking passwords, PINs, or OTPs.\n'
              '• 100% Offline parsing: CSV statement imports are parsed locally on your phone.\n'
              '• Truthful integrations: We do not simulate or harvest credentials for banks lacking licensed Open Banking APIs.\n\n'
              'Your bank statements remain entirely on your device.',
              style: TextStyle(
                  fontSize: 13.5, height: 1.45, color: AppColors.textDark),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('I Understand'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context);
    final accounts = finance.accounts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Import Statement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppColors.primaryNavy),
            tooltip: 'Privacy & Banking Policy',
            onPressed: _showBankingBoundaryModal,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Target Account Section
              _buildTargetAccountCard(accounts),
              const SizedBox(height: 16),

              // Source Input Methods
              _buildInputMethodsCard(),
              const SizedBox(height: 16),

              // Column Mapping & Preview
              if (_parseResult != null) ...[
                _buildMappingAndPreviewCard(),
                const SizedBox(height: 24),
              ],

              // Bottom Confirm CTA
              if (_parseResult != null && _parseResult!.records.isNotEmpty)
                _buildConfirmButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetAccountCard(List<Account> accounts) {
    if (accounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          children: [
            const Icon(Icons.account_balance_wallet_outlined,
                size: 40, color: AppColors.alertAmber),
            const SizedBox(height: 8),
            const Text(
              'No Accounts Available',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'You must create a manual account before importing bank statements.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Account'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final created = await CreateAccountSheet.show(context);
                if (created != null) {
                  setState(() {
                    _selectedAccountId = created.id;
                  });
                }
              },
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DESTINATION ACCOUNT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const Key('import_account_dropdown'),
            initialValue: _selectedAccountId,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.chipBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: accounts.map((acc) {
              return DropdownMenuItem(
                value: acc.id,
                child: Row(
                  children: [
                    Text(acc.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Text(
                      '${acc.name} (${acc.currency})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedAccountId = val;
              });
              _reparse();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputMethodsCard() {
    return Material(
      color: AppColors.surfaceWhite,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'STATEMENT SOURCE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                if (_loadedFileName != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _loadedFileName!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentGreen,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // File Picker Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('import_pick_file_button'),
                icon: const Icon(Icons.file_upload_outlined,
                    color: AppColors.primaryNavy),
                label: const Text(
                  'Pick CSV File from Device',
                  style: TextStyle(
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(
                      color: AppColors.primaryNavy, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _pickFile,
              ),
            ),
            const SizedBox(height: 12),

            // Direct Paste Accordion
            ExpansionTile(
              key: const Key('import_paste_expansion_tile'),
              tilePadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.paste_rounded, color: AppColors.primaryNavy),
              title: const Text(
                'Paste CSV Statement Text',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              children: [
                const SizedBox(height: 6),
                TextField(
                  key: const Key('import_paste_text_field'),
                  controller: _pasteCtrl,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText:
                        'Date,Description,Debit,Credit\n2026-10-15,Grocery,45.00,\n2026-10-16,Salary,,2500.00',
                    hintStyle: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.chipBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    key: const Key('import_parse_pasted_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      if (_pasteCtrl.text.trim().isNotEmpty) {
                        _loadCsvString(_pasteCtrl.text, fileName: 'Pasted CSV');
                      }
                    },
                    child: const Text('Parse Pasted Text'),
                  ),
                ),
              ],
            ),

            const Divider(height: 20),

            // Sample Statements Quick Loaders
            const Text(
              'OR TRY A REAL-WORLD SAMPLE STATEMENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  key: const Key('sample_meezan_chip'),
                  avatar: const Text('🇵🇰'),
                  label: const Text('Meezan Bank (PKR)'),
                  onPressed: () => _loadSample(
                      'Meezan Bank (PKR)', SampleStatements.meezanBankCsv),
                ),
                ActionChip(
                  key: const Key('sample_revolut_chip'),
                  avatar: const Text('🇬🇧'),
                  label: const Text('Revolut (GBP)'),
                  onPressed: () => _loadSample(
                      'Revolut (GBP)', SampleStatements.revolutGbpCsv),
                ),
                ActionChip(
                  key: const Key('sample_chase_chip'),
                  avatar: const Text('🇺🇸'),
                  label: const Text('Chase (USD)'),
                  onPressed: () => _loadSample(
                      'Chase Bank (USD)', SampleStatements.chaseUsdCsv),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMappingAndPreviewCard() {
    final pr = _parseResult!;
    return Material(
      color: AppColors.surfaceWhite,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'STATEMENT PREVIEW',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${pr.records.length} records found',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNavy),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stat chips
            Row(
              children: [
                _buildBadge('${pr.validCount} Ready', AppColors.accentGreen),
                const SizedBox(width: 8),
                _buildBadge(
                    '${pr.duplicateCount} Duplicates', AppColors.alertAmber),
                const SizedBox(width: 8),
                _buildBadge('${pr.invalidCount} Invalid', AppColors.alertRed),
              ],
            ),
            const SizedBox(height: 16),

            // Column Mapping Selector
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              leading: const Icon(Icons.table_chart_outlined,
                  color: AppColors.primaryNavy, size: 20),
              title: const Text('Column Mapping',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
              subtitle: const Text(
                  'Adjust if bank headers are mapped incorrectly',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              children: [
                const SizedBox(height: 8),
                _buildColumnDropdown(
                  label: 'Date Column',
                  selectedIndex: _customMapping?.dateColumn,
                  headers: pr.headers,
                  onChanged: (idx) {
                    setState(() {
                      _customMapping = ColumnMapping(
                        dateColumn: idx,
                        descriptionColumn: _customMapping?.descriptionColumn,
                        amountColumn: _customMapping?.amountColumn,
                        debitColumn: _customMapping?.debitColumn,
                        creditColumn: _customMapping?.creditColumn,
                        categoryColumn: _customMapping?.categoryColumn,
                      );
                    });
                    _reparse();
                  },
                ),
                const SizedBox(height: 8),
                _buildColumnDropdown(
                  label: 'Description Column',
                  selectedIndex: _customMapping?.descriptionColumn,
                  headers: pr.headers,
                  onChanged: (idx) {
                    setState(() {
                      _customMapping = ColumnMapping(
                        dateColumn: _customMapping?.dateColumn,
                        descriptionColumn: idx,
                        amountColumn: _customMapping?.amountColumn,
                        debitColumn: _customMapping?.debitColumn,
                        creditColumn: _customMapping?.creditColumn,
                        categoryColumn: _customMapping?.categoryColumn,
                      );
                    });
                    _reparse();
                  },
                ),
                const SizedBox(height: 8),
                _buildColumnDropdown(
                  label: 'Debit (Withdrawal) Column',
                  selectedIndex: _customMapping?.debitColumn,
                  headers: pr.headers,
                  allowNone: true,
                  onChanged: (idx) {
                    setState(() {
                      _customMapping = ColumnMapping(
                        dateColumn: _customMapping?.dateColumn,
                        descriptionColumn: _customMapping?.descriptionColumn,
                        amountColumn: null,
                        debitColumn: idx,
                        creditColumn: _customMapping?.creditColumn,
                        categoryColumn: _customMapping?.categoryColumn,
                      );
                    });
                    _reparse();
                  },
                ),
                const SizedBox(height: 8),
                _buildColumnDropdown(
                  label: 'Credit (Deposit) Column',
                  selectedIndex: _customMapping?.creditColumn,
                  headers: pr.headers,
                  allowNone: true,
                  onChanged: (idx) {
                    setState(() {
                      _customMapping = ColumnMapping(
                        dateColumn: _customMapping?.dateColumn,
                        descriptionColumn: _customMapping?.descriptionColumn,
                        amountColumn: null,
                        debitColumn: _customMapping?.debitColumn,
                        creditColumn: idx,
                        categoryColumn: _customMapping?.categoryColumn,
                      );
                    });
                    _reparse();
                  },
                ),
              ],
            ),

            const Divider(height: 20),

            // Transaction records preview list
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pr.records.take(15).length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (ctx, i) {
                final rec = pr.records[i];
                return _buildRecordPreviewTile(rec);
              },
            ),
            if (pr.records.length > 15)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: Text(
                    '+ ${pr.records.length - 15} more rows',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildColumnDropdown({
    required String label,
    required int? selectedIndex,
    required List<String> headers,
    required ValueChanged<int?> onChanged,
    bool allowNone = false,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int?>(
            initialValue: selectedIndex,
            isDense: true,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: [
              if (allowNone)
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('(None)', style: TextStyle(fontSize: 12)),
                ),
              ...List.generate(headers.length, (i) {
                return DropdownMenuItem<int?>(
                  value: i,
                  child: Text(
                    'Col $i: ${headers[i]}',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordPreviewTile(ImportedTransactionRecord rec) {
    final isExpense = rec.type == TransactionType.expense;
    Color statusColor = AppColors.accentGreen;
    String statusText = 'Ready';

    if (!rec.isValid) {
      statusColor = AppColors.alertRed;
      statusText = 'Invalid';
    } else if (rec.isDuplicate) {
      statusColor = AppColors.alertAmber;
      statusText = 'Duplicate';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Type indicator
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isExpense
                ? AppColors.alertRed.withValues(alpha: 0.1)
                : AppColors.accentGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(
            isExpense
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 18,
            color: isExpense ? AppColors.alertRed : AppColors.accentGreen,
          ),
        ),
        const SizedBox(width: 10),

        // Description & Date
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rec.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${rec.rawDate} • ${rec.category}',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              if (!rec.isValid && rec.errorMessage != null)
                Text(
                  rec.errorMessage!,
                  style: const TextStyle(
                      fontSize: 10.5, color: AppColors.alertRed),
                ),
            ],
          ),
        ),

        // Amount & Status Badge
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              (isExpense ? '-' : '+') + rec.amount.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: isExpense ? AppColors.textDark : AppColors.accentGreen,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmButton() {
    final pr = _parseResult!;
    final canConfirm =
        _selectedAccountId != null && pr.validCount > 0 && !_isProcessing;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        key: const Key('import_confirm_button'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentGreen,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        onPressed: canConfirm ? _executeImport : null,
        child: _isProcessing
            ? const Text(
                'Importing...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              )
            : Text(
                'Import ${pr.validCount} Transactions',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
