import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  static const String _vaultFileName = 'spendwise_vault.json';

  Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_vaultFileName');
  }

  Future<Map<String, dynamic>?> loadVault() async {
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

  Future<void> saveVault(Map<String, dynamic> vaultData) async {
    try {
      final file = await _getLocalFile();
      final tempFile = File('${file.path}.tmp');
      final jsonString = const JsonEncoder.withIndent('  ').convert(vaultData);

      await tempFile.writeAsString(jsonString, flush: true);
      if (await tempFile.exists()) {
        await tempFile.rename(file.path);
      }
    } catch (e) {
      debugPrint('LocalStorageService: Error saving vault: $e');
    }
  }

  Future<String> exportVaultJson(Map<String, dynamic> vaultData) async {
    return const JsonEncoder.withIndent('  ').convert(vaultData);
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
