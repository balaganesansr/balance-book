import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../theme/app_colors.dart';

/// Thin strip shown while Firestore is serving from its local cache.
///
/// The wording is deliberately precise. Reading offline is fine, because the figures
/// on screen are the last confirmed ones. Writing is not: recording a charge or
/// a payment needs a round trip so the balance and the ledger stay in step, and
/// the app says so rather than accepting a write it cannot honour.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(isOfflineProvider).value ?? false;

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: offline
          ? Container(
              width: double.infinity,
              color: context.colors.chargeSurface,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 15,
                    color: context.colors.charge,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline. Showing the last synced figures. '
                      'New charges and payments cannot be saved yet.',
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.charge,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

/// Inline notice for a form that cannot be submitted while offline.
class OfflineNotice extends ConsumerWidget {
  const OfflineNotice({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(isOfflineProvider).value ?? false;
    if (!offline) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.chargeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.charge.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: context.colors.charge,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message ??
                  'You are offline. This needs a connection so the balance and '
                      'the transaction are saved together, so nothing will be '
                      'recorded until you reconnect.',
              style: context.text.bodySmall?.copyWith(
                color: context.colors.charge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
