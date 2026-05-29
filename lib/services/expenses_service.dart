import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense_model.dart';

class ExpensesService {
  final _client = Supabase.instance.client;

  String get _userId => _client.auth.currentUser!.id;

  /// Expense creation with multi-payer and custom split support.
  ///
  /// Each settlement is persisted as one `expense_splits` row representing a
  /// debtor -> creditor edge: `user_id` is the debtor, `owed_to` is the
  /// creditor, `amount` is what flows between them. The edges come from
  /// minimizing transactions over the net position of every participant, so
  /// single-payer and multi-payer are handled identically downstream.
  ///
  /// TEST CASE 1 - Single payer equal split:
  ///   Bill: PKR 1200, Paid by: Haider; Split: each 400
  ///   Edges: Ali -> Haider 400, Mohsin -> Haider 400
  ///
  /// TEST CASE 2 - Multiple payers equal split:
  ///   Bill: PKR 1200, Paid: Haider=240, Ali=960; Split equally: each 400
  ///   Net: Haider=-160, Ali=+560, Mohsin=-400
  ///   Edges: Mohsin -> Ali 400, Haider -> Ali 160
  ///
  /// TEST CASE 3 - Single payer custom split:
  ///   Bill: PKR 1200, Paid by: Haider; Custom: Ali=600, Mohsin=400, Haider=200
  ///   Edges: Ali -> Haider 600, Mohsin -> Haider 400
  ///
  /// TEST CASE 4 - Multiple payers custom split:
  ///   Bill: PKR 1500, Paid: Ali=1000, Mohsin=500; Custom: each 500
  ///   Net: Ali=+500, Mohsin=0, Haider=-500
  ///   Edge: Haider -> Ali 500
  Future<Expense> addExpenseV2({
    required String groupId,
    required String title,
    required double totalAmount,
    required bool isMultiPayer,
    String? singlePayerId,
    required List<Map<String, dynamic>> payerAmounts,
    required List<Map<String, dynamic>> splitAmounts,
    required bool isEqualSplit,
    required String category,
    String? note,
    required bool isCustom,
    List<GuestSplitInput> guestSplits = const [],
  }) async {
    final expenseData = <String, dynamic>{
      'group_id': groupId,
      'title': title,
      'amount': totalAmount,
      'paid_by': isMultiPayer ? null : singlePayerId,
      'is_multi_payer': isMultiPayer,
      'category': category,
      'is_custom': isCustom || guestSplits.isNotEmpty,
    };
    if (note != null && note.isNotEmpty) {
      expenseData['note'] = note;
    }

    final row = await _client.from('expenses').insert(expenseData).select().single();
    final expenseId = row['id'] as String;

    try {
      if (isMultiPayer) {
        for (final payer in payerAmounts) {
          final amountPaid = (payer['amountPaid'] as num).toDouble();
          if (amountPaid > 0) {
            await _client.from('expense_payers').insert({
              'expense_id': expenseId,
              'user_id': payer['userId'],
              'amount_paid': amountPaid,
            });
          }
        }
      }

      final edges = _computeSettlementEdges(
        isMultiPayer: isMultiPayer,
        singlePayerId: singlePayerId,
        totalAmount: totalAmount,
        payerAmounts: payerAmounts,
        splitAmounts: splitAmounts,
      );

      if (edges.isNotEmpty) {
        final splitRows = edges
            .map((e) => {
                  'expense_id': expenseId,
                  'user_id': e['from'],
                  'owed_to': e['to'],
                  'amount': e['amount'],
                  'is_settled': false,
                  'payment_status': 'pending',
                })
            .toList();
        await _client.from('expense_splits').insert(splitRows);
      }

      if (guestSplits.isNotEmpty) {
        final guestRows = guestSplits
            .map((g) => {
                  'expense_id': expenseId,
                  'guest_name': g.guestName,
                  'guest_phone': g.guestPhone,
                  'amount': g.amount,
                  'is_settled': false,
                })
            .toList();
        await _client.from('guest_splits').insert(guestRows);
      }
    } catch (e) {
      // Cascades to expense_payers / expense_splits / guest_splits.
      await _client.from('expenses').delete().eq('id', expenseId);
      rethrow;
    }

    return Expense.fromMap(row, paidByName: 'You', userShare: 0, isSettled: false);
  }

