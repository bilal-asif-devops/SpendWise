import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

enum BalanceValidationStatus {
  notPresent,
  verified,
  discrepancy,
}

class BalanceValidationResult {
  final BalanceValidationStatus status;
  final String? message;
  final double? startingBalance;
  final double? endingBalance;

  const BalanceValidationResult({
    required this.status,
    this.message,
    this.startingBalance,
    this.endingBalance,
  });
}

class ColumnMapping {
  int? dateColumn;
  int? descriptionColumn;
  int? amountColumn;
  int? debitColumn;
  int? creditColumn;
  int? categoryColumn;
  int? balanceColumn;
  double confidenceScore;
  bool isConfident;

  ColumnMapping({
    this.dateColumn,
    this.descriptionColumn,
    this.amountColumn,
    this.debitColumn,
    this.creditColumn,
    this.categoryColumn,
    this.balanceColumn,
    this.confidenceScore = 1.0,
    this.isConfident = true,
  });

  bool get hasValidMapping {
    final hasDate = dateColumn != null && dateColumn! >= 0;
    final hasDesc = descriptionColumn != null && descriptionColumn! >= 0;
    final hasAmount = (amountColumn != null && amountColumn! >= 0) ||
        ((debitColumn != null && debitColumn! >= 0) ||
            (creditColumn != null && creditColumn! >= 0));
    return hasDate && hasDesc && hasAmount;
  }

  ColumnMapping copyWith({
    int? dateColumn,
    int? descriptionColumn,
    int? amountColumn,
    int? debitColumn,
    int? creditColumn,
    int? categoryColumn,
    int? balanceColumn,
    double? confidenceScore,
    bool? isConfident,
  }) {
    return ColumnMapping(
      dateColumn: dateColumn ?? this.dateColumn,
      descriptionColumn: descriptionColumn ?? this.descriptionColumn,
      amountColumn: amountColumn ?? this.amountColumn,
      debitColumn: debitColumn ?? this.debitColumn,
      creditColumn: creditColumn ?? this.creditColumn,
      categoryColumn: categoryColumn ?? this.categoryColumn,
      balanceColumn: balanceColumn ?? this.balanceColumn,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      isConfident: isConfident ?? this.isConfident,
    );
  }
}

class ImportedTransactionRecord {
  final int rowIndex;
  final DateTime? date;
  final String rawDate;
  final String description;
  final double amount;
  final String rawAmount;
  TransactionType type;
  String category;
  final String importHash;
  final bool isValid;
  final String? errorMessage;
  bool isDuplicate;
  bool needsReview;
  bool userOverridden;
  final int occurrenceIndex;
  final double? runningBalance;
  bool isPotentialTransfer;
  String? transferTargetAccountId;
  String? transferTargetWalletName;

  ImportedTransactionRecord({
    required this.rowIndex,
    required this.date,
    required this.rawDate,
    required this.description,
    required this.amount,
    required this.rawAmount,
    required this.type,
    required this.category,
    required this.importHash,
    required this.isValid,
    this.errorMessage,
    this.isDuplicate = false,
    this.needsReview = false,
    this.userOverridden = false,
    this.occurrenceIndex = 0,
    this.runningBalance,
    this.isPotentialTransfer = false,
    this.transferTargetAccountId,
    this.transferTargetWalletName,
  });

  ImportedTransactionRecord copyWith({
    int? rowIndex,
    DateTime? date,
    String? rawDate,
    String? description,
    double? amount,
    String? rawAmount,
    TransactionType? type,
    String? category,
    String? importHash,
    bool? isValid,
    String? errorMessage,
    bool? isDuplicate,
    bool? needsReview,
    bool? userOverridden,
    int? occurrenceIndex,
    double? runningBalance,
    bool? isPotentialTransfer,
    String? transferTargetAccountId,
    String? transferTargetWalletName,
  }) {
    return ImportedTransactionRecord(
      rowIndex: rowIndex ?? this.rowIndex,
      date: date ?? this.date,
      rawDate: rawDate ?? this.rawDate,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      rawAmount: rawAmount ?? this.rawAmount,
      type: type ?? this.type,
      category: category ?? this.category,
      importHash: importHash ?? this.importHash,
      isValid: isValid ?? this.isValid,
      errorMessage: errorMessage ?? this.errorMessage,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      needsReview: needsReview ?? this.needsReview,
      userOverridden: userOverridden ?? this.userOverridden,
      occurrenceIndex: occurrenceIndex ?? this.occurrenceIndex,
      runningBalance: runningBalance ?? this.runningBalance,
      isPotentialTransfer: isPotentialTransfer ?? this.isPotentialTransfer,
      transferTargetAccountId:
          transferTargetAccountId ?? this.transferTargetAccountId,
      transferTargetWalletName:
          transferTargetWalletName ?? this.transferTargetWalletName,
    );
  }
}

class StatementParseResult {
  final List<String> headers;
  final List<List<dynamic>> rawRows;
  final ColumnMapping mapping;
  final List<ImportedTransactionRecord> records;
  final int validCount;
  final int duplicateCount;
  final int invalidCount;
  final int needsReviewCount;
  final bool isDateAmbiguous;
  final String? detectedDateFormat;
  final String? detectedBankPreset;
  final double totalCreditAmount;
  final double totalDebitAmount;
  final int incomingCount;
  final int outgoingCount;
  final int transferCount;
  final BalanceValidationResult balanceValidation;

  StatementParseResult({
    required this.headers,
    required this.rawRows,
    required this.mapping,
    required this.records,
    required this.validCount,
    required this.duplicateCount,
    required this.invalidCount,
    this.needsReviewCount = 0,
    this.isDateAmbiguous = false,
    this.detectedDateFormat,
    this.detectedBankPreset,
    this.totalCreditAmount = 0.0,
    this.totalDebitAmount = 0.0,
    this.incomingCount = 0,
    this.outgoingCount = 0,
    this.transferCount = 0,
    this.balanceValidation = const BalanceValidationResult(
        status: BalanceValidationStatus.notPresent),
  });
}

class BankPreset {
  final String id;
  final String bankName;
  final String country;
  final String currency;
  final String sampleCsv;
  final List<String> expectedHeaders;
  final String defaultDateFormat;

