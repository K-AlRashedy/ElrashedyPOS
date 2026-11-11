import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../state/shift_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> showExpenseDialog(BuildContext context) => showPosDialog<void>(
      context,
      title: 'تسجيل مصروف تشغيل',
      width: 620,
      child: const _ExpenseForm(),
    );

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm();

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  String? _mainId;
  String? _accountId;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    context.read<ShiftState>().loadExpenses();
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  List<ExpenseAccount> _children(AppState app) => app.bootstrap?.subAccounts
          .where((account) => '${account.parentId}' == _mainId)
          .toList() ??
      [];

  Future<void> _submit(AppState app, ShiftState shift) async {
    final problem = validateAmount(_amount.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (_accountId == null) {
      setState(() => _error = 'اختر بند المصروف.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final failure = await shift.addExpense(
      accountId: int.parse(_accountId!),
      amount: _amount.text.trim(),
      reason: _reason.text.trim(),
    );
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
    final app = context.watch<AppState>();
    final shift = context.watch<ShiftState>();
    final mains = app.bootstrap?.mainAccounts ?? const [];
    final children = _children(app);
    var mainName = '';
    for (final account in mains) {
      if ('${account.id}' == _mainId) mainName = account.name;
    }
    final accountOptions = [
      for (final account in children) PickerOption('${account.id}', account.name),
      if (children.isEmpty && _mainId != null) PickerOption(_mainId!, '$mainName (حساب مباشر)'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: PosColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PosColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: PosColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'يُحفظ المصروف مؤقتاً مع الوردية ولا يغيّر رصيد الخزينة إلا بعد اعتماد محاسب الخزينة لتقفيل الوردية. الفرع: ${app.branch?.name ?? '-'} · اليوم التشغيلي: ${shift.operationalDate}',
                  style: const TextStyle(fontSize: 11.5, color: PosColors.muted, height: 1.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SearchPickerField(
          label: 'الحساب الرئيسي',
          value: _mainId,
          options: [for (final account in mains) PickerOption('${account.id}', account.name)],
          onChanged: (value) => setState(() {
            _mainId = value;
            _accountId = null;
          }),
        ),
        const SizedBox(height: 12),
        SearchPickerField(
          label: 'بند المصروف',
          value: _accountId,
          enabled: _mainId != null,
          placeholder: _mainId == null ? 'اختر الحساب الرئيسي أولاً' : 'اختر بند المصروف...',
          options: accountOptions,
          onChanged: (value) => setState(() => _accountId = value),
        ),
        const SizedBox(height: 12),
        AmountField(controller: _amount, label: 'المبلغ', autofocus: true),
        const SizedBox(height: 12),
        const FieldLabel('البيان'),
        TextField(
          controller: _reason,
          maxLength: 255,
          decoration: const InputDecoration(hintText: 'سبب المصروف', counterText: ''),
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
                onPressed: _saving || shift.closed ? null : () => _submit(app, shift),
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: Text(shift.closed ? 'الوردية مقفلة' : 'حفظ المصروف'),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          ],
        ),
        const SizedBox(height: 18),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(child: Text('مصروفات الوردية', style: TextStyle(fontWeight: FontWeight.w800))),
            Text('${double.tryParse(shift.expensesTotal)?.toStringAsFixed(2) ?? '0.00'} ج.م',
                style: const TextStyle(fontWeight: FontWeight.w900, color: PosColors.brand)),
            IconButton(
              onPressed: shift.loadExpenses,
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'تحديث',
            ),
          ],
        ),
        if (shift.expenses.isEmpty)
          const EmptyHint('لا توجد مصروفات مسجلة لهذه الوردية.', icon: Icons.money_off_csred_outlined)
        else
          for (final expense in shift.expenses.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: PosColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: PosColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(expense.account, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                          Text(expense.reason.isEmpty ? 'بدون بيان' : expense.reason,
                              style: const TextStyle(color: PosColors.muted, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    Text('${double.tryParse(expense.amount)?.toStringAsFixed(2) ?? expense.amount} ج.م',
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
        if (shift.expenses.length > 6)
          Text('يتم عرض آخر 6 مصروفات من أصل ${shift.expenses.length}. الإجمالي يشملها جميعاً.',
              style: const TextStyle(color: PosColors.muted, fontSize: 11.5)),
      ],
    );
  }
}