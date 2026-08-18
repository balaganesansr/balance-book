import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder.dart';

/// Device-local settings: theme, recently viewed clients and reminders.
///
/// Anything here is per-device by design and never leaves the phone.
class PrefsService {
  PrefsService(this._prefs);

  final SharedPreferences _prefs;

  static Future<PrefsService> create() async =>
      PrefsService(await SharedPreferences.getInstance());

  static const _kThemeMode = 'theme_mode';
  static const _kRecentClients = 'recent_clients';
  static const _kReminders = 'reminders';
  static const _kSeenWelcome = 'seen_welcome';

  static const _recentLimit = 8;

  // --- Theme ---------------------------------------------------------------

  ThemeMode get themeMode => switch (_prefs.getString(_kThemeMode)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_kThemeMode, mode.name);

  // --- Recently viewed clients --------------------------------------------

  List<String> get recentClientIds =>
      _prefs.getStringList(_kRecentClients) ?? const [];

  /// Moves [clientId] to the front of the recent list, capped at
  /// [_recentLimit].
  Future<void> touchClient(String clientId) async {
    final list = [...recentClientIds]
      ..remove(clientId)
      ..insert(0, clientId);
    await _prefs.setStringList(
      _kRecentClients,
      list.take(_recentLimit).toList(growable: false),
    );
  }

  Future<void> forgetClient(String clientId) async {
    final list = [...recentClientIds]..remove(clientId);
    await _prefs.setStringList(_kRecentClients, list);
  }

  // --- Reminders -----------------------------------------------------------

  List<Reminder> get reminders {
    final raw = _prefs.getStringList(_kReminders) ?? const [];
    final result = <Reminder>[];
    for (final entry in raw) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is! Map) continue;
        final reminder = Reminder.fromJson(decoded.cast<String, dynamic>());
        if (reminder != null) result.add(reminder);
      } on FormatException {
        // A malformed entry should never take the whole list down.
        continue;
      }
    }
    result.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return result;
  }

  Future<void> saveReminders(List<Reminder> reminders) => _prefs.setStringList(
    _kReminders,
    reminders.map((r) => jsonEncode(r.toJson())).toList(growable: false),
  );

  // --- Onboarding ----------------------------------------------------------

  bool get hasSeenWelcome => _prefs.getBool(_kSeenWelcome) ?? false;

  Future<void> markWelcomeSeen() => _prefs.setBool(_kSeenWelcome, true);
}
