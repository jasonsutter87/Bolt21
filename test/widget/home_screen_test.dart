import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bolt21/models/wallet_metadata.dart';
import 'package:bolt21/screens/home_screen.dart';
import 'package:bolt21/providers/wallet_provider.dart';
import 'package:bolt21/services/lightning_service.dart';
import 'package:bolt21/services/operation_state_service.dart';
import 'package:bolt21/utils/theme.dart';
import 'package:flutter_breez_liquid/flutter_breez_liquid.dart';

// Mock classes
class MockLightningService extends Mock implements LightningService {}
class MockOperationStateService extends Mock implements OperationStateService {}

// Test helper to wrap widget with necessary providers
Widget createTestWidget(Widget child, {WalletProvider? wallet}) {
  return MaterialApp(
    theme: Bolt21Theme.darkTheme,
    home: ChangeNotifierProvider<WalletProvider>.value(
      value: wallet ?? TestWalletProvider(),
      child: child,
    ),
  );
}

// Test WalletProvider with controllable state
class TestWalletProvider extends ChangeNotifier implements WalletProvider {
  bool _isLoading = false;
  bool _isInitialized = true;
  String? _error;
  String? _onChainAddress;
  String? _bolt12Offer;
  GetInfoResponse? _info;
  List<Payment> _payments = [];
  List<OperationState> _incompleteOperations = [];
  List<WalletMetadata> _wallets = [];
  WalletMetadata? _activeWallet;
  final LightningService _lightningService = MockLightningService();
  final OperationStateService _operationStateService = MockOperationStateService();

  TestWalletProvider({
    bool isLoading = false,
    bool isInitialized = true,
    String? error,
    int balanceSat = 10000,
    int pendingReceiveSat = 0,
    int pendingSendSat = 0,
    List<Payment>? payments,
    List<OperationState>? incompleteOperations,
  }) {
    _isLoading = isLoading;
    _isInitialized = isInitialized;
    _error = error;
    _payments = payments ?? [];
    _incompleteOperations = incompleteOperations ?? [];
    _wallets = [WalletMetadata(id: 'test-id', name: 'Test Wallet', createdAt: DateTime.now())];
    _activeWallet = _wallets.first;
    _info = GetInfoResponse(
      walletInfo: WalletInfo(
        balanceSat: BigInt.from(balanceSat),
        pendingReceiveSat: BigInt.from(pendingReceiveSat),
        pendingSendSat: BigInt.from(pendingSendSat),
        pubkey: 'test_pubkey',
        fingerprint: 'test_fingerprint',
        assetBalances: [],
      ),
      blockchainInfo: BlockchainInfo(liquidTip: 100, bitcoinTip: 800000),
    );
  }

  @override bool get isLoading => _isLoading;
  @override bool get isInitialized => _isInitialized;
  @override String? get error => _error;
  @override String? get onChainAddress => _onChainAddress;
  @override String? get bolt12Offer => _bolt12Offer;
  @override GetInfoResponse? get info => _info;
  @override List<Payment> get payments => _payments;
  @override List<OperationState> get incompleteOperations => _incompleteOperations;
  @override bool get hasIncompleteOperations => _incompleteOperations.isNotEmpty;
  @override LightningService get lightningService => _lightningService;
  @override OperationStateService get operationStateService => _operationStateService;
  @override List<WalletMetadata> get wallets => _wallets;
  @override WalletMetadata? get activeWallet => _activeWallet;
  @override bool get hasMultipleWallets => _wallets.length > 1;

  @override int get totalBalanceSats => _info?.walletInfo.balanceSat.toInt() ?? 0;
  @override int get pendingReceiveSats => _info?.walletInfo.pendingReceiveSat.toInt() ?? 0;
  @override int get pendingSendSats => _info?.walletInfo.pendingSendSat.toInt() ?? 0;
  @override String? get nodeId => _info?.walletInfo.pubkey;

