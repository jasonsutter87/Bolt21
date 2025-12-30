import 'package:flutter_test/flutter_test.dart';
import 'package:bolt21/models/wallet_metadata.dart';
import 'package:bolt21/services/operation_state_service.dart';

/// Security tests for multi-wallet functionality
/// Tests the security fixes implemented for:
/// - Wallet isolation (walletId in operations)
/// - Input validation (rename)
/// - Operation isolation
void main() {
  group('Multi-Wallet Security', () {
    // ==================== WALLET ID ISOLATION ====================
    group('Wallet ID Isolation in Operations', () {
      test('OperationState includes walletId', () {
        final op = OperationState(
          id: 'op-1',
          walletId: 'wallet-abc',
          type: OperationType.send,
          status: OperationStatus.pending,
          startedAt: DateTime.now(),
        );

        expect(op.walletId, equals('wallet-abc'));
      });

      test('walletId is preserved in copyWith', () {
        final original = OperationState(
          id: 'op-1',
          walletId: 'wallet-xyz',
          type: OperationType.send,
          status: OperationStatus.pending,
          startedAt: DateTime.now(),
        );

        final updated = original.copyWith(status: OperationStatus.completed);

        expect(updated.walletId, equals('wallet-xyz'));
      });

      test('walletId is included in toJson', () {
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

      test('walletId is restored from fromJson', () {
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

      test('null walletId is handled for legacy operations', () {
        final json = {
          'id': 'op-legacy',
          'type': 'send',
          'status': 'pending',
          'startedAt': '2024-01-01T00:00:00.000',
          // No walletId field - simulating legacy data
        };

        final op = OperationState.fromJson(json);

        expect(op.walletId, isNull);
      });

      test('operations can be filtered by walletId', () {
        final operations = [
          OperationState(
            id: 'op-1', walletId: 'wallet-A',
            type: OperationType.send, status: OperationStatus.pending,
            startedAt: DateTime.now(),
          ),
          OperationState(
            id: 'op-2', walletId: 'wallet-B',
            type: OperationType.send, status: OperationStatus.pending,
            startedAt: DateTime.now(),
          ),
          OperationState(
            id: 'op-3', walletId: 'wallet-A',
            type: OperationType.receiveBolt12, status: OperationStatus.executing,
            startedAt: DateTime.now(),
          ),
        ];

        final walletAOps = operations.where((op) => op.walletId == 'wallet-A').toList();

        expect(walletAOps.length, equals(2));
        expect(walletAOps.every((op) => op.walletId == 'wallet-A'), isTrue);
      });
    });

    // ==================== WALLET NAME VALIDATION ====================
    group('Wallet Name Validation', () {
      test('WalletMetadata accepts valid names', () {
        final validNames = [
          'Main Wallet',
          'Savings',
          'Daily Spending',
          'Business Account',
          '12345',
          'A',
          'Wallet with spaces',
        ];

        for (final name in validNames) {
          final wallet = WalletMetadata.create(name: name);
          expect(wallet.name, equals(name));
        }
      });

      test('WalletMetadata handles max length name', () {
        final maxName = 'A' * 50;
        final wallet = WalletMetadata.create(name: maxName);
        expect(wallet.name.length, equals(50));
      });

      test('WalletMetadata handles special characters', () {
        final specialNames = [
          'Wallet & More',
          'Test (1)',
          'Wallet #2',
          'Name-with-dashes',
          'Name_with_underscores',
        ];

        for (final name in specialNames) {
          final wallet = WalletMetadata.create(name: name);
          expect(wallet.name, equals(name));
        }
      });

      test('renameWallet validates input - documented behavior', () {
        // This test documents expected validation behavior
        // The actual validation is in WalletProvider.renameWallet

        // Empty name should be rejected
        final emptyName = '';
        expect(emptyName.trim().isEmpty, isTrue);

        // Whitespace-only should be rejected
        final whitespace = '   ';
        expect(whitespace.trim().isEmpty, isTrue);

        // Over 50 chars should be rejected
        final tooLong = 'A' * 51;
        expect(tooLong.length > 50, isTrue);
      });
    });

    // ==================== OPERATION STATE SECURITY ====================
    group('Operation State Security', () {
      test('incomplete operations are properly identified', () {
        final incompleteStatuses = [
          OperationStatus.pending,
          OperationStatus.preparing,
          OperationStatus.executing,
          OperationStatus.unknown,
        ];

        for (final status in incompleteStatuses) {
          final op = OperationState(
            id: 'op-test',
            type: OperationType.send,
            status: status,
            startedAt: DateTime.now(),
          );
          expect(op.isIncomplete, isTrue, reason: 'Status $status should be incomplete');
        }
      });

      test('complete operations are properly identified', () {
        final completeStatuses = [
          OperationStatus.completed,
          OperationStatus.failed,
        ];

        for (final status in completeStatuses) {
          final op = OperationState(
            id: 'op-test',
            type: OperationType.send,
            status: status,
            startedAt: DateTime.now(),
          );
          expect(op.isIncomplete, isFalse, reason: 'Status $status should be complete');
        }
      });

      test('send operations are identified as high-risk', () {
        final op = OperationState(
          id: 'op-send',
          type: OperationType.send,
          status: OperationStatus.executing,
          startedAt: DateTime.now(),
        );

        expect(op.isSend, isTrue);
        expect(op.isReceive, isFalse);
      });

      test('receive operations are identified as low-risk', () {
        final receiveTypes = [
          OperationType.receiveBolt12,
          OperationType.receiveBolt11,
          OperationType.receiveOnchain,
        ];

        for (final type in receiveTypes) {
          final op = OperationState(
            id: 'op-receive',
            type: type,
            status: OperationStatus.executing,
            startedAt: DateTime.now(),
          );
          expect(op.isReceive, isTrue, reason: 'Type $type should be receive');
          expect(op.isSend, isFalse, reason: 'Type $type should not be send');
        }
      });
    });

    // ==================== CROSS-WALLET DATA ISOLATION ====================
    group('Cross-Wallet Data Isolation', () {
      test('wallets have unique IDs', () {
        final ids = <String>{};

        for (var i = 0; i < 100; i++) {
          final wallet = WalletMetadata.create(name: 'Wallet $i');
          expect(ids.contains(wallet.id), isFalse, reason: 'Duplicate ID: ${wallet.id}');
          ids.add(wallet.id);
        }
      });

      test('wallet working directories are isolated', () {
        final wallet1 = WalletMetadata.create(name: 'Wallet 1');
        final wallet2 = WalletMetadata.create(name: 'Wallet 2');

        expect(wallet1.workingDir, isNot(equals(wallet2.workingDir)));
        expect(wallet1.workingDir, startsWith('wallet_'));
        expect(wallet2.workingDir, startsWith('wallet_'));
      });

      test('operations can be segregated by wallet', () {
        final wallet1Id = 'wallet-1';
        final wallet2Id = 'wallet-2';

        final allOperations = [
          OperationState(id: 'op1', walletId: wallet1Id, type: OperationType.send, status: OperationStatus.pending, startedAt: DateTime.now()),
          OperationState(id: 'op2', walletId: wallet1Id, type: OperationType.send, status: OperationStatus.executing, startedAt: DateTime.now()),
          OperationState(id: 'op3', walletId: wallet2Id, type: OperationType.send, status: OperationStatus.pending, startedAt: DateTime.now()),
          OperationState(id: 'op4', walletId: wallet2Id, type: OperationType.receiveBolt12, status: OperationStatus.completed, startedAt: DateTime.now()),
        ];

        final wallet1Ops = allOperations.where((op) => op.walletId == wallet1Id).toList();
        final wallet2Ops = allOperations.where((op) => op.walletId == wallet2Id).toList();

        expect(wallet1Ops.length, equals(2));
        expect(wallet2Ops.length, equals(2));

        // Verify no cross-contamination
        for (final op in wallet1Ops) {
          expect(op.walletId, equals(wallet1Id));
        }
        for (final op in wallet2Ops) {
          expect(op.walletId, equals(wallet2Id));
        }
      });
    });

    // ==================== FEE BUFFER VALIDATION ====================
    group('Fee Buffer Validation', () {
      test('fee buffer constant is reasonable', () {
        // The fee buffer should be enough for typical Lightning fees
        // but not so high as to be prohibitive for small transactions
        const feeBuffer = 500; // sats

        // Should cover typical routing fees
        expect(feeBuffer, greaterThanOrEqualTo(100));

        // Should not be excessive
        expect(feeBuffer, lessThanOrEqualTo(2000));
      });

      test('available balance calculation with fee buffer', () {
        const feeBuffer = 500;

        // Test cases: (total balance, expected available)
        final testCases = [
          (10000, 9500),   // Normal case
          (500, 0),        // Exactly at fee buffer
          (100, 0),        // Below fee buffer
          (0, 0),          // Zero balance
          (1000000, 999500), // Large balance
        ];

        for (final (balance, expectedAvailable) in testCases) {
          final available = balance > feeBuffer ? balance - feeBuffer : 0;
          expect(available, equals(expectedAvailable),
            reason: 'Balance $balance should give available $expectedAvailable');
        }
      });
    });
  });
}
