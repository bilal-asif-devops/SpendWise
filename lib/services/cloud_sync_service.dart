abstract class CloudSyncService {
  bool get isConfigured;

  Future<void> uploadVault({
    required String userId,
    required Map<String, dynamic> vaultData,
  });

  Future<Map<String, dynamic>?> downloadVault({
    required String userId,
  });

  Future<Map<String, dynamic>> mergeGuestVault({
    required String userId,
    required Map<String, dynamic> guestVault,
    required Map<String, dynamic>? cloudVault,
  });
}
