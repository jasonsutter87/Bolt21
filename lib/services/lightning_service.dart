import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ldk_node/ldk_node.dart';
import 'package:path_provider/path_provider.dart';

/// LSP configuration for automatic channel liquidity
class LspConfig {
  final String nodeId;
  final String address;
  final int port;
  final String? token;

  const LspConfig({
    required this.nodeId,
    required this.address,
    required this.port,
    this.token,
  });

  /// Voltage Flow LSP (mainnet) - requires token from voltage.cloud
  static LspConfig? voltage(String token) => LspConfig(
        nodeId: '025804d4431ad05b06a1a1ee41f22f3c095c2a4e48e9cfe90ee9c2823c0301c396',
        address: 'lsp.voltage.cloud',
        port: 9735,
        token: token,
      );
}

/// Service for managing LDK Lightning node operations
class LightningService {
  Node? _node;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  Node? get node => _node;

  /// Initialize the Lightning node
  Future<void> initialize({
    String? mnemonic,
    LspConfig? lspConfig,
  }) async {
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
        builder.setEntropyBip39Mnemonic(
            mnemonic: Mnemonic(seedPhrase: mnemonic));
      }

      // Configure LSP for automatic inbound liquidity
      if (lspConfig != null) {
        builder.setLiquiditySourceLsps2(
          address: SocketAddress.hostname(
            addr: lspConfig.address,
            port: lspConfig.port,
          ),
          publicKey: PublicKey(hex: lspConfig.nodeId),
          token: lspConfig.token,
        );
        debugPrint('LSP configured: ${lspConfig.address}:${lspConfig.port}');
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

  /// Sync wallets with the blockchain
  Future<void> syncWallets() async {
    _ensureInitialized();
    await _node!.syncWallets();
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

  /// List all channels
  Future<List<ChannelDetails>> listChannels() async {
    _ensureInitialized();
    return await _node!.listChannels();
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
