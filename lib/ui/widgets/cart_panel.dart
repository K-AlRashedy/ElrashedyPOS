import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/money.dart';
import '../../state/app_state.dart';
import '../../state/cart_state.dart';
import '../dialogs/order_dialog.dart';
import '../theme.dart';
import 'common.dart';

class CartPanel extends StatelessWidget {
  const CartPanel({super.key});

  Future<void> _checkout(
    BuildContext context,
    CartState cart,
    String paymentMethod,
  ) async {
    if (cart.needsOrderDetails) {
      final ready = await showOrderDialog(context, requireCompletion: true);
      if (!ready || !context.mounted) return;
    }
    await cart.checkout(paymentMethod);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cart = context.watch<CartState>();
    final methods = app.bootstrap?.paymentMethods ?? const [];
    var cashLabel = 'نقدي';
    for (final method in methods) {
      if (method.value == 'cash') cashLabel = method.label;
    }
    final nonCashMethods = methods
        .where((method) => method.value != 'cash')
        .take(3)
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: PosColors.card,
        border: Border(left: BorderSide(color: PosColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: _OrderTypeSelector(cart: cart),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 6),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: PosColors.brand,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'الطلب الحالي',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
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
                StatusPill(
                  label: cart.orderSummary,
                  color: PosColors.brand,
                  icon: Icons.storefront_outlined,
                ),
                const SizedBox(width: 8),
                Text(
                  '${formatQty(cart.itemCount)} قطعة',
                  style: const TextStyle(color: PosColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: cart.isEmpty
                ? const EmptyHint(
                    'الطلب فارغ — اختر الأصناف من القائمة',
                    icon: Icons.shopping_cart_outlined,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
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
                      border: Border.all(
                        color: PosColors.danger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: PosColors.danger,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'الوردية مقفلة ومُرسلة للمراجعة. لا يمكن البيع حتى يفتح المحاسب وردية جديدة.',
                            style: TextStyle(
                              color: PosColors.danger,
                              fontSize: 11.5,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    const Text(
                      'الإجمالي',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: PosColors.muted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${cart.total} ج.م',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: PosColors.brandDark,
                      ),
                    ),
                  ],
                ),
                if (cart.payment == 'cash') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _TenderedField(
                          value: cart.tendered,
                          selected: cart.keypadTargetsTendered,
                          onTap: () =>
                              cart.selectKeypadTarget(KeypadTarget.tendered),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'المتبقي',
                            style: TextStyle(
                              fontSize: 11,
                              color: PosColors.muted,
                            ),
                          ),
                          Text(
                            '${formatCents(cart.changeCents)} ج.م',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: PosColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                _CartQuantityPad(
                  cart: cart,
                  cashLabel: cashLabel,
                  cashEnabled: cart.canSell,
                  onCash: () => _checkout(context, cart, 'cash'),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      for (
                        var index = 0;
                        index < nonCashMethods.length;
                        index++
                      ) ...[
                        Expanded(
                          child: _PaymentButton(
                            label: nonCashMethods[index].label,
                            icon: switch (nonCashMethods[index].value) {
                              'visa' => Icons.credit_card,
                              'instapay' => Icons.account_balance_outlined,
                              _ => Icons.phone_android_outlined,
                            },
                            enabled: cart.canSell,
                            onTap: () => _checkout(
                              context,
                              cart,
                              nonCashMethods[index].value,
                            ),
                          ),
                        ),
                        if (index < nonCashMethods.length - 1)
                          const SizedBox(width: 7),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTypeSelector extends StatelessWidget {
  const _OrderTypeSelector({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context) {
    const types = [
      ('takeaway', 'تيك أواي', Icons.shopping_bag_outlined),
      ('dine_in', 'صالة', Icons.table_restaurant_outlined),
      ('delivery', 'دليفري', Icons.delivery_dining_outlined),
    ];
    return Row(
      children: [
        for (var index = 0; index < types.length; index++) ...[
          Expanded(
            child: _OrderTypeButton(
              label: types[index].$2,
              icon: types[index].$3,
              selected: cart.orderType == types[index].$1,
              onTap: () {
                final wasSelected = cart.orderType == types[index].$1;
                cart.setDetail('type', types[index].$1);
                if (types[index].$1 != 'takeaway' || wasSelected) {
                  showOrderDialog(context);
                }
              },
            ),
          ),
          if (index < types.length - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class _OrderTypeButton extends StatelessWidget {
  const _OrderTypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => selected
      ? FilledButton.icon(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          ),
          icon: Icon(icon, size: 16),
          label: Text(label, overflow: TextOverflow.ellipsis),
        )
      : OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          ),
          icon: Icon(icon, size: 16),
          label: Text(label, overflow: TextOverflow.ellipsis),
        );
}

class _CartQuantityPad extends StatelessWidget {
  const _CartQuantityPad({
    required this.cart,
    required this.cashLabel,
    required this.cashEnabled,
    required this.onCash,
  });

  final CartState cart;
  final String cashLabel;
  final bool cashEnabled;
  final VoidCallback onCash;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => cart.selectKeypadTarget(KeypadTarget.quantity),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'كمية الصنف التالي',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      color: cart.keypadTargetsTendered
                          ? PosColors.muted
                          : PosColors.brandDark,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    cart.nextQuantityDisplay,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      color: cart.keypadTargetsTendered
                          ? PosColors.muted
                          : PosColors.brandDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 182,
          child: Column(
            children: [
              _PadRow(
                children: [
                  for (final key in const ['7', '8', '9'])
                    _QuantityKey(
                      label: key,
                      onTap: () => cart.appendKeypadValue(key),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              _PadRow(
                children: [
                  for (final key in const ['4', '5', '6'])
                    _QuantityKey(
                      label: key,
                      onTap: () => cart.appendKeypadValue(key),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              _PadRow(
                children: [
                  for (final key in const ['1', '2', '3'])
                    _QuantityKey(
                      label: key,
                      onTap: () => cart.appendKeypadValue(key),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              _PadRow(
                children: [
                  _QuantityKey(
                    icon: Icons.backspace_outlined,
                    onTap: cart.backspaceKeypad,
                  ),
                  _QuantityKey(
                    label: '0',
                    onTap: () => cart.appendKeypadValue('0'),
                  ),
                  _CashKey(
                    label: cashLabel,
                    enabled: cashEnabled,
                    onTap: onCash,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _PadRow extends StatelessWidget {
  const _PadRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          Expanded(child: SizedBox.expand(child: children[index])),
          if (index < children.length - 1) const SizedBox(width: 6),
        ],
      ],
    ),
  );
}

class _QuantityKey extends StatelessWidget {
  const _QuantityKey({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: Colors.white,
      foregroundColor: PosColors.brandDark,
      side: const BorderSide(color: PosColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: icon == null
        ? Text(
            label!,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          )
        : Icon(icon, size: 18),
  );
}

class _CashKey extends StatelessWidget {
  const _CashKey({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: FilledButton.icon(
      onPressed: enabled ? onTap : null,
      style: FilledButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: PosColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.payments_outlined, size: 16),
      label: Text(label, overflow: TextOverflow.ellipsis),
    ),
  );
}

class _PaymentButton extends StatelessWidget {
  const _PaymentButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool enabled;
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
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
      child: child,
    );
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
                child: Text(
                  line.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${formatCents(line.subtotalCents)} ج.م',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: PosColors.brand,
                  fontSize: 13,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => cart.removeAt(index),
                icon: const Icon(
                  Icons.close,
                  size: 17,
                  color: PosColors.danger,
                ),
                tooltip: 'حذف ${line.name}',
              ),
            ],
          ),
          Row(
            children: [
              Text(
                '${line.price} ج.م',
                style: const TextStyle(color: PosColors.muted, fontSize: 11.5),
              ),
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
                icon: Icon(
                  line.note.isEmpty
                      ? Icons.sticky_note_2_outlined
                      : Icons.sticky_note_2,
                  size: 18,
                  color: line.note.isEmpty
                      ? PosColors.muted
                      : PosColors.warning,
                ),
                tooltip: 'ملاحظة للمطبخ',
              ),
            ],
          ),
          if (line.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'ملاحظة: ${line.note}',
                style: const TextStyle(
                  fontSize: 11,
                  color: PosColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editNote(
    BuildContext context,
    CartState cart,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final saved = await showPosDialog<bool>(
      context,
      title: 'ملاحظة على الصنف',
      width: 420,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('حفظ'),
        ),
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
  const _TenderedField({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TenderedField> createState() => _TenderedFieldState();
}

class _TenderedFieldState extends State<_TenderedField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

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
    readOnly: true,
    showCursor: false,
    enableInteractiveSelection: false,
    onTap: widget.onTap,
    decoration: InputDecoration(
      labelText: 'المدفوع',
      hintText: 'المس الحقل ثم استخدم لوحة الأرقام',
      suffixText: 'ج.م',
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: widget.selected ? PosColors.brand : PosColors.border,
          width: widget.selected ? 2 : 1,
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: PosColors.brand, width: 2),
      ),
    ),
  );
}

class _QtyField extends StatefulWidget {
  const _QtyField({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final String value;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  State<_QtyField> createState() => _QtyFieldState();
}

class _QtyFieldState extends State<_QtyField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

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
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      ),
      onSubmitted: widget.onChanged,
      onTapOutside: (_) => widget.onChanged(_controller.text),
    ),
  );
}
