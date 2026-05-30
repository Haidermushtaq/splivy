import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group_model.dart';
import 'expenses_service.dart';

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

      final expenseIdRows = await _client
          .from('expenses')
          .select('id')
          .eq('group_id', gId)
          .eq('is_archived', false);
      final expenseIds =
          (expenseIdRows as List).map((e) => e['id'] as String).toList();

      double userBalance = 0;
      if (expenseIds.isNotEmpty) {
        final owedToMe = await _client
            .from('expense_splits')
            .select('amount')
            .eq('owed_to', _userId)
            .eq('is_settled', false)
            .inFilter('expense_id', expenseIds);
        for (final s in owedToMe as List) {
          userBalance += (s['amount'] as num).toDouble();
        }

        final iOwe = await _client
            .from('expense_splits')
            .select('amount')
            .eq('user_id', _userId)
            .eq('is_settled', false)
            .inFilter('expense_id', expenseIds);
        for (final s in iOwe as List) {
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

    final expenses = await ExpensesService().getGroupExpenses(groupId);

    double userBalance = 0;
    for (final exp in expenses) {
      if (exp.isSettled) continue;
      if (exp.userOwes) {
        userBalance -= exp.userShare;
      } else {
        userBalance += exp.userShare;
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

  /// Adds a registered user to a group by their exact username.
  ///
  /// Only the group creator may add members (enforced by RLS); a permission
  /// error is surfaced as a readable message. Returns the added member.
  Future<GroupMember> addMemberByUsername(
      String groupId, String username) async {
    final uname = username.trim().replaceFirst('@', '');
    if (uname.isEmpty) throw Exception('Enter a username');

    final profile = await _client
        .from('profiles')
        .select('id, full_name, username')
        .eq('username', uname)
        .maybeSingle();

    if (profile == null) {
      throw Exception('No user found with username "$uname"');
    }

    final userId = profile['id'] as String;

    final existing = await _client
        .from('group_members')
        .select('id')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();
    if (existing != null) {
      throw Exception('${profile['full_name']} is already in this group');
    }

    try {
      await _client.from('group_members').insert({
        'group_id': groupId,
        'user_id': userId,
      });
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('row-level security') || msg.contains('policy')) {
        throw Exception('Only the group creator can add members');
      }
      rethrow;
    }

    return GroupMember(
      id: userId,
      fullName: profile['full_name'] as String,
      username: profile['username'] as String,
    );
  }

  Future<void> deleteGroup(String groupId) async {
    await _client.from('groups').delete().eq('id', groupId);
  }
}
