import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../services/operation_state_service.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import '../widgets/wallet_switcher.dart';
import 'receive_screen.dart';
import 'send_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Center(child: WalletSwitcher()),
        ),
        leadingWidth: 160,
        title: Image.asset(
          'assets/images/logo.png',
          height: 32,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
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
                      onPressed: () => wallet.refreshAll(),
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
                // Incomplete operations warning
                if (wallet.hasIncompleteOperations)
                  _IncompleteOperationsAlert(
                    operations: wallet.incompleteOperations,
                    onDismiss: () => wallet.clearIncompleteOperations(),
                  ),

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
                  icon: Icons.access_time,
                  label: 'Pending In',
                  value: formatSatsCompact(wallet.pendingReceiveSats),
                ),
                const SizedBox(width: 24),
                _BalanceChip(
                  icon: Icons.schedule_send,
                  label: 'Pending Out',
                  value: formatSatsCompact(wallet.pendingSendSats),
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

/// Alert banner for incomplete operations from previous session
class _IncompleteOperationsAlert extends StatelessWidget {
  final List<OperationState> operations;
  final VoidCallback onDismiss;

  const _IncompleteOperationsAlert({
    required this.operations,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final sendOps = operations.where((op) => op.isSend).toList();
    final hasPendingSends = sendOps.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasPendingSends
            ? Bolt21Theme.error.withValues(alpha: 0.1)
            : Bolt21Theme.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPendingSends
              ? Bolt21Theme.error.withValues(alpha: 0.3)
              : Bolt21Theme.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasPendingSends ? Icons.warning_amber : Icons.info_outline,
                color: hasPendingSends ? Bolt21Theme.error : Bolt21Theme.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasPendingSends
                      ? 'Payment May Be Pending'
                      : 'Interrupted Operations',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: hasPendingSends
                        ? Bolt21Theme.error
                        : Bolt21Theme.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasPendingSends
                ? 'A payment was interrupted. Check your transaction history before sending again to avoid double-paying.'
                : '${operations.length} operation(s) were interrupted. Your balance should still be correct.',
            style: const TextStyle(
              fontSize: 13,
              color: Bolt21Theme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          // Show each incomplete operation
          ...operations.map((op) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      op.isSend ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14,
                      color: Bolt21Theme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_operationTypeName(op.type)} - ${op.status.name}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Bolt21Theme.textSecondary,
                      ),
                    ),
                    if (op.amountSat != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${op.amountSat} sats',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Bolt21Theme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              )),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDismiss,
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _operationTypeName(OperationType type) {
    switch (type) {
      case OperationType.send:
        return 'Send';
      case OperationType.receiveBolt12:
        return 'Receive (BOLT12)';
      case OperationType.receiveOnchain:
        return 'Receive (On-chain)';
      case OperationType.receiveBolt11:
        return 'Receive (Invoice)';
    }
  }
}