  const BankPreset({
    required this.id,
    required this.bankName,
    required this.country,
    required this.currency,
    required this.sampleCsv,
    required this.expectedHeaders,
    required this.defaultDateFormat,
  });
}

class CategorizationResult {
  final String category;
  final bool isConfident;
  final String? matchedRule;

  const CategorizationResult({
    required this.category,
    required this.isConfident,
    this.matchedRule,
  });
}

class StatementImporter {
  static final Map<String, String> userRules = {};

  static void addUserRule(String keyword, String category) {
    final cleanKey = keyword.toLowerCase().trim();
    if (cleanKey.isNotEmpty) {
      userRules[cleanKey] = category;
    }
  }

  static void clearUserRules() {
    userRules.clear();
  }

  static String detectDelimiter(String content) {
    final sampleLines = content.split('\n').take(5).join('\n');
    final commas = RegExp(r',').allMatches(sampleLines).length;
    final semicolons = RegExp(r';').allMatches(sampleLines).length;
    final tabs = RegExp(r'\t').allMatches(sampleLines).length;

    if (tabs > commas && tabs > semicolons) return '\t';
    if (semicolons > commas && semicolons > tabs) return ';';
    return ',';
  }

  static ColumnMapping detectColumnMapping(List<String> headers) {
    int? dateCol;
    int? descCol;
    int? amtCol;
    int? debitCol;
    int? creditCol;
    int? catCol;
    int? balCol;

    double confidence = 0.0;

    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase().trim();
      if (dateCol == null &&
          (h.contains('date') ||
              h.contains('txn date') ||
              h.contains('tran date') ||
              h.contains('time'))) {
        dateCol = i;
        confidence += 0.35;
      } else if (descCol == null &&
          (h.contains('desc') ||
              h.contains('narrat') ||
              h.contains('payee') ||
              h.contains('detail') ||
              h.contains('title') ||
              h.contains('memo') ||
              h.contains('particular') ||
              h.contains('remark'))) {
        descCol = i;
        confidence += 0.35;
      } else if (debitCol == null &&
          (h.contains('debit') ||
              h.contains('withdrawal') ||
              h.contains('paid out') ||
              h == 'dr')) {
        debitCol = i;
        confidence += 0.15;
      } else if (creditCol == null &&
          (h.contains('credit') ||
              h.contains('deposit') ||
              h.contains('paid in') ||
              h == 'cr')) {
        creditCol = i;
        confidence += 0.15;
      } else if (amtCol == null &&
          (h.contains('amount') || h.contains('total') || h.contains('net'))) {
        amtCol = i;
        confidence += 0.3;
      } else if (catCol == null &&
          (h.contains('category') || h.contains('type') || h.contains('tag'))) {
        catCol = i;
      } else if (balCol == null &&
          (h.contains('balance') || h.contains('bal'))) {
        balCol = i;
      }
    }

    final hasIdentifiedAmount =
        (debitCol != null || creditCol != null) || amtCol != null;
    final isConfident =
        dateCol != null && descCol != null && hasIdentifiedAmount;

