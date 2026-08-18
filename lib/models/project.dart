import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

/// A project belonging to a client.
///
/// Projects are **organisational labels only**. They group a client's
/// transactions so the history can be filtered ("Website redesign", "Monthly
/// retainer"). They deliberately hold no balance of their own: the client
/// balance stays the single source of truth for what is owed. Any per-project
/// figure shown in the UI is computed on the fly from the filtered
/// transactions, never stored.
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.note,
    required this.color,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String note;
  final String color;
  final ProjectStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isArchived => status == ProjectStatus.archived;

  factory Project.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Project(
      id: doc.id,
      name: (d['name'] as String?) ?? '',
      note: (d['note'] as String?) ?? '',
      color: (d['color'] as String?) ?? '#4F46E5',
      status: ProjectStatusX.fromId(d['status'] as String?),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name.trim(),
    'nameLower': name.trim().toLowerCase(),
    'note': note.trim(),
    'color': color,
    'status': status.id,
  };
}
