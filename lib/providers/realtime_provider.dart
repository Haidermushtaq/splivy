import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense_model.dart';
import '../models/friend_model.dart';
import '../models/group_model.dart';
import '../services/realtime_service.dart';
import 'expenses_provider.dart';
import 'friends_provider.dart';
import 'groups_provider.dart';

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService();
  ref.onDispose(service.disposeAll);
  return service;
});

// Real-time expense stream for a group — uses asyncMap so we get fully
// computed expenses (paidByName, userShare, isSettled) on every update.
final groupExpensesStreamProvider =
    StreamProvider.family<List<Expense>, String>((ref, groupId) {
  final service = ref.read(expensesServiceProvider);
  return Supabase.instance.client
      .from('expenses')
      .stream(primaryKey: ['id'])
      .eq('group_id', groupId)
      .asyncMap((_) => service.getGroupExpenses(groupId));
});

// Real-time balance stream — re-calculates whenever the current user's splits change.
final userBalanceStreamProvider = StreamProvider<UserBalance>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return const Stream.empty();
  final service = ref.read(expensesServiceProvider);
  return Supabase.instance.client
      .from('expense_splits')
      .stream(primaryKey: ['id'])
      .eq('user_id', user.id)
      .asyncMap((_) => service.getUserTotalBalance());
});

// Real-time pending friend requests stream.
final friendRequestsStreamProvider = StreamProvider<List<PendingRequest>>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return const Stream.empty();
  final service = ref.read(friendsServiceProvider);
  return Supabase.instance.client
      .from('friends')
      .stream(primaryKey: ['id'])
      .eq('friend_id', user.id)
      .asyncMap((_) => service.getPendingRequests());
});

// Real-time group members stream for a specific group.
final groupMembersStreamProvider =
    StreamProvider.family<List<GroupMember>, String>((ref, groupId) {
  final service = ref.read(groupsServiceProvider);
  return Supabase.instance.client
      .from('group_members')
      .stream(primaryKey: ['id'])
      .eq('group_id', groupId)
      .asyncMap((_) async {
        final detail = await service.getGroupDetails(groupId);
        return detail.members;
      });
});

// Real-time groups list — re-fetches whenever the user's group memberships change.
final userGroupsStreamProvider = StreamProvider<List<Group>>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return const Stream.empty();
  final service = ref.read(groupsServiceProvider);
  return Supabase.instance.client
      .from('group_members')
      .stream(primaryKey: ['id'])
      .eq('user_id', user.id)
      .asyncMap((_) => service.getUserGroups());
});
