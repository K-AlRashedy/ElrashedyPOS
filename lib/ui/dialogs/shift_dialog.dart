import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/operational_date.dart';
import '../../state/app_state.dart';
import '../../state/shift_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> showLogoutDialog(BuildContext context) => showPosDialog<void>(
  context,
  title: 'تسجيل الخروج وتقفيل الوردية',
  width: 580,
  child: const _LogoutForm(),
);

class _LogoutForm extends StatefulWidget {
  const _LogoutForm();

  @override
  State<_LogoutForm> createState() => _LogoutFormState();
}

class _LogoutFormState extends State<_LogoutForm> {
  final _password = TextEditingController();
  String _shift = 'day';
  bool _shiftTouched = false;
  bool _passwordVisible = false;
  bool _loggingOut = false;
  String? _error;
  ShiftSummary? _report;

  @override
  void initState() {
    super.initState();
    _shift = context.read<ShiftState>().summary?.shift ?? 'day';
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final state = context.read<ShiftState>();
    await state.refresh();
    final summary = state.summary;
    if (!mounted || _shiftTouched || summary == null || summary.shift.isEmpty) {
      return;
    }
    setState(() => _shift = summary.shift);
  }

  Future<void> _submit() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'أدخل كلمة مرور حسابك للمتابعة.');
      return;
    }
    setState(() => _error = null);
    final report = await context.read<ShiftState>().closeShift(
      _shift,
      _password.text,
    );
    if (!mounted) return;
    if (report == null) {
      setState(
        () =>
            _error = context.read<ShiftState>().error ?? 'تعذر تقفيل الوردية.',
      );
      return;
    }
    _password.clear();
    setState(() => _report = report);
    await _printAndLogout();
  }

  Future<void> _printAndLogout() async {
    final report = _report;
    if (report == null) return;
    setState(() {
      _error = null;
      _loggingOut = true;
    });
    final printed = await context.read<AppState>().printer.printShiftSummary(
      report,
    );
    if (!mounted) return;
    if (!printed) {
      setState(() {
        _loggingOut = false;
        _error = 'تم تقفيل الوردية، لكن تعذرت طباعة الملخص. أعد المحاولة أو تابع تسجيل الخروج.';
      });
      return;
    }
    await _logout();
  }

  Future<void> _logout() async {
    setState(() {
      _error = null;
      _loggingOut = true;
    });
    try {
      await context.read<AppState>().logout();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loggingOut = false;
        _error = 'تم تقفيل الوردية، لكن تعذر حذف الجلسة المحلية. أعد المحاولة.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final shift = context.watch<ShiftState>();
    final summary = _report ?? shift.summary;
    final shifts = app.bootstrap?.shifts ?? const [];
    final selectedShift = shifts.any((option) => option.value == _shift)
        ? _shift
        : (shifts.isEmpty ? 'day' : shifts.first.value);
    final busy = shift.busy || app.printer.busy || _loggingOut;
    final reportReady = _report != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${summary?.branchName ?? app.branch?.name ?? '-'} · اليوم التشغيلي ${summary?.operationalDate ?? operationalDateIso(DateTime.now())}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            IconButton(
              onPressed: busy ? null : () => shift.refresh(),
              icon: const Icon(Icons.refresh, size: 19),
              tooltip: 'تحديث الملخص',
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (shift.loading && summary == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.9,
            children: [
              _SummaryTile(
                label: 'المبيعات',
                value: summary?.sales ?? '0',
                icon: Icons.point_of_sale,
                color: PosColors.brand,
              ),
              _SummaryTile(
                label: 'المصروفات',
                value: summary?.expenses ?? '0',
                icon: Icons.money_off_csred_outlined,
                color: PosColors.warning,
              ),
              _SummaryTile(
                label: 'سلف الموظفين',
                value: summary?.advances ?? '0',
                icon: Icons.people_outline,
                color: PosColors.accent,
              ),
              _SummaryTile(
                label: 'سدادات الموردين',
                value: summary?.suppliers ?? '0',
                icon: Icons.local_shipping_outlined,
                color: PosColors.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (app.pendingCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PosColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: PosColors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_upload_outlined,
                    color: PosColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'يوجد ${app.pendingCount} طلب غير متزامن. سيتم التحقق من مزامنته قبل التقفيل.',
                      style: const TextStyle(fontSize: 12, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
          if (summary?.closed == true)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PosColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: PosColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: PosColors.success,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reportReady
                          ? 'تم إرسال الوردية للمراجعة برقم #${summary?.cashInId ?? '-'}.'
                          : 'الوردية مُقفلة بالفعل برقم #${summary?.cashInId ?? '-'}. سيتم التحقق وطباعة الملخص الأصلي ثم تسجيل الخروج.',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: PosColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            const Text(
              'سيتم تجميع المبيعات والمصروفات والسلف والسدادات في توريد واحد لمراجعة محاسب الخزينة، ثم طباعة ملخص واحد قبل تسجيل الخروج.',
              style: TextStyle(
                fontSize: 11.5,
                color: PosColors.muted,
                height: 1.7,
              ),
            ),
          const SizedBox(height: 14),
          if (!reportReady) ...[
            const FieldLabel('نوع الوردية'),
            DropdownButtonFormField<String>(
              key: ValueKey(selectedShift),
              initialValue: selectedShift,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                if (shifts.isEmpty)
                  const DropdownMenuItem(value: 'day', child: Text('صباحية'))
                else
                  for (final option in shifts)
                    DropdownMenuItem(
                      value: option.value,
                      child: Text(option.label),
                    ),
              ],
              onChanged: busy
                  ? null
                  : (value) => setState(() {
                      _shiftTouched = true;
                      if (value != null) _shift = value;
                    }),
            ),
            const SizedBox(height: 14),
            const FieldLabel('كلمة مرور حسابك'),
            TextField(
              controller: _password,
              autofocus: true,
              enabled: !busy,
              obscureText: !_passwordVisible,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!busy) _submit();
              },
              decoration: InputDecoration(
                hintText: 'أدخل كلمة المرور',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                  icon: Icon(
                    _passwordVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                color: PosColors.danger,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy
                      ? null
                      : (reportReady ? _printAndLogout : _submit),
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(reportReady ? Icons.print_outlined : Icons.logout),
                  label: Text(
                    busy
                        ? 'جارٍ التنفيذ...'
                        : reportReady
                        ? 'إعادة الطباعة وتسجيل الخروج'
                        : 'تأكيد وتسجيل الخروج',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: busy ? null : () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
            ],
          ),
          if (reportReady && !busy) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: _logout,
              child: const Text('تسجيل الخروج بدون إعادة الطباعة'),
            ),
          ],
        ],
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: PosColors.muted),
              ),
              Text(
                '${formatCents(((double.tryParse(value) ?? 0) * 100).round())} ج.م',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
