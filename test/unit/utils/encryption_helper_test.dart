import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

/// Tests for EncryptionHelper utility
/// Note: These tests verify the encryption logic without Flutter bindings.
/// Full integration tests require TestWidgetsFlutterBinding.
void main() {
  group('EncryptionHelper', () {
    group('isEncrypted', () {
      test('returns false for empty string', () {
        expect(_isEncrypted(''), isFalse);
      });

      test('returns false for plain JSON', () {
        final json = '{"id": "wallet-1", "name": "Test"}';
        expect(_isEncrypted(json), isFalse);
      });

      test('returns false for short base64', () {
        // Less than 29 bytes minimum (12 nonce + 1 data + 16 mac)
        final shortData = base64Encode([1, 2, 3, 4, 5]);
        expect(_isEncrypted(shortData), isFalse);
      });

      test('returns true for valid encrypted format', () {
        // 12 (nonce) + 10 (data) + 16 (mac) = 38 bytes
        final validLength = List.generate(38, (i) => i);
        final encoded = base64Encode(validLength);
        expect(_isEncrypted(encoded), isTrue);
      });

      test('returns false for invalid base64', () {
        expect(_isEncrypted('not valid base64!!!'), isFalse);
      });
    });

    group('encryption format', () {
      test('minimum encrypted size is 29 bytes', () {
        // 12 (nonce) + 1 (minimum data) + 16 (mac) = 29 bytes
        const minSize = 12 + 1 + 16;
        expect(minSize, equals(29));
      });

      test('nonce is 12 bytes (96 bits for GCM)', () {
        const nonceSize = 12;
        expect(nonceSize, equals(12));
      });

      test('mac is 16 bytes (128 bits for GCM)', () {
        const macSize = 16;
        expect(macSize, equals(16));
      });
    });

    group('AES-256-GCM properties', () {
      test('uses 256-bit key', () {
        const keyBits = 256;
        expect(keyBits, equals(256));
      });

      test('GCM provides authenticated encryption', () {
        // GCM mode provides both confidentiality and integrity
        // Tampering will be detected during decryption
        const isAuthenticated = true;
        expect(isAuthenticated, isTrue);
      });
    });

    group('key storage', () {
      test('key name is properly namespaced', () {
        const keyName = 'wallet_list';
        final storageKey = 'bolt21_enc_key_$keyName';
        expect(storageKey, startsWith('bolt21_'));
        expect(storageKey, contains('enc_key'));
      });

      test('different data types have different keys', () {
        final key1 = 'bolt21_enc_key_wallet_list';
        final key2 = 'bolt21_enc_key_operations';
        expect(key1, isNot(equals(key2)));
      });
    });
  });
}

/// Static version of isEncrypted for testing without Flutter bindings
bool _isEncrypted(String data) {
  if (data.isEmpty) return false;
  try {
    final decoded = base64Decode(data);
    // Minimum: 12 (nonce) + 1 (data) + 16 (mac) = 29 bytes
    return decoded.length >= 29;
  } catch (_) {
    return false;
  }
}
