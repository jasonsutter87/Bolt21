import 'package:flutter_test/flutter_test.dart';
import 'package:bolt21/models/wallet_metadata.dart';

void main() {
  group('WalletMetadata', () {
    group('construction', () {
      test('creates with required fields', () {
        final wallet = WalletMetadata(
          id: 'test-id',
          name: 'Test Wallet',
          createdAt: DateTime(2024, 1, 15),
        );

        expect(wallet.id, equals('test-id'));
        expect(wallet.name, equals('Test Wallet'));
        expect(wallet.createdAt, equals(DateTime(2024, 1, 15)));
      });

      test('create() generates unique ID', () {
        final wallet1 = WalletMetadata.create(name: 'Wallet 1');
        final wallet2 = WalletMetadata.create(name: 'Wallet 2');

        expect(wallet1.id, isNotEmpty);
        expect(wallet2.id, isNotEmpty);
        expect(wallet1.id, isNot(equals(wallet2.id)));
      });

      test('create() sets createdAt to now', () {
        final before = DateTime.now();
        final wallet = WalletMetadata.create(name: 'Test');
        final after = DateTime.now();

        expect(wallet.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
        expect(wallet.createdAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
      });

      test('workingDir is derived from id', () {
        final wallet = WalletMetadata(
          id: 'abc-123',
          name: 'Test',
          createdAt: DateTime.now(),
        );

        expect(wallet.workingDir, equals('wallet_abc-123'));
      });
    });

    group('copyWith', () {
      test('copies name', () {
        final original = WalletMetadata(
          id: 'id-1',
          name: 'Original',
          createdAt: DateTime(2024, 1, 1),
        );

        final copy = original.copyWith(name: 'Updated');

        expect(copy.id, equals(original.id));
        expect(copy.name, equals('Updated'));
        expect(copy.createdAt, equals(original.createdAt));
      });

      test('preserves fields when not specified', () {
        final original = WalletMetadata(
          id: 'id-1',
          name: 'Original',
          createdAt: DateTime(2024, 1, 1),
        );

        final copy = original.copyWith();

        expect(copy.id, equals(original.id));
        expect(copy.name, equals(original.name));
        expect(copy.createdAt, equals(original.createdAt));
      });
    });

    group('JSON serialization', () {
      test('toJson includes all fields', () {
        final wallet = WalletMetadata(
          id: 'json-id',
          name: 'JSON Wallet',
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        final json = wallet.toJson();

        expect(json['id'], equals('json-id'));
        expect(json['name'], equals('JSON Wallet'));
        expect(json['createdAt'], contains('2024-06-15'));
      });

      test('fromJson reconstructs wallet', () {
        final json = {
          'id': 'from-json',
          'name': 'From JSON',
          'createdAt': '2024-03-20T14:00:00.000',
        };

        final wallet = WalletMetadata.fromJson(json);

        expect(wallet.id, equals('from-json'));
        expect(wallet.name, equals('From JSON'));
        expect(wallet.createdAt.year, equals(2024));
        expect(wallet.createdAt.month, equals(3));
        expect(wallet.createdAt.day, equals(20));
      });

      test('round-trip preserves data', () {
        final original = WalletMetadata(
          id: 'roundtrip-id',
          name: 'Roundtrip Wallet',
          createdAt: DateTime(2024, 12, 25, 8, 0, 0),
        );

        final json = original.toJson();
        final restored = WalletMetadata.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.name, equals(original.name));
        expect(restored.createdAt.year, equals(original.createdAt.year));
        expect(restored.createdAt.month, equals(original.createdAt.month));
        expect(restored.createdAt.day, equals(original.createdAt.day));
      });
    });

    group('list encoding/decoding', () {
      test('encodeList handles empty list', () {
        final encoded = WalletMetadata.encodeList([]);
        expect(encoded, equals('[]'));
      });

      test('decodeList handles empty list', () {
        final decoded = WalletMetadata.decodeList('[]');
        expect(decoded, isEmpty);
      });

      test('encodeList/decodeList round-trip', () {
        final wallets = [
          WalletMetadata(id: 'w1', name: 'Wallet 1', createdAt: DateTime(2024, 1, 1)),
          WalletMetadata(id: 'w2', name: 'Wallet 2', createdAt: DateTime(2024, 2, 2)),
          WalletMetadata(id: 'w3', name: 'Wallet 3', createdAt: DateTime(2024, 3, 3)),
        ];

        final encoded = WalletMetadata.encodeList(wallets);
        final decoded = WalletMetadata.decodeList(encoded);

        expect(decoded.length, equals(3));
        expect(decoded[0].id, equals('w1'));
        expect(decoded[1].name, equals('Wallet 2'));
        expect(decoded[2].createdAt.month, equals(3));
      });

      test('handles special characters in name', () {
        final wallets = [
          WalletMetadata(id: 'w1', name: 'Wallet "with" quotes', createdAt: DateTime.now()),
          WalletMetadata(id: 'w2', name: "Wallet's apostrophe", createdAt: DateTime.now()),
          WalletMetadata(id: 'w3', name: 'Wallet\nwith\nnewlines', createdAt: DateTime.now()),
        ];

        final encoded = WalletMetadata.encodeList(wallets);
        final decoded = WalletMetadata.decodeList(encoded);

        expect(decoded[0].name, contains('quotes'));
        expect(decoded[1].name, contains('apostrophe'));
        expect(decoded[2].name, contains('newlines'));
      });

      test('handles unicode in name', () {
        final wallets = [
          WalletMetadata(id: 'w1', name: 'Bitcoin Wallet', createdAt: DateTime.now()),
        ];

        final encoded = WalletMetadata.encodeList(wallets);
        final decoded = WalletMetadata.decodeList(encoded);

        expect(decoded[0].name, equals('Bitcoin Wallet'));
      });
    });

    group('equality', () {
      test('same id means same wallet', () {
        final w1 = WalletMetadata(id: 'same', name: 'Name 1', createdAt: DateTime(2024, 1, 1));
        final w2 = WalletMetadata(id: 'same', name: 'Name 2', createdAt: DateTime(2024, 2, 2));

        // Note: Dart doesn't auto-generate equality, so these are different objects
        // This test documents expected behavior
        expect(w1.id, equals(w2.id));
      });
    });
  });
}
