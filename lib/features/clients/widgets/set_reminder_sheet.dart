import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/widgets/feedback.dart';
import '../../../models/client.dart';
import '../../../models/reminder.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../core/utils/safe_insets.dart';

/// Opens the "remind me to follow up" sheet.
Future<void> showSetReminderSheet(BuildContext context, Client client) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => SetReminderSheet(client: client),
  );
}

/// Schedules a local follow-up notification.
///
/// This is a personal nudge, not a message to the client. It never leaves the
/// device and nothing is sent to anyone.
class SetReminderSheet extends ConsumerStatefulWidget {
  const SetReminderSheet({super.key, required this.client});

  final Client client;

  @override
  ConsumerState<SetReminderSheet> createState() => _SetReminderSheetState();
}

class _SetReminderSheetState extends ConsumerState<SetReminderSheet> {
  late final TextEditingController _message = TextEditingController(
    text: 'Follow up with ${widget.client.name} about the pending balance',
  );

  Duration _delay = const Duration(days: 1);
  DateTime? _customDate;
  bool _saving = false;

  static const _presets = <({String label, Duration delay})>[
    (label: 'In 3 hours', delay: Duration(hours: 3)),
    (label: 'Tomorrow', delay: Duration(days: 1)),
    (label: 'In 3 days', delay: Duration(days: 3)),
    (label: 'Next week', delay: Duration(days: 7)),
  ];

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  DateTime get _dueAt => _customDate ?? DateTime.now().add(_delay);

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (!mounted) return;

    setState(() {
      _customDate = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 10,
        time?.minute ?? 0,
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final due = _dueAt;
    if (!due.isAfter(DateTime.now())) {
      AppToast.info(context, 'Pick a time in the future.');
      return;
    }

    setState(() => _saving = true);

    final notifications = ref.read(notificationServiceProvider);
    final granted = await notifications.requestPermission();
    if (!mounted) return;

    if (!granted) {
      setState(() => _saving = false);
      AppToast.info(
        context,
        'Notifications are turned off for this app, so the reminder cannot '
        'alert you. Enable them in your device settings.',
      );
      return;
    }

    final reminder = Reminder(
      id: '${widget.client.id}-${due.millisecondsSinceEpoch}',
      clientId: widget.client.id,
      clientName: widget.client.name,
      message: _message.text.trim().isEmpty
          ? 'Follow up with ${widget.client.name}'
          : _message.text.trim(),
      dueAt: due,
      createdAt: DateTime.now(),
    );

    await ref.read(remindersProvider.notifier).add(reminder);
    if (!mounted) return;

    Navigator.of(context).pop();
    AppToast.success(context, 'Reminder set for ${AppDate.full(due)}');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.keyboardInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, context.sheetBottomPadding()),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Set a reminder', style: context.text.titleLarge),
              const SizedBox(height: 4),
              Text(
                'A private nudge on this device. Nothing is sent to '
                '${widget.client.name}.',
                style: context.text.bodySmall,
              ),
              const SizedBox(height: 18),

              TextField(
                controller: _message,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Remind me to…',
                  prefixIcon: Icon(Icons.notes_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'When',
                style: context.text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in _presets)
                    ChoiceChip(
                      label: Text(preset.label),
                      selected: _customDate == null && _delay == preset.delay,
                      onSelected: (_) => setState(() {
                        _customDate = null;
                        _delay = preset.delay;
                      }),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.event_rounded, size: 15),
                    label: Text(
                      _customDate == null
                          ? 'Pick date'
                          : AppDate.dayShort(_customDate!),
                    ),
                    onPressed: _pickCustom,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.surfaceSunken,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.alarm_rounded,
                      size: 16,
                      color: context.scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppDate.full(_dueAt),
                        style: context.text.bodySmall?.copyWith(
                          color: context.scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.alarm_add_rounded, size: 20),
                  label: Text(_saving ? 'Setting…' : 'Set reminder'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
