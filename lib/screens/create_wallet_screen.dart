import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/theme.dart';
import '../utils/secure_clipboard.dart';
import 'home_screen.dart';

class CreateWalletScreen extends StatefulWidget {
  /// If true, this is adding a wallet to existing wallets (not first wallet)
  final bool addWallet;

  const CreateWalletScreen({super.key, this.addWallet = false});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  String? _mnemonic;
  bool _isLoading = true;
  bool _backedUp = false;
  bool _showWords = false;
  final _nameController = TextEditingController();
  int _step = 0; // 0 = name, 1 = seed phrase

  @override
  void initState() {
    super.initState();
    // Set default wallet name
    final wallet = context.read<WalletProvider>();
    _nameController.text = 'Wallet ${wallet.wallets.length + 1}';

    // If this is the first wallet, skip name step and show seed immediately
    if (!widget.addWallet && wallet.wallets.isEmpty) {
      _nameController.text = 'Main Wallet';
      _step = 1;
      _generateMnemonic();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    // SECURITY: Clear mnemonic from memory when leaving screen
    _mnemonic = null;
    _nameController.dispose();
    super.dispose();
  }

  void _generateMnemonic() {
    final wallet = context.read<WalletProvider>();
    final mnemonic = wallet.generateMnemonic();
    setState(() {
      _mnemonic = mnemonic;
      _isLoading = false;
    });
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
    _generateMnemonic();
  }

  Future<void> _createWallet() async {
    if (_mnemonic == null) return;

    setState(() => _isLoading = true);

    try {
      final wallet = context.read<WalletProvider>();
      final name = _nameController.text.trim();
      final isFirstWallet = wallet.wallets.isEmpty;

      // Use importWallet since we already have the mnemonic
      await wallet.importWallet(name: name, mnemonic: _mnemonic!);

      // SECURITY: Clear mnemonic from UI state after successful storage
      if (mounted) {
        setState(() => _mnemonic = null);
      }

      // Check if initialization succeeded
      if (wallet.error != null) {
        throw Exception(wallet.error);
      }

      if (mounted) {
        if (isFirstWallet) {
          // First wallet - go to home
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        } else {
          // Added wallet - pop back
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Wallet "$name" created'),
              backgroundColor: Bolt21Theme.success,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create wallet: $e'),
            backgroundColor: Bolt21Theme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
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
        title: const Text('Create Wallet'),
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
    final words = _mnemonic?.split(' ') ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.addWallet ? 'Create Wallet' : 'Create Wallet'),
      ),
      body: _isLoading && _mnemonic == null
          ? const Center(
              child: CircularProgressIndicator(color: Bolt21Theme.orange),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Warning card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Bolt21Theme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Bolt21Theme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Bolt21Theme.error),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Write down these 12 words and store them safely. They are the only way to recover your wallet.',
                          style: TextStyle(color: Bolt21Theme.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Seed phrase display
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${_nameController.text} Recovery Phrase',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setState(() => _showWords = !_showWords);
                              },
                              icon: Icon(
                                _showWords
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 18,
                              ),
                              label: Text(_showWords ? 'Hide' : 'Show'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 2.5,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: words.length,
                          itemBuilder: (context, index) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Bolt21Theme.darkBg,
                                borderRadius: BorderRadius.circular(8),
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
                                    child: Text(
                                      _showWords ? words[index] : '••••',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await SecureClipboard.copyWithTimeout(
                              context,
                              _mnemonic ?? '',
                              timeout: const Duration(seconds: 30),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copy to Clipboard (30s auto-clear)'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Backup confirmation
                CheckboxListTile(
                  value: _backedUp,
                  onChanged: (value) {
                    setState(() => _backedUp = value ?? false);
                  },
                  title: const Text(
                    'I have written down my recovery phrase',
                  ),
                  subtitle: const Text(
                    'I understand that losing it means losing access to my funds',
                    style: TextStyle(
                      color: Bolt21Theme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Bolt21Theme.orange,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),

                // Create button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _backedUp && !_isLoading ? _createWallet : null,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Create Wallet',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
