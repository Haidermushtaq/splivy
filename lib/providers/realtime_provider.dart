import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense_model.dart';
import '../models/friend_model.dart';
import '../models/group_model.dart';
import '../services/notification_service.dart';
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

// Fires a local notification when a new friend request arrives.
// Watch this provider at the app level to keep it alive.
final friendRequestNotificationProvider = Provider.autoDispose((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;

  bool initialized = false;
  Set<String> knownIds = {};

  final sub = Supabase.instance.client
      .from('friends')
      .stream(primaryKey: ['id'])
      .eq('friend_id', user.id)
      .listen((data) async {
        final pending = data
            .where((r) => r['status'] == 'pending')
            .toList();

        if (!initialized) {
          knownIds = pending.map((r) => r['id'] as String).toSet();
          initialized = true;
          return;
        }

        final currentIds = pending.map((r) => r['id'] as String).toSet();
        final newIds = currentIds.difference(knownIds);

        for (final id in newIds) {
          final req = pending.firstWhere((r) => r['id'] == id);
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('username')
              .eq('id', req['user_id'] as String)
              .maybeSingle();
          if (profile != null) {
            NotificationService()
                .showFriendRequestNotification(profile['username'] as String);
          }
        }

        knownIds = currentIds;
      });

  ref.onDispose(sub.cancel);
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
