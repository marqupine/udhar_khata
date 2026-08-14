import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class SecurityService {
  static const String _keyMpin = 'app_security_mpin';
  static const String _keyBiometricEnabled = 'app_security_biometric_enabled';
  static const String _keyLastPromptTimestamp = 'app_security_last_prompt_time';

  final SharedPreferences _prefs;
  final LocalAuthentication _localAuth;

  SecurityService(this._prefs, {LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  // MPIN methods
  bool get hasMpin =>
      _prefs.getString(_keyMpin) != null &&
      _prefs.getString(_keyMpin)!.length == 4;

  bool verifyMpin(String pin) {
    final storedPin = _prefs.getString(_keyMpin);
    return storedPin == pin;
  }

  Future<void> setMpin(String pin) async {
    if (pin.length != 4) throw ArgumentError('MPIN must be 4 digits');
    await _prefs.setString(_keyMpin, pin);
  }

  Future<void> clearMpin() async {
    await _prefs.remove(_keyMpin);
    await setBiometricEnabled(false); // Disabling MPIN disables Biometrics
  }

  // Biometric methods
  bool get isBiometricEnabled => _prefs.getBool(_keyBiometricEnabled) ?? false;

  Future<bool> setBiometricEnabled(bool enabled) async {
    // Biometric cannot be setup without MPIN
    if (enabled && !hasMpin) {
      return false;
    }
    await _prefs.setBool(_keyBiometricEnabled, enabled);
    return true;
  }

  Future<bool> isBiometricHardwareAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics({
    String? reason,
    bool requireEnabledCheck = true,
  }) async {
    final localizedReason =
        reason ?? 'Authenticate to unlock ${AppConstants.appName}';
    if (requireEnabledCheck && !isBiometricEnabled) return false;
    try {
      final isAvailable = await isBiometricHardwareAvailable();
      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication exception: $e');
      return false;
    }
  }

  // Interval Prompting (10 - 15 Days Gap)
  Future<bool> shouldPromptBiometricSetup({int gapInDays = 10}) async {
    // If biometrics are already enabled, no need to prompt
    if (isBiometricEnabled) return false;

    // Check if hardware is available
    final available = await isBiometricHardwareAvailable();
    if (!available) return false;

    final lastPromptMs = _prefs.getInt(_keyLastPromptTimestamp) ?? 0;
    if (lastPromptMs == 0) return true; // Never prompted before

    final lastPromptDate = DateTime.fromMillisecondsSinceEpoch(lastPromptMs);
    final daysDifference = DateTime.now().difference(lastPromptDate).inDays;

    return daysDifference >= gapInDays;
  }

  Future<void> updateLastBiometricPromptTime() async {
    await _prefs.setInt(
      _keyLastPromptTimestamp,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
