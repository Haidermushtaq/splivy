import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense_model.dart';

class RealtimeService {
  final _client = Supabase.instance.client;
  final List<StreamSubscription> _subscriptions = [];

  StreamSubscription subscribeToGroupExpenses(
    String groupId,
    void Function(List<Expense>) onUpdate,
  ) {
    final sub = _client
        .from('expenses')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .listen((data) {
          final expenses = data.map((e) => Expense.fromJson(e)).toList();
          onUpdate(expenses);
        });
    _subscriptions.add(sub);
    return sub;
  }

  StreamSubscription subscribeToGroupMembers(
    String groupId,
    void Function() onUpdate,
  ) {
    final sub = _client
        .from('group_members')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .listen((_) => onUpdate());
    _subscriptions.add(sub);
    return sub;
  }

  StreamSubscription subscribeToFriendRequests(
    String userId,
    void Function() onUpdate,
  ) {
    final sub = _client
        .from('friends')
        .stream(primaryKey: ['id'])
        .eq('friend_id', userId)
        .listen((_) => onUpdate());
    _subscriptions.add(sub);
    return sub;
  }

  StreamSubscription subscribeToExpenseSplits(
    String userId,
    void Function() onUpdate,
  ) {
    final sub = _client
        .from('expense_splits')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((_) => onUpdate());
    _subscriptions.add(sub);
    return sub;
  }

  StreamSubscription subscribeToUserBalance(
    String userId,
    void Function() onUpdate,
  ) {
    return subscribeToExpenseSplits(userId, onUpdate);
  }

  void disposeAll() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
