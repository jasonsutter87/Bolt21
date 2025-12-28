import 'package:flutter_test/flutter_test.dart';
import 'package:bolt21/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const Bolt21App());
    expect(find.text('Bolt21'), findsOneWidget);
  });
}
