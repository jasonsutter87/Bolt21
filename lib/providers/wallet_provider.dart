import 'package:flutter/foundation.dart';
import 'package:flutter_breez_liquid/flutter_breez_liquid.dart';
import 'package:synchronized/synchronized.dart';
import '../models/wallet_metadata.dart';
import '../services/lightning_service.dart';
import '../services/operation_state_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/retry_helper.dart';
import '../utils/secure_logger.dart';

/// Wallet state management with multi-wallet support
class WalletProvider extends ChangeNotifier {
  final LightningService _lightningService = LightningService();
  final OperationStateService _operationStateService = OperationStateService();

  // Atomic mutex lock to prevent concurrent payment operations (TOCTOU-safe)
  final Lock _sendLock = Lock();

  // SECURITY: Track if a payment is in progress to prevent wallet switching
  bool _paymentInProgress = false;
  bool get paymentInProgress => _paymentInProgress;

  // SECURITY: Rate limiting for payment attempts (prevent DoS and rapid drain attacks)
  static const int _maxPaymentAttemptsPerMinute = 5;
  final List<DateTime> _paymentAttempts = [];

  // Multi-wallet state
  List<WalletMetadata> _wallets = [];
  WalletMetadata? _activeWallet;

  // Per-wallet state
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  String? _onChainAddress;
  String? _bolt12Offer;
  GetInfoResponse? _info;
  List<Payment> _payments = [];
  List<OperationState> _incompleteOperations = [];

  // Getters - Multi-wallet
  List<WalletMetadata> get wallets => _wallets;
  WalletMetadata? get activeWallet => _activeWallet;
  bool get hasMultipleWallets => _wallets.length > 1;

  // Getters - Per-wallet state
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  String? get onChainAddress => _onChainAddress;
  String? get bolt12Offer => _bolt12Offer;
  GetInfoResponse? get info => _info;
  List<Payment> get payments => _payments;
  LightningService get lightningService => _lightningService;
  List<OperationState> get incompleteOperations => _incompleteOperations;
  bool get hasIncompleteOperations => _incompleteOperations.isNotEmpty;
  OperationStateService get operationStateService => _operationStateService;

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

  /// Load wallet list and initialize active wallet
  /// Call this on app startup
  Future<void> loadWallets() async {
    _setLoading(true);
    _error = null;

    try {
      // Check for and perform migration from single-wallet to multi-wallet
      final migratedWallet = await SecureStorageService.migrateLegacyWallet();
      if (migratedWallet != null) {
        SecureLogger.info('Migrated legacy wallet to multi-wallet format', tag: 'Wallet');
      }

      // Load wallet list
      _wallets = await SecureStorageService.getWalletList();

      if (_wallets.isEmpty) {
        // No wallets exist - user needs to create or restore
        _isInitialized = false;
        _setLoading(false);
        return;
      }

      // Get active wallet ID or default to first wallet
      final activeId = await SecureStorageService.getActiveWalletId();
      _activeWallet = _wallets.firstWhere(
        (w) => w.id == activeId,
        orElse: () => _wallets.first,
      );

      // Initialize the active wallet
      await _initializeActiveWallet();
    } catch (e) {
      _error = e.toString();
      SecureLogger.error('Failed to load wallets', error: e, tag: 'Wallet');
    } finally {
      _setLoading(false);
    }
  }

