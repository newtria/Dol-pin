import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolpin/shared/widgets/dolpin_button.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('DolpinButton', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(DolpinButton(label: 'Test Button', onPressed: () {})),
      );
      expect(find.text('Test Button'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildTestWidget(
          DolpinButton(label: 'Tap Me', onPressed: () => tapped = true),
        ),
      );
      await tester.tap(find.text('Tap Me'));
      expect(tapped, isTrue);
    });

    testWidgets('disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(const DolpinButton(label: 'Disabled', onPressed: null)),
      );
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('shows loading indicator when isLoading', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          DolpinButton(label: 'Loading', onPressed: () {}, isLoading: true),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
