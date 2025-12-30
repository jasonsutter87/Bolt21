import 'package:flutter/material.dart';
import 'package:flutter_breez_liquid/flutter_breez_liquid.dart';
import 'package:provider/provider.dart';
import 'providers/wallet_provider.dart';
import 'services/auth_service.dart';
import 'utils/theme.dart';
import 'screens/create_wallet_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/manage_wallets_screen.dart';
import 'screens/restore_wallet_screen.dart';
import 'screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the Breez SDK Rust library
  await FlutterBreezLiquid.init();

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
        routes: {
          '/create-wallet': (context) {
            final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
            return CreateWalletScreen(addWallet: args?['addWallet'] ?? false);
          },
          '/restore-wallet': (context) {
            final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
            return RestoreWalletScreen(addWallet: args?['addWallet'] ?? false);
          },
          '/manage-wallets': (context) => const ManageWalletsScreen(),
        },
      ),
    );
  }
}

/// Routes to welcome, lock, or home based on wallet and auth state
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _hasWallet = false;
  bool _isLocked = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkWalletStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lock app when it goes to background (if biometric is enabled)
    if (state == AppLifecycleState.paused && _biometricEnabled && _hasWallet) {
      setState(() => _isLocked = true);
    }
  }

  Future<void> _checkWalletStatus() async {
    final biometricEnabled = await AuthService.isBiometricEnabled();

    // Load wallets (handles migration from single-wallet automatically)
    final wallet = context.read<WalletProvider>();
    await wallet.loadWallets();

    final hasWallet = wallet.wallets.isNotEmpty;

    if (mounted) {
      setState(() {
        _hasWallet = hasWallet;
        _biometricEnabled = biometricEnabled;
        _isLocked = biometricEnabled && hasWallet;
        _isLoading = false;
      });
    }
  }

  void _onUnlocked() {
    setState(() => _isLocked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: Bolt21Theme.orange),
            ],
          ),
        ),
      );
    }

    // No wallet - show welcome
    if (!_hasWallet) {
      return const WelcomeScreen();
    }

    // Wallet exists but locked - show lock screen
    if (_isLocked) {
      return LockScreen(onUnlocked: _onUnlocked);
    }

    // Wallet exists and unlocked - show home
    return const HomeScreen();
  }
}