  /// Reduces every participant's net position (paid minus owed) into a minimal
  /// set of debtor -> creditor transfers. Returns `{from, to, amount}` maps.
  List<Map<String, dynamic>> _computeSettlementEdges({
    required bool isMultiPayer,
    String? singlePayerId,
    required double totalAmount,
    required List<Map<String, dynamic>> payerAmounts,
    required List<Map<String, dynamic>> splitAmounts,
  }) {
    final Map<String, double> net = {};

    if (isMultiPayer) {
      for (final p in payerAmounts) {
        final id = p['userId'] as String;
        net[id] = (net[id] ?? 0) + (p['amountPaid'] as num).toDouble();
      }
    } else if (singlePayerId != null) {
      net[singlePayerId] = (net[singlePayerId] ?? 0) + totalAmount;
    }

    for (final s in splitAmounts) {
      final id = s['userId'] as String;
      net[id] = (net[id] ?? 0) - (s['amountOwed'] as num).toDouble();
    }

    final debtors = net.entries.where((e) => e.value < -0.01).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final creditors = net.entries.where((e) => e.value > 0.01).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final dVals = debtors.map((e) => e.value).toList();
    final cVals = creditors.map((e) => e.value).toList();

    final edges = <Map<String, dynamic>>[];
    int di = 0, ci = 0;
    while (di < debtors.length && ci < creditors.length) {
      final amount =
          [dVals[di].abs(), cVals[ci]].reduce((a, b) => a < b ? a : b);
      if (amount > 0.01) {
        edges.add({
          'from': debtors[di].key,
          'to': creditors[ci].key,
          'amount': double.parse(amount.toStringAsFixed(2)),
        });
      }
      dVals[di] += amount;
      cVals[ci] -= amount;
      if (dVals[di].abs() < 0.01) di++;
      if (cVals[ci].abs() < 0.01) ci++;
    }
    return edges;
  }

  Future<List<Expense>> getGroupExpenses(String groupId) async {
    final rows = await _client
        .from('expenses')
        .select()
        .eq('group_id', groupId)
        .eq('is_archived', false)
        .order('created_at', ascending: false);

    final List<Expense> result = [];
    for (final e in rows as List) {
      final expenseId = e['id'] as String;
      final isMultiPayer = e['is_multi_payer'] as bool? ?? false;
      final paidById = e['paid_by'] as String?;

      final paidByName =
          await _resolvePaidByName(expenseId, isMultiPayer, paidById);

      final splits = await _client
          .from('expense_splits')
          .select('user_id, owed_to, amount, is_settled')
          .eq('expense_id', expenseId);

      double iOwe = 0;
      bool iOweSettled = true;
      double owedToMe = 0;
      bool owedToMeSettled = true;

      for (final s in splits as List) {
        final amount = (s['amount'] as num).toDouble();
        final settled = s['is_settled'] as bool? ?? false;
        if (s['user_id'] == _userId) {
          iOwe += amount;
          if (!settled) iOweSettled = false;
        }
        if (s['owed_to'] == _userId) {
          owedToMe += amount;
          if (!settled) owedToMeSettled = false;
        }
      }

      double userShare;
      bool userOwes;
      bool isSettled;
      if (iOwe > 0.01) {
        userShare = iOwe;
        userOwes = true;
        isSettled = iOweSettled;
      } else if (owedToMe > 0.01) {
        userShare = owedToMe;
        userOwes = false;
        isSettled = owedToMeSettled;
      } else {
        userShare = 0;
        userOwes = false;
        isSettled = true;
      }

      result.add(Expense.fromMap(
        e,
        paidByName: paidByName,
        userShare: userShare,
        userOwes: userOwes,
        isSettled: isSettled,
      ));
    }

    return result;
  }

