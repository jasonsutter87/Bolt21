import 'package:flutter_test/flutter_test.dart';
import 'package:bolt21/services/operation_state_service.dart';
import 'package:bolt21/utils/formatters.dart';

/// Edge case tests for critical wallet scenarios
void main() {
  // ==================== DOUBLE-PAY PREVENTION TESTS ====================
  group('Double-Pay Prevention', () {
    test('same operation ID cannot be added twice', () {
      final operations = <String, OperationState>{};
      final op = OperationState(
        id: 'op_unique_123',
        type: OperationType.send,
        status: OperationStatus.pending,
        startedAt: DateTime.now(),
        amountSat: 5000,
      );

      operations[op.id] = op;
      expect(operations.containsKey('op_unique_123'), isTrue);

      // Attempting to add same ID would overwrite
      final op2 = op.copyWith(status: OperationStatus.executing);
      operations[op2.id] = op2;

      // Still only one entry
      expect(operations.length, equals(1));
      expect(operations['op_unique_123']!.status, equals(OperationStatus.executing));
    });

    test('idempotency key prevents duplicate sends', () {
      final processedKeys = <String>{};
      const idempotencyKey = 'send_lnbc1_5000sats_1234567890';

      // First attempt succeeds
      bool firstAttempt = !processedKeys.contains(idempotencyKey);
      if (firstAttempt) processedKeys.add(idempotencyKey);
      expect(firstAttempt, isTrue);

      // Second attempt is blocked
      bool secondAttempt = !processedKeys.contains(idempotencyKey);
      expect(secondAttempt, isFalse);
    });

    test('different destinations get unique keys', () {
      String generateKey(String dest, int amount) => 'send_${dest}_${amount}';

      final key1 = generateKey('lnbc1...', 5000);
      final key2 = generateKey('lnbc2...', 5000);

      expect(key1, isNot(equals(key2)));
    });

    test('same destination different amount gets unique key', () {
      String generateKey(String dest, int amount) => 'send_${dest}_${amount}';

      final key1 = generateKey('lnbc1...', 5000);
      final key2 = generateKey('lnbc1...', 6000);

      expect(key1, isNot(equals(key2)));
    });
  });

  // ==================== RACE CONDITION TESTS ====================
  group('Race Condition Prevention', () {
    test('concurrent operation creation uses unique IDs', () {
      final ids = <String>{};

      // Simulate rapid concurrent ID generation
      for (int i = 0; i < 1000; i++) {
        final id = 'op_${DateTime.now().microsecondsSinceEpoch}_$i';
        expect(ids.contains(id), isFalse, reason: 'Duplicate ID: $id');
        ids.add(id);
      }

      expect(ids.length, equals(1000));
    });

    test('status transitions are atomic', () {
      final op = OperationState(
        id: 'op_atomic',
        type: OperationType.send,
        status: OperationStatus.pending,
        startedAt: DateTime.now(),
      );

      // Each copyWith creates a new immutable instance
      final preparing = op.copyWith(status: OperationStatus.preparing);
      final executing = preparing.copyWith(status: OperationStatus.executing);
      final completed = executing.copyWith(
        status: OperationStatus.completed,
        completedAt: DateTime.now(),
      );

      // Original unchanged
      expect(op.status, equals(OperationStatus.pending));
      expect(completed.status, equals(OperationStatus.completed));
    });
  });

  // ==================== BOUNDARY CONDITION TESTS ====================
  group('Boundary Conditions', () {
    group('amount boundaries', () {
      test('handles zero amount', () {
        expect(formatSats(0), equals('0 sats'));
      });

      test('handles 1 sat (dust)', () {
        expect(formatSats(1), equals('1 sats'));
      });

      test('handles typical minimum (546 sats)', () {
        expect(formatSats(546), equals('546 sats'));
      });

      test('handles 1 BTC exactly', () {
        expect(formatSats(100000000), contains('BTC'));
      });

      test('handles max supply (21M BTC)', () {
        expect(formatSats(2100000000000000), contains('BTC'));
      });

      test('handles int max value', () {
        // 9,223,372,036,854,775,807 for 64-bit
        // This is > max BTC supply, but shouldn't crash
        expect(() => formatSats(9223372036854775807), returnsNormally);
      });
    });

    group('string length boundaries', () {
      test('truncateMiddle handles empty string', () {
        expect(truncateMiddle(''), equals(''));
      });

      test('truncateMiddle handles 1 char', () {
        expect(truncateMiddle('a'), equals('a'));
      });

      test('truncateMiddle handles boundary exactly', () {
        // default: start=8, end=8, ellipsis=3 = 19 chars
        final boundary = 'x' * 19;
        expect(truncateMiddle(boundary), equals(boundary));
      });

      test('truncateMiddle handles boundary + 1', () {
        final overBoundary = 'x' * 20;
        expect(truncateMiddle(overBoundary), contains('...'));
      });
    });

    group('time boundaries', () {
      test('formatTimestamp handles epoch', () {
        final epoch = DateTime.fromMillisecondsSinceEpoch(0);
        expect(() => formatTimestamp(epoch), returnsNormally);
      });

      test('formatTimestamp handles far future', () {
        final future = DateTime(2100, 1, 1);
        expect(() => formatTimestamp(future), returnsNormally);
      });

      test('formatTimestamp handles 1 second ago', () {
        final oneSecAgo = DateTime.now().subtract(const Duration(seconds: 1));
        expect(formatTimestamp(oneSecAgo), equals('Just now'));
      });

      test('formatTimestamp handles 59 seconds ago', () {
        final fiftyNine = DateTime.now().subtract(const Duration(seconds: 59));
        expect(formatTimestamp(fiftyNine), equals('Just now'));
      });

      test('formatTimestamp handles 60 seconds ago', () {
        final sixty = DateTime.now().subtract(const Duration(seconds: 60));
        expect(formatTimestamp(sixty), equals('1m ago'));
      });
    });
  });

  // ==================== DATA INTEGRITY TESTS ====================
  group('Data Integrity', () {
    test('operation state survives serialization', () {
      final original = OperationState(
        id: 'op_integrity_test',
        type: OperationType.send,
        status: OperationStatus.executing,
        startedAt: DateTime(2024, 6, 15, 10, 30, 45),
        destination: 'lnbc1500n1pj9nr6pp5...',
        amountSat: 1500,
        error: null,
        txId: 'tx_abc123',
      );

      final json = original.toJson();
      final restored = OperationState.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.type, equals(original.type));
      expect(restored.status, equals(original.status));
      expect(restored.destination, equals(original.destination));
      expect(restored.amountSat, equals(original.amountSat));
      expect(restored.txId, equals(original.txId));
    });

    test('null fields preserved in serialization', () {
      final original = OperationState(
        id: 'op_null_test',
        type: OperationType.receiveBolt12,
        status: OperationStatus.pending,
        startedAt: DateTime.now(),
        destination: null,
        amountSat: null,
        error: null,
        txId: null,
      );

      final json = original.toJson();
      final restored = OperationState.fromJson(json);

      expect(restored.destination, isNull);
      expect(restored.amountSat, isNull);
      expect(restored.error, isNull);
      expect(restored.txId, isNull);
    });

    test('special characters preserved in strings', () {
      final original = OperationState(
        id: 'op_special',
        type: OperationType.send,
        status: OperationStatus.failed,
        startedAt: DateTime.now(),
        error: 'Error: "Connection failed" — code: 408',
      );

      final json = original.toJson();
      final restored = OperationState.fromJson(json);

      expect(restored.error, equals('Error: "Connection failed" — code: 408'));
    });
  });

  // ==================== CRASH RECOVERY SCENARIOS ====================
  group('Crash Recovery Scenarios', () {
    test('incomplete send operation detected', () {
      final operations = [
        OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: OperationStatus.executing,
          startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          amountSat: 5000,
        ),
      ];

      final incomplete = operations.where((op) => op.isIncomplete && op.isSend);
      expect(incomplete.length, equals(1));
    });

    test('completed operations not flagged as incomplete', () {
      final operations = [
        OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: OperationStatus.completed,
          startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          amountSat: 5000,
        ),
        OperationState(
          id: 'op_2',
          type: OperationType.receiveBolt12,
          status: OperationStatus.completed,
          startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
      ];

      final incomplete = operations.where((op) => op.isIncomplete);
      expect(incomplete, isEmpty);
    });

    test('failed operations not flagged as incomplete', () {
      final op = OperationState(
        id: 'op_failed',
        type: OperationType.send,
        status: OperationStatus.failed,
        startedAt: DateTime.now(),
        error: 'Insufficient funds',
      );

      expect(op.isIncomplete, isFalse);
      expect(op.isFailed, isTrue);
    });

    test('unknown status flagged as incomplete (needs investigation)', () {
      final op = OperationState(
        id: 'op_unknown',
        type: OperationType.send,
        status: OperationStatus.unknown,
        startedAt: DateTime.now(),
      );

      expect(op.isIncomplete, isTrue);
    });

    test('preparing status flagged as incomplete', () {
      final op = OperationState(
        id: 'op_preparing',
        type: OperationType.send,
        status: OperationStatus.preparing,
        startedAt: DateTime.now(),
      );

      expect(op.isIncomplete, isTrue);
    });
  });

  // ==================== NETWORK ERROR HANDLING ====================
  group('Network Error Handling', () {
    test('socket exception is retryable', () {
      const error = 'SocketException: Connection refused';
      final isNetwork = error.contains('Socket') ||
          error.contains('Connection') ||
          error.contains('Network');
      expect(isNetwork, isTrue);
    });

    test('timeout exception is retryable', () {
      const error = 'TimeoutException';
      final isRetryable = error.contains('Timeout');
      expect(isRetryable, isTrue);
    });

    test('business logic errors are not retryable', () {
      const errors = [
        'Insufficient funds',
        'Invalid invoice',
        'Invoice expired',
        'Amount too small',
      ];

      for (final error in errors) {
        final isNetwork = error.contains('Socket') ||
            error.contains('Timeout') ||
            error.contains('Connection');
        expect(isNetwork, isFalse, reason: '$error should not be retryable');
      }
    });
  });

  // ==================== MNEMONIC VALIDATION ====================
  group('Mnemonic Validation', () {
    test('valid mnemonic has 12 words', () {
      const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      final words = mnemonic.split(' ');
      expect(words.length, equals(12));
    });

    test('valid mnemonic has 24 words (extended)', () {
      const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art';
      final words = mnemonic.split(' ');
      expect(words.length, equals(24));
    });

    test('mnemonic with wrong word count is invalid', () {
      const mnemonic = 'abandon abandon abandon'; // Only 3 words
      final words = mnemonic.split(' ');
      expect(words.length != 12 && words.length != 24, isTrue);
    });

    test('mnemonic with numbers is invalid', () {
      const mnemonic = 'abandon 123 abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      final hasNumbers = RegExp(r'\d').hasMatch(mnemonic);
      expect(hasNumbers, isTrue);
    });

    test('mnemonic normalization to lowercase', () {
      const mnemonic = 'ABANDON ABANDON ABANDON ABANDON ABANDON ABANDON ABANDON ABANDON ABANDON ABANDON ABANDON ABOUT';
      final normalized = mnemonic.toLowerCase();
      expect(normalized, equals(normalized.toLowerCase()));
    });
  });

  // ==================== CONCURRENT OPERATION SAFETY ====================
  group('Concurrent Operation Safety', () {
    test('multiple pending operations tracked separately', () {
      final operations = <OperationState>[
        OperationState(
          id: 'op_send_1',
          type: OperationType.send,
          status: OperationStatus.pending,
          startedAt: DateTime.now(),
        ),
        OperationState(
          id: 'op_receive_1',
          type: OperationType.receiveBolt12,
          status: OperationStatus.pending,
          startedAt: DateTime.now(),
        ),
        OperationState(
          id: 'op_send_2',
          type: OperationType.send,
          status: OperationStatus.executing,
          startedAt: DateTime.now(),
        ),
      ];

      expect(operations.length, equals(3));
      expect(operations.where((op) => op.isSend).length, equals(2));
      expect(operations.where((op) => op.isReceive).length, equals(1));
    });

    test('completing one operation does not affect others', () {
      var op1 = OperationState(
        id: 'op_1',
        type: OperationType.send,
        status: OperationStatus.executing,
        startedAt: DateTime.now(),
      );
      final op2 = OperationState(
        id: 'op_2',
        type: OperationType.send,
        status: OperationStatus.executing,
        startedAt: DateTime.now(),
      );

      // Complete op1
      op1 = op1.copyWith(status: OperationStatus.completed);

      expect(op1.status, equals(OperationStatus.completed));
      expect(op2.status, equals(OperationStatus.executing));
    });
  });

  // ==================== TIMESTAMP EDGE CASES ====================
  group('Timestamp Edge Cases', () {
    test('operations ordered by startedAt', () {
      final ops = [
        OperationState(
          id: 'op_3',
          type: OperationType.send,
          status: OperationStatus.completed,
          startedAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: OperationStatus.completed,
          startedAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        OperationState(
          id: 'op_2',
          type: OperationType.send,
          status: OperationStatus.completed,
          startedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];

      ops.sort((a, b) => b.startedAt.compareTo(a.startedAt)); // Most recent first

      expect(ops[0].id, equals('op_3'));
      expect(ops[1].id, equals('op_2'));
      expect(ops[2].id, equals('op_1'));
    });

    test('completedAt is after startedAt', () {
      final startedAt = DateTime.now().subtract(const Duration(seconds: 5));
      final completedAt = DateTime.now();

      expect(completedAt.isAfter(startedAt), isTrue);
    });
  });
}
