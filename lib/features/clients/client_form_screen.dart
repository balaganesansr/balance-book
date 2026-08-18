import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/client_avatar.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/offline_banner.dart';
import '../../models/client.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/client_providers.dart';
import '../../providers/portal_providers.dart';
import '../../core/utils/safe_insets.dart';

/// Add and edit a client.
///
/// On edit, the opening-balance field is gone entirely. That is deliberate:
/// editing contact details must never be a way to move money. A wrong balance
/// is corrected with a transaction, which leaves a trail.
class ClientFormScreen extends ConsumerStatefulWidget {
  const ClientFormScreen({super.key, this.clientId});

  final String? clientId;

  bool get isEditing => clientId != null;

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _company = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  final _openingBalance = TextEditingController();

  String _avatarColor = AvatarPalette.colors.first;
  bool _saving = false;
  bool _seeded = false;
  bool _openingIsCredit = false;

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _notes.dispose();
    _openingBalance.dispose();
    super.dispose();
  }

  /// Fills the form once the client has loaded (edit mode only).
  void _seedFrom(Client client) {
    if (_seeded) return;
    _seeded = true;
    _name.text = client.name;
    _company.text = client.companyName;
    _phone.text = client.phone;
    _email.text = client.email;
    _address.text = client.address;
    _notes.text = client.notes;
    _avatarColor = client.avatarColor.isEmpty
        ? AvatarPalette.forSeed(client.name)
        : client.avatarColor;
  }

  ClientDraft get _draft => ClientDraft(
    name: _name.text,
    companyName: _company.text,
    phone: _phone.text,
    email: _email.text,
    address: _address.text,
    notes: _notes.text,
    avatarColor: _avatarColor,
  );

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final uid = ref.read(requireUidProvider);
    final service = ref.read(clientServiceProvider);

    try {
      if (widget.isEditing) {
        await service.updateProfile(
          uid: uid,
          clientId: widget.clientId!,
          draft: _draft,
        );
        syncSharePage(ref, widget.clientId!);
        if (!mounted) return;
        context.pop();
        AppToast.success(context, 'Client details updated');
      } else {
        final opening = _openingAmount;
        final id = await service.create(
          uid: uid,
          draft: _draft,
          openingBalance: opening,
          actorName: ref.read(actorNameProvider),
        );
        if (!mounted) return;
        context.pushReplacement('/clients/$id');
        AppToast.success(
          context,
          opening == 0
              ? '${_name.text.trim()} added'
              : '${_name.text.trim()} added with an opening balance',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(context, error);
    }
  }

  /// Signed opening balance, negative when the client has paid in advance.
  int get _openingAmount {
    final parsed = Money.tryParse(
      _openingBalance.text,
      currency: ref.read(currencyProvider),
    );
    if (parsed == null || parsed == 0) return 0;
    return _openingIsCredit ? -parsed.abs() : parsed.abs();
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(isOfflineProvider).value ?? false;

    if (widget.isEditing) {
      final client = ref.watch(clientByIdProvider(widget.clientId!));
      if (client == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Edit client')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      _seedFrom(client);
    }

    final name = _name.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit client' : 'Add client'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, context.scrollBottomPadding()),
          children: [
            const OfflineNotice(
              message:
                  'You are offline. Saving a client needs a connection. '
                  'reconnect and try again.',
            ),

            Center(
              child: Column(
                children: [
                  ClientAvatar(
                    name: name.isEmpty ? '?' : name,
                    colorHex: _avatarColor,
                    size: 76,
                  ),
                  const SizedBox(height: 14),
                  _ColorPicker(
                    value: _avatarColor,
                    onChanged: (hex) => setState(() => _avatarColor = hex),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _FieldGroup(
              title: 'Contact',
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: !widget.isEditing,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full name *',
                    hintText: 'Rahul Sharma',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'A client needs a name'
                      : null,
                ),
                TextFormField(
                  controller: _company,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Company',
                    hintText: 'ABC Agency',
                    prefixIcon: Icon(Icons.business_outlined, size: 20),
                  ),
                ),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    hintText: '+91 98765 43210',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    final digits = text.replaceAll(RegExp(r'\D'), '');
                    return digits.length < 6 ? 'That number looks too short' : null;
                  },
                ),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'rahul@example.com',
                    prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    final ok = RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(text);
                    return ok ? null : 'That email address does not look right';
                  },
                ),
                TextFormField(
                  controller: _address,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            _FieldGroup(
              title: 'Notes',
              subtitle:
                  'Things worth remembering about this client. Kept separate '
                  'from the notes on individual transactions.',
              children: [
                TextFormField(
                  controller: _notes,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText:
                        'Prefers WhatsApp · Usually pays on the 15th · '
                        'Website maintenance client',
                    counterText: '',
                  ),
                ),
              ],
            ),

            if (!widget.isEditing) ...[
              const SizedBox(height: 18),
              _OpeningBalanceSection(
                controller: _openingBalance,
                isCredit: _openingIsCredit,
                onDirectionChanged: (credit) =>
                    setState(() => _openingIsCredit = credit),
                onChanged: () => setState(() {}),
                amount: _openingAmount,
              ),
            ],

            const SizedBox(height: 28),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              onPressed: (_saving || offline) ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(
                _saving
                    ? 'Saving…'
                    : widget.isEditing
                    ? 'Save changes'
                    : 'Add client',
              ),
            ),
            if (widget.isEditing) ...[
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'Editing these details never changes the balance.',
                  style: context.text.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FieldGroup extends StatelessWidget {
  const _FieldGroup({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            title,
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10, right: 4),
            child: Text(subtitle!, style: context.text.bodySmall),
          )
        else
          const SizedBox(height: 6),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    );
  }
}

/// Opening balance, shown only when creating a client.
class _OpeningBalanceSection extends ConsumerWidget {
  const _OpeningBalanceSection({
    required this.controller,
    required this.isCredit,
    required this.onDirectionChanged,
    required this.onChanged,
    required this.amount,
  });

  final TextEditingController controller;
  final bool isCredit;
  final ValueChanged<bool> onDirectionChanged;
  final VoidCallback onChanged;
  final int amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            'Opening balance',
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10, right: 4),
          child: Text(
            'Optional. If this client already owes you something, enter it '
            'here and it is recorded as an opening transaction, not as a '
            'silent balance.',
            style: context.text.bodySmall,
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(
            decimal: currency.decimalDigits > 0,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            labelText: 'Amount',
            hintText: '0',
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Text(
                currency.symbol.trim(),
                style: context.text.titleMedium?.copyWith(
                  color: context.scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return null;
            return Money.tryParse(text, currency: currency) == null
                ? 'That is not a valid amount'
                : null;
          },
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              icon: Icon(Icons.trending_up_rounded, size: 16),
              label: Text('They owe me'),
            ),
            ButtonSegment(
              value: true,
              icon: Icon(Icons.savings_outlined, size: 16),
              label: Text('Paid in advance'),
            ),
          ],
          selected: {isCredit},
          onSelectionChanged: (s) => onDirectionChanged(s.first),
        ),
        if (amount != 0) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 16,
                  color: context.scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Creates an opening transaction of',
                    style: context.text.bodySmall,
                  ),
                ),
                MoneyText(
                  amount,
                  absolute: true,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  color: amount >= 0 ? colors.charge : colors.payment,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (final hex in AvatarPalette.colors)
          Semantics(
            button: true,
            selected: hex == value,
            label: 'Avatar colour',
            child: InkWell(
              onTap: () => onChanged(hex),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AvatarPalette.parse(hex),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hex == value
                        ? context.scheme.onSurface
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: hex == value
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}
