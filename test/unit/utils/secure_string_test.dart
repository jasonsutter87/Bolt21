import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bolt21/utils/secure_string.dart';

void main() {
  group('SecureString', () {
    group('creation', () {
      test('fromString creates SecureString with correct value', () {
        final secure = SecureString.fromString('test value');
        expect(secure.value, equals('test value'));
        expect(secure.isDisposed, isFalse);
        secure.dispose();
      });

      test('fromBytes creates SecureString from bytes', () {
        final bytes = Uint8List.fromList([116, 101, 115, 116]); // 'test'
        final secure = SecureString.fromBytes(bytes);
        expect(secure.value, equals('test'));
        secure.dispose();
      });

      test('empty creates empty SecureString', () {
        final secure = SecureString.empty();
        expect(secure.isEmpty, isTrue);
        expect(secure.value, equals(''));
        secure.dispose();
      });
    });

    group('disposal', () {
      test('dispose marks SecureString as disposed', () {
        final secure = SecureString.fromString('secret');
        expect(secure.isDisposed, isFalse);
        secure.dispose();
        expect(secure.isDisposed, isTrue);
      });

      test('accessing value after dispose throws', () {
        final secure = SecureString.fromString('secret');
        secure.dispose();
        expect(() => secure.value, throwsStateError);
      });

      test('accessing bytes after dispose throws', () {
        final secure = SecureString.fromString('secret');
        secure.dispose();
        expect(() => secure.bytes, throwsStateError);
      });

      test('double dispose is safe', () {
        final secure = SecureString.fromString('secret');
        secure.dispose();
        secure.dispose(); // Should not throw
        expect(secure.isDisposed, isTrue);
      });
    });

    group('properties', () {
      test('length returns byte count', () {
        final secure = SecureString.fromString('test');
        expect(secure.length, equals(4));
        secure.dispose();
      });

      test('isEmpty returns true for empty', () {
        final secure = SecureString.empty();
        expect(secure.isEmpty, isTrue);
        secure.dispose();
      });

      test('isEmpty returns false for non-empty', () {
        final secure = SecureString.fromString('test');
        expect(secure.isEmpty, isFalse);
        secure.dispose();
      });

      test('bytes returns copy of data', () {
        final secure = SecureString.fromString('test');
        final bytes = secure.bytes;
        expect(bytes, equals([116, 101, 115, 116]));
        secure.dispose();
      });
    });

    group('copy', () {
      test('copy creates independent SecureString', () {
        final original = SecureString.fromString('secret');
        final copy = original.copy();

        expect(copy.value, equals('secret'));
        expect(copy.isDisposed, isFalse);

        original.dispose();
        expect(copy.isDisposed, isFalse); // Copy is independent
        expect(copy.value, equals('secret'));

        copy.dispose();
      });

      test('copy of disposed throws', () {
        final secure = SecureString.fromString('secret');
        secure.dispose();
        expect(() => secure.copy(), throwsStateError);
      });
    });

    group('toString', () {
      test('toString does not reveal content', () {
        final secure = SecureString.fromString('my secret password');
        final str = secure.toString();
        expect(str, isNot(contains('secret')));
        expect(str, isNot(contains('password')));
        expect(str, contains('bytes')); // Shows byte count only
        secure.dispose();
      });

      test('toString shows disposed status', () {
        final secure = SecureString.fromString('secret');
        secure.dispose();
        expect(secure.toString(), contains('disposed'));
      });
    });

    group('extension', () {
      test('toSecureString extension works', () {
        final secure = 'test value'.toSecureString();
        expect(secure.value, equals('test value'));
        secure.dispose();
      });
    });

    group('unicode support', () {
      test('handles unicode characters', () {
        final secure = SecureString.fromString('Bitcoin ₿');
        expect(secure.value, equals('Bitcoin ₿'));
        secure.dispose();
      });

      test('handles emoji', () {
        final secure = SecureString.fromString('Hello 🔐');
        expect(secure.value, equals('Hello 🔐'));
        secure.dispose();
      });
    });

    group('mnemonic use case', () {
      test('stores and retrieves 12-word mnemonic', () {
        const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
        final secure = SecureString.fromString(mnemonic);

        expect(secure.value, equals(mnemonic));
        expect(secure.value.split(' ').length, equals(12));

        secure.dispose();
        expect(secure.isDisposed, isTrue);
      });
    });
  });
}
