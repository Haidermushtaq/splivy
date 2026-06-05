import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/expense_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize({void Function(String? payload)? onTap}) async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Karachi'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (details) {
        onTap?.call(details.payload);
      },
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();

    // Create both channels up front so they exist before any notification fires.
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'splivy_channel',
        'Splivy',
        description: 'Splivy real-time expense notifications',
        importance: Importance.high,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'splivy_reminders',
        'Splivy Reminders',
        description: 'Reminders from Splivy app',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  // ── Immediate notifications ─────────────────────────────────────────────────

  Future<void> showExpenseNotification({
    required String groupName,
    required String expenseTitle,
    required double amount,
    String? groupId,
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 10000,
      'New expense in $groupName',
      '$expenseTitle • PKR ${amount.toStringAsFixed(0)}',
      _immediateDetails(),
      payload: groupId != null ? 'group_$groupId' : null,
    );
  }

  Future<void> showFriendRequestNotification(String username) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 10000,
      'New Friend Request',
      '@$username wants to connect with you on Splivy',
      _immediateDetails(),
      payload: 'friends',
    );
  }

  Future<void> showSettlementNotification({
    required String name,
    required double amount,
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 10000,
      'Payment settled',
      '$name settled PKR ${amount.toStringAsFixed(0)} ✓',
      _immediateDetails(),
      payload: 'settle_up',
    );
  }

  Future<void> showAutoNetNotification({
    required String name,
    required double amount,
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 10000,
      'Debts auto-settled 🔄',
      'PKR ${amount.toStringAsFixed(0)} with $name cancelled out from offsetting expenses.',
      _immediateDetails(),
      payload: 'settle_up',
    );
  }

  Future<void> showPaymentReceivedNotification({
    required String payerName,
    required double amount,
    required String method,
    required String splitId,
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 10000,
      'Payment Received! 💰',
      '$payerName paid PKR ${amount.toStringAsFixed(0)} via $method. Tap to confirm.',
      _immediateDetails(),
      payload: 'confirm_payment_$splitId',
    );
  }

  Future<void> showPaymentConfirmedNotification({
    required String receiverName,
    required double amount,
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 10000,
      'Payment Confirmed ✅',
      '$receiverName confirmed your payment of PKR ${amount.toStringAsFixed(0)}',
      _immediateDetails(),
      payload: 'payment_confirmed',
    );
  }

  Future<void> showCashPaymentNotification({
    required String payerName,
    required double amount,
    required bool isPayer,
  }) async {
    final title = isPayer ? 'Cash Payment Marked' : 'Cash Payment Confirmed ✅';
    final body = isPayer
        ? '$payerName marked PKR ${amount.toStringAsFixed(0)} as paid cash'
        : '$payerName confirmed receiving PKR ${amount.toStringAsFixed(0)} cash';
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 10000,
      title,
      body,
      _immediateDetails(),
      payload: 'settle_up',
    );
  }

  Future<void> showDisputeNotification({
    required String disputerName,
    required String message,
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 10000,
      'Payment Disputed ⚠️',
      '$disputerName disputed your payment: $message',
      _immediateDetails(),
      payload: 'settle_up',
    );
  }

  // ── Scheduled notifications ─────────────────────────────────────────────────

  Future<void> scheduleReminderNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      _reminderDetails(body),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) => _plugin.cancel(id);

  Future<void> cancelAllNotifications() => _plugin.cancelAll();

  // ── Reminder batches ────────────────────────────────────────────────────────

  Future<void> schedulePaymentReminders(
      List<DebtItem> debts, int intervalHours) async {
    int id = 1000;
    for (final debt in debts) {
      if (!debt.youOwe || id >= 1100) break;
      await scheduleReminderNotification(
        id: id++,
        title: 'Payment Reminder',
        body:
            'You owe ${debt.name} PKR ${debt.amount.toStringAsFixed(0)} in ${debt.groupName}',
        scheduledDate: DateTime.now().add(Duration(hours: intervalHours)),
        payload: 'settle_up',
      );
    }
  }

  Future<void> scheduleOwedReminders(
      List<DebtItem> debts, int intervalHours) async {
    int id = 2000;
    int offset = 0;
    for (final debt in debts) {
      if (debt.youOwe || id >= 2100) break;
      await scheduleReminderNotification(
        id: id++,
        title: 'Someone Owes You',
        body:
            '${debt.name} owes you PKR ${debt.amount.toStringAsFixed(0)} in ${debt.groupName}',
        scheduledDate: DateTime.now()
            .add(Duration(hours: intervalHours, minutes: offset * 30)),
        payload: 'settle_up',
      );
      offset++;
    }
  }

  // ── Notification detail builders ────────────────────────────────────────────

  NotificationDetails _immediateDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'splivy_channel',
        'Splivy',
        channelDescription: 'Splivy real-time expense notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  NotificationDetails _reminderDetails(String body) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'splivy_reminders',
        'Splivy Reminders',
        channelDescription: 'Reminders from Splivy app',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }
}
