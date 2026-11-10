import 'package:flutter_test/flutter_test.dart';
import 'package:convoyguard/main.dart';

void main() {
  testWidgets('App loads splash screen title test', (WidgetTester tester) async {
    // Build our app and trigger initial frame.
    await tester.pumpWidget(const ConvoyGuardApp());

    // Verify that ConvoyGuard branding text exists on splash screen
    expect(find.text('CONVOYGUARD'), findsOneWidget);

    // Advance timers so pending splash screen navigation completes cleanly
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();
  });
}
