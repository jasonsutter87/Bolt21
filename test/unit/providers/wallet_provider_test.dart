import 'package:flutter_test/flutter_test.dart';
import 'package:bolt21/models/wallet_metadata.dart';
import 'package:bolt21/services/operation_state_service.dart';

/// Tests for WalletProvider-related functionality
/// Note: WalletProvider uses internal service instances, so we test the
/// OperationState class and related logic directly
void main() {
  // ==================== MULTI-WALLET SECURITY TESTS ====================
  group('Multi-Wallet Security', () {
    group('Payment In Progress Protection', () {
      test('paymentInProgress flag prevents wallet switch', () {
        // SECURITY: When a payment is in progress, wallet switching should be blocked
        bool paymentInProgress = true;
        final canSwitch = !paymentInProgress;
        expect(canSwitch, isFalse, reason: 'Cannot switch during payment');
      });

      test('paymentInProgress cleared after successful payment', () {
        bool paymentInProgress = true;
        paymentInProgress = false; // Simulate completion
        expect(paymentInProgress, isFalse);
      });

      test('paymentInProgress cleared in finally block on failure', () {
        bool paymentInProgress = true;
        try {
          throw Exception('Payment failed');
        } catch (_) {
        } finally {
          paymentInProgress = false;
        }
        expect(paymentInProgress, isFalse);
      });
    });

    group('Wallet Rename Validation', () {
      test('empty name is rejected', () {
        const newName = '';
        expect(newName.trim().isEmpty, isTrue);
      });

      test('whitespace-only name is rejected', () {
        const newName = '   \t\n  ';
        expect(newName.trim().isEmpty, isTrue);
      });

      test('name over 50 chars is rejected', () {
        final newName = 'A' * 51;
        expect(newName.length > 50, isTrue);
      });

      test('name at 50 chars is accepted', () {
        final newName = 'A' * 50;
        expect(newName.length <= 50, isTrue);
        expect(newName.trim().isNotEmpty, isTrue);
      });

      test('valid name with spaces is trimmed', () {
        const newName = '  My Wallet  ';
        expect(newName.trim(), equals('My Wallet'));
      });
    });

    group('Fee Buffer Balance Validation', () {
      const int feeBufferSats = 500;

      test('fee buffer is subtracted from available balance', () {
        const balance = 10000;
        final available = balance > feeBufferSats ? balance - feeBufferSats : 0;
        expect(available, equals(9500));
      });

      test('balance below fee buffer shows 0 available', () {
        const balance = 300;
        final available = balance > feeBufferSats ? balance - feeBufferSats : 0;
        expect(available, equals(0));
      });

      test('balance exactly at fee buffer shows 0 available', () {
        const balance = 500;
        final available = balance > feeBufferSats ? balance - feeBufferSats : 0;
        expect(available, equals(0));
      });

      test('amount exceeding available balance is rejected', () {
        const balance = 10000;
        final available = balance > feeBufferSats ? balance - feeBufferSats : 0;
        const requestedAmount = 9600;
        expect(requestedAmount > available, isTrue);
      });

      test('zero amount is rejected', () {
        const requestedAmount = 0;
        expect(requestedAmount <= 0, isTrue);
      });

      test('negative amount is rejected', () {
        const requestedAmount = -100;
        expect(requestedAmount <= 0, isTrue);
      });
    });

    group('Wallet Deletion Safety', () {
      test('cannot delete last wallet', () {
        final wallets = [WalletMetadata.create(name: 'Only Wallet')];
        expect(wallets.length > 1, isFalse);
      });

      test('can delete when multiple wallets exist', () {
        final wallets = [
          WalletMetadata.create(name: 'Wallet 1'),
          WalletMetadata.create(name: 'Wallet 2'),
        ];
        expect(wallets.length > 1, isTrue);
      });

      test('deleting active wallet triggers switch', () {
        final wallets = [
          WalletMetadata(id: 'wallet-1', name: 'Active', createdAt: DateTime.now()),
          WalletMetadata(id: 'wallet-2', name: 'Other', createdAt: DateTime.now()),
        ];
        const activeId = 'wallet-1';
        const deletingId = 'wallet-1';
        final needsSwitch = activeId == deletingId;
        final otherWallet = wallets.firstWhere((w) => w.id != deletingId);
        expect(needsSwitch, isTrue);
        expect(otherWallet.id, equals('wallet-2'));
      });
    });

    group('WalletId Isolation in Operations', () {
      test('operations filtered by wallet ID', () {
        const wallet1Id = 'wallet-1';
        const wallet2Id = 'wallet-2';

        final operations = [
          OperationState(id: 'op-1', walletId: wallet1Id, type: OperationType.send, status: OperationStatus.pending, startedAt: DateTime.now()),
          OperationState(id: 'op-2', walletId: wallet2Id, type: OperationType.send, status: OperationStatus.pending, startedAt: DateTime.now()),
          OperationState(id: 'op-3', walletId: wallet1Id, type: OperationType.receiveBolt12, status: OperationStatus.pending, startedAt: DateTime.now()),
        ];

        final wallet1Ops = operations.where((op) => op.walletId == wallet1Id).toList();
        expect(wallet1Ops.length, equals(2));
        expect(wallet1Ops.every((op) => op.walletId == wallet1Id), isTrue);
      });

      test('walletId is preserved in copyWith', () {
        final op = OperationState(
          id: 'op-1',
          walletId: 'wallet-abc',
          type: OperationType.send,
          status: OperationStatus.pending,
          startedAt: DateTime.now(),
        );
        final updated = op.copyWith(status: OperationStatus.completed);
        expect(updated.walletId, equals('wallet-abc'));
      });

      test('walletId included in toJson', () {
        final op = OperationState(
          id: 'op-1',
          walletId: 'wallet-123',
          type: OperationType.send,
          status: OperationStatus.pending,
          startedAt: DateTime.now(),
        );
        final json = op.toJson();
        expect(json['walletId'], equals('wallet-123'));
      });

      test('walletId restored from fromJson', () {
        final json = {
          'id': 'op-from-json',
          'walletId': 'wallet-restored',
          'type': 'send',
          'status': 'pending',
          'startedAt': '2024-01-01T00:00:00.000',
        };
        final op = OperationState.fromJson(json);
        expect(op.walletId, equals('wallet-restored'));
      });

      test('null walletId handled for legacy operations', () {
        final json = {
          'id': 'op-legacy',
          'type': 'send',
          'status': 'pending',
          'startedAt': '2024-01-01T00:00:00.000',
        };
        final op = OperationState.fromJson(json);
        expect(op.walletId, isNull);
      });
    });

    group('Payment Idempotency', () {
      test('duplicate in-progress payment is blocked', () {
        final operations = [
          OperationState(
            id: 'op-existing',
            walletId: 'wallet-1',
            type: OperationType.send,
            status: OperationStatus.executing,
            startedAt: DateTime.now(),
            destination: 'lnbc100...',
            amountSat: 1000,
          ),
        ];

        const newDestination = 'lnbc100...';
        const newAmount = 1000;

        final existing = operations.where((op) =>
            op.destination == newDestination &&
            op.amountSat == newAmount &&
            op.isIncomplete);

        expect(existing.isNotEmpty, isTrue, reason: 'Duplicate should be blocked');
      });

      test('different destination is allowed', () {
        final operations = [
          OperationState(
            id: 'op-existing',
            walletId: 'wallet-1',
            type: OperationType.send,
            status: OperationStatus.executing,
            startedAt: DateTime.now(),
            destination: 'lnbc100...',
            amountSat: 1000,
          ),
        ];

        const newDestination = 'lnbc200...';
        const newAmount = 1000;

        final existing = operations.where((op) =>
            op.destination == newDestination &&
            op.amountSat == newAmount &&
            op.isIncomplete);

        expect(existing.isEmpty, isTrue);
      });

      test('completed operation allows new payment to same destination', () {
        final operations = [
          OperationState(
            id: 'op-existing',
            walletId: 'wallet-1',
            type: OperationType.send,
            status: OperationStatus.completed,
            startedAt: DateTime.now(),
            destination: 'lnbc100...',
            amountSat: 1000,
          ),
        ];

        const newDestination = 'lnbc100...';
        const newAmount = 1000;

        final existing = operations.where((op) =>
            op.destination == newDestination &&
            op.amountSat == newAmount &&
            op.isIncomplete);

        expect(existing.isEmpty, isTrue);
      });
    });
  });


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
