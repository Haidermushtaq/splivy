import 'package:flutter_test/flutter_test.dart';
import 'package:splivy/services/expenses_service.dart';

// Verifies the net-settlement edge algorithm that underpins both single- and
// multi-payer expenses. Each edge is a debtor -> creditor transfer.

const haider = 'haider';
const ali = 'ali';
const mohsin = 'mohsin';

List<Map<String, dynamic>> payer(Map<String, double> amounts) =>
    amounts.entries.map((e) => {'userId': e.key, 'amountPaid': e.value}).toList();

List<Map<String, dynamic>> split(Map<String, double> amounts) =>
    amounts.entries.map((e) => {'userId': e.key, 'amountOwed': e.value}).toList();

/// Total moved to each creditor, summed across edges.
Map<String, double> credits(List<Map<String, dynamic>> edges) {
  final m = <String, double>{};
  for (final e in edges) {
    m[e['to'] as String] = (m[e['to'] as String] ?? 0) + (e['amount'] as double);
  }
  return m;
}

/// Total moved out of each debtor, summed across edges.
Map<String, double> debits(List<Map<String, dynamic>> edges) {
  final m = <String, double>{};
  for (final e in edges) {
    m[e['from'] as String] = (m[e['from'] as String] ?? 0) + (e['amount'] as double);
  }
  return m;
}

void main() {
  group('computeSettlementEdges', () {
    test('Case 1 - single payer, equal split', () {
      final edges = ExpensesService.computeSettlementEdges(
        isMultiPayer: false,
        singlePayerId: haider,
        totalAmount: 1200,
        payerAmounts: const [],
        splitAmounts: split({haider: 400, ali: 400, mohsin: 400}),
      );

      // Haider paid all, owes 400 himself -> net +800. Ali & Mohsin owe 400 each.
      expect(credits(edges), {haider: 800});
      expect(debits(edges), {ali: 400, mohsin: 400});
    });

    test('Case 2 - multiple payers, equal split', () {
      final edges = ExpensesService.computeSettlementEdges(
        isMultiPayer: true,
        totalAmount: 1200,
        payerAmounts: payer({haider: 240, ali: 960}),
        splitAmounts: split({haider: 400, ali: 400, mohsin: 400}),
      );

      // Net: Haider -160, Ali +560, Mohsin -400. Ali is sole creditor.
      expect(credits(edges), {ali: 560});
      expect(debits(edges), {haider: 160, mohsin: 400});
    });

    test('Case 3 - single payer, custom split', () {
      final edges = ExpensesService.computeSettlementEdges(
        isMultiPayer: false,
        singlePayerId: haider,
        totalAmount: 1200,
        payerAmounts: const [],
        splitAmounts: split({ali: 600, mohsin: 400, haider: 200}),
      );

      // Haider net +1000 (paid 1200, owes 200). Ali owes 600, Mohsin 400.
      expect(credits(edges), {haider: 1000});
      expect(debits(edges), {ali: 600, mohsin: 400});
    });

    test('Case 4 - multiple payers, custom split', () {
      final edges = ExpensesService.computeSettlementEdges(
        isMultiPayer: true,
        totalAmount: 1500,
        payerAmounts: payer({ali: 1000, mohsin: 500}),
        splitAmounts: split({ali: 500, mohsin: 500, haider: 500}),
      );

      // Net: Ali +500, Mohsin 0, Haider -500. One edge: Haider -> Ali 500.
      expect(edges.length, 1);
      expect(edges.single['from'], haider);
      expect(edges.single['to'], ali);
      expect(edges.single['amount'], 500);
    });

    test('fully self-funded payer produces no edges', () {
      final edges = ExpensesService.computeSettlementEdges(
        isMultiPayer: false,
        singlePayerId: haider,
        totalAmount: 400,
        payerAmounts: const [],
        splitAmounts: split({haider: 400}),
      );
      expect(edges, isEmpty);
    });

    test('sub-cent residue is not turned into an edge', () {
      // 100 split three ways: 33.33 / 33.33 / 33.34 — payer keeps own share.
      final edges = ExpensesService.computeSettlementEdges(
        isMultiPayer: false,
        singlePayerId: haider,
        totalAmount: 100,
        payerAmounts: const [],
        splitAmounts: split({haider: 33.33, ali: 33.33, mohsin: 33.34}),
      );
      // Haider net +66.67; Ali owes 33.33, Mohsin 33.34.
      final c = credits(edges);
      expect(c.keys, {haider});
      expect(c[haider], closeTo(66.67, 0.01));
      expect(debits(edges), {ali: 33.33, mohsin: 33.34});
    });

    test('every debit is matched by an equal total credit', () {
      final edges = ExpensesService.computeSettlementEdges(
        isMultiPayer: true,
        totalAmount: 900,
        payerAmounts: payer({haider: 300, ali: 600}),
        splitAmounts: split({haider: 300, ali: 300, mohsin: 300}),
      );
      final totalOut =
          edges.fold<double>(0, (s, e) => s + (e['amount'] as double));
      // Ali net +300, Mohsin -300, Haider 0 -> exactly 300 should move.
      expect(totalOut, closeTo(300, 0.01));
    });
  });
}
