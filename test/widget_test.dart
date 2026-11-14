import 'package:flutter_test/flutter_test.dart';
import 'package:gallery_app/main.dart';

void main() {
  testWidgets('Document Hub initial smoke test', (WidgetTester tester) async {
    // Build our app and advance through splash timers.
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Verify MaterialApp loads
    expect(find.byType(MyApp), findsOneWidget);
  });
}
