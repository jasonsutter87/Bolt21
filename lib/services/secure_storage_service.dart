import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/wallet_metadata.dart';
import '../utils/encryption_helper.dart';
import '../utils/secure_logger.dart';

/// Secure storage for sensitive wallet data
///
/// Security hardening:
/// - Android: Encrypted shared preferences with hardware-backed keystore
/// - iOS: Keychain with accessibility restricted to when device is unlocked,
///        explicitly disabled iCloud backup to prevent cloud sync of secrets
/// - Wallet metadata is encrypted with AES-256-GCM before storage
class SecureStorageService {
  // Encryption helper for wallet metadata (defense in depth)
  static EncryptionHelper? _walletListEncryption;
  static bool _isInitialized = false;
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

  // LND connection keys (global, not per-wallet)
  static const _lndRestUrlKey = 'bolt21_lnd_rest_url';
  static const _lndMacaroonKey = 'bolt21_lnd_macaroon';

  // ============================================
  // INITIALIZATION
  // ============================================

  /// Initialize encryption for wallet metadata
  /// Call this before accessing wallet data
  static Future<void> initialize() async {
    if (_isInitialized) return;

    _walletListEncryption = EncryptionHelper(keyName: 'wallet_list');
    await _walletListEncryption!.initialize();
    _isInitialized = true;
  }

  /// Ensure encryption is initialized
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // ============================================
  // MULTI-WALLET MANAGEMENT
  // ============================================

  /// Get list of all wallets
  /// SECURITY: Wallet metadata is encrypted with AES-256-GCM
  static Future<List<WalletMetadata>> getWalletList() async {
    await _ensureInitialized();

    final encryptedData = await _storage.read(key: _walletListKey);
    if (encryptedData == null || encryptedData.isEmpty) return [];

    try {
      // Check if data is encrypted (migration support)
      if (EncryptionHelper.isEncrypted(encryptedData)) {
        final json = await _walletListEncryption!.decrypt(encryptedData);
        return WalletMetadata.decodeList(json);
      } else {
        // Legacy unencrypted data - migrate on next save
        SecureLogger.info('Migrating unencrypted wallet list to encrypted format', tag: 'Storage');
        final wallets = WalletMetadata.decodeList(encryptedData);
        // Re-save encrypted
        await saveWalletList(wallets);
        return wallets;
      }
    } catch (e) {
      SecureLogger.error('Failed to decrypt wallet list', error: e, tag: 'Storage');
      return [];
    }
  }

  /// Save wallet list
  /// SECURITY: Wallet metadata is encrypted with AES-256-GCM
  static Future<void> saveWalletList(List<WalletMetadata> wallets) async {
    await _ensureInitialized();

    final json = WalletMetadata.encodeList(wallets);
    final encrypted = await _walletListEncryption!.encrypt(json);
    await _storage.write(key: _walletListKey, value: encrypted);
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

  // ============================================
  // LND NODE CONNECTION
  // ============================================

  /// Save LND connection credentials
  static Future<void> saveLndCredentials({
    required String restUrl,
    required String macaroon,
  }) async {
    await _storage.write(key: _lndRestUrlKey, value: restUrl);
    await _storage.write(key: _lndMacaroonKey, value: macaroon);
  }

  /// Get LND REST URL
  static Future<String?> getLndRestUrl() async {
    return await _storage.read(key: _lndRestUrlKey);
  }

  /// Get LND macaroon (hex encoded)
  static Future<String?> getLndMacaroon() async {
    return await _storage.read(key: _lndMacaroonKey);
  }

  /// Check if LND is configured
  static Future<bool> hasLndCredentials() async {
    final url = await getLndRestUrl();
    final macaroon = await getLndMacaroon();
    return url != null && macaroon != null;
  }

  /// Clear LND credentials
  static Future<void> clearLndCredentials() async {
    await _storage.delete(key: _lndRestUrlKey);
    await _storage.delete(key: _lndMacaroonKey);
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
