import 'package:flutter_test/flutter_test.dart';
import 'package:bolt21/services/operation_state_service.dart';

/// Tests for WalletProvider-related functionality
/// Note: WalletProvider uses internal service instances, so we test the
/// OperationState class and related logic directly
void main() {
  // ==================== OPERATION STATE TESTS ====================
  group('OperationState', () {
    group('serialization', () {
      test('toJson includes all fields', () {
        final op = OperationState(
          id: 'op_123',
          type: OperationType.send,
          status: OperationStatus.pending,
          startedAt: DateTime(2024, 1, 15, 10, 30),
          destination: 'lnbc1...',
          amountSat: 5000,
        );

        final json = op.toJson();

        expect(json['id'], equals('op_123'));
        expect(json['type'], equals('send'));
        expect(json['status'], equals('pending'));
        expect(json['destination'], equals('lnbc1...'));
        expect(json['amountSat'], equals(5000));
      });

      test('fromJson reconstructs operation', () {
        final json = {
          'id': 'op_456',
          'type': 'receiveBolt12',
          'status': 'completed',
          'startedAt': '2024-01-15T10:30:00.000',
          'amountSat': 2000,
        };

        final op = OperationState.fromJson(json);

        expect(op.id, equals('op_456'));
        expect(op.type, equals(OperationType.receiveBolt12));
        expect(op.status, equals(OperationStatus.completed));
        expect(op.amountSat, equals(2000));
      });

      test('round-trip serialization preserves data', () {
        final original = OperationState(
          id: 'op_789',
          type: OperationType.receiveOnchain,
          status: OperationStatus.executing,
          startedAt: DateTime(2024, 1, 15, 10, 30),
          destination: 'bc1q...',
          amountSat: 100000,
          error: 'timeout',
          txId: 'tx_abc123',
        );

        final json = original.toJson();
        final restored = OperationState.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.type, equals(original.type));
        expect(restored.status, equals(original.status));
        expect(restored.destination, equals(original.destination));
        expect(restored.amountSat, equals(original.amountSat));
        expect(restored.error, equals(original.error));
        expect(restored.txId, equals(original.txId));
      });

      test('handles null optional fields', () {
        final op = OperationState(
          id: 'op_null',
          type: OperationType.send,
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

    group('status helpers', () {
      test('isComplete returns true for completed', () {
        final op = OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: OperationStatus.completed,
          startedAt: DateTime.now(),
        );
        expect(op.isComplete, isTrue);
      });

      test('isComplete returns false for pending', () {
        final op = OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: OperationStatus.pending,
          startedAt: DateTime.now(),
        );
        expect(op.isComplete, isFalse);
      });

      test('isFailed returns true for failed', () {
        final op = OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: OperationStatus.failed,
          startedAt: DateTime.now(),
        );
        expect(op.isFailed, isTrue);
      });

      test('isFailed returns false for completed', () {
        final op = OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: OperationStatus.completed,
          startedAt: DateTime.now(),
        );
        expect(op.isFailed, isFalse);
      });

      test('isIncomplete returns true for pending', () {
        final op = OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: OperationStatus.pending,
          startedAt: DateTime.now(),
        );
        expect(op.isIncomplete, isTrue);
      });

      test('isIncomplete returns true for preparing', () {
        final op = OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: OperationStatus.preparing,
          startedAt: DateTime.now(),
        );
        expect(op.isIncomplete, isTrue);
      });

      test('isIncomplete returns true for executing', () {
        final op = OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: OperationStatus.executing,
          startedAt: DateTime.now(),
        );
        expect(op.isIncomplete, isTrue);
      });

      test('isIncomplete returns true for unknown', () {
        final op = OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: OperationStatus.unknown,
          startedAt: DateTime.now(),
        );
        expect(op.isIncomplete, isTrue);
      });

      test('isIncomplete returns false for completed', () {
        final op = OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: OperationStatus.completed,
          startedAt: DateTime.now(),
        );
        expect(op.isIncomplete, isFalse);
      });

      test('isIncomplete returns false for failed', () {
        final op = OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: OperationStatus.failed,
          startedAt: DateTime.now(),
        );
        expect(op.isIncomplete, isFalse);
      });
    });

    group('type helpers', () {
      test('isSend returns true for send type', () {
        final op = OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: OperationStatus.pending,
          startedAt: DateTime.now(),
        );
        expect(op.isSend, isTrue);
      });

      test('isSend returns false for receive types', () {
        final op = OperationState(
          id: 'op_1',
          type: OperationType.receiveBolt12,
          status: OperationStatus.pending,
          startedAt: DateTime.now(),
        );
        expect(op.isSend, isFalse);
      });

      test('isReceive returns true for receiveBolt12', () {
        final op = OperationState(
          id: 'op_1',
          type: OperationType.receiveBolt12,
          status: OperationStatus.pending,
          startedAt: DateTime.now(),
        );
        expect(op.isReceive, isTrue);
      });

      test('isReceive returns true for receiveOnchain', () {
        final op = OperationState(
          id: 'op_1',
          type: OperationType.receiveOnchain,
          status: OperationStatus.pending,
          startedAt: DateTime.now(),
        );
        expect(op.isReceive, isTrue);
      });

      test('isReceive returns true for receiveBolt11', () {
        final op = OperationState(
          id: 'op_1',
          type: OperationType.receiveBolt11,
          status: OperationStatus.pending,
          startedAt: DateTime.now(),
        );
        expect(op.isReceive, isTrue);
      });

      test('isReceive returns false for send', () {
        final op = OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: OperationStatus.pending,
          startedAt: DateTime.now(),
        );
        expect(op.isReceive, isFalse);
      });
    });

    group('copyWith', () {
      test('updates status', () {
        final original = OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: OperationStatus.pending,
          startedAt: DateTime.now(),
        );

        final updated = original.copyWith(status: OperationStatus.completed);

        expect(updated.status, equals(OperationStatus.completed));
        expect(updated.id, equals(original.id));
        expect(updated.type, equals(original.type));
      });

      test('updates error', () {
        final original = OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: OperationStatus.pending,
          startedAt: DateTime.now(),
        );

        final updated = original.copyWith(
          status: OperationStatus.failed,
          error: 'Network error',
        );

        expect(updated.error, equals('Network error'));
        expect(updated.status, equals(OperationStatus.failed));
      });

      test('updates txId', () {
        final original = OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: OperationStatus.executing,
          startedAt: DateTime.now(),
        );

        final updated = original.copyWith(
          status: OperationStatus.completed,
          txId: 'tx_final_123',
        );

        expect(updated.txId, equals('tx_final_123'));
      });

      test('updates completedAt', () {
        final original = OperationState(
          id: 'op_1',
          type: OperationType.send,
          status: OperationStatus.pending,
          startedAt: DateTime.now(),
        );

        final completedTime = DateTime.now();
        final updated = original.copyWith(
          status: OperationStatus.completed,
          completedAt: completedTime,
        );

        expect(updated.completedAt, equals(completedTime));
      });

      test('preserves unchanged fields', () {
        final startTime = DateTime.now();
        final original = OperationState(
          id: 'op_preserve',
          type: OperationType.receiveBolt12,
          status: OperationStatus.pending,
          startedAt: startTime,
          destination: 'lno1...',
          amountSat: 5000,
        );

        final updated = original.copyWith(status: OperationStatus.executing);

        expect(updated.id, equals('op_preserve'));
        expect(updated.type, equals(OperationType.receiveBolt12));
        expect(updated.startedAt, equals(startTime));
        expect(updated.destination, equals('lno1...'));
        expect(updated.amountSat, equals(5000));
      });
    });

    group('toString', () {
      test('includes key information', () {
        final op = OperationState(
          id: 'op_str',
          type: OperationType.send,
          status: OperationStatus.executing,
          startedAt: DateTime.now(),
        );

        final str = op.toString();
        expect(str, contains('op_str'));
        expect(str, contains('send'));
        expect(str, contains('executing'));
      });
    });
  });

  // ==================== OPERATION TYPE TESTS ====================
  group('OperationType', () {
    test('has send type', () {
      expect(OperationType.values, contains(OperationType.send));
    });

    test('has receiveBolt12 type', () {
      expect(OperationType.values, contains(OperationType.receiveBolt12));
    });

    test('has receiveOnchain type', () {
      expect(OperationType.values, contains(OperationType.receiveOnchain));
    });

    test('has receiveBolt11 type', () {
      expect(OperationType.values, contains(OperationType.receiveBolt11));
    });

    test('has exactly 4 types', () {
      expect(OperationType.values.length, equals(4));
    });
  });

  // ==================== OPERATION STATUS TESTS ====================
  group('OperationStatus', () {
    test('has pending status', () {
      expect(OperationStatus.values, contains(OperationStatus.pending));
    });

    test('has preparing status', () {
      expect(OperationStatus.values, contains(OperationStatus.preparing));
    });

    test('has executing status', () {
      expect(OperationStatus.values, contains(OperationStatus.executing));
    });

    test('has completed status', () {
      expect(OperationStatus.values, contains(OperationStatus.completed));
    });

    test('has failed status', () {
      expect(OperationStatus.values, contains(OperationStatus.failed));
    });

    test('has unknown status', () {
      expect(OperationStatus.values, contains(OperationStatus.unknown));
    });

    test('has exactly 6 statuses', () {
      expect(OperationStatus.values.length, equals(6));
    });
  });

  // ==================== STATE MACHINE TESTS ====================
  group('State Machine', () {
    test('valid transition: pending -> preparing', () {
      final op = OperationState(
        id: 'op_sm',
        type: OperationType.send,
        status: OperationStatus.pending,
        startedAt: DateTime.now(),
      );
      final next = op.copyWith(status: OperationStatus.preparing);
      expect(next.status, equals(OperationStatus.preparing));
    });

    test('valid transition: preparing -> executing', () {
      final op = OperationState(
        id: 'op_sm',
        type: OperationType.send,
        status: OperationStatus.preparing,
        startedAt: DateTime.now(),
      );
      final next = op.copyWith(status: OperationStatus.executing);
      expect(next.status, equals(OperationStatus.executing));
    });

    test('valid transition: executing -> completed', () {
      final op = OperationState(
        id: 'op_sm',
        type: OperationType.send,
        status: OperationStatus.executing,
        startedAt: DateTime.now(),
      );
      final next = op.copyWith(status: OperationStatus.completed);
      expect(next.status, equals(OperationStatus.completed));
    });

    test('valid transition: executing -> failed', () {
      final op = OperationState(
        id: 'op_sm',
        type: OperationType.send,
        status: OperationStatus.executing,
        startedAt: DateTime.now(),
      );
      final next = op.copyWith(status: OperationStatus.failed);
      expect(next.status, equals(OperationStatus.failed));
    });

    test('valid transition: any -> unknown (crash recovery)', () {
      for (final status in OperationStatus.values) {
        final op = OperationState(
          id: 'op_sm',
          type: OperationType.send,
          status: status,
          startedAt: DateTime.now(),
        );
        final next = op.copyWith(status: OperationStatus.unknown);
        expect(next.status, equals(OperationStatus.unknown));
      }
    });
  });
}
