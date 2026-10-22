import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

class ColumnMapping {
  int? dateColumn;
  int? descriptionColumn;
  int? amountColumn;
  int? debitColumn;
  int? creditColumn;
  int? categoryColumn;

  ColumnMapping({
    this.dateColumn,
    this.descriptionColumn,
    this.amountColumn,
    this.debitColumn,
    this.creditColumn,
    this.categoryColumn,
  });

  bool get hasValidMapping {
    final hasDate = dateColumn != null && dateColumn! >= 0;
    final hasDesc = descriptionColumn != null && descriptionColumn! >= 0;
    final hasAmount = (amountColumn != null && amountColumn! >= 0) ||
        ((debitColumn != null && debitColumn! >= 0) ||
            (creditColumn != null && creditColumn! >= 0));
    return hasDate && hasDesc && hasAmount;
  }
}

class ImportedTransactionRecord {
  final int rowIndex;
  final DateTime? date;
  final String rawDate;
  final String description;
  final double amount;
  final String rawAmount;
  final TransactionType type;
  final String category;
  final String importHash;
  final bool isValid;
  final String? errorMessage;
  bool isDuplicate;

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
  });
}

class StatementParseResult {
  final List<String> headers;
  final List<List<dynamic>> rawRows;
  final ColumnMapping mapping;
  final List<ImportedTransactionRecord> records;
  final int validCount;
  final int duplicateCount;
  final int invalidCount;

  StatementParseResult({
    required this.headers,
    required this.rawRows,
    required this.mapping,
    required this.records,
    required this.validCount,
    required this.duplicateCount,
    required this.invalidCount,
  });
}

