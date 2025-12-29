import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for sensitive wallet data
///
/// Security hardening:
/// - Android: Encrypted shared preferences with hardware-backed keystore
/// - iOS: Keychain with accessibility restricted to when device is unlocked,
///        explicitly disabled iCloud backup to prevent cloud sync of secrets
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,  // Use EncryptedSharedPreferences
      sharedPreferencesName: 'bolt21_secure_prefs',
      preferencesKeyPrefix: 'bolt21_',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,  // More restrictive
      synchronizable: false,  // CRITICAL: Disable iCloud Keychain sync
    ),
  );

  static const _mnemonicKey = 'bolt21_mnemonic';
  static const _walletInitializedKey = 'bolt21_wallet_initialized';

  /// Save the mnemonic seed phrase securely
  static Future<void> saveMnemonic(String mnemonic) async {
    await _storage.write(key: _mnemonicKey, value: mnemonic);
    await _storage.write(key: _walletInitializedKey, value: 'true');
  }

  /// Retrieve the stored mnemonic
  static Future<String?> getMnemonic() async {
    return await _storage.read(key: _mnemonicKey);
  }

  /// Check if a wallet has been initialized
  static Future<bool> hasWallet() async {
    final value = await _storage.read(key: _walletInitializedKey);
    return value == 'true';
  }

  /// Delete all wallet data (for wallet reset)
  static Future<void> clearWallet() async {
    await _storage.delete(key: _mnemonicKey);
    await _storage.delete(key: _walletInitializedKey);
  }

  /// Generic read for any key (used by other services)
  static Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  /// Generic write for any key (used by other services)
  static Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Generic delete for any key
  static Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}