    return ColumnMapping(
      dateColumn: dateCol ?? (headers.isNotEmpty ? 0 : null),
      descriptionColumn: descCol ?? (headers.length > 1 ? 1 : null),
      amountColumn: (debitCol != null || creditCol != null)
          ? null
          : (amtCol ?? (headers.length > 2 ? 2 : null)),
      debitColumn: debitCol,
      creditColumn: creditCol,
      categoryColumn: catCol,
      balanceColumn: balCol,
      confidenceScore:
          isConfident ? (confidence > 1.0 ? 1.0 : confidence) : 0.4,
      isConfident: isConfident,
    );
  }

  static StatementParseResult parseCsv({
    required String csvContent,
    String? accountId,
    ColumnMapping? explicitMapping,
    List<Expense>? existingTransactions,
    List<Account>? userAccounts,
    String? forcedDateFormat,
  }) {
    if (csvContent.trim().isEmpty) {
      return StatementParseResult(
        headers: [],
        rawRows: [],
        mapping: ColumnMapping(isConfident: false, confidenceScore: 0.0),
        records: [],
        validCount: 0,
        duplicateCount: 0,
        invalidCount: 0,
      );
    }

    // Check if content is OFX / QFX format
    if (csvContent.contains('<OFX>') || csvContent.contains('<STMTTRN>')) {
      return _parseOfx(
        ofxContent: csvContent,
        accountId: accountId,
        existingTransactions: existingTransactions,
      );
    }

    final delimiter = detectDelimiter(csvContent);
    final decoder = CsvDecoder(
      fieldDelimiter: delimiter,
      dynamicTyping: false,
    );

    // Normalize Windows CRLF to LF
    final normalizedContent =
        csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    List<List<dynamic>> rows;
    try {
      rows = decoder.convert(normalizedContent);
    } catch (_) {
      rows = _manualParseCsv(normalizedContent, delimiter);
    }

    if (rows.isEmpty) {
      return StatementParseResult(
        headers: [],
        rawRows: [],
        mapping: ColumnMapping(isConfident: false, confidenceScore: 0.0),
        records: [],
        validCount: 0,
        duplicateCount: 0,
        invalidCount: 0,
      );
    }

    // Identify header row
    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final dataRows = rows.skip(1).toList();

    // Detect Bank Preset
    final detectedPreset = _detectBankPreset(headers);

    final mapping = explicitMapping ?? detectColumnMapping(headers);

    // Inspect date strings to evaluate ambiguity
    final sampleDateStrings = <String>[];
    if (mapping.dateColumn != null) {
      for (final r in dataRows.take(20)) {
        if (mapping.dateColumn! < r.length) {
          final s = r[mapping.dateColumn!].toString().trim();
          if (s.isNotEmpty) sampleDateStrings.add(s);
        }
      }
    }
    final isAmbiguous = _isDatePatternAmbiguous(sampleDateStrings);

    final records = <ImportedTransactionRecord>[];
    int valid = 0;
    int duplicates = 0;
    int invalid = 0;
    int needsReviewCount = 0;
    int incomingCount = 0;
    int outgoingCount = 0;
    int transferCount = 0;
    double totalCredit = 0.0;
    double totalDebit = 0.0;

    // Existing transaction fingerprints (persisted in DB/vault)
    final existingFingerprints = <String>{};
    if (existingTransactions != null) {
      for (final tx in existingTransactions) {
        if (accountId == null || tx.accountId == accountId) {
          final fp = tx.importHash ??
              generateFingerprint(
                accountId: tx.accountId,
                date: tx.date,
                description: tx.title,
                amount: tx.amount,
                type: tx.type,
              );
          existingFingerprints.add(fp);
        }
      }
    }

    // Detect signed amounts in single Amount column
    bool hasNegativeAmounts = false;
    if (mapping.amountColumn != null) {
      for (final r in dataRows) {
        if (mapping.amountColumn! < r.length) {
          final str = r[mapping.amountColumn!].toString();
          final val = _parseNumber(str);
          if (val != null && (val < 0 || _isNegativeString(str))) {
            hasNegativeAmounts = true;
            break;
          }
        }
      }
    }

    // Track occurrences of identical transactions within THIS file
    // to distinguish repeated transactions in the same statement from duplicate imports
    final sessionRowCounters = <String, int>{};

    for (int idx = 0; idx < dataRows.length; idx++) {
      final row = dataRows[idx];
      if (row.isEmpty ||
          (row.length == 1 && row[0].toString().trim().isEmpty)) {
        continue;
      }

      final dateStr =
          (mapping.dateColumn != null && mapping.dateColumn! < row.length)
              ? row[mapping.dateColumn!].toString().trim()
              : '';
      final descStr = (mapping.descriptionColumn != null &&
              mapping.descriptionColumn! < row.length)
          ? row[mapping.descriptionColumn!].toString().trim()
          : '';

      String rawAmtStr = '';
      double? parsedAmount;
      TransactionType inferredType = TransactionType.expense;
      bool directionIndeterminate = false;

      if (mapping.debitColumn != null || mapping.creditColumn != null) {
        final debitStr =
            (mapping.debitColumn != null && mapping.debitColumn! < row.length)
                ? row[mapping.debitColumn!].toString().trim()
                : '';
        final creditStr =
            (mapping.creditColumn != null && mapping.creditColumn! < row.length)
                ? row[mapping.creditColumn!].toString().trim()
                : '';

        final debitVal = _parseNumber(debitStr);
        final creditVal = _parseNumber(creditStr);

        if (debitVal != null && debitVal > 0) {
          parsedAmount = debitVal;
          rawAmtStr = debitStr;
          inferredType = TransactionType.expense;
        } else if (creditVal != null && creditVal > 0) {
          parsedAmount = creditVal;
          rawAmtStr = creditStr;
          inferredType = TransactionType.income;
        } else if (debitVal != null && debitVal != 0) {
          parsedAmount = debitVal.abs();
          rawAmtStr = debitStr;
          inferredType = TransactionType.expense;
        } else if (creditVal != null && creditVal != 0) {
          parsedAmount = creditVal.abs();
          rawAmtStr = creditStr;
          inferredType = TransactionType.income;
        } else {
          directionIndeterminate = true;
        }
      } else if (mapping.amountColumn != null &&
          mapping.amountColumn! < row.length) {
        rawAmtStr = row[mapping.amountColumn!].toString().trim();
        final numVal = _parseNumber(rawAmtStr);
        if (numVal != null) {
          if (hasNegativeAmounts) {
            if (numVal < 0 || _isNegativeString(rawAmtStr)) {
              parsedAmount = numVal.abs();
              inferredType = TransactionType.expense;
            } else {
              parsedAmount = numVal;
              inferredType = TransactionType.income;
            }
          } else {
            parsedAmount = numVal.abs();
            if (_isIncomeKeyword(descStr)) {
              inferredType = TransactionType.income;
            } else {
              inferredType = TransactionType.expense;
            }
          }
        }
      }

      // Parse Running Balance if mapped
      double? rowBalance;
      if (mapping.balanceColumn != null &&
          mapping.balanceColumn! < row.length) {
        final balStr = row[mapping.balanceColumn!].toString().trim();
        rowBalance = _parseNumber(balStr);
      }

      final date = _parseDate(dateStr, forcedFormat: forcedDateFormat);
      final desc = descStr.isNotEmpty ? descStr : "Transaction ${idx + 1}";

      // Internal transfer detection between user's own accounts
      bool isPotentialTransfer = false;
      String? transferTargetAccountId;
      String? transferTargetWalletName;
      TransactionType finalType = inferredType;

      if (userAccounts != null && userAccounts.isNotEmpty) {
        final lowerDesc = desc.toLowerCase();
        for (final acc in userAccounts) {
          if (acc.id != accountId && acc.name.isNotEmpty) {
            final accNameLower = acc.name.toLowerCase();
            if (lowerDesc.contains(accNameLower) &&
                (lowerDesc.contains('transfer') ||
                    lowerDesc.contains('ibft') ||
                    lowerDesc.contains('raast') ||
                    lowerDesc.contains('to ') ||
                    lowerDesc.contains('from '))) {
              finalType = TransactionType.transfer;
              transferTargetAccountId = acc.id;
              transferTargetWalletName = acc.name;
              isPotentialTransfer = true;
              break;
            }
          }
        }

        if (!isPotentialTransfer &&
            userAccounts.length > 1 &&
            (lowerDesc.contains('internal transfer') ||
                lowerDesc.contains('self transfer') ||
                lowerDesc.contains('own account transfer'))) {
          isPotentialTransfer = true;
        }
      }

      // Category handling: never required, defaults safely to "Uncategorized"
      String category;
      if (mapping.categoryColumn != null &&
          mapping.categoryColumn! < row.length &&
          row[mapping.categoryColumn!].toString().trim().isNotEmpty) {
        category = row[mapping.categoryColumn!].toString().trim();
      } else {
        final catResult = inferCategory(desc, type: finalType);
        category = catResult.category;
      }

      bool isValid = true;
      bool rowNeedsReview = false;
      String? error;

      if (date == null) {
        isValid = false;
        rowNeedsReview = true;
        error = "Unrecognized date format: '$dateStr'";
      } else if (parsedAmount == null ||
          parsedAmount <= 0 ||
          !parsedAmount.isFinite ||
          parsedAmount.isNaN) {
        isValid = false;
        rowNeedsReview = true;
        error = "Invalid or non-positive amount: '$rawAmtStr'";
      } else if (directionIndeterminate) {
        rowNeedsReview = true;
        error = "Transaction direction (incoming or outgoing) is uncertain";
      } else if (isPotentialTransfer &&
          transferTargetAccountId == null &&
          userAccounts != null &&
          userAccounts.length > 1) {
        rowNeedsReview = true;
        error =
            "Potential transfer detected — please verify counterparty account";
      }

      // Base transaction identity for deduplication
      final baseFpKey =
          "${date?.toIso8601String()}|$desc|${parsedAmount?.toStringAsFixed(2)}|${finalType.name}";
      final occIndex = sessionRowCounters[baseFpKey] ?? 0;
      sessionRowCounters[baseFpKey] = occIndex + 1;

      final fingerprint = generateFingerprint(
        accountId: accountId ?? 'acc_import',
        date: date ?? DateTime.now(),
        description: desc,
        amount: parsedAmount ?? 0.0,
        type: finalType,
        occurrenceIndex: occIndex,
      );

      final isDup = isValid && existingFingerprints.contains(fingerprint);

      if (isValid) {
        if (isDup) {
          duplicates++;
        } else {
          valid++;
          if (finalType == TransactionType.income) {
            totalCredit += parsedAmount!;
            incomingCount++;
          } else if (finalType == TransactionType.expense) {
            totalDebit += parsedAmount!;
            outgoingCount++;
          } else {
            transferCount++;
          }
          if (rowNeedsReview) {
            needsReviewCount++;
          }
        }
      } else {
        invalid++;
        needsReviewCount++;
      }

      records.add(
        ImportedTransactionRecord(
          rowIndex: idx + 1,
          date: date,
          rawDate: dateStr,
          description: desc,
          amount: parsedAmount ?? 0.0,
          rawAmount: rawAmtStr,
          type: finalType,
          category: category,
          importHash: fingerprint,
          isValid: isValid,
          errorMessage: error,
          isDuplicate: isDup,
          needsReview: rowNeedsReview,
          occurrenceIndex: occIndex,
          runningBalance: rowBalance,
          isPotentialTransfer: isPotentialTransfer,
          transferTargetAccountId: transferTargetAccountId,
          transferTargetWalletName: transferTargetWalletName,
        ),
      );
    }

    // Mathematical balance verification across running balances (if present)
    BalanceValidationResult balanceValidation = const BalanceValidationResult(
      status: BalanceValidationStatus.notPresent,
    );

    final rowsWithBalance =
        records.where((r) => r.isValid && r.runningBalance != null).toList();
    if (rowsWithBalance.length >= 2) {
      bool isChronologicalValid = true;
      bool isReverseValid = true;
      String? discrepancyMsg;

      for (int i = 0; i < rowsWithBalance.length - 1; i++) {
        final curr = rowsWithBalance[i];
        final next = rowsWithBalance[i + 1];
        final netChange =
            next.type == TransactionType.income ? next.amount : -next.amount;
        final expectedNext = curr.runningBalance! + netChange;
        if ((expectedNext - next.runningBalance!).abs() > 0.05) {
          isChronologicalValid = false;
          discrepancyMsg =
              "Balance mismatch at Row ${next.rowIndex}: expected ${expectedNext.toStringAsFixed(2)}, statement shows ${next.runningBalance!.toStringAsFixed(2)}";
          break;
        }
      }

      if (!isChronologicalValid) {
        for (int i = 0; i < rowsWithBalance.length - 1; i++) {
          final curr = rowsWithBalance[i];
          final next = rowsWithBalance[i + 1];
          final netChange =
              curr.type == TransactionType.income ? curr.amount : -curr.amount;
          final expectedCurr = next.runningBalance! + netChange;
          if ((expectedCurr - curr.runningBalance!).abs() > 0.05) {
            isReverseValid = false;
            break;
          }
        }
      }

      if (isChronologicalValid || isReverseValid) {
        balanceValidation = BalanceValidationResult(
          status: BalanceValidationStatus.verified,
          message:
              "All running balances verified mathematically against transactions.",
          startingBalance: rowsWithBalance.first.runningBalance,
          endingBalance: rowsWithBalance.last.runningBalance,
        );
      } else {
        balanceValidation = BalanceValidationResult(
          status: BalanceValidationStatus.discrepancy,
          message: discrepancyMsg ??
              "Detected discrepancy between running balance and transaction amounts.",
          startingBalance: rowsWithBalance.first.runningBalance,
          endingBalance: rowsWithBalance.last.runningBalance,
        );
      }
    }

    return StatementParseResult(
      headers: headers,
      rawRows: dataRows,
      mapping: mapping,
      records: records,
      validCount: valid,
      duplicateCount: duplicates,
      invalidCount: invalid,
      needsReviewCount: needsReviewCount,
      isDateAmbiguous: isAmbiguous,
      detectedDateFormat:
          forcedDateFormat ?? (isAmbiguous ? null : 'dd/MM/yyyy'),
      detectedBankPreset: detectedPreset?.bankName,
      totalCreditAmount: totalCredit,
      totalDebitAmount: totalDebit,
      incomingCount: incomingCount,
      outgoingCount: outgoingCount,
      transferCount: transferCount,
      balanceValidation: balanceValidation,
    );
  }

  static String generateFingerprint({
    required String accountId,
    required DateTime date,
    required String description,
    required double amount,
    required TransactionType type,
    int occurrenceIndex = 0,
  }) {
    final normDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final normDesc =
        description.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    final normAmt = amount.toStringAsFixed(2);
    final occSuffix = occurrenceIndex > 0 ? "#$occurrenceIndex" : "";
    final rawKey =
        "$accountId|$normDate|$normDesc|$normAmt|${type.name}$occSuffix";

    int hash = 0x811c9dc5;
    for (int i = 0; i < rawKey.length; i++) {
      hash ^= rawKey.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return "imp_${hash.toRadixString(16).padLeft(8, '0')}";
  }

  static bool _isDatePatternAmbiguous(List<String> dates) {
    if (dates.isEmpty) return false;
    for (final d in dates) {
      final clean = d.trim();
      final parts = clean.split(RegExp(r'[/.\-]'));
      if (parts.length >= 3) {
        final p1 = int.tryParse(parts[0]);
        final p2 = int.tryParse(parts[1]);
        if (p1 != null && p2 != null) {
          if (p1 > 12 || p2 > 12) {
            return false;
          }
        }
      }
    }
    return true;
  }

  static DateTime? _parseDate(String dateStr, {String? forcedFormat}) {
    if (dateStr.trim().isEmpty) return null;
    var clean = dateStr.trim();

    final iso = DateTime.tryParse(clean);
    if (iso != null && forcedFormat == null) return iso;

    clean = _normalizeMonthCase(clean);

    if (forcedFormat != null && forcedFormat.isNotEmpty) {
      String normFmt = forcedFormat;
      if (normFmt.toUpperCase() == 'MM/DD/YYYY') normFmt = 'MM/dd/yyyy';
      if (normFmt.toUpperCase() == 'DD/MM/YYYY') normFmt = 'dd/MM/yyyy';
      if (normFmt.toUpperCase() == 'YYYY-MM-DD') normFmt = 'yyyy-MM-dd';
      if (normFmt.toUpperCase() == 'DD-MM-YYYY') normFmt = 'dd-MM-yyyy';
      if (normFmt.toUpperCase() == 'DD.MM.YYYY') normFmt = 'dd.MM.yyyy';
      try {
        return DateFormat(normFmt).parseStrict(clean);
      } catch (_) {}
    }

    final formats = [
      'yyyy-MM-dd',
      'dd/MM/yyyy',
      'dd-MM-yyyy',
      'dd-MMM-yyyy',
      'd-MMM-yyyy',
      'dd.MM.yyyy',
      'd/M/yyyy',
      'd-M-yyyy',
      'd.M.yyyy',
      'MMM d, yyyy',
      'd MMM yyyy',
      'MM/dd/yyyy',
      'yyyy/MM/dd',
      'MM/dd/yy',
      'dd/MM/yy',
    ];

    for (final fmt in formats) {
      try {
        final parsed = DateFormat(fmt).parseStrict(clean);
        return parsed;
      } catch (_) {}
    }

    return null;
  }

  static String _normalizeMonthCase(String str) {
    final months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    for (final m in months) {
      if (str.contains(m)) {
        final titleCase = m[0] + m.substring(1).toLowerCase();
        return str.replaceAll(m, titleCase);
      }
    }
    return str;
  }

  static double? _parseNumber(String numStr) {
    if (numStr.trim().isEmpty) return null;
    var clean = numStr.trim();

    bool isParenNegative = false;
    if (clean.startsWith('(') && clean.endsWith(')')) {
      isParenNegative = true;
      clean = clean.substring(1, clean.length - 1).trim();
    }

    // Strip currency prefixes and words (e.g. "Rs.", "PKR", "USD", "$", "€", "£")
    clean = clean.replaceAll(RegExp(r'^[a-zA-Z\s.$€£¥₹]+'), '');
    clean = clean.replaceAll(RegExp(r'[a-zA-Z$€£¥₹\s]'), '');
    // Remove thousand separators
    clean = clean.replaceAll(',', '');

    if (clean.isEmpty || clean == '-') return null;

    final val = double.tryParse(clean);
    if (val == null) return null;
    return isParenNegative ? -val.abs() : val;
  }

  static bool _isNegativeString(String s) {
    final t = s.trim();
    return t.startsWith('-') ||
        (t.startsWith('(') && t.endsWith(')')) ||
        t.toUpperCase().endsWith('DR');
  }

  static bool _isIncomeKeyword(String text) {
    final lower = text.toLowerCase();
    return lower.contains('salary') ||
        lower.contains('payroll') ||
        lower.contains('deposit') ||
        lower.contains('credit interest') ||
        lower.contains('dividend') ||
        lower.contains('profit') ||
        lower.contains('remittance') ||
        lower.contains('income');
  }

  static CategorizationResult inferCategory(String description,
      {TransactionType? type}) {
    final lower = description.toLowerCase();

    // Layer 1: Check user-defined rules
    for (final entry in userRules.entries) {
      if (lower.contains(entry.key)) {
        return CategorizationResult(
          category: entry.value,
          isConfident: true,
          matchedRule: 'User Rule: ${entry.key}',
        );
      }
    }

    // High-confidence patterns
    if (lower.contains('imtiaz') ||
        lower.contains('carrefour') ||
        lower.contains('metro') ||
        lower.contains('al-fatah') ||
        lower.contains('al fatah') ||
        lower.contains('naheed') ||
        lower.contains('chase up') ||
        lower.contains('chaseup') ||
        lower.contains('jalal sons') ||
        lower.contains('spar') ||
        lower.contains('hyperstar') ||
        lower.contains('grocery') ||
        lower.contains('supermarket') ||
        lower.contains('mart') ||
        lower.contains('tesco') ||
        lower.contains('whole foods')) {
      return const CategorizationResult(
        category: 'Groceries',
        isConfident: true,
        matchedRule: 'Merchant: Grocery',
      );
    }

    if (lower.contains('foodpanda') ||
        lower.contains('mcdonald') ||
        lower.contains('kfc') ||
        lower.contains('subway') ||
        lower.contains('gloria jean') ||
        lower.contains('second cup') ||
        lower.contains('broadway') ||
        lower.contains('cheezious') ||
        lower.contains('coffee wagera') ||
        lower.contains('kababjees') ||
        lower.contains('dunkin') ||
        lower.contains('hardees') ||
        lower.contains('domino') ||
        lower.contains('pizza') ||
        lower.contains('burger') ||
        lower.contains('cafe') ||
        lower.contains('coffee') ||
        lower.contains('restaurant') ||
        lower.contains('bistro') ||
        lower.contains('pret a manger') ||
        lower.contains('starbucks')) {
      return const CategorizationResult(
        category: 'Food & Drink',
        isConfident: true,
        matchedRule: 'Merchant: Dining & Food',
      );
    }

    if (lower.contains('careem') ||
        lower.contains('bykea') ||
        lower.contains('indrive') ||
        lower.contains('in-drive') ||
        lower.contains('uber') ||
        lower.contains('metro bus') ||
        lower.contains('speedo') ||
        lower.contains('orange line') ||
        lower.contains('petrol') ||
        lower.contains('fuel') ||
        lower.contains('shell') ||
        lower.contains('pso') ||
        lower.contains('total parco') ||
        lower.contains('attock') ||
        lower.contains('gas station') ||
        lower.contains('transport for london')) {
      return const CategorizationResult(
        category: 'Transport',
        isConfident: true,
        matchedRule: 'Merchant: Transit & Fuel',
      );
    }

    if (lower.contains('k-electric') ||
        lower.contains('kelectric') ||
        lower.contains('iesco') ||
        lower.contains('lesco') ||
        lower.contains('fesco') ||
        lower.contains('mepco') ||
        lower.contains('ssgc') ||
        lower.contains('sngpl') ||
        lower.contains('ptcl') ||
        lower.contains('nayatel') ||
        lower.contains('stormfiber') ||
        lower.contains('transworld') ||
        lower.contains('jazz bill') ||
        lower.contains('telenor bill') ||
        lower.contains('zong bill') ||
        lower.contains('ufone bill') ||
        lower.contains('electric') ||
        lower.contains('utility')) {
      return const CategorizationResult(
        category: 'Bills & Fees',
        isConfident: true,
        matchedRule: 'Utility: Public Service',
      );
    }

    if (lower.contains('daraz') ||
        lower.contains('amazon') ||
        lower.contains('aliexpress') ||
        lower.contains('telemart') ||
        lower.contains('shophive') ||
        lower.contains('khaadi') ||
        lower.contains('sapphire') ||
        lower.contains('gul ahmed') ||
        lower.contains('outfitters') ||
        lower.contains('junaid jamshed') ||
        lower.contains('target store') ||
        lower.contains('shopping')) {
      return const CategorizationResult(
        category: 'Shopping',
        isConfident: true,
        matchedRule: 'Retail: Shopping',
      );
    }

    if (lower.contains('salary') ||
        lower.contains('payroll') ||
        lower.contains('retainer') ||
        lower.contains('deposit payroll')) {
      return const CategorizationResult(
        category: 'Salary',
        isConfident: true,
        matchedRule: 'Income: Payroll',
      );
    }

    // Default safe fallback: Uncategorized without inventing a purpose
    return const CategorizationResult(
      category: 'Uncategorized',
      isConfident: false,
      matchedRule: null,
    );
  }

  static BankPreset? _detectBankPreset(List<String> headers) {
    final lowerHeaders = headers.map((h) => h.toLowerCase().trim()).toList();

    if (lowerHeaders
        .any((h) => h.contains('cheque no') || h.contains('cheque-no'))) {
      return hblPreset;
    }
    if (lowerHeaders
        .any((h) => h.contains('cheque #') || h.contains('txn date'))) {
      return mcbPreset;
    }
    if (lowerHeaders
        .any((h) => h.contains('particulars') || h.contains('tran date'))) {
      return ublPreset;
    }
    if (lowerHeaders.any((h) =>
        h.contains('transaction details') || h.contains('debit amount'))) {
      return alfalahPreset;
    }
    if (lowerHeaders
        .any((h) => h.contains('withdrawals') || h.contains('deposits'))) {
      return scbPreset;
    }
    if (lowerHeaders.any((h) => h.contains('completed date'))) {
      return revolutPreset;
    }
    if (lowerHeaders.any((h) => h.contains('post date'))) {
      return chasePreset;
    }
    if (lowerHeaders.any((h) => h == 'date') &&
        lowerHeaders.any((h) => h.contains('debit')) &&
        lowerHeaders.any((h) => h.contains('credit'))) {
      return meezanPreset;
    }

    for (final preset in allPresets) {
      bool allMatch = true;
      for (final exp in preset.expectedHeaders) {
        final expLower = exp.toLowerCase();
        if (!lowerHeaders.any((h) => h == expLower)) {
          allMatch = false;
          break;
        }
      }
      if (allMatch) return preset;
    }
    return null;
  }

  static List<List<dynamic>> _manualParseCsv(String content, String delimiter) {
    final result = <List<dynamic>>[];
    final lines = content.split('\n');
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final tokens = line
          .split(delimiter)
          .map((e) => e.replaceAll('"', '').trim())
          .toList();
      result.add(tokens);
    }
    return result;
  }

  static StatementParseResult _parseOfx({
    required String ofxContent,
    String? accountId,
    List<Expense>? existingTransactions,
  }) {
    final records = <ImportedTransactionRecord>[];
    final existingFingerprints = <String>{};
    if (existingTransactions != null) {
      for (final tx in existingTransactions) {
        if (accountId == null || tx.accountId == accountId) {
          existingFingerprints.add(tx.importHash ?? '');
        }
      }
    }

    final trnRegex = RegExp(r'<STMTTRN>(.*?)</STMTTRN>', dotAll: true);
    final matches = trnRegex.allMatches(ofxContent);

    int valid = 0;
    int duplicates = 0;
    int invalid = 0;
    int incomingCount = 0;
    int outgoingCount = 0;
    double totalCredit = 0.0;
    double totalDebit = 0.0;
    int rowIndex = 1;

    for (final m in matches) {
      final block = m.group(1) ?? '';
      rowIndex++;

      final typeMatch = RegExp(r'<TRNTYPE>(.*?)[\r\n<]').firstMatch(block);
      final dateMatch = RegExp(r'<DTPOSTED>(\d{8})').firstMatch(block);
      final amtMatch = RegExp(r'<TRNAMT>([-\d.]+)').firstMatch(block);
      final nameMatch = RegExp(r'<NAME>(.*?)[\r\n<]').firstMatch(block);
      final memoMatch = RegExp(r'<MEMO>(.*?)[\r\n<]').firstMatch(block);

      final rawType = typeMatch?.group(1)?.trim() ?? 'DEBIT';
      final rawDate = dateMatch?.group(1)?.trim() ?? '';
      final rawAmt = amtMatch?.group(1)?.trim() ?? '0';
      final desc = (nameMatch?.group(1)?.trim() ??
              memoMatch?.group(1)?.trim() ??
              'OFX Transaction')
          .trim();

      DateTime? date;
      if (rawDate.length == 8) {
        final y = int.tryParse(rawDate.substring(0, 4));
        final mo = int.tryParse(rawDate.substring(4, 6));
        final d = int.tryParse(rawDate.substring(6, 8));
        if (y != null && mo != null && d != null) {
          date = DateTime(y, mo, d);
        }
      }

      final amountVal = double.tryParse(rawAmt);
      final isExpense =
          (amountVal != null && amountVal < 0) || rawType == 'DEBIT';
      final positiveAmt = amountVal != null ? amountVal.abs() : 0.0;
      final type = isExpense ? TransactionType.expense : TransactionType.income;

      final catResult = inferCategory(desc, type: type);
      final isValid = date != null && positiveAmt > 0;

      final fp = generateFingerprint(
        accountId: accountId ?? 'acc_ofx',
        date: date ?? DateTime.now(),
        description: desc,
        amount: positiveAmt,
        type: type,
      );

      final isDup = isValid && existingFingerprints.contains(fp);
      if (isValid) {
        if (isDup) {
          duplicates++;
        } else {
          valid++;
          if (type == TransactionType.income) {
            totalCredit += positiveAmt;
            incomingCount++;
          } else {
            totalDebit += positiveAmt;
            outgoingCount++;
          }
        }
      } else {
        invalid++;
      }

      records.add(
        ImportedTransactionRecord(
          rowIndex: rowIndex,
          date: date,
          rawDate: rawDate,
          description: desc,
          amount: positiveAmt,
          rawAmount: rawAmt,
          type: type,
          category: catResult.category,
          importHash: fp,
          isValid: isValid,
          errorMessage: isValid ? null : 'Invalid date or amount in OFX block',
          isDuplicate: isDup,
          needsReview: !isValid,
        ),
      );
    }

    return StatementParseResult(
      headers: ['OFX', 'XML'],
      rawRows: [],
      mapping: ColumnMapping(),
      records: records,
      validCount: valid,
      duplicateCount: duplicates,
      invalidCount: invalid,
      needsReviewCount: invalid,
      detectedBankPreset: 'OFX / QFX File',
      totalCreditAmount: totalCredit,
      totalDebitAmount: totalDebit,
      incomingCount: incomingCount,
      outgoingCount: outgoingCount,
    );
  }

  // Pre-configured bank fixtures & presets
  static const BankPreset meezanPreset = BankPreset(
    id: 'meezan',
    bankName: 'Meezan Bank',
    country: 'Pakistan',
    currency: 'PKR',
    expectedHeaders: ['Date', 'Description', 'Debit', 'Credit'],
    defaultDateFormat: 'yyyy-MM-dd',
    sampleCsv: SampleStatements.meezanBankCsv,
  );

  static const BankPreset hblPreset = BankPreset(
    id: 'hbl',
    bankName: 'Habib Bank Limited (HBL)',
    country: 'Pakistan',
    currency: 'PKR',
    expectedHeaders: ['Transaction Date', 'Description', 'Debit', 'Credit'],
    defaultDateFormat: 'dd/MM/yyyy',
    sampleCsv: SampleStatements.hblCsv,
  );

  static const BankPreset alfalahPreset = BankPreset(
    id: 'alfalah',
    bankName: 'Bank Alfalah',
    country: 'Pakistan',
    currency: 'PKR',
    expectedHeaders: [
      'Date',
      'Transaction Details',
      'Debit Amount',
      'Credit Amount'
    ],
    defaultDateFormat: 'dd-MMM-yyyy',
    sampleCsv: SampleStatements.bankAlfalahCsv,
  );

  static const BankPreset ublPreset = BankPreset(
    id: 'ubl',
    bankName: 'United Bank Limited (UBL)',
    country: 'Pakistan',
    currency: 'PKR',
    expectedHeaders: ['Tran Date', 'Particulars', 'Debit', 'Credit'],
    defaultDateFormat: 'dd/MM/yyyy',
    sampleCsv: SampleStatements.ublCsv,
  );

  static const BankPreset mcbPreset = BankPreset(
    id: 'mcb',
    bankName: 'Muslim Commercial Bank (MCB)',
    country: 'Pakistan',
    currency: 'PKR',
    expectedHeaders: ['Txn Date', 'Description', 'Debit', 'Credit'],
    defaultDateFormat: 'dd-MM-yyyy',
    sampleCsv: SampleStatements.mcbCsv,
  );

  static const BankPreset scbPreset = BankPreset(
    id: 'scb_pk',
    bankName: 'Standard Chartered Pakistan',
    country: 'Pakistan',
    currency: 'PKR',
    expectedHeaders: ['Date', 'Description', 'Withdrawals', 'Deposits'],
    defaultDateFormat: 'dd/MM/yyyy',
    sampleCsv: SampleStatements.standardCharteredPkCsv,
  );

  static const BankPreset revolutPreset = BankPreset(
    id: 'revolut',
    bankName: 'Revolut (GBP)',
    country: 'United Kingdom',
    currency: 'GBP',
    expectedHeaders: ['Completed Date', 'Description', 'Amount'],
    defaultDateFormat: 'yyyy-MM-dd',
    sampleCsv: SampleStatements.revolutGbpCsv,
  );

  static const BankPreset chasePreset = BankPreset(
    id: 'chase',
    bankName: 'Chase Bank (USD)',
    country: 'United States',
    currency: 'USD',
    expectedHeaders: ['Transaction Date', 'Description', 'Amount'],
    defaultDateFormat: 'MM/dd/yyyy',
    sampleCsv: SampleStatements.chaseUsdCsv,
  );

  static const List<BankPreset> allPresets = [
    meezanPreset,
    hblPreset,
    alfalahPreset,
    ublPreset,
    mcbPreset,
    scbPreset,
    revolutPreset,
    chasePreset,
  ];
}

