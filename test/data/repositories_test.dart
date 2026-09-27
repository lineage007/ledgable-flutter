import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgable_app/api/api_client.dart';
import 'package:ledgable_app/api/api_exception.dart';
import 'package:ledgable_app/api/models/invoice.dart';
import 'package:ledgable_app/api/models/receipt.dart';
import 'package:ledgable_app/api/token_store.dart';
import 'package:ledgable_app/data/approvals_repository.dart';
import 'package:ledgable_app/data/dashboard_repository.dart';
import 'package:ledgable_app/data/invoices_repository.dart';
import 'package:ledgable_app/data/receipts_repository.dart';
import 'package:ledgable_app/data/transactions_repository.dart';

import '../support/fake_http.dart';

void main() {
  late FakeHttpAdapter http;
  late ApiClient client;

  setUp(() async {
    http = FakeHttpAdapter();
    client = ApiClient(store: InMemoryTokenStore(), baseUrl: 'https://example.test/api/mobile/v1');
    client.useAdapter(http);
    await client.session.adopt(
      AuthTokens(
        accessToken: 'access-1',
        accessExpiresAt: DateTime.now().add(const Duration(minutes: 15)),
        refreshToken: 'refresh-1',
        refreshExpiresAt: DateTime.now().add(const Duration(days: 60)),
        deviceId: 'device-1',
      ),
    );
  });

  group('DashboardRepository', () {
    test('maps KPIs, aged totals and activity', () async {
      http.on('GET', '/dashboard', [
        FakeReply(200, {
          'workspace': {'id': 'ws-1', 'name': 'Salt & Stone Pty Ltd'},
          'kpis': {
            'cashPosition': 18450.25,
            'fyRevenue': 240000,
            'fyRevenueTrendPct': 12.4,
            'fyExpenses': 180000,
            'fyExpensesTrendPct': null,
            'fyNetProfit': 60000,
          },
          'receivables': {'total': 9200, 'count': 4, 'overdueTotal': 3100, 'overdueCount': 2},
          'payables': {'total': 4100, 'count': 3, 'overdueTotal': 0, 'overdueCount': 0},
          'monthlySeries': [
            {'month': '2026-08', 'income': 20000, 'expenses': 15000},
          ],
          'topExpenseCategories': [
            {'name': 'Subcontractors', 'value': 42000, 'pct': 23.3},
          ],
          'recentActivity': [
            {
              'id': 'txn-1',
              'date': '2026-09-20T02:00:00.000Z',
              'description': 'Bunnings Warehouse',
              'merchant': 'Bunnings',
              'amount': -184.30,
              'category': 'tools_small_equipment',
              'type': 'expense',
            },
          ],
        }),
      ]);

      final dashboard = await DashboardRepository(client).load();

      expect(dashboard.workspaceName, 'Salt & Stone Pty Ltd');
      expect(dashboard.kpis.cashPosition, 18450.25);
      expect(dashboard.kpis.fyRevenueTrendPct, 12.4);
      // Null must stay null, not become zero — see the KPI comment in the model.
      expect(dashboard.kpis.fyExpensesTrendPct, isNull);
      expect(dashboard.receivables.hasOverdue, isTrue);
      expect(dashboard.payables.hasOverdue, isFalse);
      expect(dashboard.recentActivity.single.isIncome, isFalse);
      expect(dashboard.monthlySeries.single.income, 20000);
    });

    test('survives a payload with every optional field missing', () async {
      http.on('GET', '/dashboard', [FakeReply(200, const <String, dynamic>{})]);

      final dashboard = await DashboardRepository(client).load();

      expect(dashboard.kpis.cashPosition, isNull);
      expect(dashboard.receivables.total, 0);
      expect(dashboard.recentActivity, isEmpty);
    });
  });

  group('TransactionsRepository', () {
    test('defaults to the needs-review queue and maps cents', () async {
      http.on('GET', '/transactions', [
        FakeReply(200, {
          'transactions': [
            {
              'id': 'txn-1',
              'merchant': 'Officeworks',
              'description': 'OFFICEWORKS 4821 SYDNEY',
              'total': -18430,
              'type': 'expense',
              'categoryCode': null,
              'createdAt': '2026-09-20T02:00:00.000Z',
            },
          ],
          'page': {'limit': 25, 'offset': 0, 'total': 41, 'hasMore': true},
        }),
      ]);

      final page = await TransactionsRepository(client).list();

      expect(http.requestsTo('GET', '/transactions').single.query['filter'], 'needs_review');
      final transaction = page.items.single;
      // Integer cents, not dollars — the one place the API is not a string.
      expect(transaction.totalCents, -18430);
      expect(transaction.amount, Decimal.parse('-184.30'));
      expect(transaction.needsReview, isTrue);
      // Merchant is the recognisable label; the bank's description is secondary.
      expect(transaction.title, 'Officeworks');
      expect(transaction.subtitle, 'OFFICEWORKS 4821 SYDNEY');
      expect(page.page.nextOffset, 25);
    });

    test('truncates an over-long search rather than failing validation', () async {
      http.on('GET', '/transactions', [
        FakeReply(200, {
          'transactions': [],
          'page': {'limit': 25, 'offset': 0, 'total': 0, 'hasMore': false},
        }),
      ]);

      await TransactionsRepository(client).list(search: 'x' * 200);

      expect(
        (http.requestsTo('GET', '/transactions').single.query['search'] as String).length,
        120,
      );
    });

    test('categorise returns the prior code so an undo can be offered', () async {
      http.on('POST', '/transactions/txn-1/categorise', [
        FakeReply(200, {
          'transactionId': 'txn-1',
          'previousCategoryCode': 'general_expenses',
          'categoryCode': 'tools_small_equipment',
        }),
      ]);

      final result = await TransactionsRepository(
        client,
      ).categorise(transactionId: 'txn-1', categoryCode: 'tools_small_equipment');

      expect(result.categoryCode, 'tools_small_equipment');
      expect(result.previousCategoryCode, 'general_expenses');
      expect(result.isUndoable, isTrue);
    });

    test('a first-time categorisation reports no prior code to undo to', () async {
      http.on('POST', '/transactions/txn-1/categorise', [
        FakeReply(200, {
          'transactionId': 'txn-1',
          'previousCategoryCode': null,
          'categoryCode': 'fuel',
        }),
      ]);

      final result = await TransactionsRepository(
        client,
      ).categorise(transactionId: 'txn-1', categoryCode: 'fuel');

      expect(result.isUndoable, isFalse);
    });

    test('derives category options from codes the workspace has actually used', () async {
      // There is no /categories endpoint, so the picker is built from real
      // usage. Most-used first.
      http.on('GET', '/transactions', [
        FakeReply(200, {
          'transactions': [
            {'id': 'a', 'categoryCode': 'fuel', 'createdAt': '2026-09-01T00:00:00.000Z'},
            {'id': 'b', 'categoryCode': 'fuel', 'createdAt': '2026-09-02T00:00:00.000Z'},
            {
              'id': 'c',
              'categoryCode': 'tools_small_equipment',
              'createdAt': '2026-09-03T00:00:00.000Z',
            },
            {'id': 'd', 'categoryCode': null, 'createdAt': '2026-09-04T00:00:00.000Z'},
          ],
          'page': {'limit': 100, 'offset': 0, 'total': 4, 'hasMore': false},
        }),
      ]);

      final options = await TransactionsRepository(client).usedCategories();

      expect(options.map((option) => option.code), ['fuel', 'tools_small_equipment']);
      expect(options.first.usageCount, 2);
      expect(options.first.label, 'Fuel');
      expect(options.last.label, 'Tools Small Equipment');
    });
  });

  group('InvoicesRepository', () {
    test('trusts the server-computed overdue flag', () async {
      http.on('GET', '/invoices', [
        FakeReply(200, {
          'invoices': [
            {
              'id': 'inv-1',
              'invoiceNumber': 'INV-0042',
              'status': 'authorised',
              'date': '2026-08-01T00:00:00.000Z',
              'dueDate': '2026-08-15T00:00:00.000Z',
              'total': '2750.00',
              'amountDue': '2750.00',
              'amountPaid': '0.00',
              'currencyCode': 'AUD',
              'sentToContact': true,
              'overdue': true,
              'contact': {'id': 'c-1', 'name': 'Harbour Cafe', 'email': 'accounts@harbour.test'},
            },
          ],
          'page': {'limit': 25, 'offset': 0, 'total': 1, 'hasMore': false},
        }),
      ]);

      final page = await InvoicesRepository(client).list();

      final invoice = page.items.single;
      expect(invoice.overdue, isTrue);
      expect(invoice.total, Decimal.parse('2750.00'));
      expect(invoice.status.label, 'Awaiting payment');
      expect(invoice.contactName, 'Harbour Cafe');
    });

    test('createDraft sends integer cents and a date-only due date', () async {
      http.on('POST', '/invoices', [
        FakeReply(201, {
          'invoice': {
            'id': 'inv-9',
            'invoiceNumber': 'INV-0043',
            'contactId': 'c-1',
            'total': '148.50',
            'status': 'draft',
          },
        }),
      ]);

      final created = await InvoicesRepository(client).createDraft(
        contactId: 'c-1',
        dueDate: DateTime(2026, 10, 11, 17, 30),
        lines: [
          DraftLine(
            description: 'Site visit',
            quantity: Decimal.fromInt(2),
            unitPrice: Decimal.parse('67.50'),
          ),
        ],
      );

      expect(created.invoiceNumber, 'INV-0043');
      expect(created.status, 'draft');
      final body = http.requestsTo('POST', '/invoices').single.json!;
      expect(body['dueDate'], '2026-10-11T00:00:00.000Z');
      final lines = body['lines'] as List;
      expect((lines.single as Map)['unitPriceCents'], 6750);
      expect((lines.single as Map)['quantity'], 2);
    });

    test('a draft line with sub-cent precision is refused, not rounded', () {
      final line = DraftLine(
        description: 'Hourly',
        quantity: Decimal.one,
        unitPrice: Decimal.parse('99.999'),
      );

      expect(line.toJson, throwsArgumentError);
    });

    test('send omits the body entirely when using the address on file', () async {
      http.on('POST', '/invoices/inv-1/send', [
        FakeReply(200, {
          'emailJobId': 'job-1',
          'invoice': {
            'id': 'inv-1',
            'invoiceNumber': 'INV-0042',
            'status': 'submitted',
            'sentToEmail': 'accounts@harbour.test',
          },
        }),
      ]);

      final result = await InvoicesRepository(client).send('inv-1');

      expect(result.sentToEmail, 'accounts@harbour.test');
      expect(result.status, 'submitted');
      expect(http.requestsTo('POST', '/invoices/inv-1/send').single.json, isNull);
    });

    test('send carries an override address when one is given', () async {
      http.on('POST', '/invoices/inv-1/send', [
        FakeReply(200, {
          'emailJobId': 'job-2',
          'invoice': {
            'id': 'inv-1',
            'invoiceNumber': 'INV-0042',
            'status': 'submitted',
            'sentToEmail': 'other@harbour.test',
          },
        }),
      ]);

      await InvoicesRepository(client).send('inv-1', sendToEmail: ' other@harbour.test ');

      expect(
        http.requestsTo('POST', '/invoices/inv-1/send').single.json?['sendToEmail'],
        'other@harbour.test',
      );
    });
  });

  group('ContactsRepository', () {
    test('defaults payment terms so a new invoice can propose a due date', () async {
      http.on('GET', '/contacts', [
        FakeReply(200, {
          'contacts': [
            {
              'id': 'c-1',
              'name': 'Harbour Cafe',
              'email': 'accounts@harbour.test',
              'paymentTermsDays': 30,
            },
            {'id': 'c-2', 'name': 'No Email Pty Ltd'},
          ],
          'page': {'limit': 25, 'offset': 0, 'total': 2, 'hasMore': false},
        }),
      ]);

      final page = await ContactsRepository(client).list(type: ContactType.customer);

      expect(http.requestsTo('GET', '/contacts').single.query['type'], 'customer');
      expect(page.items.first.paymentTermsDays, 30);
      expect(page.items.first.canBeEmailed, isTrue);
      // A contact with no address cannot be emailed an invoice; the send screen
      // asks for one rather than failing at the API.
      expect(page.items.last.canBeEmailed, isFalse);
      expect(page.items.last.paymentTermsDays, 14);
    });
  });

  group('ReceiptsRepository', () {
    test('sends archived as the literal string the API enum accepts', () async {
      http.on('GET', '/receipts', [
        FakeReply(200, {
          'receipts': [],
          'page': {'limit': 25, 'offset': 0, 'total': 0, 'hasMore': false},
        }),
      ]);

      await ReceiptsRepository(client).list();

      expect(http.requestsTo('GET', '/receipts').single.query['archived'], 'false');
    });

    test('maps an extraction and flags a low-confidence reading', () async {
      http.on('GET', '/receipts/r-1', [
        FakeReply(200, {
          'id': 'r-1',
          'fileName': 'receipt.jpg',
          'ocrStatus': 'COMPLETED',
          'createdAt': '2026-09-20T02:00:00.000Z',
          'retentionExpiresAt': '2033-09-20T02:00:00.000Z',
          'linkedTransactionIds': [],
          'extractions': [
            {
              'id': 'e-1',
              'vendor': 'Bunnings Warehouse',
              'totalAmount': '184.30',
              'taxAmount': '16.75',
              'transactionDate': '2026-09-19T00:00:00.000Z',
              'confidence': 0.62,
              'reviewStatus': 'EXTRACTED',
              'vendorAbn': '26008672179',
              'vendorGstRegistered': true,
              'fieldConfidence': {'vendor': 0.91, 'totalAmount': 0.55},
            },
          ],
        }),
      ]);

      final receipt = await ReceiptsRepository(client).detail('r-1');
      final extraction = receipt.canonical!;

      expect(receipt.ocrStatus, OcrStatus.completed);
      expect(receipt.ocrStatus.isTerminal, isTrue);
      expect(extraction.totalAmount, Decimal.parse('184.30'));
      expect(extraction.isLowConfidence, isTrue);
      expect(extraction.fieldConfidence.totalAmount, 0.55);
      // Seven-year Australian record-keeping deadline.
      expect(receipt.retentionExpiresAt?.year, 2033);
    });

    test('GST read off the receipt is checked against one eleventh of the total', () async {
      // $184.30 GST-inclusive implies $16.75 GST (1/11th), not $18.43. A till
      // that printed 10% of the inclusive figure overstates the credit.
      http.on('GET', '/receipts/r-1', [
        FakeReply(200, {
          'id': 'r-1',
          'fileName': 'r.jpg',
          'ocrStatus': 'COMPLETED',
          'extractions': [
            {'totalAmount': '184.30', 'taxAmount': '18.43'},
          ],
        }),
      ]);

      final extraction = (await ReceiptsRepository(client).detail('r-1')).canonical!;

      expect(extraction.impliedGst, Decimal.parse('16.75'));
      expect(extraction.gstLooksOff, isTrue);
    });

    test('a correct GST reading is not flagged', () async {
      http.on('GET', '/receipts/r-1', [
        FakeReply(200, {
          'id': 'r-1',
          'fileName': 'r.jpg',
          'ocrStatus': 'COMPLETED',
          'extractions': [
            {'totalAmount': '184.30', 'taxAmount': '16.75'},
          ],
        }),
      ]);

      final extraction = (await ReceiptsRepository(client).detail('r-1')).canonical!;

      expect(extraction.gstLooksOff, isFalse);
    });

    test('GST charged by a supplier that is not registered is flagged', () async {
      // A supplier that is not GST-registered cannot charge GST at all, so this
      // is a BAS problem rather than a rounding quirk.
      http.on('GET', '/receipts/r-1', [
        FakeReply(200, {
          'id': 'r-1',
          'fileName': 'r.jpg',
          'ocrStatus': 'COMPLETED',
          'extractions': [
            {'totalAmount': '110.00', 'taxAmount': '10.00', 'vendorGstRegistered': false},
          ],
        }),
      ]);

      final extraction = (await ReceiptsRepository(client).detail('r-1')).canonical!;

      expect(extraction.hasGstMismatch, isTrue);
    });

    test('upload posts multipart and returns the 202 poll handle', () async {
      final file = File('${Directory.systemTemp.path}/ledgable-test-receipt.jpg')
        ..writeAsBytesSync(List<int>.filled(2048, 7));
      addTearDown(() => file.existsSync() ? file.deleteSync() : null);

      http.on('POST', '/receipts', [
        FakeReply(202, {
          'receiptId': 'r-9',
          'ocrStatus': 'PENDING',
          'pollUrl': '/api/mobile/v1/receipts/r-9',
        }),
      ]);

      final accepted = await ReceiptsRepository(client).upload(file);

      expect(accepted.receiptId, 'r-9');
      expect(accepted.ocrStatus, OcrStatus.pending);
      final request = http.requestsTo('POST', '/receipts').single;
      expect(request.body.toString(), startsWith('stream:'));
      expect(request.headers['content-type'].toString(), contains('multipart/form-data'));
    });

    test('an upload interrupted by an expired token is replayed, not lost', () async {
      // The multipart body has already been streamed once at this point. It only
      // replays because the part is built from the file on disk and cloned.
      final file = File('${Directory.systemTemp.path}/ledgable-test-retry.jpg')
        ..writeAsBytesSync(List<int>.filled(4096, 3));
      addTearDown(() => file.existsSync() ? file.deleteSync() : null);

      http.on('POST', '/receipts', [
        FakeReply.error(401, code: ApiErrorCode.tokenExpired),
        FakeReply(202, {'receiptId': 'r-10', 'ocrStatus': 'PENDING', 'pollUrl': '/x'}),
      ]);
      http.on('POST', '/auth/refresh', [
        FakeReply(200, tokenPair(access: 'access-2', refresh: 'refresh-2')),
      ]);

      final accepted = await ReceiptsRepository(client).upload(file);

      expect(accepted.receiptId, 'r-10');
      final uploads = http.requestsTo('POST', '/receipts');
      expect(uploads, hasLength(2));
      // The replay carried the same bytes, so the receipt was not truncated.
      expect(uploads.last.body, uploads.first.body);
      expect(uploads.last.bearer, 'access-2');
    });

    test('polling backs off 1s, 2s, 4s, then 5s', () {
      expect(ReceiptsRepository.delayForAttempt(0), const Duration(seconds: 1));
      expect(ReceiptsRepository.delayForAttempt(1), const Duration(seconds: 2));
      expect(ReceiptsRepository.delayForAttempt(2), const Duration(seconds: 4));
      expect(ReceiptsRepository.delayForAttempt(3), const Duration(seconds: 5));
      expect(ReceiptsRepository.delayForAttempt(9), const Duration(seconds: 5));
    });

    test('polling stops at a terminal status', () async {
      http.on('GET', '/receipts/r-1', [
        FakeReply(200, {'id': 'r-1', 'fileName': 'r.jpg', 'ocrStatus': 'PROCESSING'}),
        FakeReply(200, {'id': 'r-1', 'fileName': 'r.jpg', 'ocrStatus': 'COMPLETED'}),
      ]);

      final statuses = await ReceiptsRepository(
        client,
      ).pollUntilSettled('r-1').map((receipt) => receipt.ocrStatus).toList();

      expect(statuses, [OcrStatus.processing, OcrStatus.completed]);
      expect(http.countOf('GET', '/receipts/r-1'), 2);
    });

    test('polling stops on SKIPPED — nothing further is coming', () async {
      http.on('GET', '/receipts/r-1', [
        FakeReply(200, {'id': 'r-1', 'fileName': 'r.pdf', 'ocrStatus': 'SKIPPED'}),
      ]);

      final statuses = await ReceiptsRepository(
        client,
      ).pollUntilSettled('r-1').map((receipt) => receipt.ocrStatus).toList();

      expect(statuses, [OcrStatus.skipped]);
      expect(http.countOf('GET', '/receipts/r-1'), 1);
    });
  });

  group('ApprovalsRepository', () {
    test('keeps server counts separate from the capped lists', () async {
      http.on('GET', '/approvals', [
        FakeReply(200, {
          'counts': {'bills': 40, 'payRuns': 1, 'leave': 2},
          'bills': [
            {
              'id': 'b-1',
              'billNumber': 'BILL-7',
              'status': 'submitted',
              'total': '990.00',
              'amountDue': '990.00',
              'currencyCode': 'AUD',
              'supplier': {'id': 's-1', 'name': 'Reece Plumbing'},
              'deepLink': '/bills/b-1',
            },
          ],
          'payRuns': [
            {
              'id': 'pr-1',
              'grossTotal': '12000.00',
              'taxTotal': '2800.00',
              'superTotal': '1440.00',
              'netTotal': '9200.00',
              'lifecycleStatus': 'CALCULATED',
              'deepLink': '/payroll/pay-runs/pr-1',
            },
          ],
          'leave': [
            {
              'id': 'l-1',
              'leaveType': 'PERSONAL',
              'startDate': '2026-10-01T00:00:00.000Z',
              'endDate': '2026-10-02T00:00:00.000Z',
              'hours': '7.60',
              'employee': {'id': 'e-1', 'name': 'Alex Tran'},
              'deepLink': '/payroll/leave/l-1',
            },
          ],
        }),
      ]);

      final approvals = await ApprovalsRepository(client).load();

      // 40 bills exist but the API caps the list at 25; reporting 1 would be a
      // lie about how much is waiting.
      expect(approvals.billCount, 40);
      expect(approvals.bills, hasLength(1));
      expect(approvals.totalCount, 43);
      expect(approvals.payRuns.single.superTotal, Decimal.parse('1440.00'));
      // PERSONAL is the single NES sick + carer's entitlement, not two.
      expect(approvals.leave.single.leaveType.label, "Personal / carer's leave");
      expect(approvals.leave.single.hoursLabel, '7.6 hours');
    });

    test('an empty queue is empty, not absent', () async {
      http.on('GET', '/approvals', [
        FakeReply(200, {
          'counts': {'bills': 0, 'payRuns': 0, 'leave': 0},
          'bills': [],
          'payRuns': [],
          'leave': [],
        }),
      ]);

      final approvals = await ApprovalsRepository(client).load();

      expect(approvals.isEmpty, isTrue);
    });
  });

  group('error surfacing', () {
    test('folds field issues into a message a user can act on', () async {
      http.on('POST', '/invoices', [
        FakeReply.error(
          400,
          code: ApiErrorCode.validationError,
          message: 'Invalid request',
          details: {
            'issues': [
              {'path': 'lines.0.unitPriceCents', 'message': 'Must be greater than 0'},
            ],
          },
        ),
      ]);

      await expectLater(
        InvoicesRepository(client).createDraft(
          contactId: 'c-1',
          dueDate: DateTime(2026, 10, 1),
          lines: [
            DraftLine(description: 'x', quantity: Decimal.one, unitPrice: Decimal.parse('1.00')),
          ],
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.displayMessage, 'displayMessage', contains('Must be greater than 0'))
              .having((e) => e.requestId, 'requestId', 'req_test'),
        ),
      );
    });

    test('a 429 carries the retry-after so the UI can say how long', () async {
      http.on('GET', '/dashboard', [
        FakeReply(429, {'error': 'rate_limited', 'message': 'Slow down', 'retryAfter': 42}),
      ]);

      await expectLater(
        DashboardRepository(client).load(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isRateLimited, 'isRateLimited', isTrue)
              .having((e) => e.retryAfter, 'retryAfter', 42),
        ),
      );
    });

    test('an HTML error page becomes a readable message, not a cast error', () async {
      http.on('GET', '/dashboard', [FakeReply(502, '<html>bad gateway</html>')]);

      await expectLater(
        DashboardRepository(client).load(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 502)),
      );
    });
  });
}
