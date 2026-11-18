import 'package:flutter/material.dart';

import '../data/world_ports.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// A labelled From/To field with port/city/country autocomplete, styled to
/// match [AuthTextField] (same decoration, just swapping the plain
/// `TextFormField` for Flutter's built-in `Autocomplete`). Backed by the
/// bundled [kWorldPorts] list — no geocoding API, no network call.
///
/// [controller] is the single source of truth for the field's text (prefill,
/// read, and the save-button's enabled check all read it directly, same as
/// before this field had autocomplete) — free typing without picking a
/// suggestion still works exactly as it did with a plain text field.
class PortAutocompleteField extends StatefulWidget {
  const PortAutocompleteField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  State<PortAutocompleteField> createState() => _PortAutocompleteFieldState();
}

class _PortAutocompleteFieldState extends State<PortAutocompleteField> {
  // RawAutocomplete requires textEditingController and focusNode to be
  // provided together (or neither) — this field owns the focus node so
  // callers only need to supply the controller, same as AuthTextField.
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Iterable<Port> _optionsFor(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final matches = kWorldPorts.where((p) => p.matches(q)).toList()
      // Ports whose city starts with the query surface above ones that only
      // match deeper in the name/country — e.g. "val" -> Valparaiso before
      // some country that merely contains "val".
      ..sort((a, b) {
        final aStarts = a.city.toLowerCase().startsWith(q);
        final bStarts = b.city.toLowerCase().startsWith(q);
        if (aStarts != bStarts) return aStarts ? -1 : 1;
        return a.city.compareTo(b.city);
      });
    return matches.take(8);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label.toUpperCase(), style: AppTextStyles.caption),
        const SizedBox(height: 8),
        Autocomplete<Port>(
          textEditingController: widget.controller,
          focusNode: _focusNode,
          optionsBuilder: (value) => _optionsFor(value.text),
          displayStringForOption: (port) => port.displayLabel,
          fieldViewBuilder: (context, fieldController, focusNode, onSubmit) {
            return TextFormField(
              controller: fieldController,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.words,
              onFieldSubmitted: (_) => onSubmit(),
              cursorColor: AppColors.seafoam,
              style: AppTextStyles.body.copyWith(color: AppColors.white),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppColors.glassFill,
                hintText: widget.hint,
                hintStyle: AppTextStyles.body.copyWith(color: AppColors.muted),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusTile),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusTile),
                  borderSide: const BorderSide(
                    color: AppColors.glassBorderSoft,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusTile),
                  borderSide: const BorderSide(color: AppColors.seafoam),
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final list = options.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(AppTheme.radiusTile),
                elevation: 6,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 280,
                    maxWidth: 340,
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final port = list[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          port.displayLabel,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                        subtitle: Text(
                          port.name,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        onTap: () => onSelected(port),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
