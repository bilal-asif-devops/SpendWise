import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/auth_models.dart';
import 'cloud_sync_service.dart';
import 'statement_importer.dart';
import '../models/models.dart';

class FirestoreSyncService implements CloudSyncService {
  final FirebaseFirestore? _firestore;
  final fb.FirebaseAuth? _auth;
  final String? Function()? _currentUidResolver;

  FirestoreSyncService({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    @visibleForTesting String? Function()? currentUidResolver,
  })  : _firestore = firestore,
        _auth = auth,
        _currentUidResolver = currentUidResolver;

  @override
  bool get isConfigured =>
      _firestore != null ||
      _currentUidResolver != null ||
      Firebase.apps.isNotEmpty;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
  fb.FirebaseAuth get _firebaseAuth => _auth ?? fb.FirebaseAuth.instance;

  bool get _isFirebaseAppReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String? get currentUserId {
    if (_currentUidResolver != null) {
      return _currentUidResolver!();
    }
    if (_auth != null || _isFirebaseAppReady) {
      try {
        return _firebaseAuth.currentUser?.uid;
      } catch (e) {
        debugPrint('FirestoreSyncService currentUserId error: $e');
        return null;
      }
    }
    return null;
  }

  DocumentReference<Map<String, dynamic>> _vaultDoc(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('vault')
        .doc('current');
  }

  /// Builds a compliant Firestore vault payload containing all mandatory security
  /// schema fields (`updatedBy`, `clientTimestamp`, `lastUpdated`, `serverSyncedAt`)
  /// alongside the serialized financial vault collections.
  static Map<String, dynamic> buildUploadPayload({
    required String userId,
    required Map<String, dynamic> vaultData,
    DateTime? clientTime,
    dynamic serverTimestamp,
  }) {
    final now = clientTime ?? DateTime.now();
    final payload = Map<String, dynamic>.from(vaultData);
    payload['lastUpdated'] = now.toIso8601String();
    payload['updatedBy'] = userId;
    payload['clientTimestamp'] = now.millisecondsSinceEpoch;
    payload['serverSyncedAt'] = serverTimestamp ?? FieldValue.serverTimestamp();
    return payload;
  }

