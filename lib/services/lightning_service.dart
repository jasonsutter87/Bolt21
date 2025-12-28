import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ldk_node/ldk_node.dart';
import 'package:path_provider/path_provider.dart';

/// Service for managing LDK Lightning node operations
class LightningService {
  Node? _node;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  Node? get node => _node;

  /// Initialize the Lightning node
  Future<void> initialize({String? mnemonic}) async {
    if (_isInitialized) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final ldkDir = '${directory.path}/ldk_node';

      // Ensure directory exists
      await Directory(ldkDir).create(recursive: true);

      // Build the node
      final builder = Builder()
        ..setNetwork(Network.bitcoin)
        ..setStorageDirPath(ldkDir)
        ..setEsploraServer('https://blockstream.info/api');

      // Set mnemonic if provided, otherwise generate new one
      if (mnemonic != null) {
        builder.setEntropyBip39Mnemonic(mnemonic: Mnemonic(seedPhrase: mnemonic));
      }

      _node = await builder.build();
      await _node!.start();
      _isInitialized = true;

      debugPrint('Lightning node initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Lightning node: $e');
      rethrow;
    }
  }

  /// Generate a new mnemonic seed phrase
  Future<String> generateMnemonic() async {
    final mnemonic = await Mnemonic.generate();
    return mnemonic.seedPhrase;
  }

  /// Get on-chain wallet address
  Future<String> getOnChainAddress() async {
    _ensureInitialized();
    final onChainPayment = await _node!.onChainPayment();
    final address = await onChainPayment.newAddress();
    return address.s;
  }

  /// Get wallet balances
  Future<BalanceDetails> getBalances() async {
    _ensureInitialized();
    return await _node!.listBalances();
  }

  /// Generate a BOLT12 offer (reusable payment address)
  Future<String> generateBolt12Offer({String? description}) async {
    _ensureInitialized();
    final bolt12Payment = await _node!.bolt12Payment();
    final offer = await bolt12Payment.receiveVariableAmount(
      description: description ?? 'Bolt21 Wallet',
    );
    return offer.s;
  }

  /// Pay a BOLT12 offer
  Future<PaymentId> payBolt12Offer({
    required String offer,
    BigInt? amountMsat,
  }) async {
    _ensureInitialized();
    final bolt12Payment = await _node!.bolt12Payment();

    if (amountMsat != null) {
      return await bolt12Payment.sendUsingAmount(
        offer: Offer(s: offer),
        payerNote: 'Sent via Bolt21',
        amountMsat: amountMsat,
      );
    } else {
      return await bolt12Payment.send(
        offer: Offer(s: offer),
        payerNote: 'Sent via Bolt21',
      );
    }
  }

  /// Pay a BOLT11 invoice (for compatibility)
  Future<PaymentId> payBolt11Invoice(String invoice) async {
    _ensureInitialized();
    final bolt11Payment = await _node!.bolt11Payment();
    final paymentId = await bolt11Payment.send(
      invoice: Bolt11Invoice(signedRawInvoice: invoice),
    );
    return paymentId;
  }

  /// List all payments
  Future<List<PaymentDetails>> listPayments() async {
    _ensureInitialized();
    return await _node!.listPayments();
  }

  /// Get node ID
  Future<String> getNodeId() async {
    _ensureInitialized();
    final nodeId = await _node!.nodeId();
    return nodeId.hex;
  }

  /// Stop the node
  Future<void> stop() async {
    if (_node != null) {
      await _node!.stop();
      _isInitialized = false;
    }
  }

  void _ensureInitialized() {
    if (!_isInitialized || _node == null) {
      throw Exception('Lightning node not initialized');
    }
  }
}
