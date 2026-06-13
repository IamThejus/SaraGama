// Smoke test.
//
// The full app (YTPlayerApp) boots Hive boxes and the audio service in main(),
// which aren't available in a plain widget test, so this verifies a minimal
// widget tree renders instead. Replace with integration tests for real flows.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp renders a basic tree', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('SaraGama'))),
      ),
    );
    expect(find.text('SaraGama'), findsOneWidget);
  });
}
