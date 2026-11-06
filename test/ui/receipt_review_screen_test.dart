import 'package:flutter_test/flutter_test.dart';
import 'package:ledgable_app/ui/screens/receipt_review_screen.dart';

import '../support/fake_http.dart';
import '../support/fixtures.dart';
import '../support/harness.dart';

void main() {
  setUpAll(setUpFormatting);

  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.signedIn();
  });

  Future<void> pumpReceipt(WidgetTester tester, {required String taxAmount}) async {
    harness.http.on('GET', '/receipts/r-1', [
      FakeReply(200, receiptDetailPayload(taxAmount: taxAmount)),
    ]);
    useIPhoneSurface(tester);
    await tester.pumpWidget(
      harness.wrap(const ReceiptReviewScreen(receiptId: 'r-1'), me: testMe()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('less GST than one eleventh is not called an error', (tester) async {
    // $10 on $184.30: a shop mixing GST-free items. Saying GST "should be"
    // $16.75 would push the user to overclaim the credit.
    await pumpReceipt(tester, taxAmount: '10.00');

    expect(find.text('Less GST than a fully taxable total'), findsOneWidget);
    expect(find.textContaining('normal when some items are GST-free'), findsOneWidget);
    expect(find.text('The GST figure does not add up'), findsNothing);
  });

  testWidgets('more GST than one eleventh is flagged as not adding up', (tester) async {
    await pumpReceipt(tester, taxAmount: '18.43');

    expect(find.text('The GST figure does not add up'), findsOneWidget);
    expect(find.textContaining('can be at most \$16.75'), findsOneWidget);
  });
}
