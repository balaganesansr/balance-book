import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/contact_links.dart';
import '../../core/utils/csv_export.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/client_avatar.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/money_text.dart';
import '../../models/app_transaction.dart';
import '../../models/client.dart';
import '../../models/enums.dart';
import '../../models/project.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/client_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/transaction_providers.dart';
import '../transactions/transaction_sheet.dart';
import '../transactions/widgets/transaction_list.dart';
import 'widgets/projects_sheet.dart';
import 'widgets/reminder_sheet.dart';
import 'widgets/set_reminder_sheet.dart';
import 'widgets/share_link_sheet.dart';
import '../../core/utils/safe_insets.dart';

/// The client profile: balance, quick actions and the full ledger.
class ClientDetailScreen extends ConsumerStatefulWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Remember this client for the "recent" shortcuts on the dashboard.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(recentClientIdsProvider.notifier).touch(widget.clientId);
      ref.read(projectFilterProvider.notifier).clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(clientByIdProvider(widget.clientId));
    final clientsAsync = ref.watch(clientsProvider);

    if (client == null) {
      // Still loading, or the client was deleted on another device.
      if (clientsAsync.isLoading) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Client not found',
          message: 'This client may have been deleted.',
          action: FilledButton(
            onPressed: () => context.go('/clients'),
            child: const Text('Back to clients'),
          ),
        ),
      );
    }

    return _ClientDetailView(client: client);
  }
}

