import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'expenses_service.dart';
import 'notification_service.dart';

class ReminderService {
  static const _enabledKey = 'reminder_enabled';
  static const _hoursKey = 'reminder_interval_hours';

  Future<void> saveReminderSettings(int intervalHours, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    await prefs.setInt(_hoursKey, intervalHours);
  }

  Future<({bool enabled, int intervalHours})> getReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      enabled: prefs.getBool(_enabledKey) ?? true,
      intervalHours: prefs.getInt(_hoursKey) ?? 24,
    );
  }

  Future<void> scheduleAllReminders() async {
    if (Supabase.instance.client.auth.currentUser == null) return;

    final settings = await getReminderSettings();
    await NotificationService().cancelAllNotifications();
    if (!settings.enabled) return;

    try {
      final debts = await ExpensesService().getSettleUpData();
      await NotificationService().schedulePaymentReminders(
        debts.where((d) => d.youOwe).toList(),
        settings.intervalHours,
      );
      await NotificationService().scheduleOwedReminders(
        debts.where((d) => !d.youOwe).toList(),
        settings.intervalHours,
      );
    } catch (_) {
      // Reminders are non-critical — silently ignore errors.
    }
  }
}
