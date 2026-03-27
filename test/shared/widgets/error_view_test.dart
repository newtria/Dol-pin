import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolpin/shared/widgets/error_view.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('ErrorView', () {
    testWidgets('shows error message', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const ErrorView(message: 'Something went wrong'),
      ));
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows retry button when onRetry is provided', (tester) async {
      var retried = false;
      await tester.pumpWidget(buildTestWidget(
        ErrorView(
          message: 'Error',
          onRetry: () => retried = true,
        ),
      ));
      final retryButton = find.byType(TextButton);
      expect(retryButton, findsOneWidget);
      await tester.tap(retryButton);
      expect(retried, isTrue);
    });

    testWidgets('hides retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const ErrorView(message: 'Error'),
      ));
      expect(find.byType(TextButton), findsNothing);
    });
  });
}
