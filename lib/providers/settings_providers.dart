import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reminder.dart';
import 'app_providers.dart';

/// Light / dark / follow-the-system, persisted on the device.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(prefsProvider).themeMode;

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(prefsProvider).setThemeMode(mode);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Locally scheduled follow-up reminders.
///
/// The list in shared preferences and the OS notification schedule are kept in
/// step here. Every add cancels and re-schedules, every removal cancels.
class RemindersNotifier extends Notifier<List<Reminder>> {
  @override
  List<Reminder> build() => ref.watch(prefsProvider).reminders;

  Future<void> add(Reminder reminder) async {
    final next = [...state.where((r) => r.id != reminder.id), reminder]
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    await _persist(next);
    await ref.read(notificationServiceProvider).schedule(reminder);
  }

  Future<void> remove(Reminder reminder) async {
    await _persist(state.where((r) => r.id != reminder.id).toList());
    await ref.read(notificationServiceProvider).cancel(reminder);
  }

  /// Drops reminders whose time has passed, so the list stays a to-do rather
  /// than a graveyard. Called when the Settings screen opens.
  Future<void> pruneExpired() async {
    final now = DateTime.now();
    final live = state.where((r) => r.dueAt.isAfter(now)).toList();
    if (live.length != state.length) await _persist(live);
  }

  Future<void> clearForClient(String clientId) async {
    final removed = state.where((r) => r.clientId == clientId).toList();
    if (removed.isEmpty) return;
    final notifications = ref.read(notificationServiceProvider);
    for (final reminder in removed) {
      await notifications.cancel(reminder);
    }
    await _persist(state.where((r) => r.clientId != clientId).toList());
  }

  Future<void> _persist(List<Reminder> reminders) async {
    state = reminders;
    await ref.read(prefsProvider).saveReminders(reminders);
  }
}

final remindersProvider =
    NotifierProvider<RemindersNotifier, List<Reminder>>(RemindersNotifier.new);

/// Reminders attached to one client.
final clientRemindersProvider =
    Provider.family<List<Reminder>, String>((ref, clientId) {
  return ref
      .watch(remindersProvider)
      .where((r) => r.clientId == clientId)
      .toList(growable: false);
});
