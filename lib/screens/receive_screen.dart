import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;
import '../providers/wallet_provider.dart';
import '../utils/theme.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Bolt21Theme.orange,
          labelColor: Bolt21Theme.orange,
          unselectedLabelColor: Bolt21Theme.textSecondary,
          tabs: const [
            Tab(text: 'BOLT12 Offer'),
            Tab(text: 'On-chain'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _Bolt12Tab(),
          _OnChainTab(),
        ],
      ),
    );
  }
}

/// BOLT12 Offer tab - reusable Lightning address
class _Bolt12Tab extends StatefulWidget {
  const _Bolt12Tab();

  @override
  State<_Bolt12Tab> createState() => _Bolt12TabState();
}

class _Bolt12TabState extends State<_Bolt12Tab> {
  final _noteController = TextEditingController();
  String? _savedNote;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, wallet, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                Icons.bolt,
                size: 48,
                color: Bolt21Theme.orange,
              ),
              const SizedBox(height: 16),
              Text(
                'BOLT12 Offer',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Share this once. Receive payments forever.',
                style: TextStyle(color: Bolt21Theme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              if (wallet.bolt12Offer == null) ...[
                // Note input field
                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'e.g., Ocean Mining Payout',
                    hintStyle: TextStyle(
                      color: Bolt21Theme.textSecondary.withValues(alpha: 0.5),
                    ),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                  ),
                  maxLength: 100,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: wallet.isLoading
                        ? null
                        : () {
                            setState(() {
                              _savedNote = _noteController.text.isNotEmpty
                                  ? _noteController.text
                                  : null;
                            });
                            wallet.generateBolt12Offer();
                          },
                    child: wallet.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Generate Offer'),
                  ),
                ),
              ] else ...[
                // Show note if provided
                if (_savedNote != null && _savedNote!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Bolt21Theme.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Bolt21Theme.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.note_alt,
                          color: Bolt21Theme.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _savedNote!,
                            style: const TextStyle(
                              color: Bolt21Theme.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _QrCard(
                  data: wallet.bolt12Offer!,
                  label: 'Scan to pay',
                ),
                const SizedBox(height: 16),
                _ActionButtons(data: wallet.bolt12Offer!),
                const SizedBox(height: 50),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// On-chain Bitcoin address tab
class _OnChainTab extends StatelessWidget {
  const _OnChainTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, wallet, child) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                Icons.link,
                size: 48,
                color: Bolt21Theme.orange,
              ),
              const SizedBox(height: 16),
              Text(
                'Bitcoin Address',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Receive on-chain Bitcoin',
                style: TextStyle(color: Bolt21Theme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              if (wallet.onChainAddress == null) ...[
                ElevatedButton(
                  onPressed: wallet.isLoading
                      ? null
                      : () => wallet.generateOnChainAddress(),
                  child: wallet.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Generate Address'),
                ),
              ] else ...[
                Expanded(
                  child: _QrCard(
                    data: 'bitcoin:${wallet.onChainAddress!}',
                    label: wallet.onChainAddress!,
                  ),
                ),
                const SizedBox(height: 16),
                _ActionButtons(data: wallet.onChainAddress!),
                const SizedBox(height: 50),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _QrCard extends StatelessWidget {
  final String data;
  final String label;

  const _QrCard({required this.data, required this.label});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: data,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Bolt21Theme.darkBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _truncate(label, 32),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Bolt21Theme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _truncate(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max ~/ 2)}...${s.substring(s.length - max ~/ 2)}';
  }
}

class _ActionButtons extends StatelessWidget {
  final String data;

  const _ActionButtons({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: data));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                  backgroundColor: Bolt21Theme.success,
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              SharePlus.instance.share(ShareParams(text: data));
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ),
      ],
    );
  }
}
