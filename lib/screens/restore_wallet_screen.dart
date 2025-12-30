import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bip39/bip39.dart' as bip39;
import '../providers/wallet_provider.dart';
import '../utils/secure_string.dart';
import '../utils/theme.dart';
import 'home_screen.dart';

class RestoreWalletScreen extends StatefulWidget {
  /// If true, this is adding a wallet to existing wallets (not first wallet)
  final bool addWallet;

  const RestoreWalletScreen({super.key, this.addWallet = false});

  @override
  State<RestoreWalletScreen> createState() => _RestoreWalletScreenState();
}

class _RestoreWalletScreenState extends State<RestoreWalletScreen> {
  final List<TextEditingController> _controllers =
      List.generate(12, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(12, (_) => FocusNode());
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String _syncStatus = '';
  int _syncStep = 0;
  static const int _totalSyncSteps = 4;
  int _step = 0; // 0 = name, 1 = seed phrase

  @override
  void initState() {
    super.initState();
    final wallet = context.read<WalletProvider>();
    _nameController.text = 'Wallet ${wallet.wallets.length + 1}';

    // If this is the first wallet, skip name step
    if (!widget.addWallet && wallet.wallets.isEmpty) {
      _nameController.text = 'Main Wallet';
      _step = 1;
    }
  }

  @override
  void dispose() {
    // SECURITY: Clear mnemonic words from text controllers before disposal
    for (final controller in _controllers) {
      controller.clear();
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    _nameController.dispose();
    super.dispose();
  }

  /// SECURITY: Clear all mnemonic input fields
  void _clearMnemonicFields() {
    for (final controller in _controllers) {
      controller.clear();
    }
  }

  String get _mnemonic {
    return _controllers.map((c) => c.text.trim().toLowerCase()).join(' ');
  }

  bool get _isComplete {
    return _controllers.every((c) => c.text.trim().isNotEmpty);
  }

  void _updateSyncStatus(String status, int step) {
    if (mounted) {
      setState(() {
        _syncStatus = status;
        _syncStep = step;
      });
    }
  }

  void _proceedToSeedPhrase() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a wallet name'),
          backgroundColor: Bolt21Theme.error,
        ),
      );
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _restoreWallet() async {
    if (!_isComplete) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _syncStatus = 'Validating recovery phrase...';
      _syncStep = 1;
    });

    // SECURITY: Use SecureString to minimize mnemonic exposure in memory
    SecureString? secureMnemonic;

    try {
      // SECURITY: Immediately wrap mnemonic in SecureString for secure disposal
      secureMnemonic = SecureString.fromString(_mnemonic);

      // Validate mnemonic format (word count)
      final words = secureMnemonic.value.split(' ');
      if (words.length != 12) {
        throw Exception('Recovery phrase must be exactly 12 words');
      }

      // Validate BIP39 mnemonic checksum and word list
      if (!bip39.validateMnemonic(secureMnemonic.value)) {
        throw Exception(
          'Invalid recovery phrase. Please check that all words are spelled correctly '
          'and are valid BIP39 words.'
        );
      }

      _updateSyncStatus('Importing wallet...', 2);

      // SECURITY: Clear mnemonic from UI after validation
      _clearMnemonicFields();

      final wallet = context.read<WalletProvider>();
      final name = _nameController.text.trim();
      final isFirstWallet = wallet.wallets.isEmpty;

      _updateSyncStatus('Connecting to Lightning network...', 3);

      // Import wallet with the new multi-wallet API
      // Note: importWallet internally stores to secure storage
      await wallet.importWallet(name: name, mnemonic: secureMnemonic.value);

      // SECURITY: Immediately dispose SecureString after use
      secureMnemonic.dispose();
      secureMnemonic = null;

      if (wallet.error != null) {
        setState(() {
          _error = wallet.error;
          _isLoading = false;
          _syncStatus = '';
          _syncStep = 0;
        });
        return;
      }

      _updateSyncStatus('Syncing wallet data...', 4);
      // Give a moment for the UI to update
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        // Show success message with balance
        final balance = wallet.totalBalanceSats;
        final paymentCount = wallet.payments.length;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Wallet restored! Balance: $balance sats, $paymentCount transactions found.',
            ),
            backgroundColor: Bolt21Theme.success,
            duration: const Duration(seconds: 3),
          ),
        );

        if (isFirstWallet) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _syncStatus = '';
        _syncStep = 0;
      });
    } finally {
      // SECURITY: Always dispose SecureString to wipe mnemonic from memory
      secureMnemonic?.dispose();
    }
  }

  void _onWordChanged(int index, String value) {
    // Auto-advance to next field when word is complete (has space or 3+ chars)
    if (value.contains(' ')) {
      final words = value.trim().split(RegExp(r'\s+'));
      _controllers[index].text = words.first;

      // Paste multiple words
      for (var i = 1; i < words.length && index + i < 12; i++) {
        _controllers[index + i].text = words[i];
      }

      final nextIndex = (index + words.length).clamp(0, 11);
      if (nextIndex < 12) {
        _focusNodes[nextIndex].requestFocus();
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 0) {
      return _buildNameStep();
    }
    return _buildSeedPhraseStep();
  }

  Widget _buildNameStep() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore Wallet'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Name your wallet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Give your wallet a name so you can identify it easily',
              style: TextStyle(color: Bolt21Theme.textSecondary),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Wallet Name',
                hintText: 'e.g., Savings, Daily Spending',
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _proceedToSeedPhrase,
                child: const Text('Continue', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSeedPhraseStep() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore Wallet'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Instructions
          const Text(
            'Enter your 12-word recovery phrase',
            style: TextStyle(
              fontSize: 16,
              color: Bolt21Theme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You can paste all 12 words at once into the first field',
            style: TextStyle(
              fontSize: 14,
              color: Bolt21Theme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Word input grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  color: Bolt21Theme.darkCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _focusNodes[index].hasFocus
                        ? Bolt21Theme.orange
                        : Bolt21Theme.darkBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Bolt21Theme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4),
                          isDense: true,
                        ),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: index < 11
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onChanged: (value) => _onWordChanged(index, value),
                        onSubmitted: (_) {
                          if (index < 11) {
                            _focusNodes[index + 1].requestFocus();
                          } else {
                            _restoreWallet();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Error message
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Bolt21Theme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Bolt21Theme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Bolt21Theme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Bolt21Theme.error),
                    ),
                  ),
                ],
              ),
            ),
          if (_error != null) const SizedBox(height: 24),

          // Restore button or sync progress
          if (_isLoading) ...[
            // Sync progress indicator
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Bolt21Theme.darkCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const CircularProgressIndicator(color: Bolt21Theme.orange),
                  const SizedBox(height: 16),
                  Text(
                    _syncStatus,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Bolt21Theme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _syncStep / _totalSyncSteps,
                      backgroundColor: Bolt21Theme.darkBg,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Bolt21Theme.orange,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Step $_syncStep of $_totalSyncSteps',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Bolt21Theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isComplete ? _restoreWallet : null,
                child: const Text(
                  'Restore Wallet',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
