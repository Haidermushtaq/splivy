import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/friend_model.dart';
import '../services/friends_service.dart';

/// Singleton [FriendsService] instance.
final friendsServiceProvider =
    Provider<FriendsService>((ref) => FriendsService());

/// Fetches the accepted friends list for the current user.
///
/// Used by: FriendsScreen (main list), SettleUpScreen (friend picker).
/// Updates when: invalidated after accepting/rejecting a request, or on pull-to-refresh.
final friendsListProvider = FutureProvider<List<Friend>>((ref) {
  return ref.read(friendsServiceProvider).getFriends();
});

/// Fetches incoming friend requests that have not yet been accepted or rejected.
///
/// Used by: FriendsScreen (pending section).
/// Real-time variant [friendRequestsStreamProvider] is used for the badge
/// in DashboardScreen's bottom navigation bar.
/// Updates when: invalidated after accept/reject actions.
final pendingRequestsProvider = FutureProvider<List<PendingRequest>>((ref) {
  return ref.read(friendsServiceProvider).getPendingRequests();
});
