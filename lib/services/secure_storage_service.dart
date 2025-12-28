import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for sensitive wallet data
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
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
}
