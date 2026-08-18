import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_date.dart';
import '../../core/utils/csv_export.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/feedback.dart';
import '../../models/client.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/client_providers.dart';
import '../../providers/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(remindersProvider.notifier).pruneExpired();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final user = ref.watch(authStateProvider).value;
    final themeMode = ref.watch(themeModeProvider);
    final currency = ref.watch(currencyProvider);
    final reminders = ref.watch(remindersProvider);
    final clients = ref.watch(clientsProvider).value ?? const <Client>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: context.scheme.primaryContainer,
                  child: Text(
                    profile?.initials ?? '·',
                    style: context.text.titleMedium?.copyWith(
                      color: context.scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.name.trim().isNotEmpty == true
                            ? profile!.name
                            : 'Add your name',
                        style: context.text.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  onPressed: _editName,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          const _GroupLabel('Preferences'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.brightness_6_outlined,
                title: 'Theme',
                subtitle: switch (themeMode) {
                  ThemeMode.light => 'Light',
                  ThemeMode.dark => 'Dark',
                  ThemeMode.system => 'Match device',
                },
                onTap: _pickTheme,
              ),
              _SettingsTile(
                icon: Icons.currency_exchange_rounded,
                title: 'Currency',
                subtitle: '${currency.name} (${currency.symbol.trim()})',
                onTap: _pickCurrency,
              ),
              _SettingsTile(
                icon: Icons.link_rounded,
                title: 'Balance link',
                subtitle: profile?.portalBaseUrl.trim().isNotEmpty == true
                    ? profile!.portalBaseUrl
                    : 'Set where ledger.html is hosted',
                onTap: _editPortalBaseUrl,
              ),
              _SettingsTile(
                icon: Icons.account_balance_outlined,
                title: 'Payment details',
                subtitle: profile?.paymentDetails.trim().isNotEmpty == true
                    ? 'Added to reminder messages'
                    : 'Add UPI or bank details for reminders',
                onTap: _editPaymentDetails,
              ),
            ],
          ),

          const SizedBox(height: 22),
          const _GroupLabel('Reminders'),
          _SettingsGroup(
            children: [
              if (reminders.isEmpty)
                const _SettingsTile(
                  icon: Icons.alarm_off_outlined,
                  title: 'No reminders set',
                  subtitle:
                      'Set one from a client’s More menu to get a nudge later.',
                )
              else
                for (final reminder in reminders)
                  _SettingsTile(
                    icon: Icons.alarm_rounded,
                    title: reminder.clientName,
                    subtitle:
                        '${reminder.message}\n${AppDate.full(reminder.dueAt)}',
                    trailing: IconButton(
                      tooltip: 'Cancel reminder',
                      onPressed: () =>
                          ref.read(remindersProvider.notifier).remove(reminder),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                    onTap: () => context.push('/clients/${reminder.clientId}'),
                  ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'Reminders are scheduled on this device only. They are not '
              'synced to your account and are not sent to clients.',
              style: context.text.labelSmall,
            ),
          ),

          const SizedBox(height: 22),
          const _GroupLabel('Data'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.bar_chart_rounded,
                title: 'Reports',
                subtitle: 'Outstanding, payments, charges and per-client totals',
                onTap: () => context.push('/reports'),
              ),
              _SettingsTile(
                icon: Icons.file_download_outlined,
                title: 'Export client summary',
                subtitle: 'CSV of every client and their balance',
                onTap: clients.isEmpty ? null : () => _exportSummary(clients),
              ),
              _SettingsTile(
                icon: Icons.storage_outlined,
                title: 'Storage',
                subtitle:
                    '${clients.length} ${clients.length == 1 ? 'client' : 'clients'} '
                    'in your account',
              ),
            ],
          ),

          const SizedBox(height: 22),
          const _GroupLabel('Account'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.lock_reset_rounded,
                title: 'Change password',
                subtitle: 'Sends a reset link to ${user?.email ?? 'your email'}',
                onTap: _sendPasswordReset,
              ),
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Sign out',
                tint: context.scheme.error,
                onTap: _signOut,
              ),
            ],
          ),

          const SizedBox(height: 26),
          Center(
            child: Column(
              children: [
                Text('Balance Book', style: context.text.labelMedium),
                const SizedBox(height: 2),
                Text(
                  'Every balance explained by its transactions.',
                  style: context.text.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editName() async {
    final profile = ref.read(userProfileProvider).value;
    final controller = TextEditingController(text: profile?.name ?? '');

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;

    try {
      await ref
          .read(profileServiceProvider)
          .update(uid: ref.read(requireUidProvider), name: name);
      if (mounted) AppToast.success(context, 'Name updated');
    } catch (error) {
      if (mounted) AppToast.error(context, error);
    }
  }

  Future<void> _editPaymentDetails() async {
    final profile = ref.read(userProfileProvider).value;
    final controller = TextEditingController(
      text: profile?.paymentDetails ?? '',
    );

    final details = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appended to reminder messages so clients know where to pay.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'UPI: you@bank\nAccount: 1234567890\nIFSC: ABCD0001',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (details == null) return;

    try {
      await ref
          .read(profileServiceProvider)
          .update(
            uid: ref.read(requireUidProvider),
            paymentDetails: details,
          );
      if (mounted) AppToast.success(context, 'Payment details saved');
    } catch (error) {
      if (mounted) AppToast.error(context, error);
    }
  }

  Future<void> _editPortalBaseUrl() async {
    final profile = ref.read(userProfileProvider).value;
    final controller = TextEditingController(text: profile?.portalBaseUrl ?? '');

    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Balance link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Where you host ledger.html. Share links for individual clients '
              'are built from this address.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: 'https://your-project.web.app',
                prefixIcon: Icon(Icons.public_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Leave empty to turn link sharing off. Existing links keep '
              'working until you revoke them per client.',
              style: context.text.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;

    if (value.isNotEmpty &&
        !(value.startsWith('https://') || value.startsWith('http://'))) {
      if (mounted) {
        AppToast.info(context, 'The address needs to start with https://');
      }
      return;
    }

    try {
      await ref
          .read(profileServiceProvider)
          .update(uid: ref.read(requireUidProvider), portalBaseUrl: value);
      if (mounted) AppToast.success(context, 'Balance link address saved');
    } catch (error) {
      if (mounted) AppToast.error(context, error);
    }
  }

  Future<void> _pickTheme() async {
    final current = ref.read(themeModeProvider);
    final mode = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (context) => SafeArea(
        child: RadioGroup<ThemeMode>(
          groupValue: current,
          onChanged: (value) => Navigator.of(context).pop(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in ThemeMode.values)
                RadioListTile<ThemeMode>(
                  value: option,
                  title: Text(switch (option) {
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                    ThemeMode.system => 'Match device',
                  }),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (mode != null) await ref.read(themeModeProvider.notifier).set(mode);
  }

  Future<void> _pickCurrency() async {
    final current = ref.read(currencyProvider);
    final picked = await showModalBottomSheet<Currency>(
      context: context,
      builder: (context) => SafeArea(
        child: RadioGroup<Currency>(
          groupValue: current,
          onChanged: (value) => Navigator.of(context).pop(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  'Display currency only. Stored amounts are never rewritten.',
                  style: context.text.bodySmall,
                ),
              ),
              for (final option in Currency.supported)
                RadioListTile<Currency>(
                  value: option,
                  title: Text('${option.name} (${option.symbol.trim()})'),
                  subtitle: Text(Money.format(125000000, currency: option)),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;

    try {
      await ref
          .read(profileServiceProvider)
          .update(
            uid: ref.read(requireUidProvider),
            currencyCode: picked.code,
          );
      if (mounted) AppToast.success(context, 'Currency set to ${picked.code}');
    } catch (error) {
      if (mounted) AppToast.error(context, error);
    }
  }

  Future<void> _exportSummary(List<Client> clients) async {
    try {
      final csv = CsvExport.clientSummary(
        clients: clients,
        currency: ref.read(currencyProvider),
      );
      final file = await CsvExport.writeTempFile(
        csv,
        CsvExport.fileNameFor('clients-summary'),
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Client summary',
          text: 'Client balances summary',
        ),
      );
    } catch (error) {
      if (mounted) AppToast.error(context, error);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = ref.read(authStateProvider).value?.email;
    if (email == null) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Send reset link?',
      message: 'We will email a password reset link to $email.',
      confirmLabel: 'Send link',
    );
    if (!confirmed) return;

    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (mounted) AppToast.success(context, 'Reset link sent to $email');
    } catch (error) {
      if (mounted) AppToast.error(context, error);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Sign out?',
      message:
          'Your data stays safe in your account and will be here when you '
          'sign back in.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed) return;

    await ref.read(authServiceProvider).signOut();
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: context.text.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: context.scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 54, color: context.colors.hairline),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.tint,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? context.scheme.onSurface;

    return ListTile(
      onTap: onTap,
      enabled: onTap != null || trailing != null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Icon(
        icon,
        size: 20,
        color: tint ?? context.scheme.onSurfaceVariant,
      ),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.scheme.onSurfaceVariant,
                )),
    );
  }
}