class SampleStatements {
  static const String meezanBankCsv = '''Date,Description,Debit,Credit,Balance
2026-10-15,Salary Transfer - Tech Solutions,,250000.00,320000.00
2026-10-16,Imtiaz Super Market Grocery,14500.00,,305500.00
2026-10-17,Shell Petroleum Fuel,6500.00,,299000.00
2026-10-18,K-Electric Electricity Bill,18200.00,,280800.00
2026-10-19,Gloria Jean's Coffee & Snacks,1850.00,,278950.00
2026-10-20,Daraz Online Shopping,4990.00,,273960.00''';

  static const String hblCsv =
      '''Transaction Date,Value Date,Description,Cheque No,Debit,Credit,Balance
15/10/2026,15/10/2026,IBFT From Software House,,,220000.00,350000.00
16/10/2026,16/10/2026,Carrefour Hypermarket,,14500.00,,335500.00
17/10/2026,17/10/2026,Careem Ride Karachi,,850.00,,334650.00
18/10/2026,18/10/2026,SSGC Sui Southern Gas Bill,,3400.00,,331250.00
19/10/2026,19/10/2026,Foodpanda Online Order,,2450.00,,328800.00
20/10/2026,20/10/2026,Khaadi Ready to Wear,,7800.00,,321000.00''';