  /// Initialize the currently active wallet's Lightning connection
  Future<void> _initializeActiveWallet() async {
    if (_activeWallet == null) return;

    try {
      // Initialize operation state tracking
      await _operationStateService.initialize();

      // Get mnemonic for active wallet
      final mnemonic = await SecureStorageService.getMnemonic(
        walletId: _activeWallet!.id,
      );

      if (mnemonic == null) {
        throw Exception('Mnemonic not found for wallet ${_activeWallet!.name}');
      }

      // Initialize Lightning service with wallet-specific directory
      await _lightningService.initialize(
        walletId: _activeWallet!.id,
        mnemonic: mnemonic,
      );

      _isInitialized = true;
      await _refreshAll();

      // Restore previously generated addresses for this wallet
      _onChainAddress = await SecureStorageService.getOnChainAddress(
        walletId: _activeWallet!.id,
      );
      _bolt12Offer = await SecureStorageService.getBolt12Offer(
        walletId: _activeWallet!.id,
      );

      // Check for incomplete operations
      await _checkIncompleteOperations();
    } catch (e) {
      _error = e.toString();
      SecureLogger.error('Wallet initialization error', error: e, tag: 'Wallet');
      rethrow;
    }
  }

  /// Create a new wallet with generated mnemonic
  /// SECURITY: Sanitizes wallet name to prevent injection attacks
  Future<WalletMetadata> createWallet({required String name}) async {
    _setLoading(true);
    _error = null;

    try {
      // SECURITY: Sanitize wallet name
      final sanitizedName = _sanitizeWalletName(name);
      if (sanitizedName.isEmpty) {
        throw Exception('Wallet name cannot be empty');
      }

      // Generate new mnemonic
      final mnemonic = _lightningService.generateMnemonic();

      // Create wallet metadata
      final wallet = WalletMetadata.create(name: sanitizedName);

      // Save mnemonic
      await SecureStorageService.saveMnemonic(mnemonic, walletId: wallet.id);

      // Add to wallet list
      _wallets = [..._wallets, wallet];
      await SecureStorageService.saveWalletList(_wallets);

      // Switch to new wallet
      await switchWallet(wallet.id);

      notifyListeners();
      return wallet;
    } catch (e) {
      _error = e.toString();
      SecureLogger.error('Failed to create wallet', error: e, tag: 'Wallet');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Import a wallet with provided mnemonic
  /// SECURITY: Sanitizes wallet name to prevent injection attacks
  Future<WalletMetadata> importWallet({
    required String name,
    required String mnemonic,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      // SECURITY: Sanitize wallet name
      final sanitizedName = _sanitizeWalletName(name);
      if (sanitizedName.isEmpty) {
        throw Exception('Wallet name cannot be empty');
      }

      // Create wallet metadata
      final wallet = WalletMetadata.create(name: sanitizedName);

      // Save mnemonic
      await SecureStorageService.saveMnemonic(mnemonic, walletId: wallet.id);

      // Add to wallet list
      _wallets = [..._wallets, wallet];
      await SecureStorageService.saveWalletList(_wallets);

      // Switch to new wallet
      await switchWallet(wallet.id);

      notifyListeners();
      return wallet;
    } catch (e) {
      _error = e.toString();
      SecureLogger.error('Failed to import wallet', error: e, tag: 'Wallet');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Switch to a different wallet
  /// SECURITY: Blocked during active payments to prevent wrong-wallet sends
  Future<void> switchWallet(String walletId) async {
    // SECURITY: Prevent wallet switch during active payment
    if (_paymentInProgress) {
      throw Exception('Cannot switch wallets while a payment is in progress');
    }

    final wallet = _wallets.firstWhere(
      (w) => w.id == walletId,
      orElse: () => throw Exception('Wallet not found'),
    );

    if (_activeWallet?.id == walletId && _isInitialized) {
      return; // Already active
    }

    _setLoading(true);
    _error = null;

    try {
      // Clear current wallet state
      _clearWalletState();

      // Set new active wallet
      _activeWallet = wallet;
      await SecureStorageService.setActiveWalletId(walletId);

      // Initialize the new wallet
      await _initializeActiveWallet();

      SecureLogger.info('Switched to wallet: ${wallet.name}', tag: 'Wallet');
    } catch (e) {
      _error = e.toString();
      SecureLogger.error('Failed to switch wallet', error: e, tag: 'Wallet');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Sanitize wallet name to prevent injection attacks
  /// SECURITY: Removes control characters and validates content
  String _sanitizeWalletName(String name) {
    // Remove control characters and null bytes
    var sanitized = name.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    // Remove HTML/script tags
    sanitized = sanitized.replaceAll(RegExp(r'<[^>]*>'), '');
    // Trim whitespace
    return sanitized.trim();
  }

  /// Rename a wallet
  /// SECURITY: Validates and sanitizes input to prevent injection attacks
  Future<void> renameWallet(String walletId, String newName) async {
    // Input validation and sanitization
    final sanitizedName = _sanitizeWalletName(newName);
    if (sanitizedName.isEmpty) {
      throw Exception('Wallet name cannot be empty');
    }
    if (sanitizedName.length > 50) {
      throw Exception('Wallet name cannot exceed 50 characters');
    }

    final index = _wallets.indexWhere((w) => w.id == walletId);
    if (index == -1) throw Exception('Wallet not found');

    _wallets[index] = _wallets[index].copyWith(name: sanitizedName);
    await SecureStorageService.saveWalletList(_wallets);

    // Update active wallet reference if needed
    if (_activeWallet?.id == walletId) {
      _activeWallet = _wallets[index];
    }

    notifyListeners();
  }

  /// Delete a wallet (cannot delete last wallet)
  /// SECURITY: Deletes both secure storage keys AND Breez SDK directory
  Future<void> deleteWallet(String walletId) async {
    if (_wallets.length <= 1) {
      throw Exception('Cannot delete the last wallet');
    }

    final wallet = _wallets.firstWhere(
      (w) => w.id == walletId,
      orElse: () => throw Exception('Wallet not found'),
    );

    _setLoading(true);

    try {
      // If deleting active wallet, switch to another first
      if (_activeWallet?.id == walletId) {
        final otherWallet = _wallets.firstWhere((w) => w.id != walletId);
        await switchWallet(otherWallet.id);
      }

      // Remove from list
      _wallets = _wallets.where((w) => w.id != walletId).toList();
      await SecureStorageService.saveWalletList(_wallets);

      // Delete wallet secure storage data (mnemonic, addresses)
      await SecureStorageService.deleteWalletData(walletId);

      // SECURITY: Delete Breez SDK directory to remove all cached wallet data
      await _lightningService.deleteWalletDirectory(walletId);

      SecureLogger.info('Deleted wallet: ${wallet.name}', tag: 'Wallet');
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Clear current wallet state (when switching wallets)
  void _clearWalletState() {
    _isInitialized = false;
    _info = null;
    _payments = [];
    _onChainAddress = null;
    _bolt12Offer = null;
    _incompleteOperations = [];
    _error = null;
  }

  /// Get mnemonic for a specific wallet (for recovery phrase display)
  Future<String?> getMnemonic({String? walletId}) async {
    final id = walletId ?? _activeWallet?.id;
    if (id == null) return null;
    return SecureStorageService.getMnemonic(walletId: id);
  }

  /// Generate a new mnemonic (for create wallet flow)
  String generateMnemonic() {
    return _lightningService.generateMnemonic();
  }

  /// Check for incomplete operations from previous session
  /// SECURITY: Only loads operations for the active wallet
  Future<void> _checkIncompleteOperations() async {
    _incompleteOperations = _operationStateService.getIncompleteOperations(
      walletId: _activeWallet?.id,
    );

    if (_incompleteOperations.isNotEmpty) {
      SecureLogger.info('Found ${_incompleteOperations.length} incomplete operations', tag: 'Wallet');

      // For operations that were in "executing" state, mark as unknown
      // since we don't know if they completed
      for (final op in _incompleteOperations) {
        if (op.status == OperationStatus.executing) {
          await _operationStateService.markUnknown(op.id);
        }
      }

      // Refresh the list after updates (filtered to active wallet)
      _incompleteOperations = _operationStateService.getIncompleteOperations(
        walletId: _activeWallet?.id,
      );
      notifyListeners();
    }
  }

  /// Acknowledge and dismiss an incomplete operation after user review
  Future<void> acknowledgeIncompleteOperation(String operationId) async {
    await _operationStateService.removeOperation(operationId);
    _incompleteOperations = _operationStateService.getIncompleteOperations(
      walletId: _activeWallet?.id,
    );
    notifyListeners();
  }

  /// Clear all incomplete operations (user confirmed they're resolved)
  Future<void> clearIncompleteOperations() async {
    for (final op in _incompleteOperations) {
      await _operationStateService.removeOperation(op.id);
    }
    _incompleteOperations = [];
    notifyListeners();
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
      // Use retry for network resilience
      _info = await withRefreshRetry(
        operation: () => _lightningService.getInfo(),
        operationName: 'getInfo',
      );
      _payments = await withRefreshRetry(
        operation: () => _lightningService.listPayments(),
        operationName: 'listPayments',
      );
      _error = null;
    } catch (e) {
      // Don't overwrite critical errors with refresh failures
      if (_error == null) {
        _error = 'Failed to refresh: ${e.toString()}';
      }
      SecureLogger.warn('Refresh failed', tag: 'Wallet');
    }
    notifyListeners();
  }

  /// Get new on-chain address
  Future<String?> generateOnChainAddress() async {
    if (!_isInitialized || _activeWallet == null) return null;

    final operation = await _operationStateService.createOperation(
      type: OperationType.receiveOnchain,
      walletId: _activeWallet!.id,
    );

    try {
      await _operationStateService.markExecuting(operation.id);
      _onChainAddress = await _lightningService.getOnChainAddress();
      // Persist to secure storage for app restart (per-wallet)
      await SecureStorageService.saveOnChainAddress(
        _onChainAddress!,
        walletId: _activeWallet!.id,
      );
      await _operationStateService.markCompleted(operation.id);
      notifyListeners();
      return _onChainAddress;
    } catch (e) {
      await _operationStateService.markFailed(operation.id, e.toString());
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Generate BOLT12 offer
  Future<String?> generateBolt12Offer() async {
    if (!_isInitialized || _activeWallet == null) return null;

    final operation = await _operationStateService.createOperation(
      type: OperationType.receiveBolt12,
      walletId: _activeWallet!.id,
    );

    try {
      await _operationStateService.markExecuting(operation.id);
      _bolt12Offer = await _lightningService.generateBolt12Offer();
      // Persist to secure storage for app restart (per-wallet)
      await SecureStorageService.saveBolt12Offer(
        _bolt12Offer!,
        walletId: _activeWallet!.id,
      );
      await _operationStateService.markCompleted(operation.id);
      notifyListeners();
      return _bolt12Offer;
    } catch (e) {
      await _operationStateService.markFailed(operation.id, e.toString());
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // SECURITY: Mutex lock for rate limiting to prevent TOCTOU race condition
  final Lock _rateLimitLock = Lock();

  /// SECURITY: Atomically check and record payment attempt for rate limiting
  /// Returns true if rate limited (too many attempts), false if allowed
  /// Uses mutex lock to prevent race condition between check and record
  Future<bool> _checkAndRecordPaymentAttempt() async {
    return await _rateLimitLock.synchronized(() {
      final now = DateTime.now();
      final oneMinuteAgo = now.subtract(const Duration(minutes: 1));

      // Remove attempts older than 1 minute
      _paymentAttempts.removeWhere((attempt) => attempt.isBefore(oneMinuteAgo));

      // Check if rate limited
      if (_paymentAttempts.length >= _maxPaymentAttemptsPerMinute) {
        return true; // Rate limited
      }

      // Record this attempt atomically with the check
      _paymentAttempts.add(now);
      return false; // Allowed
    });
  }

  /// Send a payment (BOLT11, BOLT12, Lightning Address, etc.)
  /// Returns operation ID on success for tracking, null on failure
  Future<String?> sendPayment(String destination, {BigInt? amountSat}) async {
    if (!_isInitialized || _activeWallet == null) return null;

    // SECURITY: Atomic rate limiting - prevents TOCTOU race condition
    // Check and record in single locked operation to prevent bypass
    final isRateLimited = await _checkAndRecordPaymentAttempt();
    if (isRateLimited) {
      _error = 'Too many payment attempts. Please wait a moment before trying again.';
      SecureLogger.warn('Payment rate limited', tag: 'Payment');
      notifyListeners();
      return null;
    }

    // SECURITY: Validate balance before attempting send
    // Reserve a buffer for fees to avoid failed transactions
    const int feeBufferSats = 500; // Reserve for on-chain/routing fees
    if (amountSat != null) {
      final balance = totalBalanceSats;
      final available = balance > feeBufferSats ? balance - feeBufferSats : 0;
      if (amountSat.toInt() > available) {
        _error = 'Insufficient balance. Available: $available sats (${feeBufferSats} sats reserved for fees)';
        notifyListeners();
        return null;
      }
      if (amountSat <= BigInt.zero) {
        _error = 'Invalid amount. Must be greater than 0';
        notifyListeners();
        return null;
      }
    }

    // SECURITY: Set payment in progress to block wallet switching
    _paymentInProgress = true;
    _setLoading(true);

    // Create operation record BEFORE starting - this is critical for crash recovery
    // SECURITY: walletId ensures operations are isolated per wallet
    final operation = await _operationStateService.createOperation(
      type: OperationType.send,
      walletId: _activeWallet!.id,
      destination: destination,
      amountSat: amountSat?.toInt(),
    );

    try {
      // Mark as preparing (SDK prepare call)
      await _operationStateService.markPreparing(operation.id);

      // Mark as executing (SDK send call)
      await _operationStateService.markExecuting(operation.id);

      final response = await _lightningService.sendPayment(
        destination: destination,
        amountSat: amountSat,
      );

      // Mark as completed with transaction ID
      await _operationStateService.markCompleted(
        operation.id,
        txId: response.payment.txId,
      );

      await _refreshAll();
      return operation.id;
    } catch (e) {
      // Mark as failed with error
      await _operationStateService.markFailed(operation.id, e.toString());
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      // SECURITY: Clear payment in progress flag
      _paymentInProgress = false;
      _setLoading(false);
    }
  }

  /// Send payment with idempotency and atomic mutex lock - prevents double-spend
  /// Uses synchronized Lock for TOCTOU-safe concurrency control
  Future<String?> sendPaymentIdempotent(
    String destination, {
    BigInt? amountSat,
    String? idempotencyKey,
  }) async {
    // Check if lock is already held (non-blocking check for UX)
    if (_sendLock.locked) {
      SecureLogger.warn('Payment blocked - another payment in progress', tag: 'Wallet');
      _error = 'Another payment is in progress. Please wait.';
      notifyListeners();
      return null;
    }

    // Atomic lock acquisition - prevents race condition
    return await _sendLock.synchronized(() async {
      // SECURITY: Double-check inside lock with wallet isolation
      // Must filter by walletId to prevent cross-wallet operation confusion
      final activeWalletId = _activeWallet?.id;
      final existing = _operationStateService.getAllOperations().where((op) =>
          op.walletId == activeWalletId &&
          op.destination == destination &&
          op.amountSat == amountSat?.toInt() &&
          op.isIncomplete);

      if (existing.isNotEmpty) {
        SecureLogger.warn('Duplicate payment blocked for wallet $activeWalletId', tag: 'Wallet');
        _error = 'A payment to this destination is already in progress';
        notifyListeners();
        return null;
      }

      return await sendPayment(destination, amountSat: amountSat);
    });
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
