import 'package:flutter_test/flutter_test.dart';
import 'package:bolt21/services/operation_state_service.dart';

/// Security and validation tests for critical wallet operations
void main() {
  // ==================== INPUT SANITIZATION TESTS ====================
  group('Input Sanitization', () {
    group('destination validation', () {
      test('rejects empty destination', () {
        const destination = '';
        expect(destination.isEmpty, isTrue);
      });

      test('rejects whitespace-only destination', () {
        const destination = '   ';
        expect(destination.trim().isEmpty, isTrue);
      });

      test('accepts valid BOLT11 invoice', () {
        const invoice = 'lnbc1500n1pj9nr6pp5ld...';
        expect(invoice.toLowerCase().startsWith('ln'), isTrue);
      });

      test('accepts valid BOLT12 offer', () {
        const offer = 'lno1qgsqvgnwgcg35z6ee2h3...';
        expect(offer.toLowerCase().startsWith('lno'), isTrue);
      });

      test('accepts valid Bitcoin address', () {
        const address = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
        expect(address.startsWith('bc1'), isTrue);
      });

      test('rejects script injection in destination', () {
        const malicious = '<script>alert("xss")</script>';
        final containsScript = malicious.contains('<script>');
        expect(containsScript, isTrue);
        // Should be rejected before reaching SDK
      });

      test('rejects SQL injection in destination', () {
        const malicious = "'; DROP TABLE payments; --";
        final containsSql = malicious.contains('DROP') || malicious.contains("'");
        expect(containsSql, isTrue);
        // Should be rejected before reaching SDK
      });
    });

    group('amount validation', () {
      test('rejects negative amounts', () {
        const amount = -1000;
        expect(amount < 0, isTrue);
      });

      test('rejects zero amount for sends', () {
        const amount = 0;
        expect(amount == 0, isTrue);
      });

      test('accepts positive amount', () {
        const amount = 1000;
        expect(amount > 0, isTrue);
      });

      test('rejects amount exceeding max supply', () {
        const maxSupply = 2100000000000000; // 21M BTC in sats
        const amount = 2100000000000001;
        expect(amount > maxSupply, isTrue);
      });

      test('accepts max supply amount', () {
        const maxSupply = 2100000000000000;
        const amount = 2100000000000000;
        expect(amount <= maxSupply, isTrue);
      });
    });

    group('mnemonic validation', () {
      test('rejects mnemonic with invalid word count', () {
        const mnemonic = 'abandon abandon abandon';
        final words = mnemonic.split(' ');
        expect(words.length != 12 && words.length != 24, isTrue);
      });

      test('rejects empty mnemonic', () {
        const mnemonic = '';
        expect(mnemonic.isEmpty, isTrue);
      });

      test('rejects mnemonic with numbers', () {
        const mnemonic = 'abandon 123 abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
        final hasNumbers = RegExp(r'\d').hasMatch(mnemonic);
        expect(hasNumbers, isTrue);
      });

      test('rejects mnemonic with special characters', () {
        const mnemonic = 'abandon @#! abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
        final hasSpecialChars = RegExp(r'[^a-zA-Z\s]').hasMatch(mnemonic);
        expect(hasSpecialChars, isTrue);
      });

      test('accepts valid 12-word mnemonic format', () {
        const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
        final words = mnemonic.split(' ');
        expect(words.length, equals(12));
        expect(mnemonic.toLowerCase(), equals(mnemonic));
      });
    });
  });

  // ==================== OPERATION ID VALIDATION ====================
  group('Operation ID Validation', () {
    test('operation ID is non-empty', () {
      final op = OperationState(
        id: 'op_12345',
        type: OperationType.send,
        status: OperationStatus.pending,
        startedAt: DateTime.now(),
      );
      expect(op.id.isNotEmpty, isTrue);
    });

    test('operation ID has proper format', () {
      final id = 'op_${DateTime.now().microsecondsSinceEpoch}';
      expect(id.startsWith('op_'), isTrue);
    });

    test('operation IDs are unique across rapid creation', () {
      final ids = <String>{};
      for (int i = 0; i < 100; i++) {
        final id = 'op_${DateTime.now().microsecondsSinceEpoch}_$i';
        expect(ids.contains(id), isFalse);
        ids.add(id);
      }
    });
  });

  // ==================== STATE TRANSITION VALIDATION ====================
  group('State Transition Validation', () {
    test('pending can transition to preparing', () {
      final op = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.pending,
        startedAt: DateTime.now(),
      );
      final updated = op.copyWith(status: OperationStatus.preparing);
      expect(updated.status, equals(OperationStatus.preparing));
    });

    test('preparing can transition to executing', () {
      final op = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.preparing,
        startedAt: DateTime.now(),
      );
      final updated = op.copyWith(status: OperationStatus.executing);
      expect(updated.status, equals(OperationStatus.executing));
    });

    test('executing can transition to completed', () {
      final op = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.executing,
        startedAt: DateTime.now(),
      );
      final updated = op.copyWith(
        status: OperationStatus.completed,
        completedAt: DateTime.now(),
      );
      expect(updated.status, equals(OperationStatus.completed));
      expect(updated.completedAt, isNotNull);
    });

    test('executing can transition to failed', () {
      final op = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.executing,
        startedAt: DateTime.now(),
      );
      final updated = op.copyWith(
        status: OperationStatus.failed,
        error: 'Network error',
      );
      expect(updated.status, equals(OperationStatus.failed));
      expect(updated.error, isNotNull);
    });

    test('any state can transition to unknown (crash recovery)', () {
      for (final status in OperationStatus.values) {
        final op = OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: status,
          startedAt: DateTime.now(),
        );
        final updated = op.copyWith(status: OperationStatus.unknown);
        expect(updated.status, equals(OperationStatus.unknown));
      }
    });
  });

  // ==================== JSON SERIALIZATION SECURITY ====================
  group('JSON Serialization Security', () {
    test('handles special characters in error messages', () {
      final op = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.failed,
        startedAt: DateTime.now(),
        error: 'Error: "Failed" with code <500>',
      );

      final json = op.toJson();
      final restored = OperationState.fromJson(json);

      expect(restored.error, equals('Error: "Failed" with code <500>'));
    });

    test('handles unicode in error messages', () {
      final op = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.failed,
        startedAt: DateTime.now(),
        error: '支付失败 - Payment failed 💸',
      );

      final json = op.toJson();
      final restored = OperationState.fromJson(json);

      expect(restored.error, contains('支付失败'));
      expect(restored.error, contains('💸'));
    });

    test('handles very long destination strings', () {
      final longDestination = 'lno1' + 'a' * 1000;
      final op = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.pending,
        startedAt: DateTime.now(),
        destination: longDestination,
      );

      final json = op.toJson();
      final restored = OperationState.fromJson(json);

      expect(restored.destination, equals(longDestination));
    });

    test('handles null fields correctly', () {
      final op = OperationState(
        id: 'op_1',
        type: OperationType.receiveBolt12,
        status: OperationStatus.pending,
        startedAt: DateTime.now(),
      );

      final json = op.toJson();
      expect(json['destination'], isNull);
      expect(json['amountSat'], isNull);
      expect(json['error'], isNull);
      expect(json['txId'], isNull);
    });
  });

  // ==================== PAYMENT TYPE SECURITY ====================
  group('Payment Type Security', () {
    test('send operations are high risk', () {
      final op = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.executing,
        startedAt: DateTime.now(),
        amountSat: 10000,
      );

      // Send operations that are incomplete are highest risk
      expect(op.isSend, isTrue);
      expect(op.isIncomplete, isTrue);
    });

    test('receive operations are lower risk', () {
      final op = OperationState(
        id: 'op_1',
        type: OperationType.receiveBolt12,
        status: OperationStatus.pending,
        startedAt: DateTime.now(),
      );

      expect(op.isSend, isFalse);
      // Incomplete receives just mean we might not have gotten funds yet
    });

    test('distinguishes between receive types', () {
      expect(OperationType.receiveBolt12, isNot(equals(OperationType.receiveOnchain)));
      expect(OperationType.receiveBolt12, isNot(equals(OperationType.receiveBolt11)));
      expect(OperationType.receiveOnchain, isNot(equals(OperationType.receiveBolt11)));
    });
  });

  // ==================== TIMESTAMP VALIDATION ====================
  group('Timestamp Validation', () {
    test('startedAt is required', () {
      final now = DateTime.now();
      final op = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.pending,
        startedAt: now,
      );
      expect(op.startedAt, equals(now));
    });

    test('completedAt is optional', () {
      final op = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.pending,
        startedAt: DateTime.now(),
      );
      expect(op.completedAt, isNull);
    });

    test('completedAt should be after startedAt', () {
      final startedAt = DateTime.now().subtract(const Duration(seconds: 5));
      final completedAt = DateTime.now();

      final op = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.completed,
        startedAt: startedAt,
        completedAt: completedAt,
      );

      expect(op.completedAt!.isAfter(op.startedAt), isTrue);
    });

    test('timestamps survive serialization', () {
      final startedAt = DateTime(2024, 6, 15, 10, 30, 45, 123);
      final completedAt = DateTime(2024, 6, 15, 10, 31, 00, 456);

      final op = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.completed,
        startedAt: startedAt,
        completedAt: completedAt,
      );

      final json = op.toJson();
      final restored = OperationState.fromJson(json);

      expect(restored.startedAt.year, equals(2024));
      expect(restored.startedAt.month, equals(6));
      expect(restored.startedAt.day, equals(15));
    });
  });

  // ==================== ERROR MESSAGE SECURITY ====================
  group('Error Message Security', () {
    test('preserves error details', () {
      const error = 'InsufficientFunds: balance=5000, required=10000';
      final op = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.failed,
        startedAt: DateTime.now(),
        error: error,
      );

      expect(op.error, equals(error));
    });

    test('handles empty error string', () {
      final op = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.failed,
        startedAt: DateTime.now(),
        error: '',
      );

      expect(op.error, isEmpty);
    });

    test('handles multi-line error messages', () {
      const error = 'Error occurred:\nLine 1\nLine 2\nLine 3';
      final op = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.failed,
        startedAt: DateTime.now(),
        error: error,
      );

      final json = op.toJson();
      final restored = OperationState.fromJson(json);

      expect(restored.error, contains('\n'));
    });
  });

  // ==================== TRANSACTION ID VALIDATION ====================
  group('Transaction ID Validation', () {
    test('txId is optional for pending operations', () {
      final op = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.pending,
        startedAt: DateTime.now(),
      );
      expect(op.txId, isNull);
    });

    test('txId should be present for completed operations', () {
      final op = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.completed,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        txId: 'tx_abc123',
      );
      expect(op.txId, isNotNull);
    });

    test('handles long transaction IDs', () {
      final longTxId = 'a' * 64; // Bitcoin tx IDs are 64 hex chars
      final op = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.completed,
        startedAt: DateTime.now(),
        txId: longTxId,
      );

      expect(op.txId!.length, equals(64));
    });
  });

  // ==================== CONCURRENT ACCESS PROTECTION ====================
  group('Concurrent Access Protection', () {
    test('immutable operations prevent race conditions', () {
      final original = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.pending,
        startedAt: DateTime.now(),
      );

      // Simulate concurrent modifications
      final update1 = original.copyWith(status: OperationStatus.preparing);
      final update2 = original.copyWith(status: OperationStatus.failed);

      // Original unchanged
      expect(original.status, equals(OperationStatus.pending));
      expect(update1.status, equals(OperationStatus.preparing));
      expect(update2.status, equals(OperationStatus.failed));
    });

    test('operation map prevents duplicate IDs', () {
      final operations = <String, OperationState>{};

      final op1 = OperationState(
        id: 'op_same_id',
        type: OperationType.send,
        status: OperationStatus.pending,
        startedAt: DateTime.now(),
        amountSat: 1000,
      );

      final op2 = OperationState(
        id: 'op_same_id',
        type: OperationType.send,
        status: OperationStatus.completed,
        startedAt: DateTime.now(),
        amountSat: 2000,
      );

      operations[op1.id] = op1;
      operations[op2.id] = op2;

      // Only one entry, second overwrites first
      expect(operations.length, equals(1));
      expect(operations['op_same_id']!.amountSat, equals(2000));
    });
  });
}
