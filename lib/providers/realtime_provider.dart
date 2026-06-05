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

/// Singleton [RealtimeService]; disposed automatically when the provider
/// is destroyed (e.g. on logout).
final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService();
  ref.onDispose(service.disposeAll);
  return service;
});

/// Live expense stream for a group.
///
/// Uses asyncMap so every Supabase row-change triggers a full re-fetch that
/// computes paidByName, userShare, and isSettled server-side.
/// Used by: GroupDetailScreen (AnimatedList).
/// Updates when: any row in 'expenses' for this group changes.
final groupExpensesStreamProvider =
    StreamProvider.family<List<Expense>, String>((ref, groupId) {
  final service = ref.read(expensesServiceProvider);
  return Supabase.instance.client
      .from('expenses')
      .stream(primaryKey: ['id'])
      .eq('group_id', groupId)
      .asyncMap((_) => service.getGroupExpenses(groupId));
});

/// Live stream of pending friend requests directed at the current user.
///
/// Used by: FriendsScreen (request list), DashboardScreen bottom-nav badge.
/// Updates when: any row in 'friends' where friend_id = current user changes.
final friendRequestsStreamProvider =
    StreamProvider<List<PendingRequest>>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return const Stream.empty();
  final service = ref.read(friendsServiceProvider);
  return Supabase.instance.client
      .from('friends')
      .stream(primaryKey: ['id'])
      .eq('friend_id', user.id)
      .asyncMap((_) => service.getPendingRequests());
});

/// Live stream of group members for a single group.
///
/// Used by: GroupDetailScreen (members row).
/// Updates when: any row in 'group_members' for this group changes.
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

/// Background listener that fires a local notification when a NEW friend
/// request arrives while the app is open.
///
/// Keep alive at the app level (watched in SplivyApp.build) so it stays
/// active regardless of which screen is visible.
/// Does NOT emit a value — side-effect only.
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

/// Live groups list for the current user.
///
/// Used by: GroupsScreen — refreshes the list automatically when the user
/// joins or is removed from a group.
/// Updates when: any row in 'group_members' for the current user changes.
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
