import 'package:flutter/material.dart';

import '../../services/ledger_exception.dart';
import '../theme/app_colors.dart';

/// Toasts.
///
/// Routine actions (a charge, a payment, a saved edit) confirm with one of
/// these instead of a dialog, so the fast flows stay fast.
///
/// Delivery goes through [messengerKey], which lives at the app root, rather
/// than through the calling widget's messenger. Most confirmations here fire
/// *after* closing a sheet or popping a screen; resolving against the caller's
/// context at that point would find a deactivated element and the confirmation
/// would silently never appear, at the one moment the user most needs to see it.
class AppToast {
  const AppToast._();

  /// Attached to `MaterialApp.router` so a toast survives the route that
  /// triggered it.
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void success(BuildContext context, String message) => _show(
    context,
    message,
    icon: Icons.check_circle_rounded,
    tone: _Tone.success,
  );

  static void info(BuildContext context, String message) =>
      _show(context, message, icon: Icons.info_outline_rounded);

  static void error(BuildContext context, Object error) {
    final message = error is LedgerException
        ? error.message
        : LedgerException.from(error).message;
    _show(
      context,
      message,
      icon: Icons.error_outline_rounded,
      tone: _Tone.error,
      duration: const Duration(seconds: 5),
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    _Tone tone = _Tone.neutral,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger =
        messengerKey.currentState ?? ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    // Theme lookup uses the root context for the same reason as the messenger.
    final themeContext = messengerKey.currentContext ?? context;
    final tint = switch (tone) {
      _Tone.success => themeContext.colors.payment,
      _Tone.error => themeContext.scheme.error,
      _Tone.neutral => Colors.white,
    };

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          content: Row(
            children: [
              Icon(icon, size: 18, color: tint),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}

enum _Tone { success, error, neutral }

/// Confirmation dialog for anything hard to undo.
///
/// Deliberately not used for adding a charge or a payment: those are frequent,
/// reversible, and a prompt on each one would make the app tiring to use.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.destructive = false,
    this.detail,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  /// Extra context shown in a tinted box, used to spell out consequences.
  final Widget? detail;

  /// Returns `true` only if the user explicitly confirmed.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
    Widget? detail,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        detail: detail,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final danger = context.scheme.error;

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (detail != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.surfaceSunken,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DefaultTextStyle.merge(
                style: context.text.bodySmall,
                child: detail!,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: danger,
                  foregroundColor: context.scheme.onError,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

/// Friendly placeholder for a screen or list with nothing in it yet.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 32,
          vertical: compact ? 24 : 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 48 : 64,
              height: compact ? 48 : 64,
              decoration: BoxDecoration(
                color: context.colors.surfaceSunken,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: compact ? 22 : 28,
                color: context.scheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: compact ? 14 : 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: (compact ? context.text.titleSmall : context.text.titleMedium)
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
            if (action != null) ...[
              SizedBox(height: compact ? 16 : 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Failure state with a retry affordance.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is LedgerException
        ? (error as LedgerException).message
        : LedgerException.from(error).message;

    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Could not load this',
      message: message,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
    );
  }
}

/// Shimmer-free skeleton block. A calm pulse reads as "loading" without the
/// busy sweep that makes a finance screen feel unstable.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 0.9).animate(_controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: context.colors.surfaceSunken,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Placeholder rows shown while a list loads.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: i == count - 1 ? 0 : 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surfaceRaised,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.hairline),
            ),
            child: Row(
              children: [
                const SkeletonBox(width: 44, height: 44, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 130, height: 13),
                      SizedBox(height: 8),
                      SkeletonBox(width: 90, height: 11),
                    ],
                  ),
                ),
                const SkeletonBox(width: 64, height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