class _ClientDetailView extends ConsumerWidget {
  const _ClientDetailView({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(clientTransactionsProvider(client.id));
    final projects = ref.watch(clientProjectsProvider(client.id)).value
        ?? const <Project>[];
    final projectsById = ref.watch(projectsByIdProvider(client.id));
    final projectFilter = ref.watch(projectFilterProvider);
    final reminders = ref.watch(clientRemindersProvider(client.id));

    final all = transactionsAsync.value ?? const <AppTransaction>[];
    final visible = projectFilter == null
        ? all
        : all.where((tx) => tx.projectId == projectFilter).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(client.name),
            actions: [
              IconButton(
                tooltip: client.isFavorite
                    ? 'Remove from favourites'
                    : 'Add to favourites',
                onPressed: () => _toggleFavorite(context, ref),
                icon: Icon(
                  client.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: client.isFavorite ? const Color(0xFFF59E0B) : null,
                ),
              ),
              _MoreMenu(client: client, transactions: all),
              const SizedBox(width: 4),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList.list(
              children: [
                _IdentityCard(client: client),
                const SizedBox(height: 14),
                _BalanceCard(client: client),
                const SizedBox(height: 14),
                _QuickActions(client: client),

                if (reminders.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _RemindersStrip(clientId: client.id),
                ],

                if (client.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _NotesCard(notes: client.notes),
                ],

                const SizedBox(height: 22),
                SectionHeader(
                  title: 'Transaction history',
                  subtitle: all.isEmpty
                      ? null
                      : '${all.length} ${all.length == 1 ? 'entry' : 'entries'}'
                            ' · newest first',
                  action: projects.isEmpty
                      ? TextButton.icon(
                          onPressed: () => showProjectsSheet(context, client),
                          icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                          label: const Text('Projects'),
                        )
                      : null,
                ),
              ],
            ),
          ),

          if (projects.isNotEmpty)
            SliverToBoxAdapter(
              child: _ProjectFilterChips(
                client: client,
                projects: projects,
                transactions: all,
                selected: projectFilter,
              ),
            ),

          if (transactionsAsync.isLoading && all.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
              sliver: SliverToBoxAdapter(child: SkeletonList(count: 4)),
            )
          else if (visible.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: EmptyState(
                  compact: true,
                  icon: Icons.receipt_long_outlined,
                  title: all.isEmpty
                      ? 'No transactions yet'
                      : 'Nothing in this project',
                  message: all.isEmpty
                      ? 'Add a charge or record a payment and it will appear '
                            'here, with the balance it left behind.'
                      : 'No transactions are tagged to this project yet.',
                  action: all.isEmpty
                      ? FilledButton.icon(
                          onPressed: () => showTransactionSheet(
                            context,
                            client: client,
                            type: TxType.charge,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add charge'),
                        )
                      : TextButton(
                          onPressed: () =>
                              ref.read(projectFilterProvider.notifier).clear(),
                          child: const Text('Show all'),
                        ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, context.scrollBottomPadding()),
              sliver: TransactionSliverList(
                rows: [
                  for (final tx in visible)
                    TransactionRow(
                      transaction: tx,
                      projectName: projectsById[tx.projectId]?.name,
                    ),
                ],
                onTap: (tx) =>
                    context.push('/clients/${client.id}/tx/${tx.id}'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(clientServiceProvider)
          .setFavorite(
            uid: ref.read(requireUidProvider),
            clientId: client.id,
            isFavorite: !client.isFavorite,
          );
    } catch (error) {
      if (context.mounted) AppToast.error(context, error);
    }
  }
}

/// Name, company and one-tap contact details.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClientAvatar.of(client, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.name,
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (client.displayCompany.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(client.displayCompany, style: context.text.bodyMedium),
                ],
                if (client.phone.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _CopyableLine(
                    icon: Icons.phone_outlined,
                    text: client.phone.trim(),
                    copyLabel: 'Phone number copied',
                  ),
                ],
                if (client.email.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _CopyableLine(
                    icon: Icons.alternate_email_rounded,
                    text: client.email.trim(),
                    copyLabel: 'Email copied',
                  ),
                ],
                if (client.address.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _CopyableLine(
                    icon: Icons.location_on_outlined,
                    text: client.address.trim(),
                    copyLabel: 'Address copied',
                    maxLines: 2,
                  ),
                ],
                if (client.isArchived) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceSunken,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Archived, hidden from the client list',
                      style: context.text.labelSmall?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyableLine extends StatelessWidget {
  const _CopyableLine({
    required this.icon,
    required this.text,
    required this.copyLabel,
    this.maxLines = 1,
  });

  final IconData icon;
  final String text;
  final String copyLabel;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) AppToast.success(context, copyLabel);
      },
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: context.scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall,
              ),
            ),
            Icon(
              Icons.copy_rounded,
              size: 12,
              color: context.scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

/// The headline balance, tinted by state.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = client.balanceState;

    return AppCard(
      color: colors.surfaceForState(state),
      borderColor: colors.forState(state).withValues(alpha: 0.22),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            switch (state) {
              BalanceState.outstanding => 'Currently owes you',
              BalanceState.settled => 'Account is clear',
              BalanceState.credit => 'You owe this client',
            },
            style: context.text.labelMedium?.copyWith(
              color: colors.forState(state),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          BalanceHeadline(balance: client.currentBalance),
          const SizedBox(height: 14),
          Divider(color: colors.forState(state).withValues(alpha: 0.18)),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniStat(
                label: 'Charged',
                amount: client.totalCharged,
                tint: colors.charge,
              ),
              Container(
                width: 1,
                height: 28,
                color: colors.forState(state).withValues(alpha: 0.18),
              ),
              _MiniStat(
                label: 'Paid',
                amount: client.totalPaid,
                tint: colors.payment,
              ),
              Container(
                width: 1,
                height: 28,
                color: colors.forState(state).withValues(alpha: 0.18),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('Entries', style: context.text.labelSmall),
                    const SizedBox(height: 3),
                    Text(
                      '${client.transactionCount}',
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.amount,
    required this.tint,
  });

  final String label;
  final int amount;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: context.text.labelSmall),
          const SizedBox(height: 3),
          MoneyText(
            amount,
            absolute: true,
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            color: tint,
            semanticsPrefix: 'Total $label',
          ),
        ],
      ),
    );
  }
}