  @override
  Future<void> uploadVault({
    required String userId,
    required Map<String, dynamic> vaultData,
  }) async {
    _ensureConfigured();

    // Verify authenticated user UID matches target userId
    final authenticatedUid = currentUserId;
    if (authenticatedUid == null || authenticatedUid != userId) {
      throw const AuthException(
        message:
            'Permission denied: Authenticated user does not match target user ID.',
        code: 'permission-denied',
      );
    }

    try {
      final docRef = _vaultDoc(userId);
      final payload = buildUploadPayload(
        userId: userId,
        vaultData: vaultData,
      );

      await docRef.set(payload, SetOptions(merge: true));
    } catch (e) {
      if (e is AuthException) rethrow;
      debugPrint('Firestore uploadVault error: $e');
      throw AuthException(
        message: 'Cloud sync upload failed: $e',
        code: 'sync-upload-error',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, dynamic>?> downloadVault({
    required String userId,
  }) async {
    _ensureConfigured();

    // Verify authenticated user UID matches target userId
    final authenticatedUid = currentUserId;
    if (authenticatedUid == null || authenticatedUid != userId) {
      throw const AuthException(
        message:
            'Permission denied: Authenticated user does not match target user ID.',
        code: 'permission-denied',
      );
    }

    try {
      final docRef = _vaultDoc(userId);
      final snapshot = await docRef.get();
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return _sanitizeFirestoreData(snapshot.data()!);
    } catch (e) {
      if (e is AuthException) rethrow;
      debugPrint('Firestore downloadVault error: $e');
      throw AuthException(
        message: 'Cloud sync download failed: $e',
        code: 'sync-download-error',
        originalError: e,
      );
    }
  }

  Map<String, dynamic> _sanitizeFirestoreData(Map<String, dynamic> raw) {
    final Map<String, dynamic> clean = {};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        clean[key] = _sanitizeFirestoreData(value);
      } else if (value is List) {
        clean[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _sanitizeFirestoreData(item);
          } else if (item is Timestamp) {
            return item.toDate().toIso8601String();
          }
          return item;
        }).toList();
      } else if (value is Timestamp) {
        clean[key] = value.toDate().toIso8601String();
      } else {
        clean[key] = value;
      }
    }
    return clean;
  }

  @override
  Future<Map<String, dynamic>> mergeGuestVault({
    required String userId,
    required Map<String, dynamic> guestVault,
    required Map<String, dynamic>? cloudVault,
  }) async {
    if (cloudVault == null || cloudVault.isEmpty) {
      // No cloud data yet, guest vault becomes the initial cloud vault
      await uploadVault(userId: userId, vaultData: guestVault);
      return guestVault;
    }

    final merged = Map<String, dynamic>.from(cloudVault);

    // 1. Merge Accounts: preserve all cloud accounts; add guest accounts if not matching by id or name
    final cloudAccounts = (merged['accounts'] as List?) ?? [];
    final guestAccounts = (guestVault['accounts'] as List?) ?? [];
    final existingAccountNames = cloudAccounts
        .map((a) => (a as Map)['name']?.toString().toLowerCase().trim())
        .whereType<String>()
        .toSet();

    for (final ga in guestAccounts) {
      if (ga is Map) {
        final gName = ga['name']?.toString().toLowerCase().trim();
        if (gName != null && !existingAccountNames.contains(gName)) {
          cloudAccounts.add(ga);
          existingAccountNames.add(gName);
        }
      }
    }
    merged['accounts'] = cloudAccounts;

    // 2. Merge Expenses with Deterministic Deduplication
    final cloudExpenses = (merged['expenses'] as List?) ?? [];
    final guestExpenses = (guestVault['expenses'] as List?) ?? [];
    final existingExpenseFingerprints = <String>{};

    for (final ce in cloudExpenses) {
      if (ce is Map) {
        final hash = ce['importHash']?.toString();
        if (hash != null && hash.isNotEmpty) {
          existingExpenseFingerprints.add(hash);
        }
        // Also build normalized fingerprint
        final fp = StatementImporter.generateFingerprint(
          accountId: ce['accountId']?.toString() ?? '',
          date:
              DateTime.tryParse(ce['date']?.toString() ?? '') ?? DateTime.now(),
          description: ce['title']?.toString() ?? '',
          amount: (ce['amount'] as num?)?.toDouble() ?? 0.0,
          type: (ce['type']?.toString() == 'income')
              ? TransactionType.income
              : TransactionType.expense,
        );
        existingExpenseFingerprints.add(fp);
      }
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
          cloudExpenses.add(ge);
          existingExpenseFingerprints.add(fp);
        }
      }
    }
    merged['expenses'] = cloudExpenses;

    // 3. Merge Budgets
    final cloudBudgets = (merged['budgets'] as List?) ?? [];
    final guestBudgets = (guestVault['budgets'] as List?) ?? [];
    final existingBudgetNames = cloudBudgets
        .map((b) => (b as Map)['name']?.toString().toLowerCase().trim())
        .whereType<String>()
        .toSet();

    for (final gb in guestBudgets) {
      if (gb is Map) {
        final bName = gb['name']?.toString().toLowerCase().trim();
        if (bName != null && !existingBudgetNames.contains(bName)) {
          cloudBudgets.add(gb);
          existingBudgetNames.add(bName);
        }
      }
    }
    merged['budgets'] = cloudBudgets;

    // 4. Update Timestamp
    merged['lastUpdated'] = DateTime.now().toIso8601String();

    // Upload merged state
    await uploadVault(userId: userId, vaultData: merged);
    return merged;
  }

  void _ensureConfigured() {
    if (!isConfigured) {
      throw const AuthException(
        message:
            'Firebase is not configured for this application. Please run "flutterfire configure" to attach your Firebase project.',
        code: 'configuration-required',
      );
    }
  }
}
