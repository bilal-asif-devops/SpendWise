import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/auth_models.dart';
import 'auth_service.dart';
import 'cloud_sync_service.dart';
import 'finance_provider.dart';
import 'firebase_auth_service.dart';
import 'firestore_sync_service.dart';
import 'local_auth_service.dart';
import 'storage_service.dart';

class AuthSyncProvider with ChangeNotifier {
  final AuthService _authService;
  final CloudSyncService _cloudSyncService;
  final LocalStorageService _storageService;
  final FinanceProvider _financeProvider;

  AuthStatus _status = AuthStatus.unauthenticated;
  AuthUser? _currentUser;
  SyncStatus _syncStatus = SyncStatus.idle;
  DateTime? _lastSyncTime;
  String? _errorMessage;
  bool _isProcessing = false;

  bool _hasPendingGuestMigration = false;
  Map<String, dynamic>? _pendingGuestVault;

  StreamSubscription<AuthUser?>? _authSubscription;

  AuthSyncProvider({
    required AuthService authService,
    required CloudSyncService cloudSyncService,
    required LocalStorageService storageService,
    required FinanceProvider financeProvider,
    bool autoInitialize = true,
  })  : _authService = authService,
        _cloudSyncService = cloudSyncService,
        _storageService = storageService,
        _financeProvider = financeProvider {
    if (autoInitialize) {
      _init();
    }
  }

  factory AuthSyncProvider.createDefault({
    required FinanceProvider financeProvider,
    LocalStorageService? storageService,
  }) {
    final storage = storageService ?? LocalStorageService();
    final bool hasFirebase = Firebase.apps.isNotEmpty;
    final AuthService authService =
        hasFirebase ? FirebaseAuthService() : LocalAuthService();
    final CloudSyncService cloudSyncService = hasFirebase
        ? FirestoreSyncService()
        : (authService as LocalAuthService);

    return AuthSyncProvider(
      authService: authService,
      cloudSyncService: cloudSyncService,
      storageService: storage,
      financeProvider: financeProvider,
    );
  }

  AuthStatus get status => _status;
  AuthUser? get currentUser => _currentUser;
  SyncStatus get syncStatus => _syncStatus;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get errorMessage => _errorMessage;
  bool get isProcessing => _isProcessing;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _currentUser != null;
  bool get isGuest => _status == AuthStatus.guest;
  bool get hasPendingGuestMigration => _hasPendingGuestMigration;
  Map<String, dynamic>? get pendingGuestVault => _pendingGuestVault;
  bool get isBackendConfigured => _authService.isConfigured;

  void _init() {
    _authSubscription = _authService.authStateChanges.listen((user) async {
      if (user != null) {
        _currentUser = user;
        _status = AuthStatus.authenticated;
        _errorMessage = null;
        notifyListeners();
        await _checkAndSyncOnLogin(user);
      } else {
        if (_status == AuthStatus.authenticated) {
          _currentUser = null;
          _status = AuthStatus.unauthenticated;
          _syncStatus = SyncStatus.idle;
          notifyListeners();
        }
      }
    });
  }

  Future<void> _checkAndSyncOnLogin(AuthUser user) async {
    // Check if current finance state has non-sample guest transactions/accounts
    final hasGuestData = _financeProvider.accounts.any((a) => !a.isSample) ||
        _financeProvider.expenses.any((e) => !e.isSample);

    if (hasGuestData && !_financeProvider.hasCompletedOnboarding) {
      // Local session was guest: trigger migration review
      _hasPendingGuestMigration = true;
      _pendingGuestVault = _financeProvider.toVaultMap();
      notifyListeners();
    } else {
      await syncVaultWithCloud();
    }
  }

