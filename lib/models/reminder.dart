/// A follow-up the user set for themselves.
///
/// Reminders are **device-local**: they live in shared preferences and fire
/// through the OS notification scheduler. They are deliberately not synced to
/// Firestore, because a reminder is a personal nudge rather than financial data, and keeping
/// it local means it needs no backend and no push infrastructure.
class Reminder {
  const Reminder({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.message,
    required this.dueAt,
    required this.createdAt,
  });

  final String id;
  final String clientId;
  final String clientName;
  final String message;
  final DateTime dueAt;
  final DateTime createdAt;

  bool get isOverdue => dueAt.isBefore(DateTime.now());

  /// Stable 32-bit id for the OS notification slot.
  int get notificationId => id.hashCode & 0x7FFFFFFF;

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientId': clientId,
    'clientName': clientName,
    'message': message,
    'dueAt': dueAt.millisecondsSinceEpoch,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  static Reminder? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final dueAt = (json['dueAt'] as num?)?.toInt();
    if (id == null || dueAt == null) return null;
    return Reminder(
      id: id,
      clientId: (json['clientId'] as String?) ?? '',
      clientName: (json['clientName'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      dueAt: DateTime.fromMillisecondsSinceEpoch(dueAt),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num?)?.toInt() ?? dueAt,
      ),
    );
  }
}
