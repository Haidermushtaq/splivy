import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense_model.dart';

class ExpensesService {
  final _client = Supabase.instance.client;

  String get _userId => _client.auth.currentUser!.id;

  Future<Expense> addExpense({
    required String groupId,
    required String title,
    required double amount,
    required String category,
    required String paidBy,
    required Map<String, double> splits,
    String? note,
    List<GuestSplitInput> guestSplits = const [],
  }) async {
    final isCustom = guestSplits.isNotEmpty;
    final row = await _client
        .from('expenses')
        .insert({
          'group_id': groupId,
          'title': title,
          'amount': amount,
          'paid_by': paidBy,
          'category': category,
          'is_custom': isCustom,
          if (note != null) 'note': note, // ignore: use_null_aware_elements
        })
        .select()
        .single();

    final expenseId = row['id'] as String;

    if (splits.isNotEmpty) {
      final splitRows = splits.entries
          .map((e) => {
                'expense_id': expenseId,
                'user_id': e.key,
                'amount': e.value,
                'is_settled': false,
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

    return Expense.fromMap(row, paidByName: 'You', userShare: 0, isSettled: false);
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
      final paidById = e['paid_by'] as String;

      String paidByName = 'Unknown';
      final profile = await _client
          .from('profiles')
          .select('full_name')
          .eq('id', paidById)
          .maybeSingle();
      if (profile != null) {
        paidByName = paidById == _userId ? 'You' : (profile['full_name'] as String);
      }

      final mySplit = await _client
          .from('expense_splits')
          .select('amount, is_settled')
          .eq('expense_id', e['id'] as String)
          .eq('user_id', _userId)
          .maybeSingle();

      double userShare = 0;
      bool isSettled = true;

      if (mySplit != null) {
        userShare = (mySplit['amount'] as num).toDouble();
        isSettled = mySplit['is_settled'] as bool? ?? false;
        if (paidById == _userId) {
          userShare = (e['amount'] as num).toDouble() - userShare;
        }
      } else if (paidById == _userId) {
        final otherSplits = await _client
            .from('expense_splits')
            .select('amount, is_settled')
            .eq('expense_id', e['id'] as String)
            .neq('user_id', _userId);
        double othersTotal = 0;
        bool allSettled = true;
        for (final s in otherSplits as List) {
          othersTotal += (s['amount'] as num).toDouble();
          if (!(s['is_settled'] as bool? ?? false)) allSettled = false;
        }
        userShare = othersTotal;
        isSettled = allSettled;
      }

      result.add(Expense.fromMap(
        e,
        paidByName: paidByName,
        userShare: userShare,
        isSettled: isSettled,
      ));
    }

    return result;
  }

  Future<UserBalance> getUserTotalBalance() async {
    double totalOwed = 0;
    double totalOwing = 0;

    final myExpenses = await _client
        .from('expenses')
        .select('id, amount')
        .eq('paid_by', _userId)
        .eq('is_archived', false);

    for (final exp in myExpenses as List) {
      final splits = await _client
          .from('expense_splits')
          .select('amount, is_settled')
          .eq('expense_id', exp['id'] as String)
          .neq('user_id', _userId)
          .eq('is_settled', false);
      for (final s in splits as List) {
        totalOwed += (s['amount'] as num).toDouble();
      }
    }

    final mySplits = await _client
        .from('expense_splits')
        .select('amount, is_settled, expense_id')
        .eq('user_id', _userId)
        .eq('is_settled', false);

    for (final s in mySplits as List) {
      final exp = await _client
          .from('expenses')
          .select('paid_by, is_archived')
          .eq('id', s['expense_id'] as String)
          .neq('paid_by', _userId)
          .eq('is_archived', false)
          .maybeSingle();
      if (exp != null) {
        totalOwing += (s['amount'] as num).toDouble();
      }
    }

    return UserBalance(totalOwed: totalOwed, totalOwing: totalOwing);
  }

  Future<List<DebtItem>> getSettleUpData() async {
    final List<DebtItem> debts = [];

    final mySplits = await _client
        .from('expense_splits')
        .select('id, expense_id, amount, payment_status, payment_proof_url, payment_method')
        .eq('user_id', _userId)
        .eq('is_settled', false);

    for (final s in mySplits as List) {
      final exp = await _client
          .from('expenses')
          .select('id, title, group_id, paid_by, created_at')
          .eq('id', s['expense_id'] as String)
          .neq('paid_by', _userId)
          .eq('is_archived', false)
          .maybeSingle();

      if (exp == null) continue;

      final paidByProfile = await _client
          .from('profiles')
          .select('full_name, phone')
          .eq('id', exp['paid_by'] as String)
          .maybeSingle();

      final groupRow = await _client
          .from('groups')
          .select('name')
          .eq('id', exp['group_id'] as String)
          .maybeSingle();

      final paidByName = paidByProfile?['full_name'] as String? ?? 'Unknown';
      final receiverPhone = paidByProfile?['phone'] as String?;
      final groupName = groupRow?['name'] as String? ?? 'Unknown Group';
      final createdAt = DateTime.parse(exp['created_at'] as String);
      final dueSince =
          '${createdAt.day}/${createdAt.month}/${createdAt.year}';

      debts.add(DebtItem(
        expenseId: exp['id'] as String,
        splitId: s['id'] as String,
        name: paidByName,
        groupName: groupName,
        dueSince: dueSince,
        amount: (s['amount'] as num).toDouble(),
        youOwe: true,
        expenseTitle: exp['title'] as String,
        receiverPhone: receiverPhone,
        paymentStatus: s['payment_status'] as String? ?? 'pending',
        paymentProofUrl: s['payment_proof_url'] as String?,
        paymentMethod: s['payment_method'] as String?,
      ));
    }

    final myPaidExpenses = await _client
        .from('expenses')
        .select('id, title, group_id, created_at')
        .eq('paid_by', _userId)
        .eq('is_archived', false);

    for (final exp in myPaidExpenses as List) {
      final unsettledSplits = await _client
          .from('expense_splits')
          .select('id, user_id, amount, payment_status, payment_proof_url, payment_method')
          .eq('expense_id', exp['id'] as String)
          .neq('user_id', _userId)
          .eq('is_settled', false);

      for (final s in unsettledSplits as List) {
        final debtorProfile = await _client
            .from('profiles')
            .select('full_name, phone')
            .eq('id', s['user_id'] as String)
            .maybeSingle();

        final groupRow = await _client
            .from('groups')
            .select('name')
            .eq('id', exp['group_id'] as String)
            .maybeSingle();

        final debtorName = debtorProfile?['full_name'] as String? ?? 'Unknown';
        final debtorPhone = debtorProfile?['phone'] as String?;
        final groupName = groupRow?['name'] as String? ?? 'Unknown Group';
        final createdAt = DateTime.parse(exp['created_at'] as String);
        final dueSince =
            '${createdAt.day}/${createdAt.month}/${createdAt.year}';

        debts.add(DebtItem(
          expenseId: exp['id'] as String,
          splitId: s['id'] as String,
          name: debtorName,
          groupName: groupName,
          dueSince: dueSince,
          amount: (s['amount'] as num).toDouble(),
          youOwe: false,
          expenseTitle: exp['title'] as String,
          receiverPhone: debtorPhone,
          paymentStatus: s['payment_status'] as String? ?? 'pending',
          paymentProofUrl: s['payment_proof_url'] as String?,
          paymentMethod: s['payment_method'] as String?,
        ));
      }
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