  static const String bankAlfalahCsv =
      '''Date,Transaction Details,Instrument No,Debit Amount,Credit Amount,Balance
15-OCT-2026,Monthly Retainer Consulting,,,180000.00,290000.00
16-OCT-2026,Naheed Supermarket Grocery,,12400.00,,277600.00
17-OCT-2026,PSO Fuel Station F-7 Islamabad,,5500.00,,272100.00
18-OCT-2026,IESCO Electricity Bill,,15600.00,,256500.00
19-OCT-2026,KFC Fast Food Restaurant,,2100.00,,254400.00
20-OCT-2026,Sapphire Clothing Store,,6200.00,,248200.00''';

  static const String ublCsv =
      '''Tran Date,Particulars,Instrument No.,Debit,Credit,Balance
15/10/2026,Direct Deposit Salary,,,195000.00,245000.00
16/10/2026,Al-Fatah Department Store,16800.00,,228200.00
17/10/2026,Bykea Delivery & Ride,450.00,,227750.00
18/10/2026,SNGPL Gas Utility Bill,2900.00,,224850.00
19/10/2026,Cheezious Commercial Market,1950.00,,222900.00
20/10/2026,Telemart Mobile Accessories,3800.00,,219100.00''';

  static const String mcbCsv =
      '''Txn Date,Description,Cheque #,Debit,Credit,Balance
15-10-2026,Payroll Credit Tech Ltd,,,175000.00,210000.00
16-10-2026,Chase Up Shopping Centre,8900.00,,201100.00
17-10-2026,Total Parco Petrol Station,4200.00,,196900.00
18-10-2026,PTCL Broadband Internet Bill,4500.00,,192400.00
19-10-2026,McDonalds Drive Thru,1650.00,,190750.00
20-10-2026,Outfitters Casuals,5400.00,,185350.00''';

