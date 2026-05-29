import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_model.dart';
import '../services/groups_service.dart';

/// Singleton [GroupsService] instance.
final groupsServiceProvider = Provider<GroupsService>((ref) => GroupsService());

/// One-shot fetch of the current user's groups (no real-time updates).
///
/// Prefer [userGroupsStreamProvider] in GroupsScreen for live updates.
/// Use this provider only when a single fetch is sufficient (e.g. pickers).
/// Updates when: manually invalidated via ref.invalidate(userGroupsProvider).
final userGroupsProvider = FutureProvider<List<Group>>((ref) {
  return ref.read(groupsServiceProvider).getUserGroups();
});

/// Holds the currently selected group ID for cross-screen navigation.
///
/// Updated by: GroupsScreen when the user taps a group card.
final selectedGroupProvider = StateProvider<String?>((ref) => null);

/// Fetches full details (members + balances) for a single group by ID.
///
/// Used by: GroupDetailScreen, AddExpenseScreen.
/// Updates when: invalidated after adding/settling an expense, or on pull-to-refresh.
final groupDetailProvider =
    FutureProvider.family<GroupDetail, String>((ref, groupId) {
  return ref.read(groupsServiceProvider).getGroupDetails(groupId);
});
