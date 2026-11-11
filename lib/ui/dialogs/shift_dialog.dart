import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/money.dart';
import '../../core/operational_date.dart';
import '../../state/app_state.dart';
import '../../state/shift_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> showShiftDialog(BuildContext context) {
  context.read<ShiftState>().refresh();
  return showPosDialog<void>(
    context,
    title: 'تقفيل الوردية',
    width: 620,
    child: const _ShiftCloseForm(),
  );
}

class _ShiftCloseForm extends StatefulWidget {
  const _ShiftCloseForm();

  @override
  State<_ShiftCloseForm> createState() => _ShiftCloseFormState();
}

class _ShiftCloseFormState extends State<_ShiftCloseForm> {
  String _shift = 'day';
  String? _error;

  Future<void> _close(ShiftState shift) async {
    setState(() => _error = null);
    final failure = await shift.closeShift(_shift);
    if (!mounted) return;
    if (failure != null) {
      setState(() => _error = failure);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final shift = context.watch<ShiftState>();
    final summary = shift.summary;
    final shifts = app.bootstrap?.shifts ?? const [];
    if (!shifts.any((option) => option.value == _shift) && shifts.isNotEmpty) _shift = shifts.first.value;
    final pending = app.pendingCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${app.branch?.name ?? '-'} · اليوم التشغيلي ${summary?.operationalDate ?? operationalDateIso(DateTime.now())}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
            IconButton(
              onPressed: shift.loading ? null : () => shift.refresh(),
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
              _SummaryTile(label: 'المبيعات', value: summary?.sales ?? '0', icon: Icons.point_of_sale, color: PosColors.brand),
              _SummaryTile(label: 'المصروفات', value: summary?.expenses ?? '0', icon: Icons.money_off_csred_outlined, color: PosColors.warning),
              _SummaryTile(label: 'سلف الموظفين', value: summary?.advances ?? '0', icon: Icons.people_outline, color: PosColors.accent),
              _SummaryTile(label: 'سدادات الموردين', value: summary?.suppliers ?? '0', icon: Icons.local_shipping_outlined, color: PosColors.success),
            ],
          ),
          const SizedBox(height: 12),
          if (shift.error != null)
            Text(shift.error!, style: const TextStyle(color: PosColors.danger, fontSize: 12)),
          if (summary?.closed == true)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PosColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PosColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: PosColors.success, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تم إرسال الوردية للمراجعة برقم #${summary?.cashInId ?? '-'}. لا يمكن تسجيل حركات أو بيع جديد حتى يفتح المحاسب وردية أخرى.',
                      style: const TextStyle(fontSize: 12, height: 1.6, color: PosColors.text),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (pending > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PosColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: PosColors.warning.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, color: PosColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'يوجد $pending طلب غير متزامن على هذا الجهاز. اتصل بالإنترنت واضغط مزامنة قبل التقفيل.',
                        style: const TextStyle(fontSize: 12, height: 1.6),
                      ),
                    ),
                    TextButton(onPressed: app.syncNow, child: const Text('مزامنة')),
                  ],
                ),
              ),
            const FieldLabel('نوع الوردية'),
            SegmentedButton<String>(
              segments: [
                for (final option in shifts) ButtonSegment(value: option.value, label: Text(option.label)),
              ],
              selected: {_shift},
              onSelectionChanged: (selection) => setState(() => _shift = selection.first),
            ),
            const SizedBox(height: 12),
            const Text(
              'يتم تجميع كل المبيعات والمصروفات والسلف والسدادات في حركة خزينة واحدة بحالة «بانتظار المراجعة». لا يتغير رصيد الخزينة ولا حسابات الموردين والموظفين إلا بعد اعتماد محاسب الخزينة.',
              style: TextStyle(fontSize: 11.5, color: PosColors.muted, height: 1.7),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: PosColors.danger, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: shift.busy || summary == null || summary.closed
                      ? null
                      : () => _close(shift),
                  icon: shift.busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_outline),
                  label: Text(summary?.closed == true
                      ? 'تم الإرسال للمراجعة #${summary?.cashInId ?? ''}'
                      : 'إرسال للمراجعة'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إغلاق')),
            ],
          ),
        ],
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value, required this.icon, required this.color});

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
                  Text(label, style: const TextStyle(fontSize: 11, color: PosColors.muted)),
                  Text('${formatCents(((double.tryParse(value) ?? 0) * 100).round())} ج.م',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      );
}