/// The actions that need to be one tap away.
class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.client});

  final Client client;

  Future<void> _launch(
    BuildContext context,
    Uri uri,
    String failureMessage,
  ) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        AppToast.info(context, failureMessage);
      }
    } catch (_) {
      if (context.mounted) AppToast.info(context, failureMessage);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final canContact = ContactLinks.isCallable(client.phone);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ActionPill(
                icon: Icons.add_rounded,
                label: 'Add charge',
                tint: colors.charge,
                filled: true,
                onTap: () => showTransactionSheet(
                  context,
                  client: client,
                  type: TxType.charge,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ActionPill(
                icon: Icons.south_west_rounded,
                label: 'Record payment',
                tint: colors.payment,
                filled: true,
                onTap: () => showTransactionSheet(
                  context,
                  client: client,
                  type: TxType.payment,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ActionPill(
                icon: Icons.phone_rounded,
                label: 'Call',
                enabled: canContact,
                onTap: () => _launch(
                  context,
                  ContactLinks.telUri(client.phone),
                  'No dialler app available on this device.',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ActionPill(
                icon: Icons.chat_rounded,
                label: 'WhatsApp',
                tint: const Color(0xFF25D366),
                enabled: canContact,
                onTap: () {
                  final profile = ref.read(userProfileProvider).value;
                  final message = MessageTemplates.balanceUpdate(
                    clientName: client.name,
                    balance: client.currentBalance,
                    currency: ref.read(currencyProvider),
                    paymentDetails: profile?.paymentDetails ?? '',
                  );
                  _launch(
                    context,
                    ContactLinks.whatsAppUri(client.phone, message),
                    'Could not open WhatsApp.',
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ActionPill(
                icon: Icons.campaign_outlined,
                label: 'Remind',
                onTap: () => showReminderSheet(context, client),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ActionPill(
                icon: Icons.edit_outlined,
                label: 'Edit',
                onTap: () => context.push('/clients/${client.id}/edit'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: context.colors.surfaceSunken,
      borderColor: Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.sticky_note_2_outlined,
            size: 16,
            color: context.scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notes',
                  style: context.text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(notes.trim(), style: context.text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RemindersStrip extends ConsumerWidget {
  const _RemindersStrip({required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(clientRemindersProvider(clientId));
    if (reminders.isEmpty) return const SizedBox.shrink();

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        children: [
          for (final reminder in reminders)
            Row(
              children: [
                Icon(
                  Icons.alarm_rounded,
                  size: 16,
                  color: context.scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: context.scheme.onSurface,
                        ),
                      ),
                      Text(
                        _reminderWhen(reminder.dueAt),
                        style: context.text.labelSmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cancel reminder',
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      ref.read(remindersProvider.notifier).remove(reminder),
                  icon: const Icon(Icons.close_rounded, size: 16),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _reminderWhen(DateTime due) {
    final diff = due.difference(DateTime.now());
    if (diff.isNegative) return 'Due now';
    if (diff.inHours < 1) return 'In ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'In ${diff.inHours} h';
    return 'In ${diff.inDays} days';
  }
}

class _ProjectFilterChips extends ConsumerWidget {
  const _ProjectFilterChips({
    required this.client,
    required this.projects,
    required this.transactions,
    required this.selected,
  });

  final Client client;
  final List<Project> projects;
  final List<AppTransaction> transactions;
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = projects.where((p) => !p.isArchived).toList();
    final untagged = transactions.where((t) => t.projectId == null).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('All · ${transactions.length}'),
                selected: selected == null,
                onSelected: (_) =>
                    ref.read(projectFilterProvider.notifier).clear(),
              ),
            ),
            for (final project in active)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(
                    Icons.folder_outlined,
                    size: 14,
                    color: selected == project.id
                        ? context.scheme.onPrimaryContainer
                        : context.scheme.onSurfaceVariant,
                  ),
                  label: Text(
                    '${project.name} · '
                    '${transactions.where((t) => t.projectId == project.id).length}',
                  ),
                  selected: selected == project.id,
                  onSelected: (_) =>
                      ref.read(projectFilterProvider.notifier).set(project.id),
                ),
              ),
            if (untagged > 0 && active.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.tune_rounded, size: 14),
                  label: const Text('Manage'),
                  onPressed: () => showProjectsSheet(context, client),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Everything that does not deserve a button on the main screen.
class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.client, required this.transactions});

  final Client client;
  final List<AppTransaction> transactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'More actions',
      position: PopupMenuPosition.under,
      onSelected: (value) => _handle(context, ref, value),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'projects',
          child: _MenuRow(icon: Icons.folder_outlined, label: 'Projects'),
        ),
        const PopupMenuItem(
          value: 'adjust',
          child: _MenuRow(icon: Icons.tune_rounded, label: 'Adjust balance'),
        ),
        PopupMenuItem(
          value: 'share',
          child: _MenuRow(
            icon: client.isShared ? Icons.link_rounded : Icons.link_outlined,
            label: client.isShared ? 'Balance link · on' : 'Balance link',
            tint: client.isShared ? context.scheme.primary : null,
          ),
        ),
        const PopupMenuItem(
          value: 'reminder',
          child: _MenuRow(icon: Icons.alarm_add_outlined, label: 'Set reminder'),
        ),
        const PopupMenuItem(
          value: 'export',
          child: _MenuRow(
            icon: Icons.file_download_outlined,
            label: 'Export statement (CSV)',
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'archive',
          child: _MenuRow(
            icon: client.isArchived
                ? Icons.unarchive_outlined
                : Icons.archive_outlined,
            label: client.isArchived ? 'Restore client' : 'Archive client',
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: _MenuRow(
            icon: Icons.delete_outline_rounded,
            label: 'Delete client',
            tint: context.scheme.error,
          ),
        ),
      ],
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    switch (action) {
      case 'projects':
        await showProjectsSheet(context, client);
      case 'adjust':
        await showTransactionSheet(
          context,
          client: client,
          type: TxType.adjustment,
        );
      case 'share':
        await showShareLinkSheet(context, client);
      case 'reminder':
        await showSetReminderSheet(context, client);
      case 'export':
        await _export(context, ref);
      case 'archive':
        await _toggleArchive(context, ref);
      case 'delete':
        await _delete(context, ref);
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final projects = ref.read(projectsByIdProvider(client.id));
      final csv = CsvExport.clientStatement(
        client: client,
        transactions: transactions,
        currency: ref.read(currencyProvider),
        projects: projects,
      );
      final file = await CsvExport.writeTempFile(
        csv,
        CsvExport.fileNameFor('${client.name}-statement'),
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: '${client.name} statement',
          text: 'Statement for ${client.name}',
        ),
      );
    } catch (error) {
      if (context.mounted) AppToast.error(context, error);
    }
  }

  Future<void> _toggleArchive(BuildContext context, WidgetRef ref) async {
    final archiving = !client.isArchived;
    if (archiving) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Archive ${client.name}?',
        message:
            'They will be hidden from your client list, but the full history '
            'and balance stay intact and can be restored at any time.',
        confirmLabel: 'Archive',
      );
      if (!confirmed) return;
    }

    try {
      await ref
          .read(clientServiceProvider)
          .setStatus(
            uid: ref.read(requireUidProvider),
            clientId: client.id,
            status: archiving ? ClientStatus.archived : ClientStatus.active,
          );
      if (context.mounted) {
        AppToast.success(
          context,
          archiving ? '${client.name} archived' : '${client.name} restored',
        );
      }
    } catch (error) {
      if (context.mounted) AppToast.error(context, error);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete ${client.name}?',
      message:
          'This permanently removes the client and every transaction recorded '
          'against them. This cannot be undone.',
      confirmLabel: 'Delete forever',
      destructive: true,
      detail: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${transactions.length} transactions will be deleted.'),
          const SizedBox(height: 4),
          const Text(
            'If you only want them out of the way, archive instead, which '
            'keeps the history.',
          ),
        ],
      ),
    );
    if (!confirmed) return;

    try {
      // Kill any public snapshot first, so a deleted client's link never keeps
      // serving stale figures.
      if (client.isShared) {
        await ref
            .read(portalServiceProvider)
            .revoke(
              uid: ref.read(requireUidProvider),
              clientId: client.id,
              shareId: client.shareId!,
            );
      }
      await ref.read(remindersProvider.notifier).clearForClient(client.id);
      await ref
          .read(clientServiceProvider)
          .deleteForever(
            uid: ref.read(requireUidProvider),
            clientId: client.id,
          );
      await ref.read(recentClientIdsProvider.notifier).forget(client.id);
      if (context.mounted) {
        context.go('/clients');
        AppToast.success(context, '${client.name} deleted');
      }
    } catch (error) {
      if (context.mounted) AppToast.error(context, error);
    }
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.tint});

  final IconData icon;
  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: tint ?? context.scheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(label, style: tint == null ? null : TextStyle(color: tint)),
      ],
    );
  }
}
