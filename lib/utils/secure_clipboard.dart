import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';

/// Secure clipboard utility for handling sensitive data
///
/// SECURITY: Implements auto-clear timeout and security warnings
/// to prevent clipboard-based attacks on sensitive data like mnemonics.
class SecureClipboard {
  static Timer? _clearTimer;
  static int _copyId = 0; // Track copy operations to prevent race conditions

  /// Copy sensitive data with auto-clear and security warning
  ///
  /// Shows a warning dialog explaining clipboard risks, then copies
  /// the data and auto-clears it after [timeout].
  static Future<void> copyWithTimeout(
    BuildContext context,
    String text, {
    Duration timeout = const Duration(seconds: 30),
    bool showWarning = true,
  }) async {
    if (showWarning) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Bolt21Theme.error),
              const SizedBox(width: 12),
              const Text('Security Warning'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your recovery phrase will be copied to clipboard for ${30} seconds.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('⚠️ SECURITY RISKS:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildWarningItem('Other apps may be able to read it'),
                _buildWarningItem('Clipboard may sync to cloud (iCloud, Google)'),
                _buildWarningItem('Keyboard apps may store clipboard history'),
                _buildWarningItem('Clipboard persists until cleared'),
                const SizedBox(height: 16),
                const Text('✅ RECOMMENDATIONS:', style: TextStyle(fontWeight: FontWeight.bold, color: Bolt21Theme.success)),
                const SizedBox(height: 8),
                _buildRecommendation('Only copy if absolutely necessary'),
                _buildRecommendation('Paste immediately into secure storage'),
                _buildRecommendation('Ensure no malicious apps are running'),
                _buildRecommendation('Close unnecessary apps before copying'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Bolt21Theme.orange,
              ),
              child: const Text('I Understand - Copy'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    // SECURITY: Cancel any existing timer first to prevent race conditions
    _clearTimer?.cancel();
    _clearTimer = null;

    // Increment copy ID to track this specific copy operation
    _copyId++;
    final thisCopyId = _copyId;

    // Copy to clipboard
    await Clipboard.setData(ClipboardData(text: text));

    // Auto-clear after timeout - but only if no new copy has occurred
    _clearTimer = Timer(timeout, () async {
      // Only clear if this is still the most recent copy operation
      // This prevents race conditions where a new copy's timer gets cleared
      if (_copyId == thisCopyId) {
        await Clipboard.setData(const ClipboardData(text: ''));
        _clearTimer = null;
      }
    });

    // Show countdown snackbar
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.timer, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Copied! Will auto-clear in ${timeout.inSeconds}s',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          duration: Duration(seconds: (timeout.inSeconds * 0.75).round()),
          backgroundColor: Bolt21Theme.orange,
          action: SnackBarAction(
            label: 'Clear Now',
            textColor: Colors.white,
            onPressed: () => clear(),
          ),
        ),
      );
    }
  }

  static Widget _buildWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Bolt21Theme.error)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Bolt21Theme.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildRecommendation(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Bolt21Theme.success)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Bolt21Theme.success, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Clear clipboard immediately
  static Future<void> clear() async {
    _clearTimer?.cancel();
    _clearTimer = null;
    await Clipboard.setData(const ClipboardData(text: ''));
  }
}
