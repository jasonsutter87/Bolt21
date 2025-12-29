import 'package:flutter_test/flutter_test.dart';
import 'package:bolt21/services/lightning_service.dart';

void main() {
  group('LightningService', () {
    // ==================== INITIALIZATION TESTS ====================
    group('initialization', () {
      test('starts not initialized', () {
        final service = LightningService();
        expect(service.isInitialized, isFalse);
      });
    });

    // ==================== MNEMONIC TESTS ====================
    group('mnemonic generation', () {
      test('generateMnemonic returns 12 words', () {
        final service = LightningService();
        final mnemonic = service.generateMnemonic();
        final words = mnemonic.split(' ');
        expect(words.length, equals(12));
      });

      test('generateMnemonic returns different values each time', () {
        final service = LightningService();
        final mnemonic1 = service.generateMnemonic();
        final mnemonic2 = service.generateMnemonic();
        expect(mnemonic1, isNot(equals(mnemonic2)));
      });

      test('generateMnemonic words are lowercase', () {
        final service = LightningService();
        final mnemonic = service.generateMnemonic();
        expect(mnemonic, equals(mnemonic.toLowerCase()));
      });

      test('generateMnemonic contains only valid characters', () {
        final service = LightningService();
        final mnemonic = service.generateMnemonic();
        final validPattern = RegExp(r'^[a-z ]+$');
        expect(validPattern.hasMatch(mnemonic), isTrue);
      });
    });
  });

  // ==================== PAYMENT INPUT VALIDATION TESTS ====================
  group('Payment Input Validation', () {
    group('BOLT11 invoice detection', () {
      test('recognizes lowercase lnbc prefix', () {
        const invoice = 'lnbc1500n1pj...';
        expect(invoice.toLowerCase().startsWith('lnbc'), isTrue);
      });

      test('recognizes uppercase LNBC prefix', () {
        const invoice = 'LNBC1500N1PJ...';
        expect(invoice.toLowerCase().startsWith('lnbc'), isTrue);
      });

      test('recognizes lntb (testnet) prefix', () {
        const invoice = 'lntb1500n1pj...';
        expect(invoice.toLowerCase().startsWith('lntb'), isTrue);
      });
    });

    group('BOLT12 offer detection', () {
      test('recognizes lno prefix', () {
        const offer = 'lno1qgsqvgnwgcg35z6...';
        expect(offer.toLowerCase().startsWith('lno'), isTrue);
      });

      test('recognizes uppercase LNO prefix', () {
        const offer = 'LNO1QGSQVGNWGCG35Z6...';
        expect(offer.toLowerCase().startsWith('lno'), isTrue);
      });
    });

    group('on-chain address detection', () {
      test('recognizes bc1 (native segwit) prefix', () {
        const address = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
        expect(address.startsWith('bc1'), isTrue);
      });

      test('recognizes bc1p (taproot) prefix', () {
        const address = 'bc1p5d7rjq7g6rdk2yhzks9smlaqtedr4dekq08ge8ztwac72sfr9rusxg3297';
        expect(address.startsWith('bc1p'), isTrue);
      });
    });
  });

  // ==================== AMOUNT PARSING TESTS ====================
  group('Amount Parsing', () {
    test('parses integer sats', () {
      const amountStr = '1000';
      final sats = int.tryParse(amountStr);
      expect(sats, equals(1000));
    });

    test('parses large amounts', () {
      const amountStr = '100000000';
      final sats = int.tryParse(amountStr);
      expect(sats, equals(100000000));
    });

    test('rejects non-numeric input', () {
      const amountStr = 'abc';
      final sats = int.tryParse(amountStr);
      expect(sats, isNull);
    });

    test('handles whitespace', () {
      const amountStr = '  1000  ';
      final sats = int.tryParse(amountStr.trim());
      expect(sats, equals(1000));
    });
  });

  // ==================== BIGINT HANDLING TESTS ====================
  group('BigInt Handling', () {
    test('converts int to BigInt correctly', () {
      const sats = 100000;
      final bigSats = BigInt.from(sats);
      expect(bigSats.toInt(), equals(sats));
    });

    test('handles max Bitcoin supply in sats', () {
      final maxSupply = BigInt.parse('2100000000000000');
      expect(maxSupply > BigInt.zero, isTrue);
    });

    test('BigInt comparison works correctly', () {
      final a = BigInt.from(1000);
      final b = BigInt.from(2000);
      expect(a < b, isTrue);
    });

    test('BigInt arithmetic works correctly', () {
      final balance = BigInt.from(10000);
      final fee = BigInt.from(100);
      final remaining = balance - fee;
      expect(remaining, equals(BigInt.from(9900)));
    });
  });
}
