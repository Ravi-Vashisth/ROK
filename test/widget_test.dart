import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:billing_app/app.dart';

void main() {
  testWidgets(
    'DatabaseBootstrapApp renders explicit disk-error retry UI without silent in-memory fallback',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        DatabaseBootstrapApp(
          initialError: StateError('Simulated SQLite open failure'),
        ),
      );

      expect(find.text('Local Storage Unavailable'), findsOneWidget);
      expect(find.text('Retry Database Connection'), findsOneWidget);
      expect(find.textContaining('Simulated SQLite open failure'), findsOneWidget);
      expect(find.byIcon(Icons.storage_rounded), findsOneWidget);
    },
  );
}
