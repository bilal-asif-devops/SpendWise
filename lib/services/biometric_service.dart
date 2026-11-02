import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

abstract class BiometricService {
  Future<bool> get isHardwareSupported;
  Future<bool> get canCheckBiometrics;
  Future<bool> authenticate({required String localizedReason});
}

class DeviceBiometricService implements BiometricService {
  final LocalAuthentication _auth;

  DeviceBiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  @override
  Future<bool> get isHardwareSupported async {
    if (kIsWeb) return false;
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported || canCheck;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> get canCheckBiometrics async {
    if (kIsWeb) return false;
    try {
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    if (kIsWeb) return false;
    try {
      final supported = await isHardwareSupported;
      if (!supported) return false;
      return await _auth.authenticate(
        localizedReason: localizedReason,
        persistAcrossBackgrounding: true,
        biometricOnly: false,
      );
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    }
  }
}
