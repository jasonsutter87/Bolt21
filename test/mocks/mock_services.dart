import 'package:mocktail/mocktail.dart';
import 'package:bolt21/services/lightning_service.dart';
import 'package:bolt21/services/operation_state_service.dart';

// Mock LightningService
class MockLightningService extends Mock implements LightningService {}

// Mock OperationStateService
class MockOperationStateService extends Mock implements OperationStateService {}

// Test data factories for OperationState (SDK-independent)
class TestDataFactory {
  static OperationState createOperationState({
    String? id,
    OperationType? type,
    String? destination,
    int? amountSat,
    OperationStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    String? error,
    String? txId,
  }) {
    return OperationState(
      id: id ?? 'op_${DateTime.now().millisecondsSinceEpoch}',
      type: type ?? OperationType.send,
      destination: destination,
      amountSat: amountSat,
      status: status ?? OperationStatus.pending,
      startedAt: startedAt ?? DateTime.now(),
      completedAt: completedAt,
      error: error,
      txId: txId,
    );
  }

  static List<OperationState> createOperationList(int count, {
    OperationType? type,
    OperationStatus? status,
  }) {
    return List.generate(count, (i) => createOperationState(
      id: 'op_$i',
      type: type ?? OperationType.send,
      status: status ?? OperationStatus.pending,
      amountSat: 1000 * (i + 1),
    ));
  }
}

// Helper to set up common mocks
void setUpMockLightningService(MockLightningService mock, {
  bool isInitialized = true,
  String? bolt12Offer,
  String? onChainAddress,
}) {
  when(() => mock.isInitialized).thenReturn(isInitialized);
  when(() => mock.currentWalletId).thenReturn('test-wallet-id');

  when(() => mock.initialize(
    walletId: any(named: 'walletId'),
    mnemonic: any(named: 'mnemonic'),
  )).thenAnswer((_) async {});

  when(() => mock.generateBolt12Offer())
      .thenAnswer((_) async => bolt12Offer ?? 'lno1test...');

  when(() => mock.getOnChainAddress())
      .thenAnswer((_) async => onChainAddress ?? 'bc1qtest...');

  when(() => mock.generateMnemonic())
      .thenReturn('abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about');

  when(() => mock.disconnect()).thenAnswer((_) async {});
}

void setUpMockOperationStateService(MockOperationStateService mock, {
  List<OperationState>? operations,
  List<OperationState>? incompleteOperations,
}) {
  when(() => mock.initialize()).thenAnswer((_) async {});

  when(() => mock.getAllOperations())
      .thenReturn(operations ?? []);

  when(() => mock.getIncompleteOperations())
      .thenReturn(incompleteOperations ?? []);

  when(() => mock.getIncompleteSends())
      .thenReturn((incompleteOperations ?? [])
          .where((op) => op.isSend && op.isIncomplete)
          .toList());

  when(() => mock.createOperation(
    type: any(named: 'type'),
    destination: any(named: 'destination'),
    amountSat: any(named: 'amountSat'),
    metadata: any(named: 'metadata'),
  )).thenAnswer((invocation) async {
    return TestDataFactory.createOperationState(
      type: invocation.namedArguments[#type] as OperationType?,
      destination: invocation.namedArguments[#destination] as String?,
      amountSat: invocation.namedArguments[#amountSat] as int?,
    );
  });

  when(() => mock.markPreparing(any())).thenAnswer((_) async {});
  when(() => mock.markExecuting(any())).thenAnswer((_) async {});
  when(() => mock.markCompleted(any(), txId: any(named: 'txId'))).thenAnswer((_) async {});
  when(() => mock.markFailed(any(), any())).thenAnswer((_) async {});
  when(() => mock.markUnknown(any())).thenAnswer((_) async {});
  when(() => mock.removeOperation(any())).thenAnswer((_) async {});
  when(() => mock.clearAll()).thenAnswer((_) async {});
}

// Register all fallback values
void registerAllFallbackValues() {
  registerFallbackValue(OperationType.send);
  registerFallbackValue(OperationStatus.pending);
}
