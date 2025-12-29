import 'package:flutter/foundation.dart';
import 'package:flutter_breez_liquid/flutter_breez_liquid.dart';
import '../services/lightning_service.dart';

/// Wallet state management
class WalletProvider extends ChangeNotifier {
  final LightningService _lightningService = LightningService();

  // State
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  String? _onChainAddress;
  String? _bolt12Offer;
  GetInfoResponse? _info;
  List<Payment> _payments = [];

  // Getters
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  String? get onChainAddress => _onChainAddress;
  String? get bolt12Offer => _bolt12Offer;
  GetInfoResponse? get info => _info;
  List<Payment> get payments => _payments;
  LightningService get lightningService => _lightningService;

  // Derived getters
  int get totalBalanceSats {
    return _info?.walletInfo.balanceSat.toInt() ?? 0;
  }

  int get pendingReceiveSats {
    return _info?.walletInfo.pendingReceiveSat.toInt() ?? 0;
  }

  int get pendingSendSats {
    return _info?.walletInfo.pendingSendSat.toInt() ?? 0;
  }

  String? get nodeId {
    return _info?.walletInfo.pubkey;
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
  String generateMnemonic() {
    return _lightningService.generateMnemonic();
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
      _info = await _lightningService.getInfo();
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
  Future<void> generateBolt12Offer() async {
    if (!_isInitialized) return;

    try {
      _bolt12Offer = await _lightningService.generateBolt12Offer();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Send a payment (BOLT11, BOLT12, Lightning Address, etc.)
  Future<bool> sendPayment(String destination, {BigInt? amountSat}) async {
    if (!_isInitialized) return false;
    _setLoading(true);

    try {
      await _lightningService.sendPayment(
        destination: destination,
        amountSat: amountSat,
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

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void dispose() {
    _lightningService.disconnect();
    super.dispose();
  }
}