  Future<bool> loginWithEmail(String email, String password) async {
    _setProcessing(true);
    _errorMessage = null;
    notifyListeners();

    try {
      final user =
          await _authService.signInWithEmailAndPassword(email, password);
      _currentUser = user;
      _status = AuthStatus.authenticated;
      _setProcessing(false);
      await _checkAndSyncOnLogin(user);
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
      _setProcessing(false);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      _status = AuthStatus.unauthenticated;
      _setProcessing(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    _setProcessing(true);
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.createUserWithEmailAndPassword(
        email,
        password,
        displayName: displayName,
      );
      _currentUser = user;
      _status = AuthStatus.authenticated;
      _setProcessing(false);
      await _checkAndSyncOnLogin(user);
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
      _setProcessing(false);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Registration error: $e';
      _status = AuthStatus.unauthenticated;
      _setProcessing(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    _setProcessing(true);
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle();
      if (user == null) {
        // User deliberately cancelled prompt
        _setProcessing(false);
        notifyListeners();
        return false;
      }

      _currentUser = user;
      _status = AuthStatus.authenticated;
      _setProcessing(false);
      await _checkAndSyncOnLogin(user);
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _setProcessing(false);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Google Sign-In failed: $e';
      _setProcessing(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _errorMessage = null;
    try {
      await _authService.sendPasswordResetEmail(email);
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Password reset failed: $e';
      notifyListeners();
      return false;
    }
  }

  void continueAsGuest() {
    _status = AuthStatus.guest;
    _currentUser = null;
    _errorMessage = null;
    _syncStatus = SyncStatus.idle;
    notifyListeners();
  }

  Future<void> logout() async {
    _setProcessing(true);
    try {
      await _authService.signOut();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _syncStatus = SyncStatus.idle;
    _lastSyncTime = null;
    _hasPendingGuestMigration = false;
    _pendingGuestVault = null;
    _setProcessing(false);
    notifyListeners();
  }

  Future<void> syncVaultWithCloud() async {
    if (!isAuthenticated || _currentUser == null) return;

    _syncStatus = SyncStatus.syncing;
    notifyListeners();

    try {
      final userId = _currentUser!.uid;
      final cloudVault = await _cloudSyncService.downloadVault(userId: userId);
      final localVault = _financeProvider.toVaultMap();

      if (cloudVault == null) {
        // First cloud sync: upload local vault
        await _cloudSyncService.uploadVault(
            userId: userId, vaultData: localVault);
      } else {
        final cloudUpdated =
            DateTime.tryParse(cloudVault['lastUpdated']?.toString() ?? '') ??
                DateTime(2000);
        final localUpdated =
            DateTime.tryParse(localVault['lastUpdated']?.toString() ?? '') ??
                DateTime(2000);

        if (cloudUpdated.isAfter(localUpdated)) {
          // Cloud has newer data: update local provider
          _financeProvider.loadFromVaultMap(cloudVault);
          await _storageService.saveVault(cloudVault);
        } else {
          // Local has newer or equal data: upload local vault to cloud
          await _cloudSyncService.uploadVault(
              userId: userId, vaultData: localVault);
        }
      }

      _syncStatus = SyncStatus.synced;
      _lastSyncTime = DateTime.now();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Sync error: $e');
      _syncStatus = SyncStatus.offline;
      _errorMessage = 'Sync failed: $e';
      notifyListeners();
    }
  }

  Future<void> resolveGuestMigration({required bool mergeGuestData}) async {
    if (!isAuthenticated || _currentUser == null) return;
    final userId = _currentUser!.uid;

    _setProcessing(true);
    try {
      if (mergeGuestData && _pendingGuestVault != null) {
        final cloudVault =
            await _cloudSyncService.downloadVault(userId: userId);
        final merged = await _cloudSyncService.mergeGuestVault(
          userId: userId,
          guestVault: _pendingGuestVault!,
          cloudVault: cloudVault,
        );

        _financeProvider.loadFromVaultMap(merged);
        await _storageService.saveVault(merged);
      } else {
        // Discard guest data: download clean cloud state if available
        final cloudVault =
            await _cloudSyncService.downloadVault(userId: userId);
        if (cloudVault != null) {
          _financeProvider.loadFromVaultMap(cloudVault);
          await _storageService.saveVault(cloudVault);
        }
      }

      _hasPendingGuestMigration = false;
      _pendingGuestVault = null;
      _syncStatus = SyncStatus.synced;
      _lastSyncTime = DateTime.now();
    } catch (e) {
      _errorMessage = 'Guest migration failed: $e';
    } finally {
      _setProcessing(false);
      notifyListeners();
    }
  }

  void _setProcessing(bool val) {
    _isProcessing = val;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
