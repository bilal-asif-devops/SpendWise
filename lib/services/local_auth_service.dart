import 'dart:async';
import '../models/auth_models.dart';
import '../models/models.dart';
import 'auth_service.dart';
import 'cloud_sync_service.dart';
import 'statement_importer.dart';

class LocalAuthService implements AuthService, CloudSyncService {
  final _authStateController = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  // In-memory user database: email -> password
  final Map<String, String> _credentials = {
    'demo@spendwise.local': 'Password123!',
  };

  // In-memory user registry: uid -> AuthUser
  final Map<String, AuthUser> _users = {
    'demo_uid_123': const AuthUser(
      uid: 'demo_uid_123',
      email: 'demo@spendwise.local',
      displayName: 'Demo User',
    ),
  };

  // In-memory per-user cloud database: uid -> vault map
  final Map<String, Map<String, dynamic>> _cloudVaults = {};

  bool _isGoogleSignInCanceled = false;
  bool _simulateNetworkError = false;

  LocalAuthService() {
    _authStateController.add(_currentUser);
  }

  void setGoogleSignInCanceled(bool canceled) {
    _isGoogleSignInCanceled = canceled;
  }

  void setSimulateNetworkError(bool error) {
    _simulateNetworkError = error;
  }

  @override
  bool get isConfigured => true;