  Future<String> _resolvePaidByName(
    String expenseId,
    bool isMultiPayer,
    String? paidById,
  ) async {
    if (isMultiPayer) {
      final payers = await _client
          .from('expense_payers')
          .select('user_id')
          .eq('expense_id', expenseId);

      final payerCount = (payers as List).length;
      if (payerCount == 0) return 'Unknown';

      final currentUserPaid = payers.any((p) => p['user_id'] == _userId);

      if (payerCount == 1) {
        final payerId = payers[0]['user_id'] as String;
        if (payerId == _userId) return 'You';
        final profile = await _client
            .from('profiles')
            .select('full_name')
            .eq('id', payerId)
            .maybeSingle();
        return profile?['full_name'] as String? ?? 'Unknown';
      }
      if (currentUserPaid) {
        return 'You + ${payerCount - 1} ${payerCount == 2 ? 'other' : 'others'}';
      }
      return '$payerCount people';
    }

    if (paidById != null) {
      if (paidById == _userId) return 'You';
      final profile = await _client
          .from('profiles')
          .select('full_name')
          .eq('id', paidById)
          .maybeSingle();
      return profile?['full_name'] as String? ?? 'Unknown';
    }
    return 'Unknown';
  }

  Future<UserBalance> getUserTotalBalance() async {
    final owedRows = await _client
        .from('expense_splits')
        .select('amount, expenses!inner(is_archived)')
        .eq('owed_to', _userId)
        .eq('is_settled', false)
        .eq('expenses.is_archived', false);

    final owingRows = await _client
        .from('expense_splits')
        .select('amount, expenses!inner(is_archived)')
        .eq('user_id', _userId)
        .eq('is_settled', false)
        .eq('expenses.is_archived', false);

    double totalOwed = 0;
    for (final s in owedRows as List) {
      totalOwed += (s['amount'] as num).toDouble();
    }

    double totalOwing = 0;
    for (final s in owingRows as List) {
      totalOwing += (s['amount'] as num).toDouble();
    }

    return UserBalance(totalOwed: totalOwed, totalOwing: totalOwing);
  }

