import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_model.dart';
import '../services/groups_service.dart';

final groupsServiceProvider = Provider<GroupsService>((ref) => GroupsService());

final userGroupsProvider = FutureProvider<List<Group>>((ref) {
  return ref.read(groupsServiceProvider).getUserGroups();
});

final selectedGroupProvider = StateProvider<String?>((ref) => null);

final groupDetailProvider =
    FutureProvider.family<GroupDetail, String>((ref, groupId) {
  return ref.read(groupsServiceProvider).getGroupDetails(groupId);
});