  @override
  Stream<AuthUser?> get authStateChanges => _authStateController.stream;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Future<AuthUser> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    if (_simulateNetworkError) {
      throw const AuthException(
        message: 'Network connection failed. Please check your internet.',
        code: 'network-request-failed',
      );
    }

    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw const AuthException(
        message: 'Please enter a valid email address.',
        code: 'invalid-email',
      );
    }

    if (!_credentials.containsKey(cleanEmail)) {
      throw const AuthException(
        message: 'No account found with this email address.',
        code: 'user-not-found',
      );
    }

    if (_credentials[cleanEmail] != password) {
      throw const AuthException(
        message: 'Incorrect email or password. Please verify your credentials.',
        code: 'wrong-password',
      );
    }

    final user =
        _users.values.firstWhere((u) => u.email?.toLowerCase() == cleanEmail);
    _currentUser = user;
    _authStateController.add(_currentUser);
    return user;
  }

  @override
  Future<AuthUser> createUserWithEmailAndPassword(
    String email,
    String password, {
    String? displayName,
  }) async {
    if (_simulateNetworkError) {
      throw const AuthException(
        message: 'Network connection failed. Please check your internet.',
        code: 'network-request-failed',
      );
    }

    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw const AuthException(
        message: 'Please enter a valid email address.',
        code: 'invalid-email',
      );
    }

    if (password.length < 6) {
      throw const AuthException(
        message: 'Password must be at least 6 characters long.',
        code: 'weak-password',
      );
    }

    if (_credentials.containsKey(cleanEmail)) {
      throw const AuthException(
        message: 'An account with this email already exists. Please log in.',
        code: 'email-already-in-use',
      );
    }

    final uid = 'usr_${DateTime.now().millisecondsSinceEpoch}';
    final user = AuthUser(
      uid: uid,
      email: cleanEmail,
      displayName: displayName ?? cleanEmail.split('@').first,
      createdAt: DateTime.now(),
    );

    _credentials[cleanEmail] = password;
    _users[uid] = user;
    _currentUser = user;
    _authStateController.add(_currentUser);
    return user;
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    if (_simulateNetworkError) {
      throw const AuthException(
        message: 'Network connection failed. Please check your internet.',
        code: 'network-request-failed',
      );
    }

    if (_isGoogleSignInCanceled) {
      return null;
    }

    final uid = 'google_usr_${DateTime.now().millisecondsSinceEpoch}';
    final user = AuthUser(
      uid: uid,
      email: 'user.google@gmail.com',
      displayName: 'Google User',
      photoUrl: null,
      createdAt: DateTime.now(),
    );

    _users[uid] = user;
    _currentUser = user;
    _authStateController.add(_currentUser);
    return user;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (_simulateNetworkError) {
      throw const AuthException(
        message: 'Network connection failed. Please check your internet.',
        code: 'network-request-failed',
      );
    }

    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw const AuthException(
        message: 'Please enter a valid email address.',
        code: 'invalid-email',
      );
    }

    if (!_credentials.containsKey(cleanEmail)) {
      throw const AuthException(
        message: 'No account found with this email address.',
        code: 'user-not-found',
      );
    }
    // Simulation: Password reset email sent
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authStateController.add(null);
  }

  // --- CloudSyncService Implementation ---

  @override
  Future<void> uploadVault({
    required String userId,
    required Map<String, dynamic> vaultData,
  }) async {
    if (_simulateNetworkError) {
      throw const AuthException(
        message:
            'Could not upload financial data. Device appears to be offline.',
        code: 'network-error',
      );
    }
    final payload = Map<String, dynamic>.from(vaultData);
    payload['lastUpdated'] = DateTime.now().toIso8601String();
    _cloudVaults[userId] = payload;
  }

  @override
  Future<Map<String, dynamic>?> downloadVault({
    required String userId,
  }) async {
    if (_simulateNetworkError) {
      throw const AuthException(
        message:
            'Could not download financial data. Device appears to be offline.',
        code: 'network-error',
      );
    }
    final data = _cloudVaults[userId];
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<Map<String, dynamic>> mergeGuestVault({
    required String userId,
    required Map<String, dynamic> guestVault,
    required Map<String, dynamic>? cloudVault,
  }) async {
    if (cloudVault == null || cloudVault.isEmpty) {
      await uploadVault(userId: userId, vaultData: guestVault);
      return guestVault;
    }

    final merged = Map<String, dynamic>.from(cloudVault);

    // Merge Accounts
    final cloudAccounts = (merged['accounts'] as List?)
            ?.map((a) => Map<String, dynamic>.from(a as Map))
            .toList() ??
        [];
    final guestAccounts = (guestVault['accounts'] as List?) ?? [];
    final existingAccountNames = cloudAccounts
        .map((a) => a['name']?.toString().toLowerCase().trim())
        .whereType<String>()
        .toSet();

    for (final ga in guestAccounts) {
      if (ga is Map) {
        final gName = ga['name']?.toString().toLowerCase().trim();
        if (gName != null && !existingAccountNames.contains(gName)) {
          cloudAccounts.add(Map<String, dynamic>.from(ga));
          existingAccountNames.add(gName);
        }
      }
    }
    merged['accounts'] = cloudAccounts;

    // Merge Expenses with Deduplication
    final cloudExpenses = (merged['expenses'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    final guestExpenses = (guestVault['expenses'] as List?) ?? [];
    final existingExpenseFingerprints = <String>{};

    for (final ce in cloudExpenses) {
      final hash = ce['importHash']?.toString();
      if (hash != null && hash.isNotEmpty) {
        existingExpenseFingerprints.add(hash);
      }
      final fp = StatementImporter.generateFingerprint(
        accountId: ce['accountId']?.toString() ?? '',
        date: DateTime.tryParse(ce['date']?.toString() ?? '') ?? DateTime.now(),
        description: ce['title']?.toString() ?? '',
        amount: (ce['amount'] as num?)?.toDouble() ?? 0.0,
        type: (ce['type']?.toString() == 'income')
            ? TransactionType.income
            : TransactionType.expense,
      );
      existingExpenseFingerprints.add(fp);
    }

    for (final ge in guestExpenses) {
      if (ge is Map) {
        final hash = ge['importHash']?.toString();
        final fp = (hash != null && hash.isNotEmpty)
            ? hash
            : StatementImporter.generateFingerprint(
                accountId: ge['accountId']?.toString() ?? '',
                date: DateTime.tryParse(ge['date']?.toString() ?? '') ??
                    DateTime.now(),
                description: ge['title']?.toString() ?? '',
                amount: (ge['amount'] as num?)?.toDouble() ?? 0.0,
                type: (ge['type']?.toString() == 'income')
                    ? TransactionType.income
                    : TransactionType.expense,
              );

        if (!existingExpenseFingerprints.contains(fp)) {
          cloudExpenses.add(Map<String, dynamic>.from(ge));
          existingExpenseFingerprints.add(fp);
        }
      }
    }
    merged['expenses'] = cloudExpenses;

    // Merge Budgets
    final cloudBudgets = (merged['budgets'] as List?)
            ?.map((b) => Map<String, dynamic>.from(b as Map))
            .toList() ??
        [];
    final guestBudgets = (guestVault['budgets'] as List?) ?? [];
    final existingBudgetNames = cloudBudgets
        .map((b) => b['name']?.toString().toLowerCase().trim())
        .whereType<String>()
        .toSet();

    for (final gb in guestBudgets) {
      if (gb is Map) {
        final bName = gb['name']?.toString().toLowerCase().trim();
        if (bName != null && !existingBudgetNames.contains(bName)) {
          cloudBudgets.add(Map<String, dynamic>.from(gb));
          existingBudgetNames.add(bName);
        }
      }
    }
    merged['budgets'] = cloudBudgets;

    merged['lastUpdated'] = DateTime.now().toIso8601String();
    await uploadVault(userId: userId, vaultData: merged);
    return merged;
  }

  void dispose() {
    _authStateController.close();
  }
}
