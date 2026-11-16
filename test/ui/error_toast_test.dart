import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgable_app/theme.dart';
import 'package:ledgable_app/ui/widgets/common.dart';

/// The new-invoice form reports its own checks ("Add at least one line with an
/// amount.") through these toasts. Routed through [showErrorToast] as a
/// `StateError`, every one of them read "Something went wrong. Try again."
void main() {
  Future<void> tapToShow(WidgetTester tester, void Function(BuildContext) show) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ledgableTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) =>
                TextButton(onPressed: () => show(context), child: const Text('go')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
  }

  testWidgets('the app\'s own guidance is shown word for word', (tester) async {
    await tapToShow(
      tester,
      (context) => showErrorMessage(context, 'Add at least one line with an amount.'),
    );

    expect(find.text('Add at least one line with an amount.'), findsOneWidget);
    expect(find.textContaining('Something went wrong'), findsNothing);
  });

  testWidgets('an unexpected error stays generic rather than leaking internals', (tester) async {
    await tapToShow(tester, (context) => showErrorToast(context, StateError('No element')));

    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    expect(find.textContaining('No element'), findsNothing);
  });
}
