import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Search box for the client list.
///
/// Filtering runs in memory against the already-loaded client list, so results
/// update on the keystroke with no query round-trip, and therefore no
/// debounce, which would only add latency here.
class ClientSearchField extends StatefulWidget {
  const ClientSearchField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hintText = 'Search name, company or phone',
    this.autofocus = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String hintText;
  final bool autofocus;

  @override
  State<ClientSearchField> createState() => _ClientSearchFieldState();
}

class _ClientSearchFieldState extends State<ClientSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant ClientSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keeps the field in step when the query is cleared from elsewhere.
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        suffixIcon: widget.value.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  FocusScope.of(context).unfocus();
                },
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: context.colors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: context.colors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: context.scheme.primary, width: 2),
        ),
      ),
    );
  }
}
