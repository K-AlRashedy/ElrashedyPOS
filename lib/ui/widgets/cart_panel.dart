import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/money.dart';
import '../../state/app_state.dart';
import '../../state/cart_state.dart';
import '../dialogs/order_dialog.dart';
import '../theme.dart';
import 'common.dart';

class CartPanel extends StatelessWidget {
  const CartPanel({super.key, required this.onKitchenPrint});

  final VoidCallback onKitchenPrint;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cart = context.watch<CartState>();
    final methods = app.bootstrap?.paymentMethods ?? const [];

    return Container(
      decoration: const BoxDecoration(
        color: PosColors.card,
        border: Border(left: BorderSide(color: PosColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined, size: 20, color: PosColors.brand),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('الطلب الحالي', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
                IconButton(
                  onPressed: cart.isEmpty ? null : cart.clear,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'تفريغ الطلب',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                StatusPill(label: cart.orderSummary, color: PosColors.brand, icon: Icons.storefront_outlined),
                const SizedBox(width: 8),
                Text('${formatQty(cart.itemCount)} قطعة',
                    style: const TextStyle(color: PosColors.muted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: cart.isEmpty
                ? const EmptyHint('الطلب فارغ — اختر الأصناف من القائمة', icon: Icons.shopping_cart_outlined)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    itemCount: cart.lines.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) => _CartLine(index: index),
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (app.shiftClosed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: PosColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: PosColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline, size: 16, color: PosColors.danger),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'الوردية مقفلة ومُرسلة للمراجعة. لا يمكن البيع حتى يفتح المحاسب وردية جديدة.',
                            style: TextStyle(color: PosColors.danger, fontSize: 11.5, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.w700, color: PosColors.muted)),
                    const Spacer(),
                    Text('${cart.total} ج.م',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: PosColors.brandDark)),
                  ],
                ),
                if (cart.payment == 'cash') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _TenderedField(
                          value: cart.tendered,
                          onChanged: (value) => cart.setDetail('tendered', value),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('المتبقي', style: TextStyle(fontSize: 11, color: PosColors.muted)),
                          Text('${formatCents(cart.changeCents)} ج.م',
                              style: const TextStyle(fontWeight: FontWeight.w900, color: PosColors.success)),
                        ],
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => showOrderDialog(context),
                  icon: const Icon(Icons.tune),
                  label: const Text('تفاصيل الطلب (صالة / دليفري)'),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.6,
                  children: [
                    for (final method in methods)
                      _PaymentButton(
                        label: method.label,
                        icon: switch (method.value) {
                          'cash' => Icons.payments_outlined,
                          'visa' => Icons.credit_card,
                          'instapay' => Icons.account_balance_outlined,
                          _ => Icons.phone_android_outlined,
                        },
                        primary: method.value == 'cash',
                        enabled: cart.canSell,
                        onTap: () => cart.checkout(method.value),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: cart.isEmpty ? null : onKitchenPrint,
                  icon: const Icon(Icons.soup_kitchen_outlined),
                  label: const Text('طباعة شيك المطبخ'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentButton extends StatelessWidget {
  const _PaymentButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 6),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
    return primary
        ? FilledButton(onPressed: enabled ? onTap : null, style: FilledButton.styleFrom(padding: EdgeInsets.zero), child: child)
        : OutlinedButton(onPressed: enabled ? onTap : null, style: OutlinedButton.styleFrom(padding: EdgeInsets.zero), child: child);
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    if (index >= cart.lines.length) return const SizedBox.shrink();
    final line = cart.lines[index];
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(line.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              Text('${formatCents(line.subtotalCents)} ج.م',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: PosColors.brand, fontSize: 13)),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => cart.removeAt(index),
                icon: const Icon(Icons.close, size: 17, color: PosColors.danger),
                tooltip: 'حذف ${line.name}',
              ),
            ],
          ),
          Row(
            children: [
              Text('${line.price} ج.م', style: const TextStyle(color: PosColors.muted, fontSize: 11.5)),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => cart.decrement(index),
                icon: const Icon(Icons.remove_circle_outline, size: 19),
                tooltip: 'تقليل الكمية',
              ),
              _QtyField(
                value: line.qty,
                label: line.name,
                onChanged: (value) => cart.setQty(index, value),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => cart.increment(index),
                icon: const Icon(Icons.add_circle_outline, size: 19),
                tooltip: 'زيادة الكمية',
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _editNote(context, cart, line.note),
                icon: Icon(line.note.isEmpty ? Icons.sticky_note_2_outlined : Icons.sticky_note_2,
                    size: 18, color: line.note.isEmpty ? PosColors.muted : PosColors.warning),
                tooltip: 'ملاحظة للمطبخ',
              ),
            ],
          ),
          if (line.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('ملاحظة: ${line.note}',
                  style: const TextStyle(fontSize: 11, color: PosColors.warning, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Future<void> _editNote(BuildContext context, CartState cart, String current) async {
    final controller = TextEditingController(text: current);
    final saved = await showPosDialog<bool>(
      context,
      title: 'ملاحظة على الصنف',
      width: 420,
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('حفظ')),
      ],
      child: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 200,
        decoration: const InputDecoration(hintText: 'مثال: بدون بصل'),
      ),
    );
    if (saved == true) cart.setNote(index, controller.text);
    controller.dispose();
  }
}

class _TenderedField extends StatefulWidget {
  const _TenderedField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TenderedField> createState() => _TenderedFieldState();
}

class _TenderedFieldState extends State<_TenderedField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _TenderedField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'المدفوع',
          hintText: 'اتركه فارغاً لتحصيل الإجمالي',
          suffixText: 'ج.م',
        ),
        onChanged: widget.onChanged,
      );
}

class _QtyField extends StatefulWidget {
  const _QtyField({required this.value, required this.label, required this.onChanged});

  final String value;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  State<_QtyField> createState() => _QtyFieldState();
}

class _QtyFieldState extends State<_QtyField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _QtyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 62,
        child: TextField(
          controller: _controller,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8)),
          onSubmitted: widget.onChanged,
          onTapOutside: (_) => widget.onChanged(_controller.text),
        ),
      );
}