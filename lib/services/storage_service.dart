import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'web_storage_stub.dart' if (dart.library.html) 'web_storage_web.dart';

class LocalStorageService {
  static const String _vaultFileName = 'spendwise_vault.json';
  static const String _webStorageKey = 'spendwise_local_vault_v2';

  Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_vaultFileName');
  }

  Future<Map<String, dynamic>?> loadVault() async {
    if (kIsWeb) {
      try {
        final content = PlatformLocalStorage.getItem(_webStorageKey);
        if (content != null && content.trim().isNotEmpty) {
          final decoded = json.decode(content);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        }
      } catch (e) {
        debugPrint('LocalStorageService: Error loading web vault: $e');
      }
      return null;
    }

    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = json.decode(content);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        }
      }
    } catch (e) {
      debugPrint('LocalStorageService: Error loading vault: $e');
    }
    return null;
  }

  static Object? _toEncodable(dynamic item) {
    if (item is DateTime) return item.toIso8601String();
    try {
      if (item != null) {
        final dynamic d = item;
        if (d.toDate != null) {
          final dt = d.toDate();
          if (dt is DateTime) return dt.toIso8601String();
        }
      }
    } catch (_) {}
    return item.toString();
  }

  Future<void> saveVault(Map<String, dynamic> vaultData) async {
    if (kIsWeb) {
      try {
        final jsonString = json.encode(vaultData, toEncodable: _toEncodable);
        PlatformLocalStorage.setItem(_webStorageKey, jsonString);
      } catch (e) {
        debugPrint('LocalStorageService: Error saving web vault: $e');
      }
      return;
    }

    try {
      final file = await _getLocalFile();
      final tempFile = File('${file.path}.tmp');
      const encoder = JsonEncoder.withIndent('  ', _toEncodable);
      final jsonString = encoder.convert(vaultData);

      await tempFile.writeAsString(jsonString, flush: true);
      if (await tempFile.exists()) {
        await tempFile.rename(file.path);
      }
    } catch (e) {
      debugPrint('LocalStorageService: Error saving vault: $e');
    }
  }

  Future<String> exportVaultJson(Map<String, dynamic> vaultData) async {
    return const JsonEncoder.withIndent('  ', _toEncodable).convert(vaultData);
  }

  Future<bool> importVaultJson(String jsonString) async {
    try {
      final decoded = json.decode(jsonString);
      if (decoded is Map<String, dynamic>) {
        await saveVault(decoded);
        return true;
      }
    } catch (e) {
      debugPrint('LocalStorageService: Error importing vault: $e');
    }
    return false;
  }
}
