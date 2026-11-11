import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/cart_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> showOrderDialog(BuildContext context) => showPosDialog<void>(
      context,
      title: 'تفاصيل الطلب',
      width: 520,
      child: const _OrderForm(),
    );

class _OrderForm extends StatefulWidget {
  const _OrderForm();

  @override
  State<_OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends State<_OrderForm> {
  late final CartState _cart = context.read<CartState>();
  late final TextEditingController _table = TextEditingController(text: _cart.table);
  late final TextEditingController _customer = TextEditingController(text: _cart.customer);
  late final TextEditingController _phone = TextEditingController(text: _cart.phone);
  late final TextEditingController _address = TextEditingController(text: _cart.address);
  late final TextEditingController _notes = TextEditingController(text: _cart.notes);

  @override
  void dispose() {
    _table.dispose();
    _customer.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cart = context.watch<CartState>();
    final types = app.bootstrap?.orderTypes ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const FieldLabel('نوع الطلب'),
        SegmentedButton<String>(
          segments: [
            for (final type in types)
              ButtonSegment(
                value: type.value,
                label: Text(type.label),
                icon: Icon(switch (type.value) {
                  'dine_in' => Icons.table_restaurant_outlined,
                  'delivery' => Icons.delivery_dining_outlined,
                  _ => Icons.shopping_bag_outlined,
                }),
              ),
          ],
          selected: {cart.orderType},
          onSelectionChanged: (selection) => cart.setDetail('type', selection.first),
        ),
        const SizedBox(height: 16),
        if (cart.orderType == 'dine_in') ...[
          const FieldLabel('رقم الطاولة'),
          TextField(
            controller: _table,
            autofocus: true,
            maxLength: 30,
            decoration: const InputDecoration(hintText: 'مثال: 12', counterText: ''),
            onChanged: (value) => cart.setDetail('table', value),
          ),
          const SizedBox(height: 12),
        ],
        if (cart.orderType == 'delivery') ...[
          const FieldLabel('اسم العميل'),
          TextField(
            controller: _customer,
            maxLength: 120,
            decoration: const InputDecoration(counterText: ''),
            onChanged: (value) => cart.setDetail('customer', value),
          ),
          const SizedBox(height: 12),
          const FieldLabel('هاتف التوصيل'),
          TextField(
            controller: _phone,
            autofocus: true,
            maxLength: 30,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(counterText: ''),
            onChanged: (value) => cart.setDetail('phone', value),
          ),
          const SizedBox(height: 12),
          const FieldLabel('عنوان التوصيل'),
          TextField(
            controller: _address,
            maxLength: 300,
            maxLines: 2,
            decoration: const InputDecoration(counterText: ''),
            onChanged: (value) => cart.setDetail('address', value),
          ),
          const SizedBox(height: 12),
        ],
        const FieldLabel('ملاحظات على الطلب'),
        TextField(
          controller: _notes,
          maxLength: 1000,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'اختياري', counterText: ''),
          onChanged: (value) => cart.setDetail('notes', value),
        ),
        const SizedBox(height: 8),
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
                  cart.orderType == 'dine_in'
                      ? 'رقم الطاولة مطلوب لإتمام البيع في الصالة.'
                      : cart.orderType == 'delivery'
                          ? 'الهاتف والعنوان مطلوبان لإتمام طلب الدليفري.'
                          : 'تيك أواي لا يحتاج بيانات إضافية.',
                  style: const TextStyle(fontSize: 11.5, color: PosColors.muted, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('تم'),
        ),
      ],
    );
  }
}