import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feedback.dart';
import '../../../models/client.dart';
import '../../../models/enums.dart';
import '../../../models/project.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/portal_providers.dart';
import '../../../providers/transaction_providers.dart';
import '../../../core/utils/safe_insets.dart';

/// Opens the project manager for [client].
Future<void> showProjectsSheet(BuildContext context, Client client) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ProjectsSheet(client: client),
  );
}

/// Create, rename, complete and remove a client's projects.
///
/// Projects are labels for grouping transactions. They carry no balance of
/// their own, so nothing here can change what a client owes.
class ProjectsSheet extends ConsumerStatefulWidget {
  const ProjectsSheet({super.key, required this.client});

  final Client client;

  @override
  ConsumerState<ProjectsSheet> createState() => _ProjectsSheetState();
}

class _ProjectsSheetState extends ConsumerState<ProjectsSheet> {
  final _nameController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(projectServiceProvider)
          .create(
            uid: ref.read(requireUidProvider),
            clientId: widget.client.id,
            name: name,
          );
      _nameController.clear();
      syncSharePage(ref, widget.client.id);
      if (mounted) AppToast.success(context, 'Project added');
    } catch (error) {
      if (mounted) AppToast.error(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _rename(Project project) async {
    final controller = TextEditingController(text: project.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename project'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Project name'),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == project.name) return;

    try {
      await ref
          .read(projectServiceProvider)
          .update(
            uid: ref.read(requireUidProvider),
            clientId: widget.client.id,
            projectId: project.id,
            name: name,
            note: project.note,
            color: project.color,
            status: project.status,
          );
    } catch (error) {
      if (mounted) AppToast.error(context, error);
    }
  }

  Future<void> _setStatus(Project project, ProjectStatus status) async {
    try {
      await ref
          .read(projectServiceProvider)
          .setStatus(
            uid: ref.read(requireUidProvider),
            clientId: widget.client.id,
            projectId: project.id,
            status: status,
          );
    } catch (error) {
      if (mounted) AppToast.error(context, error);
    }
  }

  Future<void> _delete(Project project, int taggedCount) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete “${project.name}”?',
      message:
          'The project label is removed. Every transaction stays exactly as it '
          'is. Amounts, dates and balances are untouched.',
      confirmLabel: 'Delete project',
      destructive: true,
      detail: taggedCount == 0
          ? const Text('No transactions are tagged to this project.')
          : Text(
              '$taggedCount ${taggedCount == 1 ? 'transaction' : 'transactions'} '
              'will move back to “General”.',
            ),
    );
    if (!confirmed) return;

    try {
      await ref
          .read(projectServiceProvider)
          .deleteAndUntag(
            uid: ref.read(requireUidProvider),
            clientId: widget.client.id,
            projectId: project.id,
          );
      syncSharePage(ref, widget.client.id);
      if (mounted) AppToast.success(context, 'Project deleted');
    } catch (error) {
      if (mounted) AppToast.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(clientProjectsProvider(widget.client.id));
    final transactions =
        ref.watch(clientTransactionsProvider(widget.client.id)).value
        ?? const [];

    return Padding(
      padding: EdgeInsets.only(bottom: context.keyboardInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Projects', style: context.text.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Group ${widget.client.name}’s transactions by the work '
                    'they belong to. Projects are labels, so the balance always '
                    'stays at the client level.',
                    style: context.text.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            hintText: 'New project name',
                            prefixIcon: Icon(
                              Icons.create_new_folder_outlined,
                              size: 20,
                            ),
                          ),
                          onSubmitted: (_) => _create(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _saving ? null : _create,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Expanded(
              child: projects.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorView(error: error),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyState(
                      compact: true,
                      icon: Icons.folder_open_outlined,
                      title: 'No projects yet',
                      message:
                          'Add one above, then tag charges and payments to it '
                          'when you record them.',
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(16, 8, 16, context.sheetBottomPadding()),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final project = list[index];
                      final count = transactions
                          .where((t) => t.projectId == project.id)
                          .length;
                      return _ProjectRow(
                        project: project,
                        taggedCount: count,
                        onRename: () => _rename(project),
                        onStatus: (status) => _setStatus(project, status),
                        onDelete: () => _delete(project, count),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.project,
    required this.taggedCount,
    required this.onRename,
    required this.onStatus,
    required this.onDelete,
  });

  final Project project;
  final int taggedCount;
  final VoidCallback onRename;
  final ValueChanged<ProjectStatus> onStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final muted = project.status != ProjectStatus.active;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.hairline),
      ),
      child: Row(
        children: [
          Icon(
            muted ? Icons.folder_off_outlined : Icons.folder_outlined,
            size: 18,
            color: muted
                ? context.scheme.onSurfaceVariant
                : context.scheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    color: muted
                        ? context.scheme.onSurfaceVariant
                        : context.scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$taggedCount ${taggedCount == 1 ? 'transaction' : 'transactions'}'
                  '${muted ? ' · ${project.status.label}' : ''}',
                  style: context.text.labelSmall,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Project actions',
            position: PopupMenuPosition.under,
            icon: const Icon(Icons.more_vert_rounded, size: 18),
            onSelected: (value) => switch (value) {
              'rename' => onRename(),
              'active' => onStatus(ProjectStatus.active),
              'completed' => onStatus(ProjectStatus.completed),
              'archived' => onStatus(ProjectStatus.archived),
              'delete' => onDelete(),
              _ => null,
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              if (project.status != ProjectStatus.active)
                const PopupMenuItem(
                  value: 'active',
                  child: Text('Mark active'),
                ),
              if (project.status != ProjectStatus.completed)
                const PopupMenuItem(
                  value: 'completed',
                  child: Text('Mark completed'),
                ),
              if (project.status != ProjectStatus.archived)
                const PopupMenuItem(value: 'archived', child: Text('Archive')),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete',
                  style: TextStyle(color: context.scheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
