/// Canned API payloads for widget and golden tests.
///
/// Realistic Australian small-business data — a trades workspace with an
/// overdue invoice, a GST-bearing receipt and a pay run awaiting sign-off — so a
/// golden catches a layout that only works on tidy numbers.
library;

Map<String, dynamic> dashboardPayload() => {
  'workspace': {'id': 'ws-1', 'name': 'Salt & Stone Pty Ltd'},
  // Explicitly dynamic so a test can null a field out; a bare literal here
  // would infer Map<String, num> and reject the assignment.
  'kpis': <String, dynamic>{
    'cashPosition': 18450.25,
    'fyRevenue': 246800,
    'fyRevenueTrendPct': 12.4,
    'fyExpenses': 181200.5,
    'fyExpensesTrendPct': 4.2,
    'fyNetProfit': 65599.5,
    'fyNetProfitTrendPct': 31.8,
  },
  'receivables': <String, dynamic>{
    'total': 9240.5,
    'count': 4,
    'overdueTotal': 3080.0,
    'overdueCount': 2,
  },
  'payables': <String, dynamic>{'total': 4120.0, 'count': 3, 'overdueTotal': 0, 'overdueCount': 0},
  'monthlySeries': [
    for (var month = 1; month <= 12; month++)
      {
        'month': '2026-${month.toString().padLeft(2, '0')}',
        'income': 18000 + month * 420,
        'expenses': 13500 + month * 260,
      },
  ],
  'topExpenseCategories': [
    {'name': 'Subcontractors', 'value': 42300, 'pct': 23.3},
    {'name': 'Materials & parts', 'value': 38900, 'pct': 21.5},
    {'name': 'Fuel', 'value': 12400, 'pct': 6.8},
  ],
  'recentActivity': [
    {
      'id': 'txn-1',
      'date': '2026-09-24T02:00:00.000Z',
      'description': 'BUNNINGS 4821 ALEXANDRIA',
      'merchant': 'Bunnings Warehouse',
      'amount': -184.30,
      'category': 'materials_and_parts',
      'type': 'expense',
    },
    {
      'id': 'txn-2',
      'date': '2026-09-23T02:00:00.000Z',
      'description': 'Payment — Harbour Cafe',
      'merchant': 'Harbour Cafe',
      'amount': 2750.00,
      'category': 'labour_income',
      'type': 'income',
    },
  ],
};

Map<String, dynamic> reviewQueuePayload() => {
  'transactions': [
    {
      'id': 'txn-a',
      'merchant': 'Officeworks',
      'description': 'OFFICEWORKS 4821 SYDNEY NSW',
      'total': -18430,
      'currencyCode': 'AUD',
      'type': 'expense',
      'categoryCode': null,
      'issuedAt': '2026-09-24T02:00:00.000Z',
      'createdAt': '2026-09-24T02:00:00.000Z',
    },
    {
      'id': 'txn-b',
      'merchant': 'Reece Plumbing',
      'description': 'REECE 0182 MARRICKVILLE',
      'total': -134290,
      'currencyCode': 'AUD',
      'type': 'expense',
      'categoryCode': null,
      'issuedAt': '2026-09-23T02:00:00.000Z',
      'createdAt': '2026-09-23T02:00:00.000Z',
    },
    {
      'id': 'txn-c',
      'merchant': 'Ampol',
      'total': -9855,
      'type': 'expense',
      'categoryCode': null,
      'createdAt': '2026-09-22T02:00:00.000Z',
    },
  ],
  'page': {'limit': 25, 'offset': 0, 'total': 3, 'hasMore': false},
};

/// `filter=all`, which the category picker samples for used codes.
Map<String, dynamic> categorisedTransactionsPayload() => {
  'transactions': [
    {'id': 'h-1', 'categoryCode': 'materials_and_parts', 'createdAt': '2026-09-01T00:00:00.000Z'},
    {'id': 'h-2', 'categoryCode': 'materials_and_parts', 'createdAt': '2026-09-02T00:00:00.000Z'},
    {'id': 'h-3', 'categoryCode': 'materials_and_parts', 'createdAt': '2026-09-03T00:00:00.000Z'},
    {'id': 'h-4', 'categoryCode': 'fuel', 'createdAt': '2026-09-04T00:00:00.000Z'},
    {'id': 'h-5', 'categoryCode': 'subcontractor_costs', 'createdAt': '2026-09-05T00:00:00.000Z'},
  ],
  'page': {'limit': 100, 'offset': 0, 'total': 5, 'hasMore': false},
};

