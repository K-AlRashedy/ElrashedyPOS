import 'package:flutter/material.dart';

import '../theme.dart';

class PickerOption {
  const PickerOption(this.value, this.label, {this.hint});
  final String value;
  final String label;
  final String? hint;
}

Future<T?> showPosDialog<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  double width = 560,
  List<Widget> actions = const [],
}) {
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'إغلاق',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: child,
              ),
            ),
            if (actions.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Searchable replacement for a long <select>: employees, suppliers, accounts.
Future<String?> showSearchPicker(
  BuildContext context, {
  required String title,
  required List<PickerOption> options,
  String? selected,
}) async {
  var term = '';
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final matches = options
            .where((option) =>
                term.trim().isEmpty || option.label.toLowerCase().contains(term.trim().toLowerCase()))
            .toList();
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: TextField(
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'ابحث...', prefixIcon: Icon(Icons.search)),
                    onChanged: (value) => setState(() => term = value),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: matches.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('لا توجد نتائج مطابقة', style: TextStyle(color: PosColors.muted)),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: matches.length,
                          itemBuilder: (context, index) {
                            final option = matches[index];
                            return ListTile(
                              dense: true,
                              selected: option.value == selected,
                              selectedTileColor: PosColors.surface,
                              title: Text(option.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: option.hint == null ? null : Text(option.hint!),
                              trailing: option.value == selected
                                  ? const Icon(Icons.check, color: PosColors.brand, size: 18)
                                  : null,
                              onTap: () => Navigator.of(dialogContext).pop(option.value),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class SearchPickerField extends StatelessWidget {
  const SearchPickerField({
    super.key,
    required this.label,
    required this.options,
    required this.onChanged,
    this.value,
    this.placeholder = 'اختر...',
    this.enabled = true,
  });

  final String label;
  final List<PickerOption> options;
  final ValueChanged<String> onChanged;
  final String? value;
  final String placeholder;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    String? selectedLabel;
    for (final option in options) {
      if (option.value == value) selectedLabel = option.label;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        InkWell(
          onTap: !enabled || options.isEmpty
              ? null
              : () async {
                  final picked = await showSearchPicker(
                    context,
                    title: label,
                    options: options,
                    selected: value,
                  );
                  if (picked != null) onChanged(picked);
                },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: enabled ? PosColors.card : PosColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PosColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedLabel ?? placeholder,
                    style: TextStyle(
                      color: selectedLabel == null ? PosColors.muted : PosColors.text,
                      fontWeight: selectedLabel == null ? FontWeight.w500 : FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: PosColors.muted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: PosColors.muted)),
      );
}

class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key, this.icon = Icons.inbox_outlined});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: PosColors.border),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: PosColors.muted)),
          ],
        ),
      );
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 6)],
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.label,
    this.hint = '0.00',
    this.autofocus = false,
    this.suffix = 'ج.م',
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool autofocus;
  final String suffix;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          TextField(
            controller: controller,
            autofocus: autofocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: hint, suffixText: suffix),
          ),
        ],
      );
}

String? validateAmount(String? value, {String requiredMessage = 'أدخل المبلغ.'}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return requiredMessage;
  final amount = double.tryParse(text);
  if (amount == null || !amount.isFinite) return 'أدخل رقماً صحيحاً.';
  if (amount <= 0) return 'المبلغ يجب أن يكون أكبر من صفر.';
  if (((amount * 100).round() - amount * 100).abs() > 0.001) return 'استخدم خانتين عشريتين كحد أقصى.';
  return null;
}