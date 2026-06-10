import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense_model.dart';
import 'local_cache.dart';
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

  Future<List<Expense>> getGroupExpenses(
    String groupId, {
    bool includeArchived = false,
  }) {
    return cachedRead<List<Expense>>(
      key: 'group_expenses:$groupId:$includeArchived',
      live: () => _getGroupExpensesLive(groupId, includeArchived: includeArchived),
      toCache: (list) => list.map((e) => e.toCache()).toList(),
      fromCache: (j) => (j as List)
          .map((m) => Expense.fromCache((m as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  Future<List<Expense>> _getGroupExpensesLive(
    String groupId, {
    bool includeArchived = false,
  }) async {
    var query =
        _client.from('expenses').select().eq('group_id', groupId);
    if (!includeArchived) query = query.eq('is_archived', false);
    final rows = await query.order('created_at', ascending: false);

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

  /// Full detail of a single group expense: header info, the "who paid what"
  /// breakdown, and every debtor -> creditor settlement edge (settled and
  /// unsettled alike, so the in-expense offsetting history is visible).
  Future<GroupExpenseDetail> getGroupExpenseDetail(String expenseId) {
    return cachedRead<GroupExpenseDetail>(
      key: 'group_expense_detail:$expenseId',
      live: () => _getGroupExpenseDetailLive(expenseId),
      toCache: (d) => d.toCache(),
      fromCache: (j) =>
          GroupExpenseDetail.fromCache((j as Map).cast<String, dynamic>()),
    );
  }

  Future<GroupExpenseDetail> _getGroupExpenseDetailLive(String expenseId) async {
    // Phase 1: everything keyed only by the expense id, fetched concurrently.
    final phase1 = await Future.wait<dynamic>([
      _client.from('expenses').select().eq('id', expenseId).single(),
      _client
          .from('expense_splits')
          .select(
              'id, user_id, owed_to, amount, amount_paid, is_settled, payment_status')
          .eq('expense_id', expenseId),
      _client
          .from('expense_payers')
          .select('user_id, amount_paid')
          .eq('expense_id', expenseId),
    ]);
    final e = phase1[0] as Map<String, dynamic>;
    final splitRows = phase1[1] as List;
    final payerRows = phase1[2] as List;

    final isMultiPayer = e['is_multi_payer'] as bool? ?? false;
    final paidById = e['paid_by'] as String?;
    final groupId = e['group_id'] as String?;

    // Collect every user id we need a display name for, resolved in one query.
    final ids = <String>{};
    for (final s in splitRows) {
      ids.add(s['user_id'] as String);
      ids.add(s['owed_to'] as String);
    }
    for (final p in payerRows) {
      ids.add(p['user_id'] as String);
    }
    if (paidById != null) ids.add(paidById);

    // Phase 2: profiles, group name, and (multi-payer) guest payers, concurrently.
    final phase2 = await Future.wait<dynamic>([
      ids.isEmpty
          ? Future.value(const <dynamic>[])
          : _client
              .from('profiles')
              .select('id, full_name')
              .inFilter('id', ids.toList()),
      groupId == null
          ? Future.value(null)
          : _client.from('groups').select('name').eq('id', groupId).maybeSingle(),
      isMultiPayer
          ? _client
              .from('guest_splits')
              .select('guest_name, amount_paid')
              .eq('expense_id', expenseId)
              .gt('amount_paid', 0)
          : Future.value(const <dynamic>[]),
    ]);
    final profs = phase2[0] as List;
    final groupRow = phase2[1] as Map<String, dynamic>?;
    final guestPayers = phase2[2] as List;

    final groupName = groupId == null
        ? 'One-time'
        : (groupRow?['name'] as String? ?? 'Group');

    final nameMap = <String, String>{};
    for (final p in profs) {
      nameMap[p['id'] as String] = p['full_name'] as String? ?? 'Unknown';
    }

    String nameOf(String id) => id == _userId ? 'You' : (nameMap[id] ?? 'Unknown');

    // Paid-by label, computed from rows already fetched above (no extra round trips).
    final String paidByName;
    if (isMultiPayer) {
      final payerCount = payerRows.length + guestPayers.length;
      if (payerCount == 0) {
        paidByName = 'Unknown';
      } else if (payerCount == 1) {
        paidByName = payerRows.length == 1
            ? nameOf(payerRows[0]['user_id'] as String)
            : (guestPayers[0]['guest_name'] as String? ?? 'Unknown');
      } else if (payerRows.any((p) => p['user_id'] == _userId)) {
        paidByName =
            'You + ${payerCount - 1} ${payerCount == 2 ? 'other' : 'others'}';
      } else {
        paidByName = '$payerCount people';
      }
    } else {
      paidByName = paidById == null ? 'Unknown' : nameOf(paidById);
    }

    final edges = splitRows.map((s) {
      final debtorId = s['user_id'] as String;
      final creditorId = s['owed_to'] as String;
      return ExpenseSplitEdge(
        splitId: s['id'] as String,
        debtorId: debtorId,
        debtorName: nameOf(debtorId),
        creditorId: creditorId,
        creditorName: nameOf(creditorId),
        amount: (s['amount'] as num).toDouble(),
        isSettled: s['is_settled'] as bool? ?? false,
        paymentStatus: s['payment_status'] as String? ?? 'pending',
        amountPaid: (s['amount_paid'] as num?)?.toDouble() ?? 0,
      );
    }).toList();

    final payers = <PayerContribution>[];
    if (isMultiPayer) {
      for (final p in payerRows) {
        final uid = p['user_id'] as String;
        payers.add(PayerContribution(
          name: nameOf(uid),
          amount: (p['amount_paid'] as num).toDouble(),
          isYou: uid == _userId,
        ));
      }
    } else {
      payers.add(PayerContribution(
        name: paidByName,
        amount: (e['amount'] as num).toDouble(),
        isYou: paidById == _userId,
      ));
    }

    return GroupExpenseDetail(
      expense: Expense.fromMap(e, paidByName: paidByName),
      groupName: groupName,
      payers: payers,
      edges: edges,
    );
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

  /// Resolves the "paid by" label for many expenses in one shot, batching the
  /// payer and profile lookups instead of running [_resolvePaidByName] per row.
  /// Returns a map of expense id -> display label.
  Future<Map<String, String>> _resolvePaidByNames(
    List<Map<String, dynamic>> expenses,
  ) async {
    if (expenses.isEmpty) return {};

    final multiIds = <String>[];
    final singlePaidBy = <String, String?>{};
    for (final e in expenses) {
      final id = e['id'] as String;
      if (e['is_multi_payer'] as bool? ?? false) {
        multiIds.add(id);
      } else {
        singlePaidBy[id] = e['paid_by'] as String?;
      }
    }

    final payersByExpense = <String, List<String>>{};
    final guestPayersByExpense = <String, List<String>>{};
    if (multiIds.isNotEmpty) {
      final results = await Future.wait<dynamic>([
        _client
            .from('expense_payers')
            .select('expense_id, user_id')
            .inFilter('expense_id', multiIds),
        _client
            .from('guest_splits')
            .select('expense_id, guest_name, amount_paid')
            .inFilter('expense_id', multiIds)
            .gt('amount_paid', 0),
      ]);
      for (final p in results[0] as List) {
        (payersByExpense[p['expense_id'] as String] ??= [])
            .add(p['user_id'] as String);
      }
      for (final g in results[1] as List) {
        (guestPayersByExpense[g['expense_id'] as String] ??= [])
            .add(g['guest_name'] as String? ?? 'Unknown');
      }
    }

    final ids = <String>{};
    for (final v in payersByExpense.values) {
      ids.addAll(v);
    }
    for (final v in singlePaidBy.values) {
      if (v != null) ids.add(v);
    }
    final nameMap = <String, String>{};
    if (ids.isNotEmpty) {
      final profs = await _client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', ids.toList());
      for (final p in profs as List) {
        nameMap[p['id'] as String] = p['full_name'] as String? ?? 'Unknown';
      }
    }
    String nameOf(String id) =>
        id == _userId ? 'You' : (nameMap[id] ?? 'Unknown');

    final result = <String, String>{};
    for (final e in expenses) {
      final id = e['id'] as String;
      if (e['is_multi_payer'] as bool? ?? false) {
        final users = payersByExpense[id] ?? const [];
        final guests = guestPayersByExpense[id] ?? const [];
        final count = users.length + guests.length;
        if (count == 0) {
          result[id] = 'Unknown';
        } else if (count == 1) {
          result[id] = users.length == 1 ? nameOf(users.first) : guests.first;
        } else if (users.contains(_userId)) {
          result[id] =
              'You + ${count - 1} ${count == 2 ? 'other' : 'others'}';
        } else {
          result[id] = '$count people';
        }
      } else {
        final paidBy = singlePaidBy[id];
        result[id] = paidBy == null ? 'Unknown' : nameOf(paidBy);
      }
    }
    return result;
  }

  Future<UserBalance> getUserTotalBalance() {
    return cachedRead<UserBalance>(
      key: 'user_balance',
      live: _getUserTotalBalanceLive,
      toCache: (b) => b.toCache(),
      fromCache: (j) => UserBalance.fromCache((j as Map).cast<String, dynamic>()),
    );
  }

  Future<UserBalance> _getUserTotalBalanceLive() async {
    // Guest debts live only on guest_splits (no expense_splits row). The user
    // is always the creditor on their own expenses. A positive guest amount
    // means the guest owes the user; a negative amount means the user owes the
    // guest (guest overpaid). Fetch all three sets concurrently.
    final results = await Future.wait<dynamic>([
      _client
          .from('expense_splits')
          .select('amount, expenses!inner(is_archived)')
          .eq('owed_to', _userId)
          .eq('is_settled', false)
          .eq('expenses.is_archived', false),
      _client
          .from('expense_splits')
          .select('amount, expenses!inner(is_archived)')
          .eq('user_id', _userId)
          .eq('is_settled', false)
          .eq('expenses.is_archived', false),
      _client
          .from('guest_splits')
          .select('amount, expenses!inner(paid_by, is_archived)')
          .eq('is_settled', false)
          .eq('expenses.paid_by', _userId)
          .eq('expenses.is_archived', false),
    ]);
    final owedRows = results[0] as List;
    final owingRows = results[1] as List;
    final guestRows = results[2] as List;

    double totalOwed = 0;
    for (final s in owedRows) {
      totalOwed += (s['amount'] as num).toDouble();
    }

    double totalOwing = 0;
    for (final s in owingRows) {
      totalOwing += (s['amount'] as num).toDouble();
    }

    for (final g in guestRows) {
      final amount = (g['amount'] as num).toDouble();
      if (amount >= 0) {
        totalOwed += amount;
      } else {
        totalOwing += -amount;
      }
    }

    return UserBalance(totalOwed: totalOwed, totalOwing: totalOwing);
  }

  Future<List<DebtItem>> getSettleUpData() {
    return cachedRead<List<DebtItem>>(
      key: 'settle_up_data',
      live: _getSettleUpDataLive,
      toCache: (list) => list.map((d) => d.toCache()).toList(),
      fromCache: (j) => (j as List)
          .map((m) => DebtItem.fromCache((m as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  Future<List<DebtItem>> _getSettleUpDataLive() async {
    const expenseEmbed =
        'expenses!inner(title, group_id, created_at, is_archived)';

    final bothDirections = await Future.wait<dynamic>([
      _client
          .from('expense_splits')
          .select(
              'id, expense_id, amount, payment_status, payment_proof_url, payment_method, owed_to, $expenseEmbed')
          .eq('user_id', _userId)
          .eq('is_settled', false)
          .eq('expenses.is_archived', false),
      _client
          .from('expense_splits')
          .select(
              'id, expense_id, amount, payment_status, payment_proof_url, payment_method, user_id, $expenseEmbed')
          .eq('owed_to', _userId)
          .eq('is_settled', false)
          .eq('expenses.is_archived', false),
    ]);
    final iOwe = bothDirections[0] as List;
    final owedToMe = bothDirections[1] as List;

    final counterpartIds = <String>{
      ...iOwe.map((r) => r['owed_to']).whereType<String>(),
      ...owedToMe.map((r) => r['user_id']).whereType<String>(),
    }.toList();

    final groupIds = <String>{
      ...iOwe.map((r) => (r['expenses'] as Map)['group_id']).whereType<String>(),
      ...owedToMe
          .map((r) => (r['expenses'] as Map)['group_id'])
          .whereType<String>(),
    }.toList();

    final lookups = await Future.wait<dynamic>([
      counterpartIds.isEmpty
          ? Future.value(const <dynamic>[])
          : _client
              .from('profiles')
              .select('id, full_name, phone, avatar_url')
              .inFilter('id', counterpartIds),
      groupIds.isEmpty
          ? Future.value(const <dynamic>[])
          : _client.from('groups').select('id, name').inFilter('id', groupIds),
    ]);

    final profileMap = <String, Map<String, dynamic>>{};
    for (final p in lookups[0] as List) {
      profileMap[p['id'] as String] = p as Map<String, dynamic>;
    }

    final groupMap = <String, String>{};
    for (final g in lookups[1] as List) {
      groupMap[g['id'] as String] = g['name'] as String;
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
        avatarUrl: creditor?['avatar_url'] as String?,
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
        avatarUrl: debtor?['avatar_url'] as String?,
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

  Future<List<CustomExpenseDetail>> getCustomExpenses({
    bool includeArchived = false,
  }) {
    return cachedRead<List<CustomExpenseDetail>>(
      key: 'custom_expenses:$includeArchived',
      live: () => _getCustomExpensesLive(includeArchived: includeArchived),
      toCache: (list) => list.map((d) => d.toCache()).toList(),
      fromCache: (j) => (j as List)
          .map((m) =>
              CustomExpenseDetail.fromCache((m as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  Future<List<CustomExpenseDetail>> _getCustomExpensesLive({
    bool includeArchived = false,
  }) async {
    var query = _client
        .from('expenses')
        .select()
        .eq('paid_by', _userId)
        .eq('is_custom', true);
    if (!includeArchived) query = query.eq('is_archived', false);
    final rows = await query.order('created_at', ascending: false);

    final expenses = (rows as List).cast<Map<String, dynamic>>();
    if (expenses.isEmpty) return [];
    final ids = expenses.map((e) => e['id'] as String).toList();

    // Batch every dependent table across all expenses in parallel, then
    // assemble each detail in memory — no per-expense round trips.
    final batched = await Future.wait<dynamic>([
      _client
          .from('guest_splits')
          .select()
          .inFilter('expense_id', ids)
          .order('created_at', ascending: true),
      _client
          .from('expense_splits')
          .select('id, expense_id, user_id, owed_to, amount, is_settled')
          .inFilter('expense_id', ids)
          .or('user_id.eq.$_userId,owed_to.eq.$_userId'),
      _client.from('guest_guest_debts').select().inFilter('expense_id', ids),
      _client
          .from('expense_payers')
          .select('expense_id, user_id, amount_paid')
          .inFilter('expense_id', ids),
    ]);
    final guestRows = (batched[0] as List).cast<Map<String, dynamic>>();
    final splitRows = (batched[1] as List).cast<Map<String, dynamic>>();
    final ggRows = (batched[2] as List).cast<Map<String, dynamic>>();
    final payerRows = (batched[3] as List).cast<Map<String, dynamic>>();

    final guestsByExpense = <String, List<Map<String, dynamic>>>{};
    for (final g in guestRows) {
      (guestsByExpense[g['expense_id'] as String] ??= []).add(g);
    }
    final splitsByExpense = <String, List<Map<String, dynamic>>>{};
    for (final s in splitRows) {
      (splitsByExpense[s['expense_id'] as String] ??= []).add(s);
    }
    final ggByExpense = <String, List<Map<String, dynamic>>>{};
    for (final d in ggRows) {
      (ggByExpense[d['expense_id'] as String] ??= []).add(d);
    }
    final payersByExpense = <String, List<Map<String, dynamic>>>{};
    for (final p in payerRows) {
      (payersByExpense[p['expense_id'] as String] ??= []).add(p);
    }

    // Resolve every counterpart + payer profile in one query.
    final profileIds = <String>{};
    for (final s in splitRows) {
      final from = s['user_id'] as String;
      final to = s['owed_to'] as String;
      profileIds.add(from == _userId ? to : from);
    }
    for (final p in payerRows) {
      profileIds.add(p['user_id'] as String);
    }
    final profileMap = <String, Map<String, dynamic>>{};
    if (profileIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id, full_name, phone')
          .inFilter('id', profileIds.toList());
      for (final p in profiles as List) {
        profileMap[p['id'] as String] = p as Map<String, dynamic>;
      }
    }

    final List<CustomExpenseDetail> result = [];
    for (final e in expenses) {
      final expenseId = e['id'] as String;
      final isMultiPayer = e['is_multi_payer'] as bool? ?? false;

      final guests = (guestsByExpense[expenseId] ?? const [])
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

      // Signed from my perspective: positive = friend owes me, negative = I owe.
      final friendDebts = (splitsByExpense[expenseId] ?? const []).map((s) {
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

      final guestGuestDebts = (ggByExpense[expenseId] ?? const [])
          .map((d) => GuestGuestDebt.fromJson(d))
          .toList();

      // Build the "who paid what" breakdown across registered users and guests.
      // Every custom expense is created by the current user, so a single payer
      // is always "You"; multi-payer is derived from the batched payer rows.
      final expensePayers = payersByExpense[expenseId] ?? const [];
      final guestPayers = guests.where((g) => g.amountPaid > 0.01).toList();

      final payers = <PayerContribution>[];
      if (isMultiPayer) {
        for (final p in expensePayers) {
          final uid = p['user_id'] as String;
          final isYou = uid == _userId;
          payers.add(PayerContribution(
            name: isYou
                ? 'You'
                : (profileMap[uid]?['full_name'] as String? ?? 'Unknown'),
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
      for (final g in guestPayers) {
        payers.add(PayerContribution(name: g.guestName, amount: g.amountPaid));
      }

      final String paidByName;
      if (isMultiPayer) {
        final count = expensePayers.length + guestPayers.length;
        if (count == 0) {
          paidByName = 'Unknown';
        } else if (count == 1) {
          paidByName = expensePayers.length == 1
              ? (expensePayers.first['user_id'] == _userId
                  ? 'You'
                  : (profileMap[expensePayers.first['user_id']]?['full_name']
                          as String? ??
                      'Unknown'))
              : guestPayers.first.guestName;
        } else if (expensePayers.any((p) => p['user_id'] == _userId)) {
          paidByName =
              'You + ${count - 1} ${count == 2 ? 'other' : 'others'}';
        } else {
          paidByName = '$count people';
        }
      } else {
        paidByName = 'You';
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

  /// Archives any expense (group or one-time) once every debt on it is settled.
  /// Throws if any registered-user split or guest split is still outstanding.
  Future<void> archiveExpense(String expenseId) async {
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

  Future<void> archiveCustomExpense(String expenseId) =>
      archiveExpense(expenseId);

  /// Every settled debt the current user is part of, newest first: registered
  /// -user splits in either direction plus guest splits on their own one-time
  /// expenses. Auto-net offsets are included (`payment_status == 'netted'`),
  /// each carrying the expense it came from, who paid whom, the method used and
  /// any payment proof — the data behind the Settlement History screen.
  Future<List<SettlementRecord>> getSettlementHistory() {
    return cachedRead<List<SettlementRecord>>(
      key: 'settlement_history',
      live: _getSettlementHistoryLive,
      toCache: (list) => list.map((r) => r.toCache()).toList(),
      fromCache: (j) => (j as List)
          .map((m) =>
              SettlementRecord.fromCache((m as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  Future<List<SettlementRecord>> _getSettlementHistoryLive() async {
    const expenseEmbed = 'expenses!inner(title, group_id, created_at)';
    const fields =
        'id, expense_id, amount, payment_status, payment_method, payment_proof_url, settled_at';

    final iPaid = await _client
        .from('expense_splits')
        .select('$fields, owed_to, $expenseEmbed')
        .eq('user_id', _userId)
        .eq('is_settled', true);

    final paidToMe = await _client
        .from('expense_splits')
        .select('$fields, user_id, $expenseEmbed')
        .eq('owed_to', _userId)
        .eq('is_settled', true);

    final guestSettled = await _client
        .from('guest_splits')
        .select(
            'id, expense_id, guest_name, amount, payment_status, payment_method, payment_proof_url, settled_at, expenses!inner(title, group_id, created_at, paid_by)')
        .eq('is_settled', true)
        .eq('expenses.paid_by', _userId);

    final counterpartIds = <String>{
      ...(iPaid as List).map((r) => r['owed_to']).whereType<String>(),
      ...(paidToMe as List).map((r) => r['user_id']).whereType<String>(),
    }.toList();

    final groupIds = <String>{
      ...iPaid.map((r) => (r['expenses'] as Map)['group_id']).whereType<String>(),
      ...paidToMe
          .map((r) => (r['expenses'] as Map)['group_id'])
          .whereType<String>(),
      ...(guestSettled as List)
          .map((r) => (r['expenses'] as Map)['group_id'])
          .whereType<String>(),
    }.toList();

    final nameMap = <String, String>{};
    if (counterpartIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', counterpartIds);
      for (final p in profiles as List) {
        nameMap[p['id'] as String] = p['full_name'] as String? ?? 'Unknown';
      }
    }

    final groupMap = <String, String>{};
    if (groupIds.isNotEmpty) {
      final groups = await _client
          .from('groups')
          .select('id, name')
          .inFilter('id', groupIds);
      for (final g in groups as List) {
        groupMap[g['id'] as String] = g['name'] as String? ?? 'Group';
      }
    }

    String groupNameOf(Map exp) {
      final gid = exp['group_id'] as String?;
      return gid == null ? 'One-time' : (groupMap[gid] ?? 'Group');
    }

    DateTime settledOf(Map row) {
      final s = row['settled_at'] as String?;
      final c = (row['expenses'] as Map)['created_at'] as String?;
      return DateTime.parse(
          s ?? c ?? DateTime.now().toIso8601String());
    }

    final records = <SettlementRecord>[];

    for (final s in iPaid) {
      final exp = s['expenses'] as Map;
      final status = s['payment_status'] as String? ?? 'confirmed';
      records.add(SettlementRecord(
        id: s['id'] as String,
        expenseId: s['expense_id'] as String,
        expenseTitle: exp['title'] as String? ?? 'Expense',
        groupName: groupNameOf(exp),
        counterpartName: nameMap[s['owed_to']] ?? 'Unknown',
        youPaid: true,
        amount: (s['amount'] as num).toDouble(),
        paymentMethod: s['payment_method'] as String?,
        paymentProofUrl: s['payment_proof_url'] as String?,
        paymentStatus: status,
        isOffset: status == 'netted',
        settledAt: settledOf(s),
      ));
    }

    for (final s in paidToMe) {
      final exp = s['expenses'] as Map;
      final status = s['payment_status'] as String? ?? 'confirmed';
      records.add(SettlementRecord(
        id: s['id'] as String,
        expenseId: s['expense_id'] as String,
        expenseTitle: exp['title'] as String? ?? 'Expense',
        groupName: groupNameOf(exp),
        counterpartName: nameMap[s['user_id']] ?? 'Unknown',
        youPaid: false,
        amount: (s['amount'] as num).toDouble(),
        paymentMethod: s['payment_method'] as String?,
        paymentProofUrl: s['payment_proof_url'] as String?,
        paymentStatus: status,
        isOffset: status == 'netted',
        settledAt: settledOf(s),
      ));
    }

    for (final g in guestSettled) {
      final raw = (g['amount'] as num).toDouble();
      // Guest rows that netted to zero at creation aren't real settlements.
      if (raw.abs() < 0.01) continue;
      final exp = g['expenses'] as Map;
      final status = g['payment_status'] as String? ?? 'confirmed';
      records.add(SettlementRecord(
        id: g['id'] as String,
        expenseId: g['expense_id'] as String,
        expenseTitle: exp['title'] as String? ?? 'Expense',
        groupName: groupNameOf(exp),
        counterpartName: g['guest_name'] as String? ?? 'Guest',
        // Positive = guest owed you (they paid you); negative = you owed them.
        youPaid: raw < 0,
        amount: raw.abs(),
        paymentMethod: g['payment_method'] as String?,
        paymentProofUrl: g['payment_proof_url'] as String?,
        paymentStatus: status,
        isOffset: status == 'netted',
        isGuest: true,
        settledAt: settledOf(g),
      ));
    }

    records.sort((a, b) => b.settledAt.compareTo(a.settledAt));
    return records;
  }

  /// Updates only the descriptive fields of an expense — title, category, and
  /// note. None of these columns feed the settlement algorithm, so no splits
  /// are recomputed and existing balances are untouched. An empty [note]
  /// clears the column.
  Future<void> updateExpenseMeta({
    required String expenseId,
    required String title,
    required String category,
    String? note,
  }) async {
    await _client.from('expenses').update({
      'title': title,
      'category': category,
      'note': (note != null && note.isNotEmpty) ? note : null,
    }).eq('id', expenseId);
  }

  /// Whether [expenseId] can still be fully edited (amounts, payers, people).
  ///
  /// Full edit deletes and rebuilds every split, so it is only safe while
  /// nothing on the expense has been settled or offset — those carry history
  /// (real payments, auto-net cascades) that a rewrite would silently destroy.
  /// Returns false if the expense is archived, or if any registered-user split
  /// is settled / non-pending / already touched by auto-netting
  /// (`amount_paid > 0`), or if any guest or guest-to-guest debt is settled.
  Future<bool> canFullyEdit(String expenseId) async {
    final results = await Future.wait<dynamic>([
      _client.from('expenses').select('is_archived').eq('id', expenseId).single(),
      _client
          .from('expense_splits')
          .select('is_settled, payment_status, amount_paid')
          .eq('expense_id', expenseId),
      _client
          .from('guest_splits')
          .select('is_settled')
          .eq('expense_id', expenseId),
      _client
          .from('guest_guest_debts')
          .select('is_settled')
          .eq('expense_id', expenseId),
    ]);

    final expense = results[0] as Map<String, dynamic>;
    if (expense['is_archived'] as bool? ?? false) return false;

    for (final s in results[1] as List) {
      final settled = s['is_settled'] as bool? ?? false;
      final status = s['payment_status'] as String? ?? 'pending';
      final paid = (s['amount_paid'] as num?)?.toDouble() ?? 0;
      if (settled || status != 'pending' || paid > 0.01) return false;
    }
    for (final g in results[2] as List) {
      if (g['is_settled'] as bool? ?? false) return false;
    }
    for (final d in results[3] as List) {
      if (d['is_settled'] as bool? ?? false) return false;
    }
    return true;
  }

  /// Reconstructs [expenseId] into the editable shape the add/edit form needs:
  /// header fields plus each participant's paid and owed amounts.
  ///
  /// Paid amounts are exact (single payer paid the whole bill; multi-payer comes
  /// from `expense_payers` and guest `amount_paid`). Owed amounts are recovered
  /// as `paid - net`, where net is summed from the minimized settlement edges.
  /// For group expenses the member list seeds the participant set so members who
  /// netted to zero (no edge) still appear; one-time expenses can only surface
  /// participants that left an edge or a guest row.
  Future<EditableExpense> getEditableExpense(String expenseId) async {
    final e =
        await _client.from('expenses').select().eq('id', expenseId).single();
    final groupId = e['group_id'] as String?;
    final isMultiPayer = e['is_multi_payer'] as bool? ?? false;
    final paidById = e['paid_by'] as String?;
    final total = (e['amount'] as num).toDouble();

    final batched = await Future.wait<dynamic>([
      _client
          .from('expense_splits')
          .select('user_id, owed_to, amount')
          .eq('expense_id', expenseId),
      _client
          .from('expense_payers')
          .select('user_id, amount_paid')
          .eq('expense_id', expenseId),
      _client
          .from('guest_splits')
          .select('guest_name, guest_phone, share, amount_paid')
          .eq('expense_id', expenseId)
          .order('created_at', ascending: true),
    ]);
    final splitRows = (batched[0] as List).cast<Map<String, dynamic>>();
    final payerRows = (batched[1] as List).cast<Map<String, dynamic>>();
    final guestRows = (batched[2] as List).cast<Map<String, dynamic>>();

    // net[user] = (sum of edges they're owed on) - (sum of edges they owe).
    final net = <String, double>{};
    final userIds = <String>{};
    for (final s in splitRows) {
      final debtor = s['user_id'] as String;
      final creditor = s['owed_to'] as String;
      final amt = (s['amount'] as num).toDouble();
      net[debtor] = (net[debtor] ?? 0) - amt;
      net[creditor] = (net[creditor] ?? 0) + amt;
      userIds.add(debtor);
      userIds.add(creditor);
    }

    final paid = <String, double>{};
    if (isMultiPayer) {
      for (final p in payerRows) {
        paid[p['user_id'] as String] = (p['amount_paid'] as num).toDouble();
      }
    } else if (paidById != null) {
      paid[paidById] = total;
    }
    userIds.addAll(paid.keys);
    if (paidById != null) userIds.add(paidById);
    userIds.add(_userId);

    // Group members seed the participant universe so net-zero members appear.
    if (groupId != null) {
      final members = await _client
          .from('group_members')
          .select('user_id')
          .eq('group_id', groupId);
      for (final m in members as List) {
        userIds.add(m['user_id'] as String);
      }
    }

    final nameMap = <String, String>{};
    if (userIds.isNotEmpty) {
      final profs = await _client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', userIds.toList());
      for (final p in profs as List) {
        nameMap[p['id'] as String] = p['full_name'] as String? ?? 'Unknown';
      }
    }

    final participants = <EditableParticipant>[];
    for (final id in userIds) {
      final pPaid = paid[id] ?? 0;
      final owedRaw =
          double.parse((pPaid - (net[id] ?? 0)).toStringAsFixed(2));
      final owed = owedRaw < 0.01 ? 0.0 : owedRaw;
      participants.add(EditableParticipant(
        userId: id,
        name: id == _userId ? 'You' : (nameMap[id] ?? 'Unknown'),
        isYou: id == _userId,
        paid: pPaid,
        owed: owed,
        includedInSplit: owed > 0.01,
      ));
    }
    participants.sort((a, b) {
      if (a.isYou != b.isYou) return a.isYou ? -1 : 1;
      return a.name.compareTo(b.name);
    });

    final guests = guestRows
        .map((g) => EditableGuest(
              name: g['guest_name'] as String? ?? '',
              phone: g['guest_phone'] as String? ?? '',
              owed: (g['share'] as num?)?.toDouble() ?? 0,
              paid: (g['amount_paid'] as num?)?.toDouble() ?? 0,
            ))
        .toList();

    // Detect whether the split was equal so the form can show "Equal Split";
    // otherwise preserve the exact per-person amounts under "Custom Split".
    final included = participants.where((p) => p.includedInSplit).toList();
    final splitCount = included.length + guests.length;
    bool isCustomSplit = true;
    if (splitCount > 0 && total > 0) {
      final per = total / splitCount;
      final allEqual = included.every((p) => (p.owed - per).abs() < 0.02) &&
          guests.every((g) => (g.owed - per).abs() < 0.02);
      isCustomSplit = !allEqual;
    }

    return EditableExpense(
      expenseId: expenseId,
      groupId: groupId,
      title: e['title'] as String? ?? '',
      totalAmount: total,
      category: e['category'] as String? ?? 'Other',
      note: e['note'] as String?,
      isMultiPayer: isMultiPayer,
      isCustomSplit: isCustomSplit,
      singlePayerId: isMultiPayer ? null : paidById,
      participants: participants,
      guests: guests,
    );
  }

  /// Rewrites every money-bearing part of [expenseId] — amount, payers, splits,
  /// guests — by deleting all derived rows and rebuilding them through the same
  /// settlement path used at creation. Guarded by [canFullyEdit], which is
  /// re-checked here so a debt settled while the form was open can't be
  /// clobbered. Works for both group and one-time expenses.
  Future<void> updateExpenseFull({
    required String expenseId,
    required String title,
    required double totalAmount,
    required bool isMultiPayer,
    String? singlePayerId,
    required List<Map<String, dynamic>> payerAmounts,
    required List<Map<String, dynamic>> splitAmounts,
    required String category,
    String? note,
    List<GuestSplitInput> guestSplits = const [],
  }) async {
    if (!await canFullyEdit(expenseId)) {
      throw Exception(
          'This expense can no longer be fully edited — a debt on it was '
          'settled or offset. Reopen it to see the latest.');
    }

    final existing = await _client
        .from('expenses')
        .select('group_id')
        .eq('id', expenseId)
        .single();
    final groupId = existing['group_id'] as String?;
    final isOneTime = groupId == null;

    // One-time expenses are always creator-paid and custom; group expenses keep
    // the creation rules (single payer is the selected member, custom only when
    // guests are involved).
    final effectiveSinglePayer =
        isMultiPayer ? null : (isOneTime ? _userId : singlePayerId);
    final paidByValue =
        isMultiPayer ? (isOneTime ? _userId : null) : effectiveSinglePayer;
    final isCustomFlag = isOneTime || guestSplits.isNotEmpty;

    // Wipe all derived rows, then rebuild from scratch.
    await _client.from('guest_guest_debts').delete().eq('expense_id', expenseId);
    await _client.from('guest_splits').delete().eq('expense_id', expenseId);
    await _client.from('expense_payers').delete().eq('expense_id', expenseId);
    await _client.from('expense_splits').delete().eq('expense_id', expenseId);

    final updateData = <String, dynamic>{
      'title': title,
      'amount': totalAmount,
      'paid_by': paidByValue,
      'is_multi_payer': isMultiPayer,
      'category': category,
      'note': (note != null && note.isNotEmpty) ? note : null,
      'is_custom': isCustomFlag,
    };
    await _client.from('expenses').update(updateData).eq('id', expenseId);

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

    final edges = await _writeSettlement(
      expenseId: expenseId,
      isMultiPayer: isMultiPayer,
      singlePayerId: effectiveSinglePayer,
      totalAmount: totalAmount,
      payerAmounts: payerAmounts,
      splitAmounts: splitAmounts,
      guestSplits: guestSplits,
    );

    await _autoNetAfterCreate(edges);
  }

  Future<void> deleteExpense(String expenseId) async {
    await _client.from('expenses').delete().eq('id', expenseId);
  }

  /// Captures an expense row plus its splits so a delete can be undone by
  /// re-inserting the exact same records (ids preserved).
  Future<Map<String, dynamic>> getExpenseSnapshot(String expenseId) async {
    final expense =
        await _client.from('expenses').select().eq('id', expenseId).single();
    final splits = await _client
        .from('expense_splits')
        .select()
        .eq('expense_id', expenseId);
    return {
      'expense': expense,
      'splits': (splits as List).cast<Map<String, dynamic>>(),
    };
  }

  /// Re-inserts an expense and its splits from a [getExpenseSnapshot] result.
  Future<void> restoreExpenseSnapshot(Map<String, dynamic> snapshot) async {
    await _client.from('expenses').insert(snapshot['expense']);
    final splits = (snapshot['splits'] as List).cast<Map<String, dynamic>>();
    if (splits.isNotEmpty) {
      await _client.from('expense_splits').insert(splits);
    }
  }

  /// Recent expenses the current user is part of (as payer or as a split
  /// participant), newest first, capped at 20. Used by the dashboard activity
  /// feed.
  Future<List<RecentExpense>> getRecentExpenses() {
    return cachedRead<List<RecentExpense>>(
      key: 'recent_expenses',
      live: () => _loadExpenseFeed(archived: false, limit: 20),
      toCache: (list) => list.map((e) => e.toCache()).toList(),
      fromCache: _recentFeedFromCache,
    );
  }

  /// Archived (settled) expenses the current user is part of, newest first.
  Future<List<RecentExpense>> getArchivedExpenses() {
    return cachedRead<List<RecentExpense>>(
      key: 'archived_expenses',
      live: () => _loadExpenseFeed(archived: true, limit: 100),
      toCache: (list) => list.map((e) => e.toCache()).toList(),
      fromCache: _recentFeedFromCache,
    );
  }

  static List<RecentExpense> _recentFeedFromCache(dynamic j) => (j as List)
      .map((m) => RecentExpense.fromCache((m as Map).cast<String, dynamic>()))
      .toList();

  /// One-time (non-group) expenses the current user participates in — whether
  /// they created the bill or merely appear on a split — newest first. Powers
  /// the History → One-time list so non-creators see their bills too, not just
  /// the ones they paid for.
  Future<List<RecentExpense>> getOneTimeHistory({
    bool includeArchived = false,
  }) {
    return cachedRead<List<RecentExpense>>(
      key: 'one_time_history:$includeArchived',
      live: () => _loadExpenseFeed(
        archived: includeArchived ? null : false,
        limit: 200,
        oneTimeOnly: true,
      ),
      toCache: (list) => list.map((e) => e.toCache()).toList(),
      fromCache: _recentFeedFromCache,
    );
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
    required bool? archived,
    required int limit,
    bool oneTimeOnly = false,
  }) async {
    var paidQuery =
        _client.from('expenses').select().eq('paid_by', _userId);
    if (archived != null) paidQuery = paidQuery.eq('is_archived', archived);
    final paid = await paidQuery;

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
      var splitQuery =
          _client.from('expenses').select().inFilter('id', splitIds);
      if (archived != null) {
        splitQuery = splitQuery.eq('is_archived', archived);
      }
      final fromSplits = await splitQuery;
      for (final e in fromSplits as List) {
        byId[e['id'] as String] = e as Map<String, dynamic>;
      }
    }

    if (oneTimeOnly) {
      byId.removeWhere((_, e) => e['group_id'] != null);
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

    // Resolve every payer display name in one batched query.
    final paidByMap = await _resolvePaidByNames(limited);

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
        paidByName: paidByMap[expenseId] ?? 'Unknown',
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

  Map<String, dynamic> toCache() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'paid_by_name': paidByName,
        'group_id': groupId,
        'group_name': groupName,
        'is_custom': isCustom,
        'is_multi_payer': isMultiPayer,
        'is_payer': isPayer,
        'user_share': userShare,
        'created_at': createdAt.toIso8601String(),
      };

  factory RecentExpense.fromCache(Map<String, dynamic> j) => RecentExpense(
        id: j['id'] as String,
        title: j['title'] as String,
        amount: (j['amount'] as num).toDouble(),
        category: j['category'] as String? ?? 'Other',
        paidByName: j['paid_by_name'] as String? ?? 'Unknown',
        groupId: j['group_id'] as String?,
        groupName: j['group_name'] as String?,
        isCustom: j['is_custom'] as bool? ?? false,
        isMultiPayer: j['is_multi_payer'] as bool? ?? false,
        isPayer: j['is_payer'] as bool? ?? false,
        userShare: (j['user_share'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