  Future<List<DebtItem>> getSettleUpData() async {
    const expenseEmbed =
        'expenses!inner(title, group_id, created_at, is_archived)';

    final iOwe = await _client
        .from('expense_splits')
        .select(
            'id, expense_id, amount, payment_status, payment_proof_url, payment_method, owed_to, $expenseEmbed')
        .eq('user_id', _userId)
        .eq('is_settled', false)
        .eq('expenses.is_archived', false);

    final owedToMe = await _client
        .from('expense_splits')
        .select(
            'id, expense_id, amount, payment_status, payment_proof_url, payment_method, user_id, $expenseEmbed')
        .eq('owed_to', _userId)
        .eq('is_settled', false)
        .eq('expenses.is_archived', false);

    final counterpartIds = <String>{
      ...(iOwe as List).map((r) => r['owed_to']).whereType<String>(),
      ...(owedToMe as List).map((r) => r['user_id']).whereType<String>(),
    }.toList();

    final groupIds = <String>{
      ...iOwe.map((r) => (r['expenses'] as Map)['group_id']).whereType<String>(),
      ...owedToMe
          .map((r) => (r['expenses'] as Map)['group_id'])
          .whereType<String>(),
    }.toList();

    final profileMap = <String, Map<String, dynamic>>{};
    if (counterpartIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id, full_name, phone')
          .inFilter('id', counterpartIds);
      for (final p in profiles as List) {
        profileMap[p['id'] as String] = p as Map<String, dynamic>;
      }
    }

    final groupMap = <String, String>{};
    if (groupIds.isNotEmpty) {
      final groups =
          await _client.from('groups').select('id, name').inFilter('id', groupIds);
      for (final g in groups as List) {
        groupMap[g['id'] as String] = g['name'] as String;
      }
    }

    String dueSinceOf(Map exp) {
      final createdAt = DateTime.parse(exp['created_at'] as String);
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }

    final List<DebtItem> debts = [];

    for (final s in iOwe) {
      final exp = s['expenses'] as Map;
      final creditor = profileMap[s['owed_to']];
      debts.add(DebtItem(
        expenseId: s['expense_id'] as String,
        splitId: s['id'] as String,
        name: creditor?['full_name'] as String? ?? 'Unknown',
        groupName: groupMap[exp['group_id']] ?? 'Unknown Group',
        dueSince: dueSinceOf(exp),
        amount: (s['amount'] as num).toDouble(),
        youOwe: true,
        expenseTitle: exp['title'] as String,
        receiverPhone: creditor?['phone'] as String?,
        paymentStatus: s['payment_status'] as String? ?? 'pending',
        paymentProofUrl: s['payment_proof_url'] as String?,
        paymentMethod: s['payment_method'] as String?,
      ));
    }

    for (final s in owedToMe) {
      final exp = s['expenses'] as Map;
      final debtor = profileMap[s['user_id']];
      debts.add(DebtItem(
        expenseId: s['expense_id'] as String,
        splitId: s['id'] as String,
        name: debtor?['full_name'] as String? ?? 'Unknown',
        groupName: groupMap[exp['group_id']] ?? 'Unknown Group',
        dueSince: dueSinceOf(exp),
        amount: (s['amount'] as num).toDouble(),
        youOwe: false,
        expenseTitle: exp['title'] as String,
        receiverPhone: debtor?['phone'] as String?,
        paymentStatus: s['payment_status'] as String? ?? 'pending',
        paymentProofUrl: s['payment_proof_url'] as String?,
        paymentMethod: s['payment_method'] as String?,
      ));
    }

    return debts;
  }

  Future<void> settleExpense(String expenseId, String userId) async {
    await _client
        .from('expense_splits')
        .update({'is_settled': true})
        .eq('expense_id', expenseId)
        .eq('user_id', userId);
  }

  Future<List<CustomExpenseDetail>> getCustomExpenses() async {
    final rows = await _client
        .from('expenses')
        .select()
        .eq('paid_by', _userId)
        .eq('is_custom', true)
        .eq('is_archived', false)
        .order('created_at', ascending: false);

    final List<CustomExpenseDetail> result = [];
    for (final e in rows as List) {
      final guestRows = await _client
          .from('guest_splits')
          .select()
          .eq('expense_id', e['id'] as String)
          .order('created_at', ascending: true);

      final guests = (guestRows as List)
          .map((g) => GuestSplit(
                id: g['id'] as String,
                expenseId: g['expense_id'] as String,
                guestName: g['guest_name'] as String,
                guestPhone: g['guest_phone'] as String,
                amount: (g['amount'] as num).toDouble(),
                isSettled: g['is_settled'] as bool? ?? false,
                createdAt: DateTime.parse(g['created_at'] as String),
              ))
          .toList();

      result.add(CustomExpenseDetail(
        expense: Expense.fromMap(e, paidByName: 'You'),
        guests: guests,
      ));
    }
    return result;
  }

  Future<void> settleGuestSplit(String guestSplitId) async {
    await _client
        .from('guest_splits')
        .update({'is_settled': true})
        .eq('id', guestSplitId);
  }

  Future<void> archiveCustomExpense(String expenseId) async {
    final unsettled = await _client
        .from('guest_splits')
        .select('id')
        .eq('expense_id', expenseId)
        .eq('is_settled', false);

    if ((unsettled as List).isNotEmpty) {
      throw Exception('All guests must be settled before archiving');
    }

    await _client
        .from('expenses')
        .update({'is_archived': true})
        .eq('id', expenseId);
  }

  Future<void> deleteExpense(String expenseId) async {
    await _client.from('expenses').delete().eq('id', expenseId);
  }
}
