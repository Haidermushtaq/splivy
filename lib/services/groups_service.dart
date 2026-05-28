import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';

class GroupsService {
  final _client = Supabase.instance.client;

  String get _userId => _client.auth.currentUser!.id;

  Future<Group> createGroup(String name) async {
    final row = await _client
        .from('groups')
        .insert({'name': name, 'created_by': _userId})
        .select()
        .single();

    await _client.from('group_members').insert({
      'group_id': row['id'],
      'user_id': _userId,
    });

    return Group.fromMap(row, memberCount: 1);
  }

  Future<List<Group>> getUserGroups() async {
    final memberships = await _client
        .from('group_members')
        .select('group_id')
        .eq('user_id', _userId);

    final groupIds =
        (memberships as List).map((m) => m['group_id'] as String).toList();

    if (groupIds.isEmpty) return [];

    final groups = await _client
        .from('groups')
        .select()
        .inFilter('id', groupIds)
        .eq('is_archived', false)
        .order('created_at', ascending: false);

    final result = <Group>[];
    for (final g in groups as List) {
      final gId = g['id'] as String;

      final members = await _client
          .from('group_members')
          .select('user_id')
          .eq('group_id', gId);
      final memberCount = (members as List).length;

      final expenses = await _client
          .from('expenses')
          .select('title, created_at')
          .eq('group_id', gId)
          .eq('is_archived', false)
          .order('created_at', ascending: false)
          .limit(1);

      final lastExpense = (expenses as List).isNotEmpty
          ? (expenses.first['title'] as String)
          : 'No expenses yet';

      double userBalance = 0;
      final myExpenses = await _client
          .from('expenses')
          .select('id, amount')
          .eq('group_id', gId)
          .eq('paid_by', _userId)
          .eq('is_archived', false);

      for (final exp in myExpenses as List) {
        final splits = await _client
            .from('expense_splits')
            .select('amount, is_settled, user_id')
            .eq('expense_id', exp['id'] as String)
            .neq('user_id', _userId)
            .eq('is_settled', false);
        for (final s in splits as List) {
          userBalance += (s['amount'] as num).toDouble();
        }
      }

      final mySplits = await _client
          .from('expense_splits')
          .select('amount, is_settled, expense_id')
          .eq('user_id', _userId)
          .eq('is_settled', false);

      for (final s in mySplits as List) {
        final expRow = await _client
            .from('expenses')
            .select('group_id, paid_by')
            .eq('id', s['expense_id'] as String)
            .eq('group_id', gId)
            .neq('paid_by', _userId)
            .maybeSingle();
        if (expRow != null) {
          userBalance -= (s['amount'] as num).toDouble();
        }
      }

      result.add(Group.fromMap(
        g,
        memberCount: memberCount,
        lastExpense: lastExpense,
        userBalance: userBalance,
      ));
    }

    return result;
  }

  Future<GroupDetail> getGroupDetails(String groupId) async {
    final groupRow = await _client
        .from('groups')
        .select()
        .eq('id', groupId)
        .single();

    final memberRows = await _client
        .from('group_members')
        .select('user_id')
        .eq('group_id', groupId);

    final memberIds =
        (memberRows as List).map((m) => m['user_id'] as String).toList();

    List<GroupMember> members = [];
    if (memberIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id, full_name, username')
          .inFilter('id', memberIds);
      members = (profiles as List)
          .map((p) => GroupMember(
                id: p['id'] as String,
                fullName: p['full_name'] as String,
                username: p['username'] as String,
              ))
          .toList();
    }

    final expenseRows = await _client
        .from('expenses')
        .select()
        .eq('group_id', groupId)
        .eq('is_archived', false)
        .order('created_at', ascending: false);

    final List<Expense> expenses = [];
    for (final e in expenseRows as List) {
      final paidById = e['paid_by'] as String;
      final paidByProfile = members.firstWhere(
        (m) => m.id == paidById,
        orElse: () => GroupMember(id: paidById, fullName: 'Unknown', username: ''),
      );

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
          final totalAmount = (e['amount'] as num).toDouble();
          userShare = totalAmount - userShare;
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

      expenses.add(Expense.fromMap(
        e,
        paidByName: paidByProfile.fullName,
        userShare: userShare,
        isSettled: isSettled,
      ));
    }

    double userBalance = 0;
    for (final exp in expenses) {
      if (exp.paidBy == _userId) {
        if (!exp.isSettled) userBalance += exp.userShare;
      } else {
        if (!exp.isSettled) userBalance -= exp.userShare;
      }
    }

    final group = Group.fromMap(
      groupRow,
      memberCount: memberIds.length,
      lastExpense: expenses.isNotEmpty ? expenses.first.title : 'No expenses yet',
      userBalance: userBalance,
    );

    return GroupDetail(group: group, members: members, expenses: expenses);
  }

  Future<void> deleteGroup(String groupId) async {
    await _client.from('groups').delete().eq('id', groupId);
  }
}
