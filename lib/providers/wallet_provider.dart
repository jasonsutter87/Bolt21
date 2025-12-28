import 'package:flutter/foundation.dart';
import 'package:ldk_node/ldk_node.dart';
import '../services/lightning_service.dart';

/// Wallet state management
class WalletProvider extends ChangeNotifier {
  final LightningService _lightningService = LightningService();

  // State
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  String? _nodeId;
  String? _onChainAddress;
  String? _bolt12Offer;
  BalanceDetails? _balances;
  List<PaymentDetails> _payments = [];

  // Getters
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  String? get nodeId => _nodeId;
  String? get onChainAddress => _onChainAddress;
  String? get bolt12Offer => _bolt12Offer;
  BalanceDetails? get balances => _balances;
  List<PaymentDetails> get payments => _payments;
  LightningService get lightningService => _lightningService;

  // Derived getters
  int get totalBalanceSats {
    if (_balances == null) return 0;
    final onChain = _balances!.totalOnchainBalanceSats.toInt();
    final lightning = _balances!.totalLightningBalanceSats.toInt();
    return onChain + lightning;
  }

  int get onChainBalanceSats {
    return _balances?.totalOnchainBalanceSats.toInt() ?? 0;
  }

  int get lightningBalanceSats {
    return _balances?.totalLightningBalanceSats.toInt() ?? 0;
  }

  /// Initialize wallet with existing or new mnemonic
  Future<void> initializeWallet({String? mnemonic}) async {
    _setLoading(true);
    _error = null;

    try {
      await _lightningService.initialize(mnemonic: mnemonic);
      _isInitialized = true;
      await _refreshAll();
    } catch (e) {
      _error = e.toString();
      debugPrint('Wallet initialization error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Generate a new mnemonic
  Future<String> generateMnemonic() async {
    return await _lightningService.generateMnemonic();
  }

  /// Refresh all wallet data
  Future<void> refreshAll() async {
    if (!_isInitialized) return;
    _setLoading(true);
    await _refreshAll();
    _setLoading(false);
  }

  Future<void> _refreshAll() async {
    try {
      _nodeId = await _lightningService.getNodeId();
      _balances = await _lightningService.getBalances();
      _payments = await _lightningService.listPayments();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  /// Get new on-chain address
  Future<void> generateOnChainAddress() async {
    if (!_isInitialized) return;

    try {
      _onChainAddress = await _lightningService.getOnChainAddress();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Generate BOLT12 offer
  Future<void> generateBolt12Offer({String? description}) async {
    if (!_isInitialized) return;

    try {
      _bolt12Offer = await _lightningService.generateBolt12Offer(
        description: description,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Pay a BOLT12 offer
  Future<bool> payBolt12Offer(String offer, {BigInt? amountMsat}) async {
    if (!_isInitialized) return false;
    _setLoading(true);

    try {
      await _lightningService.payBolt12Offer(
        offer: offer,
        amountMsat: amountMsat,
      );
      await _refreshAll();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Pay a BOLT11 invoice
  Future<bool> payBolt11Invoice(String invoice) async {
    if (!_isInitialized) return false;
    _setLoading(true);

    try {
      await _lightningService.payBolt11Invoice(invoice);
      await _refreshAll();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void dispose() {
    _lightningService.stop();
    super.dispose();
  }
}
