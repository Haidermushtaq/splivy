import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense_model.dart';
import 'notification_service.dart';

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

    List<Map<String, dynamic>> edges = const [];
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

      edges = await _writeSettlement(
        expenseId: expenseId,
        isMultiPayer: isMultiPayer,
        singlePayerId: singlePayerId,
        totalAmount: totalAmount,
        payerAmounts: payerAmounts,
        splitAmounts: splitAmounts,
        guestSplits: guestSplits,
      );
    } catch (e) {
      // Cascades to expense_payers / expense_splits / guest_splits.
      await _client.from('expenses').delete().eq('id', expenseId);
      rethrow;
    }

    await _autoNetAfterCreate(edges);

    return Expense.fromMap(row, paidByName: 'You', userShare: 0, isSettled: false);
  }

  /// Creates a one-time expense not tied to any group (`group_id` is null).
  ///
  /// The creator (current user) is always recorded as `paid_by` so the expense
  /// surfaces in [getCustomExpenses]. Registered participants (connected
  /// friends) become `expense_splits` edges via the same settlement algorithm
  /// as group expenses; outside people become `guest_splits` rows.
  Future<String> addOneTimeExpense({
    required String title,
    required double totalAmount,
    required bool isMultiPayer,
    required List<Map<String, dynamic>> payerAmounts,
    required List<Map<String, dynamic>> splitAmounts,
    required String category,
    String? note,
    List<GuestSplitInput> guestSplits = const [],
  }) async {
    final expenseData = <String, dynamic>{
      'group_id': null,
      'title': title,
      'amount': totalAmount,
      'paid_by': _userId,
      'is_multi_payer': isMultiPayer,
      'category': category,
      'is_custom': true,
    };
    if (note != null && note.isNotEmpty) {
      expenseData['note'] = note;
    }

    final row =
        await _client.from('expenses').insert(expenseData).select().single();
    final expenseId = row['id'] as String;

    List<Map<String, dynamic>> edges = const [];
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

      edges = await _writeSettlement(
        expenseId: expenseId,
        isMultiPayer: isMultiPayer,
        singlePayerId: isMultiPayer ? null : _userId,
        totalAmount: totalAmount,
        payerAmounts: payerAmounts,
        splitAmounts: splitAmounts,
        guestSplits: guestSplits,
      );
    } catch (e) {
      await _client.from('expenses').delete().eq('id', expenseId);
      rethrow;
    }

    await _autoNetAfterCreate(edges);

    return expenseId;
  }

  /// Runs [autoNetWithUser] for each distinct counterpart in [edges], swallowing
  /// any failure. Netting is best-effort and must never undo a created expense.
  Future<void> _autoNetAfterCreate(List<Map<String, dynamic>> edges) async {
    final counterparts = <String>{};
    for (final e in edges) {
      final from = e['from'] as String;
      final to = e['to'] as String;
      if (from == _userId) {
        counterparts.add(to);
      } else if (to == _userId) {
        counterparts.add(from);
      }
    }
    for (final id in counterparts) {
      try {
        await autoNetWithUser(id);
      } catch (_) {
        // Best-effort: ignore netting failures.
      }
    }
  }

  /// Cancels offsetting unsettled debts between the current user and
  /// [otherUserId] across every group and one-time expense.
  ///
  /// Walks both directions of still-pending, non-archived splits and nets them:
  /// fully-cancelled splits are marked `netted` (and so drop out of all balance
  /// and settle-up reads), while a single boundary split is reduced to its
  /// residual. Fires a local notification summarising the cancellation and
  /// returns the total amount netted (0 when nothing offsets).
  Future<double> autoNetWithUser(String otherUserId) async {
    Future<List<Map<String, dynamic>>> fetch({
      required String debtor,
      required String creditor,
    }) async {
      final rows = await _client
          .from('expense_splits')
          .select(
              'id, amount, amount_paid, created_at, expenses!inner(is_archived)')
          .eq('user_id', debtor)
          .eq('owed_to', creditor)
          .eq('is_settled', false)
          .eq('payment_status', 'pending')
          .eq('expenses.is_archived', false)
          .order('created_at');
      return (rows as List).cast<Map<String, dynamic>>();
    }

    final iOwe = await fetch(debtor: _userId, creditor: otherUserId);
    final theyOwe = await fetch(debtor: otherUserId, creditor: _userId);
    if (iOwe.isEmpty || theyOwe.isEmpty) return 0;

    final mineAmt = iOwe.map((r) => (r['amount'] as num).toDouble()).toList();
    final theirAmt = theyOwe.map((r) => (r['amount'] as num).toDouble()).toList();
    final mineOrig = [...mineAmt];
    final theirOrig = [...theirAmt];

    double netted = 0;
    int i = 0, j = 0;
    while (i < mineAmt.length && j < theirAmt.length) {
      if (mineAmt[i] < 0.01) {
        i++;
        continue;
      }
      if (theirAmt[j] < 0.01) {
        j++;
        continue;
      }
      final c = mineAmt[i] < theirAmt[j] ? mineAmt[i] : theirAmt[j];
      mineAmt[i] -= c;
      theirAmt[j] -= c;
      netted += c;
      if (mineAmt[i] < 0.01) i++;
      if (theirAmt[j] < 0.01) j++;
    }

    if (netted < 0.01) return 0;

    final now = DateTime.now().toIso8601String();

    Future<void> apply(
      List<Map<String, dynamic>> rows,
      List<double> residual,
      List<double> original,
    ) async {
      for (var k = 0; k < rows.length; k++) {
        final cancelled = original[k] - residual[k];
        if (cancelled < 0.01) continue;
        final paidBefore = (rows[k]['amount_paid'] as num?)?.toDouble() ?? 0;
        if (residual[k] < 0.01) {
          await _client.from('expense_splits').update({
            'is_settled': true,
            'payment_status': 'netted',
            'payment_method': 'auto_net',
            'amount_paid': paidBefore + cancelled,
            'settled_at': now,
          }).eq('id', rows[k]['id']);
        } else {
          await _client.from('expense_splits').update({
            'amount': residual[k],
            'payment_method': 'auto_net',
            'amount_paid': paidBefore + cancelled,
          }).eq('id', rows[k]['id']);
        }
      }
    }

    await apply(iOwe, mineAmt, mineOrig);
    await apply(theyOwe, theirAmt, theirOrig);

    final profile = await _client
        .from('profiles')
        .select('full_name')
        .eq('id', otherUserId)
        .maybeSingle();
    final name = profile?['full_name'] as String? ?? 'a friend';
    await NotificationService()
        .showAutoNetNotification(name: name, amount: netted);

    return netted;
  }

  /// Reduces every participant's net position (paid minus owed) into a minimal
  /// set of debtor -> creditor transfers. Returns `{from, to, amount}` maps.
  @visibleForTesting
  static List<Map<String, dynamic>> computeSettlementEdges({
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

  /// Like [computeSettlementEdges] but treats guests as first-class nodes so
  /// the minimal transfers can run *directly* between any two participants
  /// (user-user, user-guest, guest-guest). Guest nodes use the key `g:<index>`;
  /// user nodes use the user id. Returns `{from, to, amount}` over those keys.
  @visibleForTesting
  static List<Map<String, dynamic>> computeAllEdges({
    required bool isMultiPayer,
    String? singlePayerId,
    required double totalAmount,
    required List<Map<String, dynamic>> payerAmounts,
    required List<Map<String, dynamic>> splitAmounts,
    required List<Map<String, dynamic>> guestNodes,
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

    for (final g in guestNodes) {
      final key = g['key'] as String;
      net[key] = (net[key] ?? 0) +
          (g['paid'] as num).toDouble() -
          (g['owed'] as num).toDouble();
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

  /// Computes the guest-aware minimal settlement for [expenseId] and writes
  /// every edge to the right table:
  ///   * user -> user  => `expense_splits`
  ///   * you  <-> guest => `guest_splits.amount` (signed: + guest owes you)
  /// Guest -> friend (non-creator) AND guest -> guest edges are both routed
  /// through the creator so they stay actionable: a guest has no account, so
  /// the creator is the single hub that collects from and pays out to guests.
  /// Every guest also gets one participation row carrying its share and amount
  /// paid. Returns the user-user edges for auto-netting.
  Future<List<Map<String, dynamic>>> _writeSettlement({
    required String expenseId,
    required bool isMultiPayer,
    String? singlePayerId,
    required double totalAmount,
    required List<Map<String, dynamic>> payerAmounts,
    required List<Map<String, dynamic>> splitAmounts,
    required List<GuestSplitInput> guestSplits,
  }) async {
    final creator = singlePayerId ?? _userId;

    final guestNodes = <Map<String, dynamic>>[];
    for (var i = 0; i < guestSplits.length; i++) {
      guestNodes.add({
        'key': 'g:$i',
        'paid': guestSplits[i].amountPaid,
        'owed': guestSplits[i].amount,
      });
    }

    final raw = computeAllEdges(
      isMultiPayer: isMultiPayer,
      singlePayerId: singlePayerId,
      totalAmount: totalAmount,
      payerAmounts: payerAmounts,
      splitAmounts: splitAmounts,
      guestNodes: guestNodes,
    );

    bool isGuestKey(String k) => k.startsWith('g:');
    int guestIdx(String k) => int.parse(k.substring(2));

    final meEdge = List<double>.filled(guestSplits.length, 0);
    final userSplits = <Map<String, dynamic>>[];

    void addUserSplit(String from, String to, double amt) {
      if (amt <= 0.01 || from == to) return;
      userSplits.add({
        'from': from,
        'to': to,
        'amount': double.parse(amt.toStringAsFixed(2)),
      });
    }

    for (final e in raw) {
      final from = e['from'] as String;
      final to = e['to'] as String;
      final amt = (e['amount'] as num).toDouble();
      final fg = isGuestKey(from);
      final tg = isGuestKey(to);

      if (!fg && !tg) {
        addUserSplit(from, to, amt);
      } else if (fg && tg) {
        // Guest owes guest: route through the creator so it's actionable.
        // The debtor guest pays the creator, the creator pays the creditor
        // guest. Neither guest has an account, so the creator is the hub.
        meEdge[guestIdx(from)] += amt;
        meEdge[guestIdx(to)] -= amt;
      } else if (fg && !tg) {
        // Guest owes a user.
        meEdge[guestIdx(from)] += amt;
        if (to != creator) addUserSplit(creator, to, amt);
      } else {
        // A user owes a guest.
        meEdge[guestIdx(to)] -= amt;
        if (from != creator) addUserSplit(from, creator, amt);
      }
    }

    if (userSplits.isNotEmpty) {
      await _client.from('expense_splits').insert(userSplits
          .map((e) => {
                'expense_id': expenseId,
                'user_id': e['from'],
                'owed_to': e['to'],
                'amount': e['amount'],
                'is_settled': false,
                'payment_status': 'pending',
              })
          .toList());
    }

    if (guestSplits.isNotEmpty) {
      final guestRows = <Map<String, dynamic>>[];
      for (var i = 0; i < guestSplits.length; i++) {
        final g = guestSplits[i];
        final edge = double.parse(meEdge[i].toStringAsFixed(2));
        guestRows.add({
          'expense_id': expenseId,
          'guest_name': g.guestName,
          'guest_phone': g.guestPhone,
          'share': g.amount,
          'amount_paid': g.amountPaid,
          'amount': edge,
          'is_settled': edge.abs() < 0.01,
          'payment_status': 'pending',
        });
      }
      await _client.from('guest_splits').insert(guestRows);
    }

    return userSplits
        .map((e) => {'from': e['from'], 'to': e['to'], 'amount': e['amount']})
        .toList();
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

      // Guests can also be payers on a one-time expense; count any guest who
      // actually paid toward the bill so multi-payer bills aren't mislabelled
      // as "paid by you" when friends/guests chipped in.
      final guestPayers = await _client
          .from('guest_splits')
          .select('guest_name, amount_paid')
          .eq('expense_id', expenseId)
          .gt('amount_paid', 0);

      final userPayerCount = (payers as List).length;
      final guestPayerCount = (guestPayers as List).length;
      final payerCount = userPayerCount + guestPayerCount;
      if (payerCount == 0) return 'Unknown';

      final currentUserPaid = payers.any((p) => p['user_id'] == _userId);

      if (payerCount == 1) {
        if (userPayerCount == 1) {
          final payerId = payers[0]['user_id'] as String;
          if (payerId == _userId) return 'You';
          final profile = await _client
              .from('profiles')
              .select('full_name')
              .eq('id', payerId)
              .maybeSingle();
          return profile?['full_name'] as String? ?? 'Unknown';
        }
        return guestPayers[0]['guest_name'] as String? ?? 'Unknown';
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

    // Guest debts live only on guest_splits (no expense_splits row). The user
    // is always the creditor on their own expenses. A positive guest amount
    // means the guest owes the user; a negative amount means the user owes the
    // guest (guest overpaid).
    final guestRows = await _client
        .from('guest_splits')
        .select('amount, expenses!inner(paid_by, is_archived)')
        .eq('is_settled', false)
        .eq('expenses.paid_by', _userId)
        .eq('expenses.is_archived', false);

    for (final g in guestRows as List) {
      final amount = (g['amount'] as num).toDouble();
      if (amount >= 0) {
        totalOwed += amount;
      } else {
        totalOwing += -amount;
      }
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
      final expenseId = e['id'] as String;
      final isMultiPayer = e['is_multi_payer'] as bool? ?? false;

      final guestRows = await _client
          .from('guest_splits')
          .select()
          .eq('expense_id', expenseId)
          .order('created_at', ascending: true);

      final guests = (guestRows as List)
          .map((g) => GuestSplit(
                id: g['id'] as String,
                expenseId: g['expense_id'] as String,
                guestName: g['guest_name'] as String,
                guestPhone: g['guest_phone'] as String,
                amount: (g['amount'] as num).toDouble(),
                share: (g['share'] as num?)?.toDouble() ?? 0,
                amountPaid: (g['amount_paid'] as num?)?.toDouble() ?? 0,
                isSettled: g['is_settled'] as bool? ?? false,
                createdAt: DateTime.parse(g['created_at'] as String),
              ))
          .toList();

      // Registered friends involved in this one-time expense, either direction.
      final splitRows = await _client
          .from('expense_splits')
          .select('id, user_id, owed_to, amount, is_settled')
          .eq('expense_id', expenseId)
          .or('user_id.eq.$_userId,owed_to.eq.$_userId');

      final counterpartIds = <String>{};
      for (final s in splitRows as List) {
        final from = s['user_id'] as String;
        final to = s['owed_to'] as String;
        counterpartIds.add(from == _userId ? to : from);
      }
      final profileMap = <String, Map<String, dynamic>>{};
      if (counterpartIds.isNotEmpty) {
        final profiles = await _client
            .from('profiles')
            .select('id, full_name, phone')
            .inFilter('id', counterpartIds.toList());
        for (final p in profiles as List) {
          profileMap[p['id'] as String] = p as Map<String, dynamic>;
        }
      }

      // Signed from my perspective: positive = friend owes me, negative = I owe.
      final friendDebts = splitRows.map((s) {
        final from = s['user_id'] as String;
        final to = s['owed_to'] as String;
        final iAmCreditor = to == _userId;
        final counterpart = iAmCreditor ? from : to;
        final raw = (s['amount'] as num).toDouble();
        final prof = profileMap[counterpart];
        return FriendDebt(
          splitId: s['id'] as String,
          userId: counterpart,
          name: prof?['full_name'] as String? ?? 'Unknown',
          phone: prof?['phone'] as String?,
          amount: iAmCreditor ? raw : -raw,
          isSettled: s['is_settled'] as bool? ?? false,
        );
      }).toList();

      // Informational debts between two guests on this expense.
      final ggRows = await _client
          .from('guest_guest_debts')
          .select()
          .eq('expense_id', expenseId);
      final guestGuestDebts = (ggRows as List)
          .map((d) => GuestGuestDebt.fromJson(d as Map<String, dynamic>))
          .toList();

      final paidByName = await _resolvePaidByName(
          expenseId, isMultiPayer, e['paid_by'] as String?);

      // Build the "who paid what" breakdown across registered users and guests.
      final payers = <PayerContribution>[];
      if (isMultiPayer) {
        final payerRows = await _client
            .from('expense_payers')
            .select('user_id, amount_paid')
            .eq('expense_id', expenseId);
        final payerIds =
            (payerRows as List).map((p) => p['user_id'] as String).toList();
        final pProfiles = <String, String>{};
        if (payerIds.isNotEmpty) {
          final profs = await _client
              .from('profiles')
              .select('id, full_name')
              .inFilter('id', payerIds);
          for (final p in profs as List) {
            pProfiles[p['id'] as String] = p['full_name'] as String? ?? 'Unknown';
          }
        }
        for (final p in payerRows) {
          final uid = p['user_id'] as String;
          final isYou = uid == _userId;
          payers.add(PayerContribution(
            name: isYou ? 'You' : (pProfiles[uid] ?? 'Unknown'),
            amount: (p['amount_paid'] as num).toDouble(),
            isYou: isYou,
          ));
        }
      } else {
        payers.add(PayerContribution(
          name: 'You',
          amount: (e['amount'] as num).toDouble(),
          isYou: true,
        ));
      }
      for (final g in guests) {
        if (g.amountPaid > 0.01) {
          payers.add(PayerContribution(name: g.guestName, amount: g.amountPaid));
        }
      }

      result.add(CustomExpenseDetail(
        expense: Expense.fromMap(e, paidByName: paidByName),
        guests: guests,
        friendDebts: friendDebts,
        guestGuestDebts: guestGuestDebts,
        payers: payers,
      ));
    }
    return result;
  }

  Future<void> markSplitSettled(String splitId) async {
    await _client
        .from('expense_splits')
        .update({'is_settled': true})
        .eq('id', splitId);
  }

  Future<void> settleGuestSplit(String guestSplitId) async {
    await _client
        .from('guest_splits')
        .update({'is_settled': true})
        .eq('id', guestSplitId);
  }

  /// Marks an informational guest-to-guest debt as settled. These debts don't
  /// involve the current user financially, but the creator tracks them since
  /// neither guest is on the app.
  Future<void> settleGuestGuestDebt(String debtId) async {
    await _client
        .from('guest_guest_debts')
        .update({'is_settled': true})
        .eq('id', debtId);
  }

  Future<void> archiveCustomExpense(String expenseId) async {
    final unsettledGuests = await _client
        .from('guest_splits')
        .select('id')
        .eq('expense_id', expenseId)
        .eq('is_settled', false);

    final unsettledFriends = await _client
        .from('expense_splits')
        .select('id')
        .eq('expense_id', expenseId)
        .eq('is_settled', false);

    if ((unsettledGuests as List).isNotEmpty ||
        (unsettledFriends as List).isNotEmpty) {
      throw Exception('Everyone must be settled before archiving');
    }

    await _client
        .from('expenses')
        .update({'is_archived': true})
        .eq('id', expenseId);
  }

  Future<void> deleteExpense(String expenseId) async {
    await _client.from('expenses').delete().eq('id', expenseId);
  }

  /// Recent expenses the current user is part of (as payer or as a split
  /// participant), newest first, capped at 20. Used by the dashboard activity
  /// feed.
  Future<List<RecentExpense>> getRecentExpenses() async {
    return _loadExpenseFeed(archived: false, limit: 20);
  }

  /// Archived (settled) expenses the current user is part of, newest first.
  Future<List<RecentExpense>> getArchivedExpenses() async {
    return _loadExpenseFeed(archived: true, limit: 100);
  }

  Future<void> unarchiveExpense(String expenseId) async {
    await _client
        .from('expenses')
        .update({'is_archived': false})
        .eq('id', expenseId);
  }

  /// Shared loader for the recent/archived feeds. Gathers expenses where the
  /// user is the payer plus those where they appear on a split, dedupes, sorts
  /// by recency, then enriches each with payer name, group name and the user's
  /// share.
  Future<List<RecentExpense>> _loadExpenseFeed({
    required bool archived,
    required int limit,
  }) async {
    final paid = await _client
        .from('expenses')
        .select()
        .eq('paid_by', _userId)
        .eq('is_archived', archived);

    // Include expenses where the user is either the debtor (user_id) or the
    // creditor (owed_to) so a friend who is owed money still sees the expense.
    final splitRows = await _client
        .from('expense_splits')
        .select('expense_id')
        .or('user_id.eq.$_userId,owed_to.eq.$_userId');
    final splitIds = (splitRows as List)
        .map((s) => s['expense_id'] as String)
        .toSet()
        .toList();

    final byId = <String, Map<String, dynamic>>{};
    for (final e in paid as List) {
      byId[e['id'] as String] = e as Map<String, dynamic>;
    }
    if (splitIds.isNotEmpty) {
      final fromSplits = await _client
          .from('expenses')
          .select()
          .inFilter('id', splitIds)
          .eq('is_archived', archived);
      for (final e in fromSplits as List) {
        byId[e['id'] as String] = e as Map<String, dynamic>;
      }
    }

    final expenses = byId.values.toList()
      ..sort((a, b) => DateTime.parse(b['created_at'] as String)
          .compareTo(DateTime.parse(a['created_at'] as String)));

    final limited = expenses.take(limit).toList();

    // Batch-load group names.
    final groupIds = limited
        .map((e) => e['group_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final groupNames = <String, String>{};
    if (groupIds.isNotEmpty) {
      final groups =
          await _client.from('groups').select('id, name').inFilter('id', groupIds);
      for (final g in groups as List) {
        groupNames[g['id'] as String] = g['name'] as String? ?? '';
      }
    }

    final ids = limited.map((e) => e['id'] as String).toList();
    if (ids.isEmpty) return [];

    // Batch the user's shares across every expense in one query, then sum
    // per expense, instead of one query per row.
    final shareByExpense = <String, double>{};
    final shareRows = await _client
        .from('expense_splits')
        .select('expense_id, amount')
        .inFilter('expense_id', ids)
        .or('user_id.eq.$_userId,owed_to.eq.$_userId');
    for (final s in shareRows as List) {
      final eid = s['expense_id'] as String;
      shareByExpense[eid] =
          (shareByExpense[eid] ?? 0) + (s['amount'] as num).toDouble();
    }

    // Batch the payer rows so multi-payer "isPayer" needs no per-row query.
    final payerExpenseIds = <String>{};
    final payerRows = await _client
        .from('expense_payers')
        .select('expense_id')
        .inFilter('expense_id', ids)
        .eq('user_id', _userId);
    for (final p in payerRows as List) {
      payerExpenseIds.add(p['expense_id'] as String);
    }

    // Resolve payer display names concurrently rather than sequentially.
    final paidByNames = await Future.wait(limited.map((e) => _resolvePaidByName(
          e['id'] as String,
          e['is_multi_payer'] as bool? ?? false,
          e['paid_by'] as String?,
        )));

    final result = <RecentExpense>[];
    for (var i = 0; i < limited.length; i++) {
      final e = limited[i];
      final expenseId = e['id'] as String;
      final isMultiPayer = e['is_multi_payer'] as bool? ?? false;
      final paidById = e['paid_by'] as String?;
      final groupId = e['group_id'] as String?;

      final isPayer =
          paidById == _userId || payerExpenseIds.contains(expenseId);

      result.add(RecentExpense(
        id: expenseId,
        title: e['title'] as String? ?? 'Expense',
        amount: (e['amount'] as num?)?.toDouble() ?? 0,
        category: e['category'] as String? ?? 'Other',
        paidByName: paidByNames[i],
        groupId: groupId,
        groupName: groupId != null ? groupNames[groupId] : null,
        isCustom: e['is_custom'] as bool? ?? false,
        isMultiPayer: isMultiPayer,
        isPayer: isPayer,
        userShare: shareByExpense[expenseId] ?? 0,
        createdAt: DateTime.parse(e['created_at'] as String),
      ));
    }
    return result;
  }
}

/// Lightweight expense view used by the dashboard activity feed and the
/// archived-expenses screen. Carries the display fields those screens need
/// (resolved payer name, group name, the current user's share) without the
/// full [Expense] split/payer payload.
class RecentExpense {
  final String id;
  final String title;
  final double amount;
  final String category;
  final String paidByName;
  final String? groupId;
  final String? groupName;
  final bool isCustom;
  final bool isMultiPayer;
  final bool isPayer;
  final double userShare;
  final DateTime createdAt;

  const RecentExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.paidByName,
    this.groupId,
    this.groupName,
    required this.isCustom,
    required this.isMultiPayer,
    required this.isPayer,
    required this.userShare,
    required this.createdAt,
  });
}
