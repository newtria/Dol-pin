import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolpin/shared/widgets/safe_badge.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('SafeBadge', () {
    testWidgets('renders custom label with shield icon', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const SafeBadge(label: 'Escrow Protected'),
      ));
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(find.text('Escrow Protected'), findsOneWidget);
    });

    testWidgets('compact mode uses smaller size', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const SafeBadge(label: 'Safe', compact: true),
      ));
      final icon = tester.widget<Icon>(find.byIcon(Icons.shield_outlined));
      expect(icon.size, 12);
    });

    testWidgets('normal mode uses larger size', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const SafeBadge(label: 'Safe', compact: false),
      ));
      final icon = tester.widget<Icon>(find.byIcon(Icons.shield_outlined));
      expect(icon.size, 14);
    });
  });
}
