import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/wallet_metadata.dart';

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

  // Legacy keys (pre-multi-wallet) - used for migration
  static const _legacyMnemonicKey = 'bolt21_mnemonic';
  static const _legacyWalletInitializedKey = 'bolt21_wallet_initialized';
  static const _legacyOnChainAddressKey = 'bolt21_onchain_address';
  static const _legacyBolt12OfferKey = 'bolt21_bolt12_offer';

  // Multi-wallet keys
  static const _walletListKey = 'bolt21_wallet_list';
  static const _activeWalletIdKey = 'bolt21_active_wallet_id';

  // Per-wallet key prefixes
  static String _mnemonicKey(String walletId) => 'bolt21_mnemonic_$walletId';
  static String _onChainAddressKey(String walletId) => 'bolt21_onchain_$walletId';
  static String _bolt12OfferKey(String walletId) => 'bolt21_bolt12_$walletId';

  // ============================================
  // MULTI-WALLET MANAGEMENT
  // ============================================

  /// Get list of all wallets
  static Future<List<WalletMetadata>> getWalletList() async {
    final json = await _storage.read(key: _walletListKey);
    if (json == null || json.isEmpty) return [];
    return WalletMetadata.decodeList(json);
  }

  /// Save wallet list
  static Future<void> saveWalletList(List<WalletMetadata> wallets) async {
    await _storage.write(
      key: _walletListKey,
      value: WalletMetadata.encodeList(wallets),
    );
  }

  /// Get active wallet ID
  static Future<String?> getActiveWalletId() async {
    return await _storage.read(key: _activeWalletIdKey);
  }

  /// Set active wallet ID
  static Future<void> setActiveWalletId(String walletId) async {
    await _storage.write(key: _activeWalletIdKey, value: walletId);
  }

  /// Check if any wallets exist
  static Future<bool> hasWallet() async {
    final wallets = await getWalletList();
    return wallets.isNotEmpty;
  }

  // ============================================
  // PER-WALLET STORAGE
  // ============================================

  /// Save mnemonic for a specific wallet
  static Future<void> saveMnemonic(String mnemonic, {required String walletId}) async {
    await _storage.write(key: _mnemonicKey(walletId), value: mnemonic);
  }

  /// Get mnemonic for a specific wallet
  static Future<String?> getMnemonic({required String walletId}) async {
    return await _storage.read(key: _mnemonicKey(walletId));
  }

  /// Save on-chain address for a specific wallet
  static Future<void> saveOnChainAddress(String address, {required String walletId}) async {
    await _storage.write(key: _onChainAddressKey(walletId), value: address);
  }

  /// Get on-chain address for a specific wallet
  static Future<String?> getOnChainAddress({required String walletId}) async {
    return await _storage.read(key: _onChainAddressKey(walletId));
  }

  /// Save BOLT12 offer for a specific wallet
  static Future<void> saveBolt12Offer(String offer, {required String walletId}) async {
    await _storage.write(key: _bolt12OfferKey(walletId), value: offer);
  }

  /// Get BOLT12 offer for a specific wallet
  static Future<String?> getBolt12Offer({required String walletId}) async {
    return await _storage.read(key: _bolt12OfferKey(walletId));
  }

  /// Delete all data for a specific wallet
  static Future<void> deleteWalletData(String walletId) async {
    await _storage.delete(key: _mnemonicKey(walletId));
    await _storage.delete(key: _onChainAddressKey(walletId));
    await _storage.delete(key: _bolt12OfferKey(walletId));
  }

  /// Delete all wallet data (full reset)
  static Future<void> clearAllWallets() async {
    final wallets = await getWalletList();
    for (final wallet in wallets) {
      await deleteWalletData(wallet.id);
    }
    await _storage.delete(key: _walletListKey);
    await _storage.delete(key: _activeWalletIdKey);
    // Also clear legacy keys
    await _storage.delete(key: _legacyMnemonicKey);
    await _storage.delete(key: _legacyWalletInitializedKey);
    await _storage.delete(key: _legacyOnChainAddressKey);
    await _storage.delete(key: _legacyBolt12OfferKey);
  }

  // ============================================
  // MIGRATION FROM SINGLE-WALLET
  // ============================================

  /// Check if legacy single-wallet data exists (needs migration)
  static Future<bool> needsMigration() async {
    final legacyMnemonic = await _storage.read(key: _legacyMnemonicKey);
    final walletList = await getWalletList();
    // Needs migration if legacy mnemonic exists but no wallet list
    return legacyMnemonic != null && walletList.isEmpty;
  }

  /// Migrate legacy single-wallet to multi-wallet format
  /// Returns the migrated wallet metadata, or null if no migration needed
  static Future<WalletMetadata?> migrateLegacyWallet() async {
    if (!await needsMigration()) return null;

    // Read legacy data
    final legacyMnemonic = await _storage.read(key: _legacyMnemonicKey);
    if (legacyMnemonic == null) return null;

    final legacyOnChain = await _storage.read(key: _legacyOnChainAddressKey);
    final legacyBolt12 = await _storage.read(key: _legacyBolt12OfferKey);

    // Create new wallet metadata
    final wallet = WalletMetadata.create(name: 'Main Wallet');

    // Save in new format
    await saveMnemonic(legacyMnemonic, walletId: wallet.id);
    if (legacyOnChain != null) {
      await saveOnChainAddress(legacyOnChain, walletId: wallet.id);
    }
    if (legacyBolt12 != null) {
      await saveBolt12Offer(legacyBolt12, walletId: wallet.id);
    }

    // Save wallet list and set as active
    await saveWalletList([wallet]);
    await setActiveWalletId(wallet.id);

    // Clean up legacy keys
    await _storage.delete(key: _legacyMnemonicKey);
    await _storage.delete(key: _legacyWalletInitializedKey);
    await _storage.delete(key: _legacyOnChainAddressKey);
    await _storage.delete(key: _legacyBolt12OfferKey);

    return wallet;
  }

  // ============================================
  // GENERIC STORAGE (used by other services)
  // ============================================

  /// Generic read for any key
  static Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  /// Generic write for any key
  static Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Generic delete for any key
  static Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}