class StatementImporter {
  static String detectDelimiter(String content) {
    final firstLine = content.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => '',
        );
    if (firstLine.contains('\t')) return '\t';
    if (firstLine.contains(';') &&
        firstLine.split(';').length >= firstLine.split(',').length) {
      return ';';
    }
    return ',';
  }

  static ColumnMapping detectColumnMapping(List<String> headers) {
    int? dateCol;
    int? descCol;
    int? amtCol;
    int? debitCol;
    int? creditCol;
    int? catCol;

    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase().trim();
      if (dateCol == null &&
          (h.contains('date') ||
              h.contains('txn date') ||
              h.contains('time'))) {
        dateCol = i;
      } else if (descCol == null &&
          (h.contains('desc') ||
              h.contains('narrat') ||
              h.contains('payee') ||
              h.contains('detail') ||
              h.contains('title') ||
              h.contains('memo') ||
              h.contains('particular'))) {
        descCol = i;
      } else if (debitCol == null &&
          (h.contains('debit') ||
              h.contains('withdrawal') ||
              h.contains('paid out'))) {
        debitCol = i;
      } else if (creditCol == null &&
          (h.contains('credit') ||
              h.contains('deposit') ||
              h.contains('paid in'))) {
        creditCol = i;
      } else if (amtCol == null &&
          (h.contains('amount') || h.contains('total') || h.contains('net'))) {
        amtCol = i;
      } else if (catCol == null &&
          (h.contains('category') || h.contains('type') || h.contains('tag'))) {
        catCol = i;
      }
    }

    return ColumnMapping(
      dateColumn: dateCol ?? (headers.isNotEmpty ? 0 : null),
      descriptionColumn: descCol ?? (headers.length > 1 ? 1 : null),
      amountColumn: (debitCol != null || creditCol != null)
          ? null
          : (amtCol ?? (headers.length > 2 ? 2 : null)),
      debitColumn: debitCol,
      creditColumn: creditCol,
      categoryColumn: catCol,
    );
  }

  static StatementParseResult parseCsv({
    required String csvContent,
    String? accountId,
    ColumnMapping? explicitMapping,
    List<Expense>? existingTransactions,
  }) {
    if (csvContent.trim().isEmpty) {
      return StatementParseResult(
        headers: [],
        rawRows: [],
        mapping: ColumnMapping(),
        records: [],
        validCount: 0,
        duplicateCount: 0,
        invalidCount: 0,
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
    } catch (e) {
      // Fallback manual parser if converter encounters parsing issues
      rows = _manualParseCsv(normalizedContent, delimiter);
    }

    if (rows.isEmpty) {
      return StatementParseResult(
        headers: [],
        rawRows: [],
        mapping: ColumnMapping(),
        records: [],
        validCount: 0,
        duplicateCount: 0,
        invalidCount: 0,
      );
    }

    // Determine header row (row 0 or first non-empty row)
    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final dataRows = rows.skip(1).toList();

    final mapping = explicitMapping ?? detectColumnMapping(headers);

    final records = <ImportedTransactionRecord>[];
    int valid = 0;
    int duplicates = 0;
    int invalid = 0;

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

    // Detect if this CSV has signed amounts in the Amount column
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

    for (int idx = 0; idx < dataRows.length; idx++) {
      final row = dataRows[idx];
      if (row.isEmpty ||
          (row.length == 1 && row[0].toString().trim().isEmpty)) {
        continue; // Skip empty row
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

      if (mapping.debitColumn != null || mapping.creditColumn != null) {
        // Separate debit/credit columns
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
        }
      } else if (mapping.amountColumn != null &&
          mapping.amountColumn! < row.length) {
        rawAmtStr = row[mapping.amountColumn!].toString().trim();
        final numVal = _parseNumber(rawAmtStr);
        if (numVal != null) {
          if (hasNegativeAmounts) {
            // Signed statement: negative = expense, positive = income
            if (numVal < 0 || _isNegativeString(rawAmtStr)) {
              parsedAmount = numVal.abs();
              inferredType = TransactionType.expense;
            } else {
              parsedAmount = numVal;
              inferredType = TransactionType.income;
            }
          } else {
            // Unsigned statement: check keywords or default to expense
            parsedAmount = numVal.abs();
            if (_isIncomeKeyword(descStr)) {
              inferredType = TransactionType.income;
            } else {
              inferredType = TransactionType.expense;
            }
          }
        }
      }

      final date = _parseDate(dateStr);
      final desc = descStr.isNotEmpty ? descStr : "Transaction ${idx + 1}";
      final category = (mapping.categoryColumn != null &&
              mapping.categoryColumn! < row.length)
          ? row[mapping.categoryColumn!].toString().trim()
          : _inferCategory(desc);

      bool isValid = true;
      String? error;

      if (date == null) {
        isValid = false;
        error = "Unrecognized date format: '$dateStr'";
      } else if (parsedAmount == null ||
          parsedAmount <= 0 ||
          !parsedAmount.isFinite ||
          parsedAmount.isNaN) {
        isValid = false;
        error = "Invalid or non-positive amount: '$rawAmtStr'";
      }

      final fingerprint = generateFingerprint(
        accountId: accountId ?? 'acc_import',
        date: date ?? DateTime.now(),
        description: desc,
        amount: parsedAmount ?? 0.0,
        type: inferredType,
      );

      final isDup = isValid && existingFingerprints.contains(fingerprint);
      if (isValid) {
        if (isDup) {
          duplicates++;
        } else {
          valid++;
          // Add to current session fingerprints so repeated rows within the same CSV are also flagged as duplicates
          existingFingerprints.add(fingerprint);
        }
      } else {
        invalid++;
      }

      records.add(
        ImportedTransactionRecord(
          rowIndex: idx + 2, // 1-based, accounting for header
          date: date,
          rawDate: dateStr,
          description: desc,
          amount: parsedAmount ?? 0.0,
          rawAmount: rawAmtStr,
          type: inferredType,
          category: category,
          importHash: fingerprint,
          isValid: isValid,
          errorMessage: error,
          isDuplicate: isDup,
        ),
      );
    }

    return StatementParseResult(
      headers: headers,
      rawRows: dataRows,
      mapping: mapping,
      records: records,
      validCount: valid,
      duplicateCount: duplicates,
      invalidCount: invalid,
    );
  }

  static String generateFingerprint({
    required String accountId,
    required DateTime date,
    required String description,
    required double amount,
    required TransactionType type,
  }) {
    final normDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final normDesc =
        description.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    final normAmt = amount.toStringAsFixed(2);
    final rawKey = "$accountId|$normDate|$normDesc|$normAmt|${type.name}";

    // Deterministic 32-bit FNV-1a hash formatted as hex
    int hash = 0x811c9dc5;
    for (int i = 0; i < rawKey.length; i++) {
      hash ^= rawKey.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return "imp_${hash.toRadixString(16).padLeft(8, '0')}";
  }

  static DateTime? _parseDate(String dateStr) {
    if (dateStr.trim().isEmpty) return null;
    final clean = dateStr.trim();

    // Standard ISO-8601
    final iso = DateTime.tryParse(clean);
    if (iso != null) return iso;

    final formats = [
      'yyyy-MM-dd',
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'dd-MM-yyyy',
      'yyyy/MM/dd',
      'dd.MM.yyyy',
      'd/M/yyyy',
      'd-M-yyyy',
      'd.M.yyyy',
      'MMM d, yyyy',
      'd MMM yyyy',
      'd-MMM-yyyy',
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

  static double? _parseNumber(String numStr) {
    if (numStr.trim().isEmpty) return null;
    var clean = numStr.trim();

    // Check parentheses negative format e.g. "(120.50)"
    bool isNegative = false;
    if (clean.startsWith('(') && clean.endsWith(')')) {
      isNegative = true;
      clean = clean.substring(1, clean.length - 1).trim();
    } else if (clean.startsWith('-')) {
      isNegative = true;
      clean = clean.substring(1).trim();
    }

    // Strip currency codes, symbols, and optional dots (e.g. $, £, €, Rs., PKR, USD, GBP, EUR)
    clean = clean.replaceAll(RegExp(r'[a-zA-Z$£€]+[.]?'), '').trim();

    // Handle European numbers "1.250,50" vs standard "1,250.50"
    if (clean.contains(',') && clean.contains('.')) {
      if (clean.indexOf(',') > clean.indexOf('.')) {
        // "1.250,50" -> 1250.50
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // "1,250.50" -> 1250.50
        clean = clean.replaceAll(',', '');
      }
    } else if (clean.contains(',')) {
      final parts = clean.split(',');
      if (parts.length == 2 && parts[1].length <= 2) {
        // Likely decimal comma "50,25"
        clean = clean.replaceAll(',', '.');
      } else {
        // Likely thousand separator "1,500"
        clean = clean.replaceAll(',', '');
      }
    }

    final val = double.tryParse(clean);
    if (val == null || !val.isFinite || val.isNaN) return null;
    return isNegative ? -val : val;
  }

  static bool _isIncomeKeyword(String text) {
    final lower = text.toLowerCase();
    return lower.contains('salary') ||
        lower.contains('payroll') ||
        lower.contains('deposit') ||
        lower.contains('credit') ||
        lower.contains('dividend') ||
        lower.contains('refund') ||
        lower.contains('stipend') ||
        lower.contains('income');
  }

  static bool _isNegativeString(String s) {
    final t = s.trim();
    return t.startsWith('-') || (t.startsWith('(') && t.endsWith(')'));
  }

  static String _inferCategory(String description) {
    final lower = description.toLowerCase();
    if (lower.contains('supermarket') ||
        lower.contains('grocery') ||
        lower.contains('walmart') ||
        lower.contains('food') ||
        lower.contains('restaurant') ||
        lower.contains('cafe') ||
        lower.contains('coffee') ||
        lower.contains('mcdonald')) {
      return "Food & Drink";
    }
    if (lower.contains('uber') ||
        lower.contains('fuel') ||
        lower.contains('petrol') ||
        lower.contains('shell') ||
        lower.contains('transit') ||
        lower.contains('metro') ||
        lower.contains('flight') ||
        lower.contains('airline')) {
      return "Transport";
    }
    if (lower.contains('amazon') ||
        lower.contains('shopping') ||
        lower.contains('store') ||
        lower.contains('apple') ||
        lower.contains('zara')) {
      return "Shopping";
    }
    if (lower.contains('salary') ||
        lower.contains('payroll') ||
        lower.contains('dividend') ||
        lower.contains('stipend')) {
      return "Salary";
    }
    if (lower.contains('electric') ||
        lower.contains('water') ||
        lower.contains('gas') ||
        lower.contains('bill') ||
        lower.contains('utility') ||
        lower.contains('internet')) {
      return "Bills & Fees";
    }
    return "General";
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
}

class SampleStatements {
  static const String meezanBankCsv = '''Date,Description,Debit,Credit,Balance
2026-10-15,Salary Transfer - Tech Solutions,,250000.00,320000.00
2026-10-16,Imtiaz Super Market Grocery,14500.00,,305500.00
2026-10-17,Shell Petroleum Fuel,6500.00,,299000.00
2026-10-18,K-Electric Electricity Bill,18200.00,,280800.00
2026-10-19,Gloria Jean's Coffee & Snacks,1850.00,,278950.00
2026-10-20,Daraz Online Shopping,4990.00,,273960.00''';

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
}
