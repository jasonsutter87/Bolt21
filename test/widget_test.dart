import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:bolt21/screens/home_screen.dart';
import 'package:bolt21/providers/wallet_provider.dart';
import 'package:bolt21/utils/theme.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: Bolt21Theme.darkTheme,
        home: ChangeNotifierProvider(
          create: (_) => WalletProvider(),
          child: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Home screen should show key elements
    expect(find.text('Total Balance'), findsOneWidget);
  });
}
