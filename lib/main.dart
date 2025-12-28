import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/wallet_provider.dart';
import 'services/secure_storage_service.dart';
import 'utils/theme.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bolt21App());
}

class Bolt21App extends StatelessWidget {
  const Bolt21App({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WalletProvider(),
      child: MaterialApp(
        title: 'Bolt21',
        debugShowCheckedModeBanner: false,
        theme: Bolt21Theme.darkTheme,
        home: const AppRouter(),
      ),
    );
  }
}

/// Routes to welcome or home based on wallet state
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  bool _isLoading = true;
  bool _hasWallet = false;

  @override
  void initState() {
    super.initState();
    _checkWalletStatus();
  }

  Future<void> _checkWalletStatus() async {
    final hasWallet = await SecureStorageService.hasWallet();

    if (hasWallet) {
      // Auto-load existing wallet
      final mnemonic = await SecureStorageService.getMnemonic();
      if (mnemonic != null && mounted) {
        final wallet = context.read<WalletProvider>();
        await wallet.initializeWallet(mnemonic: mnemonic);
      }
    }

    if (mounted) {
      setState(() {
        _hasWallet = hasWallet;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Bolt21Theme.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bolt,
                  size: 40,
                  color: Bolt21Theme.orange,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: Bolt21Theme.orange),
            ],
          ),
        ),
      );
    }

    return _hasWallet ? const HomeScreen() : const WelcomeScreen();
  }
}
