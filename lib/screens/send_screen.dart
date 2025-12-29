import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/theme.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _controller = TextEditingController();
  final _amountController = TextEditingController();
  bool _isScanning = false;
  String? _paymentType;

  @override
  void dispose() {
    _controller.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _detectPaymentType(String input) {
    final lower = input.toLowerCase().trim();
    setState(() {
      if (lower.startsWith('lno')) {
        _paymentType = 'BOLT12 Offer';
      } else if (lower.startsWith('lnbc') || lower.startsWith('lntb')) {
        _paymentType = 'BOLT11 Invoice';
      } else if (lower.startsWith('bitcoin:') || lower.startsWith('bc1') || lower.startsWith('1') || lower.startsWith('3')) {
        _paymentType = 'On-chain';
      } else {
        _paymentType = null;
      }
    });
  }

  Future<void> _handlePay() async {
    final wallet = context.read<WalletProvider>();
    final input = _controller.text.trim();

    if (input.isEmpty) return;

    // Parse amount if provided (for BOLT12 offers)
    BigInt? amountSat;
    if (_amountController.text.isNotEmpty) {
      final parsed = int.tryParse(_amountController.text.trim());
      if (parsed == null || parsed <= 0 || parsed > 2100000000000000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid amount. Must be between 1 and 21M BTC in sats.'),
            backgroundColor: Bolt21Theme.error,
          ),
        );
        return;
      }
      amountSat = BigInt.from(parsed);
    }

    // Use idempotent method to prevent double-spend on rapid taps
    // Returns operation ID on success, null on failure
    final operationId = await wallet.sendPaymentIdempotent(input, amountSat: amountSat);

    if (operationId != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment sent!'),
          backgroundColor: Bolt21Theme.success,
        ),
      );
      Navigator.pop(context);
    } else if (wallet.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${wallet.error}'),
          backgroundColor: Bolt21Theme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send'),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.edit : Icons.qr_code_scanner),
            onPressed: () {
              setState(() {
                _isScanning = !_isScanning;
              });
            },
          ),
        ],
      ),
      body: _isScanning ? _buildScanner() : _buildManualInput(),
    );
  }

  /// Validate and sanitize QR code content to prevent injection attacks
  String? _validateQrCode(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) return null;

    // Limit QR code size to prevent DoS (max 4KB is generous for any valid payment)
    const maxLength = 4096;
    if (rawValue.length > maxLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR code too large. Maximum 4KB allowed.'),
          backgroundColor: Bolt21Theme.error,
        ),
      );
      return null;
    }

    // Basic sanitization - remove control characters except newlines
    final sanitized = rawValue.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    // Validate it looks like a valid payment destination
    final lower = sanitized.toLowerCase().trim();
    final isValidPrefix = lower.startsWith('lno') ||      // BOLT12 offer
        lower.startsWith('lnbc') ||                        // BOLT11 mainnet
        lower.startsWith('lntb') ||                        // BOLT11 testnet
        lower.startsWith('bitcoin:') ||                    // BIP21 URI
        lower.startsWith('bc1') ||                         // Bech32 address
        lower.startsWith('1') ||                           // Legacy P2PKH
        lower.startsWith('3') ||                           // P2SH address
        lower.contains('@');                               // Lightning address

    if (!isValidPrefix) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid QR code. Not a valid payment destination.'),
          backgroundColor: Bolt21Theme.error,
        ),
      );
      return null;
    }

    return sanitized.trim();
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              final validated = _validateQrCode(barcode.rawValue);
              if (validated != null) {
                setState(() {
                  _controller.text = validated;
                  _isScanning = false;
                });
                _detectPaymentType(validated);
                break;
              }
            }
          },
        ),
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Scan a QR code',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualInput() {
    return Consumer<WalletProvider>(
      builder: (context, wallet, child) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Input field
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Invoice or Offer',
                hintText: 'Paste BOLT12 offer, BOLT11 invoice, or Bitcoin address',
                alignLabelWithHint: true,
              ),
              onChanged: _detectPaymentType,
            ),
            const SizedBox(height: 12),

            // Payment type indicator
            if (_paymentType != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Bolt21Theme.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Bolt21Theme.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _paymentType == 'On-chain' ? Icons.link : Icons.bolt,
                      size: 16,
                      color: Bolt21Theme.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _paymentType!,
                      style: const TextStyle(color: Bolt21Theme.orange),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Amount field (for BOLT12 offers that accept any amount)
            if (_paymentType == 'BOLT12 Offer') ...[
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (sats)',
                  hintText: 'Enter amount to send',
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Pay button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: wallet.isLoading || _controller.text.isEmpty
                    ? null
                    : _handlePay,
                child: wallet.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text('Pay', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 16),

            // Balance info
            Center(
              child: Text(
                'Available: ${wallet.totalBalanceSats} sats',
                style: const TextStyle(color: Bolt21Theme.textSecondary),
              ),
            ),
          ],
        );
      },
    );
  }
}
