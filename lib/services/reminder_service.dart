import 'package:supabase_flutter/supabase_flutter.dart';
import 'expenses_service.dart';
import 'notification_service.dart';
import 'preferences_service.dart';

class ReminderService {
  Future<void> saveReminderSettings(int intervalHours, bool enabled) async {
    final prefs = PreferencesService();
    await prefs.saveReminderEnabled(enabled);
    await prefs.saveReminderInterval(intervalHours);
  }

  Future<({bool enabled, int intervalHours})> getReminderSettings() async {
    final prefs = PreferencesService();
    return (
      enabled: prefs.getReminderEnabled(),
      intervalHours: prefs.getReminderInterval(),
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
