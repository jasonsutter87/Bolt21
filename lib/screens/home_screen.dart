import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import 'receive_screen.dart';
import 'send_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _initWallet();
  }

  Future<void> _initWallet() async {
    final wallet = context.read<WalletProvider>();
    // TODO: Check for existing wallet, show onboarding if new
    await wallet.initializeWallet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bolt21'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Settings screen
            },
          ),
        ],
      ),
      body: Consumer<WalletProvider>(
        builder: (context, wallet, child) {
          if (wallet.isLoading && !wallet.isInitialized) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Bolt21Theme.orange),
                  SizedBox(height: 16),
                  Text('Starting Lightning node...'),
                ],
              ),
            );
          }

          if (wallet.error != null && !wallet.isInitialized) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Bolt21Theme.error),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to start node',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      wallet.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Bolt21Theme.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _initWallet,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => wallet.refreshAll(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Balance card
                _BalanceCard(wallet: wallet),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ReceiveScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_downward),
                        label: const Text('Receive'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SendScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_upward),
                        label: const Text('Send'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Transactions
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _TransactionList(payments: wallet.payments),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final WalletProvider wallet;

  const _BalanceCard({required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Total Balance',
              style: TextStyle(color: Bolt21Theme.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              formatSats(wallet.totalBalanceSats),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Bolt21Theme.orange,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _BalanceChip(
                  icon: Icons.link,
                  label: 'On-chain',
                  value: formatSatsCompact(wallet.onChainBalanceSats),
                ),
                const SizedBox(width: 24),
                _BalanceChip(
                  icon: Icons.bolt,
                  label: 'Lightning',
                  value: formatSatsCompact(wallet.lightningBalanceSats),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _BalanceChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Bolt21Theme.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Bolt21Theme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _TransactionList extends StatelessWidget {
  final List payments;

  const _TransactionList({required this.payments});

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: Bolt21Theme.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'No transactions yet',
                style: TextStyle(color: Bolt21Theme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: payments.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final payment = payments[index];
          // TODO: Render payment details
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Bolt21Theme.orange.withValues(alpha: 0.1),
              child: const Icon(Icons.bolt, color: Bolt21Theme.orange),
            ),
            title: const Text('Payment'),
            subtitle: Text(payment.toString()),
          );
        },
      ),
    );
  }
}
