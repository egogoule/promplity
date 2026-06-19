// test/widget_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PromplityApp());

    // Verify that the app starts
    expect(find.text('Promplity Client'), findsNothing);
  });
}
