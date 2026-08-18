import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/client_avatar.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/money_text.dart';
import '../../../models/client.dart';
import '../../../providers/client_providers.dart';
import '../../../core/utils/safe_insets.dart';
import 'client_search_field.dart';

/// Opens a searchable client picker. Returns the chosen client, or `null`.
Future<Client?> showClientPicker(
  BuildContext context, {
  String title = 'Choose a client',
  bool includeArchived = false,
}) {
  return showModalBottomSheet<Client>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ClientPicker(title: title, includeArchived: includeArchived),
  );
}

/// The client chooser used by quick-add and the activity filter.
///
/// Search runs over the already-loaded client list, so results appear as fast
/// as the user can type.
class ClientPicker extends ConsumerStatefulWidget {
  const ClientPicker({
    super.key,
    this.title = 'Choose a client',
    this.includeArchived = false,
  });

  final String title;
  final bool includeArchived;

  @override
  ConsumerState<ClientPicker> createState() => _ClientPickerState();
}

class _ClientPickerState extends ConsumerState<ClientPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(clientsProvider).value ?? const <Client>[];
    final recent = ref.watch(recentClientsProvider);
    final query = _query.trim().toLowerCase();

    var candidates = all.where(
      (c) => widget.includeArchived || !c.isArchived,
    );
    if (query.isNotEmpty) {
      final digits = Client.normalisePhoneForSearch(query);
      candidates = candidates.where(
        (c) =>
            c.searchHaystack.contains(query) ||
            (digits.isNotEmpty &&
                Client.normalisePhoneForSearch(c.phone).contains(digits)),
      );
    }

    final results = candidates.toList()
      ..sort((a, b) {
        if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
        return a.nameLower.compareTo(b.nameLower);
      });

    // With no search typed, put recently opened clients first, because that is
    // almost always who you are about to pick.
    final ordered = query.isEmpty && recent.isNotEmpty
        ? <Client>[
            ...recent.where((c) => widget.includeArchived || !c.isArchived),
            ...results.where((c) => !recent.any((r) => r.id == c.id)),
          ]
        : results;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: context.text.titleLarge),
                const SizedBox(height: 12),
                ClientSearchField(
                  value: _query,
                  autofocus: all.length > 8,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: ordered.isEmpty
                ? EmptyState(
                    compact: true,
                    icon: Icons.search_off_rounded,
                    title: all.isEmpty ? 'No clients yet' : 'No matches',
                    message: all.isEmpty
                        ? 'Add a client first.'
                        : 'Try a different name, company or phone number.',
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(12, 0, 12, context.sheetBottomPadding()),
                    itemCount: ordered.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 60,
                      color: context.colors.hairline,
                    ),
                    itemBuilder: (context, index) {
                      final client = ordered[index];
                      return ListTile(
                        leading: ClientAvatar.of(
                          client,
                          size: 38,
                          showFavorite: true,
                        ),
                        title: Text(
                          client.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: client.displayCompany.isEmpty
                            ? null
                            : Text(
                                client.displayCompany,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        trailing: MoneyText(
                          client.currentBalance,
                          absolute: true,
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          color: context.colors.forState(client.balanceState),
                        ),
                        onTap: () => Navigator.of(context).pop(client),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