  static const String standardCharteredPkCsv =
      '''Date,Description,Withdrawals,Deposits,Balance
15/10/2026,Remittance Inward Transfer,,300000.00,450000.00
16/10/2026,Jalal Sons Bakery & Grocery,9500.00,,440500.00
17/10/2026,Uber Premier Lahore,1200.00,,439300.00
18/10/2026,LESCO Electric Bill,22400.00,,416900.00
19/10/2026,Second Cup Gulberg,1450.00,,415450.00
20/10/2026,Gul Ahmed Ideas Online,8500.00,,406950.00''';

  static const String revolutGbpCsv =
      '''Completed Date,Description,Amount,Fee,Currency
2026-10-12,Pret A Manger,-4.25,0.00,GBP
2026-10-14,Tesco Superstore Express,-32.80,0.00,GBP
2026-10-16,Freelance UI Consulting,1200.00,0.00,GBP
2026-10-18,Transport for London Tube,-3.40,0.00,GBP
2026-10-19,Amazon UK Electronics,-45.99,0.00,GBP''';

  static const String chaseUsdCsv =
      '''Transaction Date,Post Date,Description,Category,Type,Amount
10/10/2026,10/11/2026,Whole Foods Market,Groceries,Sale,-84.50
10/12/2026,10/13/2026,Direct Deposit Payroll,Income,Credit,3200.00
10/14/2026,10/15/2026,Uber Trip SF,Travel,Sale,-24.15
10/16/2026,10/17/2026,Netflix Subscription,Entertainment,Sale,-15.99
10/18/2026,10/19/2026,Target Store,Shopping,Sale,-68.20''';

