import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/friend_model.dart';

class FriendsService {
  final _client = Supabase.instance.client;

  String get _userId => _client.auth.currentUser!.id;

  Future<void> sendFriendRequest(String friendUsername) async {
    final profile = await _client
        .from('profiles')
        .select('id')
        .eq('username', friendUsername)
        .maybeSingle();

    if (profile == null) throw Exception('User not found');

    final friendId = profile['id'] as String;
    if (friendId == _userId) throw Exception('You cannot add yourself');

    final existing = await _client
        .from('friends')
        .select('id, status')
        .or('and(user_id.eq.$_userId,friend_id.eq.$friendId),and(user_id.eq.$friendId,friend_id.eq.$_userId)')
        .maybeSingle();

    if (existing != null) {
      final status = existing['status'] as String;
      if (status == 'accepted') throw Exception('Already friends');
      if (status == 'pending') throw Exception('Request already sent');
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
        .eq('id', requestId);
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

  Future<double> getBalanceWithFriend(String friendId) =>
      _getBalanceWithUser(friendId);

  Future<double> _getBalanceWithUser(String otherUserId) async {
    double balance = 0;

    final sharedGroups = await _getSharedGroupIds(otherUserId);
    if (sharedGroups.isEmpty) return 0;

    final myPaidExpenses = await _client
        .from('expenses')
        .select('id, amount')
        .inFilter('group_id', sharedGroups)
        .eq('paid_by', _userId)
        .eq('is_archived', false);

    for (final exp in myPaidExpenses as List) {
      final split = await _client
          .from('expense_splits')
          .select('amount, is_settled')
          .eq('expense_id', exp['id'] as String)
          .eq('user_id', otherUserId)
          .eq('is_settled', false)
          .maybeSingle();
      if (split != null) {
        balance += (split['amount'] as num).toDouble();
      }
    }

    final theirPaidExpenses = await _client
        .from('expenses')
        .select('id, amount')
        .inFilter('group_id', sharedGroups)
        .eq('paid_by', otherUserId)
        .eq('is_archived', false);

    for (final exp in theirPaidExpenses as List) {
      final split = await _client
          .from('expense_splits')
          .select('amount, is_settled')
          .eq('expense_id', exp['id'] as String)
          .eq('user_id', _userId)
          .eq('is_settled', false)
          .maybeSingle();
      if (split != null) {
        balance -= (split['amount'] as num).toDouble();
      }
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
