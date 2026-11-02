import '../models/models.dart';
import 'statement_importer.dart';

/// Abstract contract for financial data sources in SpendWise.
///
/// Distinguishes between local file-based statement import (currently active)
/// and potential future read-only open banking / aggregator connectors.
enum BankConnectorType {
  fileImport,
  openBankingApi,
  thirdPartyAggregator,
}

abstract class BankConnector {
  String get id;
  String get name;
  BankConnectorType get type;
  bool get isAvailableInPakistan;

  /// Whether this connector requires live network connectivity.
  bool get requiresNetwork;
}

/// Active implementation: Local file statement importer (CSV/OFX).
/// Operates 100% on-device without network calls or credential harvesting.
class FileStatementConnector implements BankConnector {
  @override
  String get id => 'local_file_importer';

  @override
  String get name => 'Bank Statement File Import (CSV/OFX)';

  @override
  BankConnectorType get type => BankConnectorType.fileImport;

  @override
  bool get isAvailableInPakistan => true;

  @override
  bool get requiresNetwork => false;

  /// Parses statement content using on-device [StatementImporter].
  StatementParseResult parse({
    required String content,
    String? accountId,
    ColumnMapping? explicitMapping,
    List<Expense>? existingTransactions,
    List<Account>? userAccounts,
    String? forcedDateFormat,
  }) {
    return StatementImporter.parseCsv(
      csvContent: content,
      accountId: accountId,
      explicitMapping: explicitMapping,
      existingTransactions: existingTransactions,
      userAccounts: userAccounts,
      forcedDateFormat: forcedDateFormat,
    );
  }
}

/// Deferred roadmap connector for future SBP Open Banking / Direct Bank APIs.
/// Explicitly marked as unavailable until regulatory standards and public APIs are live.
class SbpOpenBankingConnector implements BankConnector {
  @override
  String get id => 'sbp_open_banking_sandbox';

  @override
  String get name => 'SBP Open Banking API (Roadmap)';

  @override
  BankConnectorType get type => BankConnectorType.openBankingApi;

  @override
  bool get isAvailableInPakistan => false;

  @override
  bool get requiresNetwork => true;
}
