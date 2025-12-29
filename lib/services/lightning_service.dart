import 'dart:io';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/foundation.dart';
import 'package:flutter_breez_liquid/flutter_breez_liquid.dart';
import 'package:path_provider/path_provider.dart';
import 'config_service.dart';

/// Service for managing Lightning node operations via Breez SDK Liquid
class LightningService {
  BreezSdkLiquid? _sdk;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  BreezSdkLiquid? get sdk => _sdk;

  /// Initialize the Breez SDK
  Future<void> initialize({String? mnemonic}) async {
    if (_isInitialized) return;

    try {
      // Ensure config is loaded
      await ConfigService.instance.initialize();

      debugPrint('Breez: Getting app directory...');
      final directory = await getApplicationDocumentsDirectory();
      final workingDir = '${directory.path}/breez_sdk';

      // Ensure directory exists
      await Directory(workingDir).create(recursive: true);
      debugPrint('Breez: Directory ready: $workingDir');

      // Generate mnemonic if not provided
      final seedPhrase = mnemonic ?? generateMnemonic();

      debugPrint('Breez: Creating config...');
      // Get default config and update the working directory
      final defaultCfg = defaultConfig(
        network: LiquidNetwork.mainnet,
        breezApiKey: ConfigService.instance.breezApiKey,
      );

      final config = Config(
        liquidExplorer: defaultCfg.liquidExplorer,
        bitcoinExplorer: defaultCfg.bitcoinExplorer,
        workingDir: workingDir,
        network: defaultCfg.network,
        paymentTimeoutSec: defaultCfg.paymentTimeoutSec,
        syncServiceUrl: defaultCfg.syncServiceUrl,
        zeroConfMaxAmountSat: defaultCfg.zeroConfMaxAmountSat,
        breezApiKey: defaultCfg.breezApiKey,
        externalInputParsers: defaultCfg.externalInputParsers,
        useDefaultExternalInputParsers: defaultCfg.useDefaultExternalInputParsers,
        onchainFeeRateLeewaySat: defaultCfg.onchainFeeRateLeewaySat,
        assetMetadata: defaultCfg.assetMetadata,
        sideswapApiKey: defaultCfg.sideswapApiKey,
        useMagicRoutingHints: defaultCfg.useMagicRoutingHints,
        onchainSyncPeriodSec: defaultCfg.onchainSyncPeriodSec,
        onchainSyncRequestTimeoutSec: defaultCfg.onchainSyncRequestTimeoutSec,
      );

      debugPrint('Breez: Connecting...');
      final connectRequest = ConnectRequest(
        mnemonic: seedPhrase,
        config: config,
      );

      _sdk = await connect(req: connectRequest);
      _isInitialized = true;

      debugPrint('Breez SDK initialized successfully');
    } catch (e, stack) {
      debugPrint('Failed to initialize Breez SDK: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  /// Generate a new mnemonic seed phrase (12 words)
  String generateMnemonic() {
    return bip39.generateMnemonic(strength: 128); // 128 bits = 12 words
  }

  /// Get wallet info including balance
  Future<GetInfoResponse> getInfo() async {
    _ensureInitialized();
    return await _sdk!.getInfo();
  }

  /// Get wallet balance in sats
  Future<BigInt> getBalanceSat() async {
    final info = await getInfo();
    return info.walletInfo.balanceSat;
  }

  /// Generate a BOLT12 offer (reusable payment address)
  Future<String> generateBolt12Offer() async {
    _ensureInitialized();

    final prepareRequest = PrepareReceiveRequest(
      paymentMethod: PaymentMethod.bolt12Offer,
    );

    final prepareResponse = await _sdk!.prepareReceivePayment(
      req: prepareRequest,
    );

    final receiveRequest = ReceivePaymentRequest(
      prepareResponse: prepareResponse,
    );

    final response = await _sdk!.receivePayment(req: receiveRequest);
    return response.destination;
  }

  /// Generate a BOLT11 invoice
  Future<String> generateBolt11Invoice({
    required BigInt amountSat,
    String? description,
  }) async {
    _ensureInitialized();

    final prepareRequest = PrepareReceiveRequest(
      paymentMethod: PaymentMethod.lightning,
      amount: ReceiveAmount.bitcoin(payerAmountSat: amountSat),
    );

    final prepareResponse = await _sdk!.prepareReceivePayment(
      req: prepareRequest,
    );

    final receiveRequest = ReceivePaymentRequest(
      prepareResponse: prepareResponse,
      description: description,
    );

    final response = await _sdk!.receivePayment(req: receiveRequest);
    return response.destination;
  }

  /// Get on-chain Bitcoin address (Liquid address for receiving)
  Future<String> getOnChainAddress() async {
    _ensureInitialized();

    final prepareRequest = PrepareReceiveRequest(
      paymentMethod: PaymentMethod.bitcoinAddress,
    );

    final prepareResponse = await _sdk!.prepareReceivePayment(
      req: prepareRequest,
    );

    final receiveRequest = ReceivePaymentRequest(
      prepareResponse: prepareResponse,
    );

    final response = await _sdk!.receivePayment(req: receiveRequest);
    return response.destination;
  }

  /// Parse any payment input (BOLT11, BOLT12, BIP21, Lightning Address, etc.)
  Future<InputType> parseInput(String input) async {
    _ensureInitialized();
    return await _sdk!.parse(input: input);
  }

  /// Send a payment (works with BOLT11, BOLT12, Lightning Address, etc.)
  Future<SendPaymentResponse> sendPayment({
    required String destination,
    BigInt? amountSat,
  }) async {
    _ensureInitialized();

    final prepareRequest = PrepareSendRequest(
      destination: destination,
      amount: amountSat != null
          ? PayAmount.bitcoin(receiverAmountSat: amountSat)
          : null,
    );

    final prepareResponse = await _sdk!.prepareSendPayment(req: prepareRequest);

    final sendRequest = SendPaymentRequest(
      prepareResponse: prepareResponse,
    );

    return await _sdk!.sendPayment(req: sendRequest);
  }

  /// List all payments
  Future<List<Payment>> listPayments() async {
    _ensureInitialized();
    final request = ListPaymentsRequest();
    return await _sdk!.listPayments(req: request);
  }

  /// Listen to payment events
  Stream<SdkEvent> get paymentEvents {
    _ensureInitialized();
    return _sdk!.addEventListener();
  }

  /// Disconnect the SDK
  Future<void> disconnect() async {
    if (_sdk != null) {
      await _sdk!.disconnect();
      _isInitialized = false;
    }
  }

  void _ensureInitialized() {
    if (!_isInitialized || _sdk == null) {
      throw Exception('Breez SDK not initialized');
    }
  }
}
