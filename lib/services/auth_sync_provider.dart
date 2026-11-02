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
  final Completer<void> _initialAuthCompleter = Completer<void>();
  Timer? _autoSyncDebounce;

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
    _attachFinanceListener();
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
  Future<void> get ensureInitialized => _initialAuthCompleter.future;
  bool get isAuthInitialized => _initialAuthCompleter.isCompleted;

  void _attachFinanceListener() {
    _financeProvider.onVaultChanged = (vaultData) {
      if (isAuthenticated && !isGuest && _currentUser != null) {
        _syncStatus = SyncStatus.syncing;
        notifyListeners();
        _autoSyncDebounce?.cancel();
        _autoSyncDebounce = Timer(const Duration(milliseconds: 300), () async {
          await syncVaultWithCloud();
        });
      }
    };
  }

  void _init() {
    final initialUser = _authService.currentUser;
    if (initialUser != null) {
      _currentUser = initialUser;
      _status = AuthStatus.authenticated;
      _updateFinanceProfile(initialUser);
      if (!_initialAuthCompleter.isCompleted) {
        _initialAuthCompleter.complete();
      }
    }

    _authSubscription = _authService.authStateChanges.listen((user) async {
      debugPrint(
        'AuthSyncProvider [Safe Diagnostics]: authStateChanges received '
        'userExists=${user != null}, emailDomain=${user?.email?.split('@').last}',
      );
      if (!_initialAuthCompleter.isCompleted) {
        _initialAuthCompleter.complete();
      }
      if (user != null) {
        _currentUser = user;
        _status = AuthStatus.authenticated;
        _errorMessage = null;
        _updateFinanceProfile(user);
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

  void _updateFinanceProfile(AuthUser user) {
    String name =
        (user.displayName != null && user.displayName!.trim().isNotEmpty)
            ? user.displayName!.trim()
            : '';
    final String email = (user.email != null && user.email!.trim().isNotEmpty)
        ? user.email!.trim()
        : 'user@spendwise.app';

    if (name.isEmpty) {
      if (email.contains('@')) {
        final prefix = email.split('@').first;
        name = prefix.isNotEmpty
            ? '${prefix[0].toUpperCase()}${prefix.substring(1)}'
            : 'SpendWise User';
      } else {
        name = 'SpendWise User';
      }
    }

    _financeProvider.updateProfile(name: name, email: email);
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
      _updateFinanceProfile(user);
      _setProcessing(false);
      notifyListeners();
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
      _updateFinanceProfile(user);
      _setProcessing(false);
      notifyListeners();
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
      _updateFinanceProfile(user);
      _setProcessing(false);
      notifyListeners();
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

  Future<bool> updateDisplayName(String newName) async {
    final cleanName = newName.trim();
    if (cleanName.isEmpty) {
      _errorMessage = "Name cannot be empty.";
      notifyListeners();
      return false;
    }
    if (cleanName.length < 2) {
      _errorMessage = "Name must be at least 2 characters.";
      notifyListeners();
      return false;
    }

    _setProcessing(true);
    _errorMessage = null;
    notifyListeners();

    try {
      if (isAuthenticated && _currentUser != null && !isGuest) {
        await _authService.updateDisplayName(cleanName);
        _currentUser = _currentUser!.copyWith(displayName: cleanName);
      }
      _financeProvider.updateProfile(name: cleanName);
      if (isAuthenticated && !isGuest && _currentUser != null) {
        await syncVaultWithCloud();
      }
      _setProcessing(false);
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _setProcessing(false);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to update profile: $e';
      _setProcessing(false);
      notifyListeners();
      return false;
    }
  }

  void continueAsGuest() {
    _autoSyncDebounce?.cancel();
    _status = AuthStatus.guest;
    _currentUser = null;
    _errorMessage = null;
    _syncStatus = SyncStatus.idle;
    _financeProvider.updateProfile(
      name: 'Guest User',
      email: 'guest@spendwise.local',
    );
    notifyListeners();
  }

  Future<void> logout() async {
    _autoSyncDebounce?.cancel();
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
    _financeProvider.updateProfile(
      name: 'Guest User',
      email: 'guest@spendwise.local',
    );
    _setProcessing(false);
    notifyListeners();
  }

  Future<void> syncVaultWithCloud() async {
    if (!isAuthenticated || _currentUser == null || isGuest) return;

    _syncStatus = SyncStatus.syncing;
    notifyListeners();

    try {
      final userId = _currentUser!.uid;
      final cloudVault = await _cloudSyncService.downloadVault(userId: userId);
      final localVault = _financeProvider.toVaultMap();

      if (cloudVault == null || cloudVault.isEmpty) {
        // First cloud sync: upload local vault
        await _cloudSyncService.uploadVault(
            userId: userId, vaultData: localVault);
      } else {
        final bool localHasRealData =
            _financeProvider.accounts.any((a) => !a.isSample) ||
                _financeProvider.expenses.any((e) => !e.isSample);
        final bool cloudHasRealData =
            (cloudVault['accounts'] as List?)?.isNotEmpty == true ||
                (cloudVault['expenses'] as List?)?.isNotEmpty == true;

        if (!localHasRealData && cloudHasRealData) {
          // Cloud has real records but local has none (e.g. reload or new device):
          // Always restore cloud vault to avoid wiping remote records.
          _financeProvider.loadFromVaultMap(cloudVault);
          await _storageService.saveVault(cloudVault);
        } else if (localHasRealData && !cloudHasRealData) {
          // Local has real data, cloud was empty:
          await _cloudSyncService.uploadVault(
              userId: userId, vaultData: localVault);
        } else {
          // Both have records or both are empty: compare timestamps
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
    _autoSyncDebounce?.cancel();
    _financeProvider.onVaultChanged = null;
    _authSubscription?.cancel();
    super.dispose();
  }
}