Map<String, dynamic> invoiceListPayload() => {
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
    {
      'id': 'inv-2',
      'invoiceNumber': 'INV-0043',
      'status': 'draft',
      'date': '2026-09-20T00:00:00.000Z',
      'dueDate': '2026-10-04T00:00:00.000Z',
      'total': '1485.00',
      'amountDue': '1485.00',
      'amountPaid': '0.00',
      'currencyCode': 'AUD',
      'sentToContact': false,
      'overdue': false,
      'contact': {'id': 'c-2', 'name': 'Northside Strata', 'email': 'ap@northside.test'},
    },
    {
      'id': 'inv-3',
      'invoiceNumber': 'INV-0041',
      'status': 'paid',
      'date': '2026-07-10T00:00:00.000Z',
      'dueDate': '2026-07-24T00:00:00.000Z',
      'total': '6380.00',
      'amountDue': '0.00',
      'amountPaid': '6380.00',
      'currencyCode': 'AUD',
      'sentToContact': true,
      'overdue': false,
      'contact': {'id': 'c-3', 'name': 'Gladesville Builders', 'email': 'admin@gbuild.test'},
    },
  ],
  'page': {'limit': 25, 'offset': 0, 'total': 3, 'hasMore': false},
};

Map<String, dynamic> approvalsPayload() => {
  'counts': {'bills': 2, 'payRuns': 1, 'leave': 1},
  'bills': [
    {
      'id': 'b-1',
      'billNumber': 'BILL-0117',
      'status': 'submitted',
      'date': '2026-09-10T00:00:00.000Z',
      'dueDate': '2026-09-30T00:00:00.000Z',
      'total': '990.00',
      'amountDue': '990.00',
      'currencyCode': 'AUD',
      'supplier': {'id': 's-1', 'name': 'Reece Plumbing'},
      'deepLink': '/bills/b-1',
    },
    {
      'id': 'b-2',
      'billNumber': 'BILL-0118',
      'status': 'submitted',
      'dueDate': '2026-10-08T00:00:00.000Z',
      'total': '2310.55',
      'amountDue': '2310.55',
      'currencyCode': 'AUD',
      'supplier': {'id': 's-2', 'name': 'Tradelink'},
      'deepLink': '/bills/b-2',
    },
  ],
  'payRuns': [
    {
      'id': 'pr-1',
      'periodStart': '2026-09-08T00:00:00.000Z',
      'periodEnd': '2026-09-21T00:00:00.000Z',
      'payDate': '2026-09-25T00:00:00.000Z',
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
      'endDate': '2026-10-01T00:00:00.000Z',
      'hours': '7.60',
      'notes': 'Dentist, back in the afternoon if it is quick.',
      'employee': {'id': 'e-1', 'name': 'Alex Tran'},
      'deepLink': '/payroll/leave/l-1',
    },
  ],
};

Map<String, dynamic> receiptDetailPayload({
  double confidence = 0.94,
  String taxAmount = '16.75',
  bool? vendorGstRegistered = true,
}) => {
  'id': 'r-1',
  'fileName': 'receipt-2026-09-24.jpg',
  'mimeType': 'image/jpeg',
  'fileSize': 184320,
  'ocrStatus': 'COMPLETED',
  'archived': false,
  'createdAt': '2026-09-24T02:10:00.000Z',
  'retentionExpiresAt': '2033-09-24T02:10:00.000Z',
  'linkedTransactionIds': [],
  'extractions': [
    {
      'id': 'e-1',
      'vendor': 'Bunnings Warehouse',
      'totalAmount': '184.30',
      'taxAmount': taxAmount,
      'transactionDate': '2026-09-24T00:00:00.000Z',
      'confidence': confidence,
      'reviewStatus': 'EXTRACTED',
      'extractedAt': '2026-09-24T02:10:20.000Z',
      'provider': 'textract',
      'vendorAbn': '26008672179',
      'vendorGstRegistered': vendorGstRegistered,
      'paymentMethod': 'card',
      'fieldConfidence': {
        'vendor': 0.97,
        'vendorAbn': 0.91,
        'totalAmount': 0.95,
        'taxAmount': 0.88,
        'transactionDate': 0.93,
      },
    },
  ],
};
