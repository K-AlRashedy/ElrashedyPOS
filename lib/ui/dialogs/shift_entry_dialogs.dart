import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/shift_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> showAdvanceDialog(BuildContext context) {
  final app = context.read<AppState>();
  final shift = context.read<ShiftState>();
  final employees =
      app.bootstrap?.employees.where((employee) => employee.branchId == app.branchId).toList() ?? [];
  return showPosDialog<void>(
    context,
    title: 'سلفة موظف',
    width: 520,
    child: _EntryForm(
      pickerLabel: 'الموظف',
      notesLabel: 'ملاحظات',
      options: [for (final employee in employees) PickerOption('${employee.id}', employee.name)],
      emptyMessage: 'لا يوجد موظفون نشطون مسجلون في هذا الفرع.',
      onSubmit: (id, amount, notes) => shift.addAdvance(employeeId: id, amount: amount, notes: notes),
    ),
  );
}

Future<void> showSupplierDialog(BuildContext context) {
  final app = context.read<AppState>();
  final shift = context.read<ShiftState>();
  final suppliers = app.bootstrap?.suppliers ?? [];
  return showPosDialog<void>(
    context,
    title: 'سداد مورد',
    width: 520,
    child: _EntryForm(
      pickerLabel: 'المورد',
      notesLabel: 'بيان السداد',
      options: [for (final supplier in suppliers) PickerOption('${supplier.id}', supplier.name)],
      emptyMessage: 'لا يوجد موردون مسجلون في النظام.',
      onSubmit: (id, amount, notes) => shift.addSupplierPayment(supplierId: id, amount: amount, notes: notes),
    ),
  );
}

class _EntryForm extends StatefulWidget {
  const _EntryForm({
    required this.pickerLabel,
    required this.notesLabel,
    required this.options,
    required this.emptyMessage,
    required this.onSubmit,
  });

  final String pickerLabel;
  final String notesLabel;
  final List<PickerOption> options;
  final String emptyMessage;
  final Future<String?> Function(int id, String amount, String notes) onSubmit;

  @override
  State<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<_EntryForm> {
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  String? _selected;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null) {
      setState(() => _error = 'اختر ${widget.pickerLabel} أولاً.');
      return;
    }
    final problem = validateAmount(_amount.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final failure = await widget.onSubmit(int.parse(_selected!), _amount.text.trim(), _notes.text.trim());
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final shift = context.watch<ShiftState>();
    final app = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'تُحفظ الحركة مؤقتاً مع وردية ${app.branch?.name ?? '-'} ولا تغيّر رصيد الخزينة أو حساب الطرف إلا بعد اعتماد التقفيل.',
          style: const TextStyle(fontSize: 11.5, color: PosColors.muted, height: 1.6),
        ),
        const SizedBox(height: 14),
        if (widget.options.isEmpty)
          EmptyHint(widget.emptyMessage, icon: Icons.person_off_outlined)
        else
          SearchPickerField(
            label: widget.pickerLabel,
            value: _selected,
            options: widget.options,
            onChanged: (value) => setState(() => _selected = value),
          ),
        const SizedBox(height: 12),
        AmountField(controller: _amount, label: 'المبلغ', autofocus: widget.options.isNotEmpty),
        const SizedBox(height: 12),
        FieldLabel(widget.notesLabel),
        TextField(
          controller: _notes,
          maxLength: 255,
          decoration: const InputDecoration(hintText: 'اختياري', counterText: ''),
        ),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!, style: const TextStyle(color: PosColors.danger, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _saving || shift.closed || widget.options.isEmpty ? null : _submit,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: Text(shift.closed ? 'الوردية مقفلة' : 'حفظ الحركة'),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          ],
        ),
      ],
    );
  }
}