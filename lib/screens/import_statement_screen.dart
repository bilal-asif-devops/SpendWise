import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/finance_provider.dart';
import '../services/statement_importer.dart';
import '../theme/app_theme.dart';
import '../widgets/biometric_lock_guard.dart';
import 'budgets_screen.dart';
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
  String? _forcedDateFormat;

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
      _forcedDateFormat = null;
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
      userAccounts: finance.accounts,
      forcedDateFormat: _forcedDateFormat,
    );

    setState(() {
      _parseResult = result;
      _customMapping ??= result.mapping;
    });
  }

  Future<void> _pickFile() async {
    BiometricLockGuard.isSystemPickerActive = true;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt', 'ofx', 'qfx'],
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
    } finally {
      // Delay reset slightly to let Android lifecycle resume finish without locking
      Future.delayed(const Duration(milliseconds: 600), () {
        BiometricLockGuard.isSystemPickerActive = false;
      });
    }
  }

  void _loadSample(String sampleName, String content) {
    _loadCsvString(content, fileName: sampleName);
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
            Text(
              'Import Complete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
              '${summary.importedCount} (${summary.incomingCount} in, ${summary.outgoingCount} out)',
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
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(true);
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
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined,
                      color: AppColors.primaryNavy, size: 28),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Privacy & Security Boundaries',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildPrivacyPoint(
                icon: Icons.phonelink_lock,
                title: '100% On-Device Parsing',
                description:
                    'Bank statements (CSV/OFX) are parsed locally on your device. Raw files are never uploaded to our servers or third-party cloud services.',
              ),
              const SizedBox(height: 12),
              _buildPrivacyPoint(
                icon: Icons.no_encryption_gmailerrorred_outlined,
                title: 'No Credentials or PINs Ever Requested',
                description:
                    'SpendWise never asks for your online banking usernames, passwords, PINs, or SMS OTPs.',
              ),
              const SizedBox(height: 12),
              _buildPrivacyPoint(
                icon: Icons.storage_outlined,
                title: 'Local Vault Storage Transparency',
                description:
                    'Imported records are stored in your device application sandbox (spendwise_vault.json) as unencrypted UTF-8 JSON protected by OS-level sandbox isolation.',
              ),
              const SizedBox(height: 12),
              _buildPrivacyPoint(
                icon: Icons.cloud_sync_outlined,
                title: 'Cloud Sync Disclosure',
                description:
                    'When logged in with Google or Email, transactions sync to your private Cloud Firestore. In Guest mode, all records stay strictly offline.',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('I Understand'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyPoint({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primaryNavy),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditRecordSheet(ImportedTransactionRecord record, int index) {
    String selectedCategory = record.category;
    TransactionType selectedType = record.type;
    String? selectedTargetAccountId = record.transferTargetAccountId;
    final finance = Provider.of<FinanceProvider>(context, listen: false);
    final otherAccounts = finance.accounts
        .where((a) => a.id != (_selectedAccountId ?? ''))
        .toList();

    final expenseCats = [
      'Uncategorized',
      ...kExpenseCategories.map((c) => c['name'] as String),
    ];
    final incomeCats = ['Income', 'Salary', 'Freelance', 'Gift', 'Other'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final activeCats = selectedType == TransactionType.income
                ? incomeCats
                : expenseCats;
            if (!activeCats.contains(selectedCategory) &&
                selectedType != TransactionType.transfer) {
              selectedCategory = activeCats.first;
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Transaction Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Transaction Summary Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.chipBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.description,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Date: ${record.rawDate}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMuted),
                            ),
                            Text(
                              'Amount: ${record.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Direction / Type Selector
                  const Text(
                    'TRANSACTION DIRECTION',
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
                    children: [
                      ChoiceChip(
                        label: const Text('Outgoing (Expense)'),
                        selected: selectedType == TransactionType.expense,
                        selectedColor:
                            AppColors.alertRed.withValues(alpha: 0.2),
                        onSelected: (val) {
                          if (val) {
                            setSheetState(() {
                              selectedType = TransactionType.expense;
                              selectedCategory = 'Uncategorized';
                              selectedTargetAccountId = null;
                            });
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Incoming (Income)'),
                        selected: selectedType == TransactionType.income,
                        selectedColor:
                            AppColors.accentGreen.withValues(alpha: 0.2),
                        onSelected: (val) {
                          if (val) {
                            setSheetState(() {
                              selectedType = TransactionType.income;
                              selectedCategory = 'Income';
                              selectedTargetAccountId = null;
                            });
                          }
                        },
                      ),
                      if (otherAccounts.isNotEmpty)
                        ChoiceChip(
                          label: const Text('Internal Transfer'),
                          selected: selectedType == TransactionType.transfer,
                          selectedColor:
                              AppColors.primaryNavy.withValues(alpha: 0.2),
                          onSelected: (val) {
                            if (val) {
                              setSheetState(() {
                                selectedType = TransactionType.transfer;
                                selectedCategory = 'Transfer';
                                selectedTargetAccountId =
                                    otherAccounts.first.id;
                              });
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Destination Account (if transfer)
                  if (selectedType == TransactionType.transfer &&
                      otherAccounts.isNotEmpty) ...[
                    const Text(
                      'TRANSFER TO ACCOUNT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTargetAccountId,
                      items: otherAccounts
                          .map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Text('${a.icon} ${a.name}'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setSheetState(() {
                          selectedTargetAccountId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Category Selector (Optional)
                  if (selectedType != TransactionType.transfer) ...[
                    const Text(
                      'CATEGORY (OPTIONAL)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: activeCats.map((catName) {
                        final isSelected = catName == selectedCategory;
                        return ChoiceChip(
                          label: Text(
                            catName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor:
                              AppColors.primaryNavy.withValues(alpha: 0.15),
                          onSelected: (selected) {
                            if (selected) {
                              setSheetState(() {
                                selectedCategory = catName;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryNavy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          record.category = selectedCategory;
                          record.type = selectedType;
                          record.transferTargetAccountId =
                              selectedTargetAccountId;
                          if (selectedTargetAccountId != null) {
                            final match = otherAccounts.firstWhere(
                              (a) => a.id == selectedTargetAccountId,
                              orElse: () => otherAccounts.first,
                            );
                            record.transferTargetWalletName = match.name;
                          }
                          record.needsReview = false;
                          record.userOverridden = true;
                        });

                        Navigator.pop(sheetCtx);
                        _showSnack(
                            "Updated '${record.description}' to ${selectedType.name}");
                      },
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
            tooltip: 'Privacy & Security Policy',
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

              // Preview & Overview Card
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
                  'Pick CSV / OFX File from Device',
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
                'Paste Statement Text (CSV / OFX)',
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
                        _loadCsvString(_pasteCtrl.text,
                            fileName: 'Pasted Text');
                      }
                    },
                    child: const Text('Parse Pasted Text'),
                  ),
                ),
              ],
            ),

            const Divider(height: 20),

            // Bank Presets
            const Text(
              'SAMPLE STATEMENTS & PRESETS',
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
                  label: const Text('Meezan Bank'),
                  onPressed: () => _loadSample(
                      'Meezan Bank (PKR)', SampleStatements.meezanBankCsv),
                ),
                ActionChip(
                  key: const Key('sample_hbl_chip'),
                  avatar: const Text('🇵🇰'),
                  label: const Text('HBL'),
                  onPressed: () =>
                      _loadSample('HBL (PKR)', SampleStatements.hblCsv),
                ),
                ActionChip(
                  key: const Key('sample_alfalah_chip'),
                  avatar: const Text('🇵🇰'),
                  label: const Text('Bank Alfalah'),
                  onPressed: () => _loadSample(
                      'Bank Alfalah (PKR)', SampleStatements.bankAlfalahCsv),
                ),
                ActionChip(
                  key: const Key('sample_ubl_chip'),
                  avatar: const Text('🇵🇰'),
                  label: const Text('UBL'),
                  onPressed: () =>
                      _loadSample('UBL (PKR)', SampleStatements.ublCsv),
                ),
                ActionChip(
                  key: const Key('sample_mcb_chip'),
                  avatar: const Text('🇵🇰'),
                  label: const Text('MCB Bank'),
                  onPressed: () =>
                      _loadSample('MCB (PKR)', SampleStatements.mcbCsv),
                ),
                ActionChip(
                  key: const Key('sample_scb_chip'),
                  avatar: const Text('🇵🇰'),
                  label: const Text('Standard Chartered PK'),
                  onPressed: () => _loadSample('Standard Chartered PK (PKR)',
                      SampleStatements.standardCharteredPkCsv),
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
                  label: const Text('Chase Bank (USD)'),
                  onPressed: () => _loadSample(
                      'Chase Bank (USD)', SampleStatements.chaseUsdCsv),
                ),
                ActionChip(
                  key: const Key('sample_ofx_chip'),
                  avatar: const Text('📑'),
                  label: const Text('Sample OFX / QFX'),
                  onPressed: () => _loadSample(
                      'OFX Sample Statement', SampleStatements.sampleOfx),
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
    final isLowConfidence =
        !pr.mapping.isConfident || pr.mapping.confidenceScore < 0.7;
    final finance = Provider.of<FinanceProvider>(context, listen: false);

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
            // Bank Preset tag if identified
            if (pr.detectedBankPreset != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance,
                        size: 16, color: AppColors.primaryNavy),
                    const SizedBox(width: 6),
                    Text(
                      'Identified Format: ${pr.detectedBankPreset}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Financial Flow Overview (Incoming vs Outgoing)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.accentGreen.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.arrow_downward_rounded,
                                size: 16, color: AppColors.accentGreen),
                            SizedBox(width: 4),
                            Text('INCOMING',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accentGreen)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '+${finance.currency}${pr.totalCreditAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentGreen),
                        ),
                        Text(
                          '${pr.incomingCount} transactions',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.alertRed.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.alertRed.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.arrow_upward_rounded,
                                size: 16, color: AppColors.alertRed),
                            SizedBox(width: 4),
                            Text('OUTGOING',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.alertRed)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '-${finance.currency}${pr.totalDebitAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.alertRed),
                        ),
                        Text(
                          '${pr.outgoingCount} transactions',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Balance Verification Result Card (if statement includes balances)
            if (pr.balanceValidation.status !=
                BalanceValidationStatus.notPresent) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: pr.balanceValidation.status ==
                          BalanceValidationStatus.verified
                      ? AppColors.accentGreen.withValues(alpha: 0.08)
                      : AppColors.alertAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: pr.balanceValidation.status ==
                            BalanceValidationStatus.verified
                        ? AppColors.accentGreen.withValues(alpha: 0.3)
                        : AppColors.alertAmber.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      pr.balanceValidation.status ==
                              BalanceValidationStatus.verified
                          ? Icons.verified_outlined
                          : Icons.warning_amber_rounded,
                      size: 20,
                      color: pr.balanceValidation.status ==
                              BalanceValidationStatus.verified
                          ? AppColors.accentGreen
                          : AppColors.alertAmber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pr.balanceValidation.message ?? 'Balance verified.',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Unrecognized bank format banner
            if (isLowConfidence) ...[
              Container(
                key: const Key('import_low_confidence_banner'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.alertAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.alertAmber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.alertAmber, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Unrecognized Format — Check Mapping',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Confidence: ${(pr.mapping.confidenceScore * 100).toInt()}%. Please verify or adjust the column mapping below.',
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.textDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Ambiguous date banner
            if (pr.isDateAmbiguous) ...[
              Container(
                key: const Key('import_date_ambiguity_card'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.primaryNavy.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calendar_month_outlined,
                            size: 18, color: AppColors.primaryNavy),
                        SizedBox(width: 8),
                        Text(
                          'Ambiguous Date Format Detected',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Dates like 05/06/2026 could represent May 6 or June 5. Please select your bank statement format:',
                      style:
                          TextStyle(fontSize: 11.5, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ChoiceChip(
                          key: const Key('import_date_dmy_chip'),
                          label: const Text('DD/MM/YYYY (Pakistani / UK)'),
                          selected: _forcedDateFormat == 'DD/MM/YYYY' ||
                              _forcedDateFormat == null,
                          onSelected: (val) {
                            if (val) {
                              setState(() => _forcedDateFormat = 'DD/MM/YYYY');
                              _reparse();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          key: const Key('import_date_mdy_chip'),
                          label: const Text('MM/DD/YYYY (US)'),
                          selected: _forcedDateFormat == 'MM/DD/YYYY',
                          onSelected: (val) {
                            if (val) {
                              setState(() => _forcedDateFormat = 'MM/DD/YYYY');
                              _reparse();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Status badges
            Row(
              children: [
                _buildBadge('${pr.validCount} Ready', AppColors.accentGreen),
                const SizedBox(width: 6),
                if (pr.needsReviewCount > 0) ...[
                  _buildBadge(
                      '${pr.needsReviewCount} Review', AppColors.alertAmber),
                  const SizedBox(width: 6),
                ],
                _buildBadge(
                    '${pr.duplicateCount} Duplicates', AppColors.textMuted),
                const SizedBox(width: 6),
                _buildBadge('${pr.invalidCount} Invalid', AppColors.alertRed),
              ],
            ),
            const SizedBox(height: 14),

            // Column Mapping (expandable)
            ExpansionTile(
              initiallyExpanded: isLowConfidence,
              tilePadding: EdgeInsets.zero,
              leading: const Icon(Icons.table_chart_outlined,
                  color: AppColors.primaryNavy, size: 20),
              title: const Text('Column Mapping',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text(
                isLowConfidence
                    ? 'Required: confirm column alignment'
                    : 'Adjust if bank columns are misaligned',
                style: TextStyle(
                  fontSize: 11,
                  color: isLowConfidence
                      ? AppColors.alertAmber
                      : AppColors.textMuted,
                ),
              ),
              children: [
                const SizedBox(height: 8),
                _buildColumnDropdown(
                  label: 'Date Column',
                  selectedIndex: _customMapping?.dateColumn,
                  headers: pr.headers,
                  onChanged: (idx) {
                    setState(() {
                      _customMapping =
                          _customMapping?.copyWith(dateColumn: idx) ??
                              ColumnMapping(dateColumn: idx);
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
                      _customMapping =
                          _customMapping?.copyWith(descriptionColumn: idx) ??
                              ColumnMapping(descriptionColumn: idx);
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
                        balanceColumn: _customMapping?.balanceColumn,
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
                        balanceColumn: _customMapping?.balanceColumn,
                      );
                    });
                    _reparse();
                  },
                ),
              ],
            ),

            const Divider(height: 20),

            // Records List Header
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
                  '${pr.records.length} records',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNavy),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Transaction records preview list
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pr.records.take(15).length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (ctx, i) {
                final rec = pr.records[i];
                return InkWell(
                  onTap: () => _showEditRecordSheet(rec, i),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _buildRecordPreviewTile(rec),
                  ),
                );
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
            fontSize: 11.5,
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
    final isIncome = rec.type == TransactionType.income;
    final isTransfer = rec.type == TransactionType.transfer;

    Color directionColor = AppColors.alertRed;
    IconData directionIcon = Icons.arrow_upward_rounded;
    String directionPrefix = '-';

    if (isIncome) {
      directionColor = AppColors.accentGreen;
      directionIcon = Icons.arrow_downward_rounded;
      directionPrefix = '+';
    } else if (isTransfer) {
      directionColor = AppColors.primaryNavy;
      directionIcon = Icons.swap_horiz_rounded;
      directionPrefix = '⇄';
    }

    Color statusColor = AppColors.accentGreen;
    String statusText = 'Ready';

    if (!rec.isValid) {
      statusColor = AppColors.alertRed;
      statusText = 'Invalid';
    } else if (rec.isDuplicate) {
      statusColor = AppColors.alertAmber;
      statusText = 'Duplicate';
    } else if (rec.needsReview) {
      statusColor = AppColors.alertAmber;
      statusText = 'Review';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Direction badge
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: directionColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(
            directionIcon,
            size: 18,
            color: directionColor,
          ),
        ),
        const SizedBox(width: 10),

        // Description, Date & Category
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${rec.rawDate} • ${rec.category}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                  ),
                  if (rec.userOverridden) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.edit,
                        size: 11, color: AppColors.primaryNavy),
                  ],
                ],
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
              directionPrefix + rec.amount.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: isIncome ? AppColors.accentGreen : AppColors.textDark,
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
