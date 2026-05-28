import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  int _idCounter = 0;

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  Future<void> showExpenseNotification({
    required String groupName,
    required String expenseTitle,
    required double amount,
  }) async {
    await _plugin.show(
      _idCounter++,
      'New expense in $groupName',
      '$expenseTitle • PKR ${amount.toStringAsFixed(0)}',
      _details(),
    );
  }

  Future<void> showFriendRequestNotification(String username) async {
    await _plugin.show(
      _idCounter++,
      'New friend request',
      'New friend request from @$username',
      _details(),
    );
  }

  Future<void> showSettlementNotification({
    required String name,
    required double amount,
  }) async {
    await _plugin.show(
      _idCounter++,
      'Payment settled',
      '$name settled PKR ${amount.toStringAsFixed(0)} ✓',
      _details(),
    );
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'fairshare_channel',
        'FairShare',
        channelDescription: 'FairShare real-time expense notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );
  }
}
