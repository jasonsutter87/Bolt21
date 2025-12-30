import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/wallet_metadata.dart';
import '../providers/wallet_provider.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';

/// Wallet switcher widget for AppBar
/// Displays current wallet name and opens selector on tap
class WalletSwitcher extends StatelessWidget {
  const WalletSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, wallet, child) {
        final activeWallet = wallet.activeWallet;
        if (activeWallet == null) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () => _showWalletSelector(context, wallet),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Bolt21Theme.darkCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Bolt21Theme.darkBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  size: 16,
                  color: Bolt21Theme.orange,
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    activeWallet.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Bolt21Theme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: Bolt21Theme.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWalletSelector(BuildContext context, WalletProvider wallet) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Bolt21Theme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _WalletSelectorSheet(wallet: wallet),
    );
  }
}

class _WalletSelectorSheet extends StatelessWidget {
  final WalletProvider wallet;

  const _WalletSelectorSheet({required this.wallet});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Bolt21Theme.darkBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Wallets',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Bolt21Theme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Wallet list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: wallet.wallets.length,
              itemBuilder: (context, index) {
                final w = wallet.wallets[index];
                final isActive = w.id == wallet.activeWallet?.id;
                return _WalletListItem(
                  wallet: w,
                  isActive: isActive,
                  balance: isActive ? wallet.totalBalanceSats : null,
                  onTap: () async {
                    if (!isActive) {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context);
                      await wallet.switchWallet(w.id);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Add wallet button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showAddWalletOptions(context);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Wallet'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddWalletOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Bolt21Theme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Bolt21Theme.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Bolt21Theme.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Bolt21Theme.orange),
              ),
              title: const Text('Create New Wallet'),
              subtitle: const Text('Generate a new seed phrase'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/create-wallet', arguments: {'addWallet': true});
              },
            ),
            const Divider(color: Bolt21Theme.darkBorder),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Bolt21Theme.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.file_download_outlined, color: Bolt21Theme.orange),
              ),
              title: const Text('Import Existing Wallet'),
              subtitle: const Text('Restore from seed phrase'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/restore-wallet', arguments: {'addWallet': true});
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _WalletListItem extends StatelessWidget {
  final WalletMetadata wallet;
  final bool isActive;
  final int? balance;
  final VoidCallback onTap;

  const _WalletListItem({
    required this.wallet,
    required this.isActive,
    this.balance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive
            ? Bolt21Theme.orange.withValues(alpha: 0.1)
            : Bolt21Theme.darkBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Bolt21Theme.orange : Bolt21Theme.darkBorder,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive
                ? Bolt21Theme.orange
                : Bolt21Theme.darkCard,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.bolt,
            size: 20,
            color: isActive ? Colors.black : Bolt21Theme.textSecondary,
          ),
        ),
        title: Text(
          wallet.name,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: Bolt21Theme.textPrimary,
          ),
        ),
        subtitle: balance != null
            ? Text(
                formatSats(balance!),
                style: const TextStyle(
                  color: Bolt21Theme.textSecondary,
                  fontSize: 12,
                ),
              )
            : null,
        trailing: isActive
            ? const Icon(Icons.check_circle, color: Bolt21Theme.orange)
            : const Icon(Icons.chevron_right, color: Bolt21Theme.textSecondary),
      ),
    );
  }
}
