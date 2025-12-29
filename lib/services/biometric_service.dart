import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

/// Service for biometric authentication (Face ID / Touch ID / Fingerprint)
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if device supports biometric authentication
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Check if biometrics are available and enrolled
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// Get list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Check if Face ID is available
  Future<bool> hasFaceId() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.face);
  }

  /// Check if Touch ID / Fingerprint is available
  Future<bool> hasFingerprint() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.fingerprint) ||
        biometrics.contains(BiometricType.strong);
  }

  /// Authenticate user with biometrics
  /// Returns true if authentication successful, false otherwise
  /// SECURITY: biometricOnly defaults to true to prevent PIN/pattern bypass
  Future<bool> authenticate({
    String reason = 'Authenticate to access your wallet',
    bool biometricOnly = true,
  }) async {
    try {
      // Check if biometrics are available
      final canAuth = await canCheckBiometrics();
      final isSupported = await isDeviceSupported();

      if (!canAuth || !isSupported) {
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
        sensitiveTransaction: true,
      );
    } on PlatformException catch (e) {
      // Handle specific errors
      if (e.code == 'NotAvailable') {
        // Biometrics not available
        return false;
      } else if (e.code == 'NotEnrolled') {
        // No biometrics enrolled
        return false;
      } else if (e.code == 'LockedOut') {
        // Too many failed attempts
        return false;
      } else if (e.code == 'PermanentlyLockedOut') {
        // Device locked, requires passcode
        return false;
      }
      return false;
    }
  }

  /// Cancel any ongoing authentication
  Future<bool> cancelAuthentication() async {
    try {
      return await _localAuth.stopAuthentication();
    } on PlatformException {
      return false;
    }
  }

  /// Get a human-readable name for the biometric type
  String getBiometricName(List<BiometricType> biometrics) {
    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Touch ID';
    } else if (biometrics.contains(BiometricType.strong)) {
      return 'Fingerprint';
    } else if (biometrics.contains(BiometricType.weak)) {
      return 'Biometrics';
    }
    return 'Biometrics';
  }
}