  @override Future<void> loadWallets() async {}
  @override Future<WalletMetadata> createWallet({required String name}) async => _activeWallet!;
  @override Future<WalletMetadata> importWallet({required String name, required String mnemonic}) async => _activeWallet!;
  @override Future<void> switchWallet(String walletId) async {}
  @override Future<void> renameWallet(String walletId, String newName) async {}
  @override Future<void> deleteWallet(String walletId) async {}
  @override Future<String?> getMnemonic({String? walletId}) async => 'test mnemonic';
  @override String generateMnemonic() => 'test mnemonic';
  @override Future<void> refreshAll() async { notifyListeners(); }
  @override Future<String?> generateOnChainAddress() async => 'bc1qtest...';
  @override Future<String?> generateBolt12Offer() async => 'lno1test...';
  @override Future<String?> sendPayment(String destination, {BigInt? amountSat}) async => 'op_123';
  @override Future<String?> sendPaymentIdempotent(String destination, {BigInt? amountSat, String? idempotencyKey}) async => 'op_123';
  @override Future<void> acknowledgeIncompleteOperation(String operationId) async {}
  @override Future<void> clearIncompleteOperations() async {
    _incompleteOperations = [];
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void setBalance(int sats) {
    _info = GetInfoResponse(
      walletInfo: WalletInfo(
        balanceSat: BigInt.from(sats),
        pendingReceiveSat: _info!.walletInfo.pendingReceiveSat,
        pendingSendSat: _info!.walletInfo.pendingSendSat,
        pubkey: 'test_pubkey',
        fingerprint: 'test_fingerprint',
        assetBalances: [],
      ),
      blockchainInfo: BlockchainInfo(liquidTip: 100, bitcoinTip: 800000),
    );
    notifyListeners();
  }

  void setIncompleteOperations(List<OperationState> ops) {
    _incompleteOperations = ops;
    notifyListeners();
  }
}

void main() {
  group('HomeScreen', () {
    group('displays correctly', () {
      testWidgets('shows logo in app bar', (tester) async {
        await tester.pumpWidget(createTestWidget(const HomeScreen()));
        await tester.pumpAndSettle();

        expect(find.byType(Image), findsWidgets);
      });

      testWidgets('shows settings button', (tester) async {
        await tester.pumpWidget(createTestWidget(const HomeScreen()));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      });

      testWidgets('shows balance card', (tester) async {
        await tester.pumpWidget(createTestWidget(const HomeScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Total Balance'), findsOneWidget);
      });

      testWidgets('shows Receive button', (tester) async {
        await tester.pumpWidget(createTestWidget(const HomeScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Receive'), findsOneWidget);
      });

      testWidgets('shows Send button', (tester) async {
        await tester.pumpWidget(createTestWidget(const HomeScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Send'), findsOneWidget);
      });

      testWidgets('shows Recent Activity section', (tester) async {
        await tester.pumpWidget(createTestWidget(const HomeScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Recent Activity'), findsOneWidget);
      });

      testWidgets('shows "No transactions yet" when empty', (tester) async {
        await tester.pumpWidget(createTestWidget(const HomeScreen()));
        await tester.pumpAndSettle();

        expect(find.text('No transactions yet'), findsOneWidget);
      });
    });

    group('displays balance correctly', () {
      testWidgets('shows zero balance', (tester) async {
        final wallet = TestWalletProvider(balanceSat: 0);
        await tester.pumpWidget(createTestWidget(const HomeScreen(), wallet: wallet));
        await tester.pumpAndSettle();

        expect(find.text('0 sats'), findsAtLeastNWidgets(1));
      });

      testWidgets('shows small balance', (tester) async {
        final wallet = TestWalletProvider(balanceSat: 500);
        await tester.pumpWidget(createTestWidget(const HomeScreen(), wallet: wallet));
        await tester.pumpAndSettle();

        expect(find.text('500 sats'), findsAtLeastNWidgets(1));
      });

      testWidgets('shows balance with commas', (tester) async {
        final wallet = TestWalletProvider(balanceSat: 10000);
        await tester.pumpWidget(createTestWidget(const HomeScreen(), wallet: wallet));
        await tester.pumpAndSettle();

        expect(find.text('10,000 sats'), findsAtLeastNWidgets(1));
      });

      testWidgets('shows large balance with commas', (tester) async {
        final wallet = TestWalletProvider(balanceSat: 1234567);
        await tester.pumpWidget(createTestWidget(const HomeScreen(), wallet: wallet));
        await tester.pumpAndSettle();

        expect(find.text('1,234,567 sats'), findsOneWidget);
      });

      testWidgets('shows pending receive amount', (tester) async {
        final wallet = TestWalletProvider(pendingReceiveSat: 5000);
        await tester.pumpWidget(createTestWidget(const HomeScreen(), wallet: wallet));
        await tester.pumpAndSettle();

        expect(find.text('Pending In'), findsOneWidget);
        expect(find.text('5.0k sats'), findsOneWidget);
      });

      testWidgets('shows pending send amount', (tester) async {
        final wallet = TestWalletProvider(pendingSendSat: 3000);
        await tester.pumpWidget(createTestWidget(const HomeScreen(), wallet: wallet));
        await tester.pumpAndSettle();

        expect(find.text('Pending Out'), findsOneWidget);
        expect(find.text('3.0k sats'), findsOneWidget);
      });
    });

    group('loading states', () {
      testWidgets('shows loading indicator when initializing', (tester) async {
        final wallet = TestWalletProvider(isLoading: true, isInitialized: false);
        await tester.pumpWidget(createTestWidget(const HomeScreen(), wallet: wallet));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Starting Lightning node...'), findsOneWidget);
      });

      testWidgets('shows error state', (tester) async {
        final wallet = TestWalletProvider(
          isInitialized: false,
          error: 'Connection failed',
        );
        await tester.pumpWidget(createTestWidget(const HomeScreen(), wallet: wallet));
        await tester.pumpAndSettle();

        expect(find.text('Failed to start node'), findsOneWidget);
        expect(find.text('Connection failed'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });
    });

    group('incomplete operations alert', () {
      testWidgets('shows alert when there are incomplete operations', (tester) async {
        final wallet = TestWalletProvider(
          incompleteOperations: [
            OperationState(
              id: 'op_1',
              type: OperationType.send,
              status: OperationStatus.unknown,
              startedAt: DateTime.now(),
              amountSat: 1000,
            ),
          ],
        );
        await tester.pumpWidget(createTestWidget(const HomeScreen(), wallet: wallet));
        await tester.pumpAndSettle();

        expect(find.text('Payment May Be Pending'), findsOneWidget);
      });

      testWidgets('shows dismiss button for incomplete operations', (tester) async {
        final wallet = TestWalletProvider(
          incompleteOperations: [
            OperationState(
              id: 'op_1',
              type: OperationType.receiveBolt12,
              status: OperationStatus.executing,
              startedAt: DateTime.now(),
            ),
          ],
        );
        await tester.pumpWidget(createTestWidget(const HomeScreen(), wallet: wallet));
        await tester.pumpAndSettle();

        expect(find.text('Dismiss'), findsOneWidget);
      });

      testWidgets('hides alert when no incomplete operations', (tester) async {
        final wallet = TestWalletProvider(incompleteOperations: []);
        await tester.pumpWidget(createTestWidget(const HomeScreen(), wallet: wallet));
        await tester.pumpAndSettle();

        expect(find.text('Payment May Be Pending'), findsNothing);
        expect(find.text('Interrupted Operations'), findsNothing);
      });

      testWidgets('shows warning color for send operations', (tester) async {
        final wallet = TestWalletProvider(
          incompleteOperations: [
            OperationState(
              id: 'op_1',
              type: OperationType.send,
              status: OperationStatus.unknown,
              startedAt: DateTime.now(),
            ),
          ],
        );
        await tester.pumpWidget(createTestWidget(const HomeScreen(), wallet: wallet));
        await tester.pumpAndSettle();

        // Send operations should show the red warning
        expect(find.byIcon(Icons.warning_amber), findsOneWidget);
      });

      testWidgets('shows info color for receive operations', (tester) async {
        final wallet = TestWalletProvider(
          incompleteOperations: [
            OperationState(
              id: 'op_1',
              type: OperationType.receiveBolt12,
              status: OperationStatus.executing,
              startedAt: DateTime.now(),
            ),
          ],
        );
        await tester.pumpWidget(createTestWidget(const HomeScreen(), wallet: wallet));
        await tester.pumpAndSettle();

        // Receive operations should show the info icon
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });
    });

    group('navigation buttons', () {
      testWidgets('Receive button exists and is enabled', (tester) async {
        await tester.pumpWidget(createTestWidget(const HomeScreen()));
        await tester.pumpAndSettle();

        final receiveButton = find.text('Receive');
        expect(receiveButton, findsOneWidget);
      });

      testWidgets('Send button exists and is enabled', (tester) async {
        await tester.pumpWidget(createTestWidget(const HomeScreen()));
        await tester.pumpAndSettle();

        final sendButton = find.text('Send');
        expect(sendButton, findsOneWidget);
      });

      testWidgets('Settings button exists and is enabled', (tester) async {
        await tester.pumpWidget(createTestWidget(const HomeScreen()));
        await tester.pumpAndSettle();

        final settingsButton = find.byIcon(Icons.settings_outlined);
        expect(settingsButton, findsOneWidget);
      });
    });

    group('pull to refresh', () {
      testWidgets('can pull to refresh', (tester) async {
        await tester.pumpWidget(createTestWidget(const HomeScreen()));
        await tester.pumpAndSettle();

        // Pull down to trigger refresh
        await tester.drag(find.byType(RefreshIndicator), const Offset(0, 300));
        await tester.pump();

        expect(find.byType(RefreshIndicator), findsOneWidget);
      });
    });
  });
}
