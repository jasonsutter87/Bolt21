import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/wallet_provider.dart';
import 'utils/theme.dart';
import 'screens/home_screen.dart';

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
        home: const HomeScreen(),
      ),
    );
  }
}
