import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/money.dart';
import '../../state/app_state.dart';
import '../../state/cart_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<bool> showOrderDialog(
  BuildContext context, {
  bool requireCompletion = false,
}) async =>
    await showPosDialog<bool>(
      context,
      title: requireCompletion ? 'أكمل بيانات الطلب' : 'تفاصيل الطلب',
      width: 520,
      child: _OrderForm(requireCompletion: requireCompletion),
    ) ??
    false;

class _OrderForm extends StatefulWidget {
  const _OrderForm({required this.requireCompletion});

  final bool requireCompletion;

  @override
  State<_OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends State<_OrderForm> {
  final _formKey = GlobalKey<FormState>();
  late final CartState _cart = context.read<CartState>();
  late final TextEditingController _table = TextEditingController(
    text: _cart.table,
  );
  late final TextEditingController _customer = TextEditingController(
    text: _cart.customer,
  );
  late final TextEditingController _phone = TextEditingController(
    text: _cart.phone,
  );
  late final TextEditingController _address = TextEditingController(
    text: _cart.address,
  );
  late final TextEditingController _notes = TextEditingController(
    text: _cart.notes,
  );
  Timer? _lookupTimer;
  Timer? _saveTimer;
  List<DeliveryCustomer> _suggestions = [];
  bool _lookingUp = false;
  bool _savingCustomer = false;
  String? _customerSaveMessage;
  String _lastSavedCustomer = '';
  int _lookupSequence = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<AppState>().refreshDeliveryZones());
    });
  }

  @override
  void dispose() {
    _lookupTimer?.cancel();
    _saveTimer?.cancel();
    _lookupSequence++;
    _table.dispose();
    _customer.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  String get _normalizedPhone => DeliveryCustomer.normalizePhone(_cart.phone);

  String get _customerSignature => [
    _normalizedPhone,
    _cart.customer.trim(),
    _cart.address.trim(),
    _cart.deliveryZoneId,
    _cart.notes.trim(),
  ].join('\u0001');

  bool get _canSaveCustomer =>
      _cart.orderType == 'delivery' &&
      _normalizedPhone.length >= 6 &&
      _normalizedPhone.length <= 15 &&
      _cart.customer.trim().isNotEmpty &&
      _cart.address.trim().isNotEmpty &&
      (_cart.deliveryZone?.isActive ?? false);

  void _customerEdited({bool lookup = false}) {
    if (mounted && _customerSaveMessage != null) {
      setState(() => _customerSaveMessage = null);
    }
    if (lookup) {
      _lookupTimer?.cancel();
      final sequence = ++_lookupSequence;
      final phone = _normalizedPhone;
      if (phone.length < 3) {
        setState(() {
          _suggestions = [];
          _lookingUp = false;
        });
      } else {
        setState(() => _lookingUp = true);
        _lookupTimer = Timer(
          const Duration(milliseconds: 350),
          () => _lookupCustomer(sequence, phone),
        );
      }
    }
    _scheduleCustomerSave();
  }

  Future<void> _lookupCustomer(int sequence, String phone) async {
    final api = context.read<AppState>().api;
    if (api == null) {
      if (mounted && sequence == _lookupSequence) {
        setState(() => _lookingUp = false);
      }
      return;
    }
    try {
      final customers = await api.searchDeliveryCustomers(phone);
      if (!mounted || sequence != _lookupSequence) return;
      DeliveryCustomer? exact;
      for (final customer in customers) {
        if (DeliveryCustomer.normalizePhone(customer.phoneNumber) == phone) {
          exact = customer;
          break;
        }
      }
      if (exact != null) {
        _applyCustomer(exact);
        setState(() => _suggestions = []);
      } else {
        setState(() => _suggestions = customers);
      }
    } catch (_) {
      if (mounted && sequence == _lookupSequence) {
        setState(() => _suggestions = []);
      }
    } finally {
      if (mounted && sequence == _lookupSequence) {
        setState(() => _lookingUp = false);
      }
    }
  }

  void _applyCustomer(DeliveryCustomer customer) {
    _saveTimer?.cancel();
    _customer.text = customer.customerName;
    _phone.text = customer.phoneNumber;
    _address.text = customer.address;
    _notes.text = customer.notes;
    _cart.setDetail('customer', customer.customerName);
    _cart.setDetail('phone', customer.phoneNumber);
    _cart.setDetail('address', customer.address);
    _cart.setDetail('notes', customer.notes);
    _cart.setDeliveryZone(customer.deliveryZone);
    _lastSavedCustomer = _customerSignature;
  }

  void _selectCustomer(DeliveryCustomer customer) {
    setState(() {
      _applyCustomer(customer);
      _suggestions = [];
      _customerSaveMessage = null;
    });
  }

  void _scheduleCustomerSave() {
    _saveTimer?.cancel();
    if (!_canSaveCustomer || _customerSignature == _lastSavedCustomer) return;
    _saveTimer = Timer(const Duration(milliseconds: 900), _saveCustomer);
  }

  Future<void> _saveCustomer() async {
    if (!mounted || !_canSaveCustomer) return;
    if (_savingCustomer) {
      _scheduleCustomerSave();
      return;
    }
    final api = context.read<AppState>().api;
    if (api == null) return;
    final signature = _customerSignature;
    final zoneId = _cart.deliveryZoneId!;
    _savingCustomer = true;
    setState(() => _customerSaveMessage = null);
    try {
      await api.upsertDeliveryCustomer(
        phone: _normalizedPhone,
        customer: _cart.customer.trim(),
        address: _cart.address.trim(),
        deliveryZoneId: zoneId,
        notes: _cart.notes.trim(),
      );
      if (!mounted) return;
      if (signature == _customerSignature) {
        _lastSavedCustomer = signature;
        setState(() => _customerSaveMessage = 'تم حفظ بيانات العميل تلقائياً.');
      } else {
        _scheduleCustomerSave();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _customerSaveMessage =
              'تعذر الحفظ الآن؛ ستُحفظ بيانات العميل مع مزامنة الطلب.',
        );
      }
    } finally {
      _savingCustomer = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cart = context.watch<CartState>();
    final types = app.bootstrap?.orderTypes ?? const [];
    final zones = [...app.deliveryZones];
    final selectedZone = cart.deliveryZone;
    if (selectedZone != null &&
        !zones.any((zone) => zone.id == selectedZone.id)) {
      zones.add(selectedZone);
    }
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
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
            onSelectionChanged: (selection) {
              cart.setDetail('type', selection.first);
              if (selection.first != 'delivery') {
                _lookupTimer?.cancel();
                _saveTimer?.cancel();
                _lookupSequence++;
                setState(() {
                  _suggestions = [];
                  _lookingUp = false;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          if (cart.orderType == 'dine_in') ...[
            const FieldLabel('رقم الطاولة'),
            TextFormField(
              controller: _table,
              autofocus: true,
              maxLength: 30,
              decoration: const InputDecoration(
                hintText: 'مثال: 12',
                counterText: '',
              ),
              onChanged: (value) => cart.setDetail('table', value),
              validator: (value) =>
                  widget.requireCompletion &&
                      cart.orderType == 'dine_in' &&
                      (value == null || value.trim().isEmpty)
                  ? 'رقم الطاولة مطلوب'
                  : null,
            ),
            const SizedBox(height: 12),
          ],
          if (cart.orderType == 'delivery') ...[
            const FieldLabel('اسم العميل *'),
            TextFormField(
              controller: _customer,
              autofocus: true,
              maxLength: 120,
              decoration: const InputDecoration(counterText: ''),
              onChanged: (value) {
                cart.setDetail('customer', value);
                _customerEdited();
              },
              validator: (value) =>
                  widget.requireCompletion &&
                      cart.orderType == 'delivery' &&
                      (value == null || value.trim().isEmpty)
                  ? 'اسم العميل مطلوب'
                  : null,
            ),
            const SizedBox(height: 12),
            const FieldLabel('هاتف التوصيل *'),
            TextFormField(
              controller: _phone,
              maxLength: 30,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                counterText: '',
                prefixIcon: const Icon(Icons.phone_outlined),
                suffixIcon: _lookingUp
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              onChanged: (value) {
                cart.setDetail('phone', value);
                _customerEdited(lookup: true);
              },
              validator: (value) {
                if (!widget.requireCompletion || cart.orderType != 'delivery') {
                  return null;
                }
                final length = DeliveryCustomer.normalizePhone(value).length;
                if (length < 6 || length > 15) {
                  return 'أدخل هاتفاً صحيحاً من 6 إلى 15 رقماً';
                }
                return null;
              },
            ),
            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: PosColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: PosColors.border),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final customer = _suggestions[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.person_outline,
                        color: PosColors.brand,
                      ),
                      title: Text(
                        customer.customerName.isEmpty
                            ? customer.phoneNumber
                            : customer.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${customer.phoneNumber} · ${customer.address}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        '${formatCents(customer.deliveryZone.deliveryFeeCents)} ج.م',
                        style: const TextStyle(
                          color: PosColors.brand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onTap: () => _selectCustomer(customer),
                    );
                  },
                ),
              ),
            if (_lookingUp || _savingCustomer || _customerSaveMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _lookingUp
                      ? 'جاري البحث عن العميل...'
                      : _savingCustomer
                      ? 'جاري حفظ بيانات العميل تلقائياً...'
                      : _customerSaveMessage!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: PosColors.muted,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const FieldLabel('عنوان التوصيل *'),
            TextFormField(
              controller: _address,
              maxLength: 300,
              maxLines: 2,
              decoration: const InputDecoration(counterText: ''),
              onChanged: (value) {
                cart.setDetail('address', value);
                _customerEdited();
              },
              validator: (value) =>
                  widget.requireCompletion &&
                      cart.orderType == 'delivery' &&
                      (value == null || value.trim().isEmpty)
                  ? 'عنوان التوصيل مطلوب'
                  : null,
            ),
            const SizedBox(height: 12),
            const FieldLabel('منطقة التوصيل *'),
            DropdownButtonFormField<int>(
              initialValue: cart.deliveryZoneId,
              isExpanded: true,
              decoration: const InputDecoration(counterText: ''),
              items: [
                for (final zone in zones)
                  DropdownMenuItem(
                    value: zone.id,
                    child: Text(
                      '${zone.name} — ${formatCents(zone.deliveryFeeCents)} ج.م',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: zones.isEmpty
                  ? null
                  : (id) {
                      final zone = zones.firstWhere((zone) => zone.id == id);
                      cart.setDeliveryZone(zone);
                      setState(() => _customerSaveMessage = null);
                      _scheduleCustomerSave();
                    },
              validator: (value) =>
                  widget.requireCompletion &&
                      cart.orderType == 'delivery' &&
                      (value == null || !(cart.deliveryZone?.isActive ?? false))
                  ? 'اختر منطقة توصيل نشطة'
                  : null,
            ),
            if (zones.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'لا توجد مناطق توصيل نشطة. راجع المدير لإضافتها.',
                  style: TextStyle(fontSize: 11.5, color: PosColors.danger),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'رسوم التوصيل',
                    style: TextStyle(
                      color: PosColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${formatCents(cart.deliveryFeeCents)} ج.م',
                  style: const TextStyle(
                    color: PosColors.brand,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          const FieldLabel('ملاحظات على الطلب'),
          TextField(
            controller: _notes,
            maxLength: 1000,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'اختياري',
              counterText: '',
            ),
            onChanged: (value) {
              cart.setDetail('notes', value);
              _customerEdited();
            },
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
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: PosColors.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cart.orderType == 'dine_in'
                        ? 'رقم الطاولة مطلوب لإتمام البيع في الصالة.'
                        : cart.orderType == 'delivery'
                        ? 'أدخل الهاتف لجلب بيانات العميل، ثم اختر منطقة التوصيل. يتم حفظ البيانات والرسوم تلقائياً.'
                        : 'تيك أواي لا يحتاج بيانات إضافية.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: PosColors.muted,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () {
              if (!widget.requireCompletion ||
                  _formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            child: Text(widget.requireCompletion ? 'حفظ ومتابعة الدفع' : 'تم'),
          ),
        ],
      ),
    );
  }
}
