import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/friend_model.dart';

class FriendsService {
  final _client = Supabase.instance.client;

  String get _userId => _client.auth.currentUser!.id;

  Future<Profile?> searchUser(String query) async {
    final q = query.startsWith('@') ? query.substring(1) : query;
    final result = await _client
        .from('profiles')
        .select('id, full_name, username, email')
        .or('username.eq.$q,email.eq.$q')
        .neq('id', _userId)
        .maybeSingle();
    if (result == null) return null;
    return Profile.fromJson(result);
  }

  Future<void> sendFriendRequest(String friendId) async {
    if (friendId == _userId) throw Exception('You cannot add yourself');

    final existing = await _client
        .from('friends')
        .select('id, status')
        .or('and(user_id.eq.$_userId,friend_id.eq.$friendId),and(user_id.eq.$friendId,friend_id.eq.$_userId)')
        .maybeSingle();

    if (existing != null) {
      final status = existing['status'] as String;
      if (status == 'accepted') throw Exception('Already friends');
      if (status == 'pending') throw Exception('Friend request already sent');
    }

    await _client.from('friends').insert({
      'user_id': _userId,
      'friend_id': friendId,
      'status': 'pending',
    });
  }

  Future<void> acceptFriendRequest(String requestId) async {
    await _client
        .from('friends')
        .update({'status': 'accepted'})
        .eq('id', requestId)
        .eq('friend_id', _userId);
  }

  Future<void> rejectFriendRequest(String friendshipId) async {
    await _client.from('friends').delete().eq('id', friendshipId);
  }

  Future<void> removeFriend(String friendshipId) async {
    await _client.from('friends').delete().eq('id', friendshipId);
  }

  Future<List<Friend>> getFriends() async {
    final rows = await _client
        .from('friends')
        .select()
        .or('user_id.eq.$_userId,friend_id.eq.$_userId')
        .eq('status', 'accepted');

    final List<Friend> result = [];
    for (final row in rows as List) {
      final isRequester = (row['user_id'] as String) == _userId;
      final otherUserId =
          isRequester ? row['friend_id'] as String : row['user_id'] as String;

      final profile = await _client
          .from('profiles')
          .select('full_name, username, email')
          .eq('id', otherUserId)
          .maybeSingle();

      if (profile == null) continue;

      final balance = await _getBalanceWithUser(otherUserId);

      result.add(Friend(
        id: row['id'] as String,
        userId: _userId,
        friendId: otherUserId,
        fullName: profile['full_name'] as String,
        username: profile['username'] as String,
        email: profile['email'] as String? ?? '',
        balance: balance,
        status: row['status'] as String,
      ));
    }

    return result;
  }

  Future<List<PendingRequest>> getPendingRequests() async {
    final rows = await _client
        .from('friends')
        .select()
        .eq('friend_id', _userId)
        .eq('status', 'pending');

    final List<PendingRequest> result = [];
    for (final row in rows as List) {
      final fromUserId = row['user_id'] as String;

      final profile = await _client
          .from('profiles')
          .select('full_name, username')
          .eq('id', fromUserId)
          .maybeSingle();

      if (profile == null) continue;

      result.add(PendingRequest(
        id: row['id'] as String,
        fromUserId: fromUserId,
        fullName: profile['full_name'] as String,
        username: profile['username'] as String,
      ));
    }

    return result;
  }

  Future<List<String>> getSharedGroupNames(String friendId) async {
    final ids = await _getSharedGroupIds(friendId);
    if (ids.isEmpty) return [];
    final groups = await _client
        .from('groups')
        .select('name')
        .inFilter('id', ids);
    return (groups as List).map((g) => g['name'] as String).toList();
  }

  Future<double> getBalanceWithFriend(String friendId) =>
      _getBalanceWithUser(friendId);

  Future<double> _getBalanceWithUser(String otherUserId) async {
    final sharedGroups = await _getSharedGroupIds(otherUserId);
    if (sharedGroups.isEmpty) return 0;

    final expenseRows = await _client
        .from('expenses')
        .select('id')
        .inFilter('group_id', sharedGroups)
        .eq('is_archived', false);
    final expenseIds =
        (expenseRows as List).map((e) => e['id'] as String).toList();
    if (expenseIds.isEmpty) return 0;

    double balance = 0;

    // They owe me.
    final theyOweMe = await _client
        .from('expense_splits')
        .select('amount')
        .eq('owed_to', _userId)
        .eq('user_id', otherUserId)
        .eq('is_settled', false)
        .inFilter('expense_id', expenseIds);
    for (final s in theyOweMe as List) {
      balance += (s['amount'] as num).toDouble();
    }

    // I owe them.
    final iOweThem = await _client
        .from('expense_splits')
        .select('amount')
        .eq('owed_to', otherUserId)
        .eq('user_id', _userId)
        .eq('is_settled', false)
        .inFilter('expense_id', expenseIds);
    for (final s in iOweThem as List) {
      balance -= (s['amount'] as num).toDouble();
    }

    return balance;
  }

  Future<List<String>> _getSharedGroupIds(String otherUserId) async {
    final myGroups = await _client
        .from('group_members')
        .select('group_id')
        .eq('user_id', _userId);
    final myGroupIds =
        (myGroups as List).map((m) => m['group_id'] as String).toList();

    if (myGroupIds.isEmpty) return [];

    final theirGroups = await _client
        .from('group_members')
        .select('group_id')
        .eq('user_id', otherUserId)
        .inFilter('group_id', myGroupIds);

    return (theirGroups as List)
        .map((m) => m['group_id'] as String)
        .toList();
  }
}