  static const String sampleOfx = '''OFXHEADER:100
DATA:OFXSGML
VERSION:102
SECURITY:NONE
ENCODING:USASCII
CHARSET:1252
COMPRESSION:NONE
OLDFILEUID:NONE
NEWFILEUID:NONE

<OFX>
<BANKMSGSRSV1>
<STMTTRNRS>
<STMTRS>
<CURDEF>PKR
<BANKTRANLIST>
<STMTTRN>
<TRNTYPE>CREDIT
<DTPOSTED>20261015120000
<TRNAMT>185000.00
<NAME>Salary Monthly Payout</NAME>
<MEMO>Oct 2026 Payroll</MEMO>
</STMTTRN>
<STMTTRN>
<TRNTYPE>DEBIT
<DTPOSTED>20261016140000
<TRNAMT>-8500.00
<NAME>Carrefour Market</NAME>
<MEMO>Groceries</MEMO>
</STMTTRN>
<STMTTRN>
<TRNTYPE>DEBIT
<DTPOSTED>20261017180000
<TRNAMT>-1850.00
<NAME>Foodpanda Karachi</NAME>
<MEMO>Dinner delivery</MEMO>
</STMTTRN>
</BANKTRANLIST>
</STMTRS>
</STMTTRNRS>
</BANKMSGSRSV1>
</OFX>''';
}
