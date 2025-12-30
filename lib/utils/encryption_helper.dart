import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import '../services/secure_storage_service.dart';
import 'secure_logger.dart';

/// AES-256-GCM encryption helper for sensitive data
///
/// SECURITY: Uses authenticated encryption (GCM) which provides both
/// confidentiality and integrity verification. Tampering is detected.
///
/// Key Management:
/// - Each data type gets its own encryption key stored in SecureStorage
/// - Keys are generated using cryptographically secure random
/// - 256-bit keys for AES-256-GCM
///
/// Format: [12-byte nonce][ciphertext][16-byte auth tag]
class EncryptionHelper {
  final String _keyStorageKey;
  final AesGcm _cipher = AesGcm.with256bits();
  final Random _secureRandom = Random.secure();
  SecretKey? _secretKey;

  EncryptionHelper({required String keyName})
      : _keyStorageKey = 'bolt21_enc_key_$keyName';

  /// Initialize encryption key from secure storage or generate new one
  Future<void> initialize() async {
    final existingKey = await SecureStorageService.read(_keyStorageKey);
    if (existingKey != null && existingKey.isNotEmpty) {
      final keyBytes = base64Decode(existingKey);
      _secretKey = SecretKey(keyBytes);
    } else {
      // Generate new 256-bit key using cryptographically secure random
      _secretKey = await _cipher.newSecretKey();
      final keyBytes = await _secretKey!.extractBytes();
      await SecureStorageService.write(
        _keyStorageKey,
        base64Encode(keyBytes),
      );
      SecureLogger.info('Generated new AES-256-GCM key for $_keyStorageKey', tag: 'Crypto');
    }
  }

  /// Encrypt a string and return base64-encoded ciphertext
  Future<String> encrypt(String plaintext) async {
    if (_secretKey == null) {
      throw StateError('EncryptionHelper not initialized. Call initialize() first.');
    }

    final plaintextBytes = utf8.encode(plaintext);

    // Generate random 96-bit nonce (recommended for GCM)
    final nonce = List.generate(12, (_) => _secureRandom.nextInt(256));

    final secretBox = await _cipher.encrypt(
      plaintextBytes,
      secretKey: _secretKey!,
      nonce: nonce,
    );

    // Combine: nonce + ciphertext + mac
    final combined = [
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ];

    return base64Encode(combined);
  }

  /// Decrypt base64-encoded ciphertext
  /// Throws if authentication fails (tampered data)
  Future<String> decrypt(String ciphertextBase64) async {
    if (_secretKey == null) {
      throw StateError('EncryptionHelper not initialized. Call initialize() first.');
    }

    final ciphertext = base64Decode(ciphertextBase64);

    if (ciphertext.length < 12 + 16) {
      throw Exception('Invalid encrypted data: too short');
    }

    // Extract components: [12-byte nonce][ciphertext][16-byte mac]
    final nonce = ciphertext.sublist(0, 12);
    final mac = Mac(ciphertext.sublist(ciphertext.length - 16));
    final encryptedData = ciphertext.sublist(12, ciphertext.length - 16);

    final secretBox = SecretBox(
      encryptedData,
      nonce: nonce,
      mac: mac,
    );

    // Decrypt and verify authentication tag
    final plaintextBytes = await _cipher.decrypt(
      secretBox,
      secretKey: _secretKey!,
    );

    return utf8.decode(plaintextBytes);
  }

  /// Check if data appears to be encrypted (base64 with minimum length)
  static bool isEncrypted(String data) {
    if (data.isEmpty) return false;
    try {
      final decoded = base64Decode(data);
      // Minimum: 12 (nonce) + 1 (data) + 16 (mac) = 29 bytes
      return decoded.length >= 29;
    } catch (_) {
      return false;
    }
  }

  /// Delete the encryption key (for wallet deletion)
  Future<void> deleteKey() async {
    await SecureStorageService.delete(_keyStorageKey);
    _secretKey = null;
  }
}
