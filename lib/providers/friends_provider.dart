import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/friend_model.dart';
import '../services/friends_service.dart';

final friendsServiceProvider =
    Provider<FriendsService>((ref) => FriendsService());

final friendsListProvider = FutureProvider<List<Friend>>((ref) {
  return ref.read(friendsServiceProvider).getFriends();
});

final pendingRequestsProvider = FutureProvider<List<PendingRequest>>((ref) {
  return ref.read(friendsServiceProvider).getPendingRequests();
});
