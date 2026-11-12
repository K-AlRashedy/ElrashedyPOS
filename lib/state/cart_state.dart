import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/money.dart';
import '../core/models.dart';
import '../core/ticket.dart';
import 'app_state.dart';

/// The open ticket: lines, order details and the per-branch durable draft.
class CartState extends ChangeNotifier {
  CartState(this._app);

  final AppState _app;
  static const _uuid = Uuid();
  Timer? _persistTimer;

  final List<TicketLine> lines = [];
  String draftId = _uuid.v4();
  String orderType = 'takeaway';
  String table = '';
  String customer = '';
  String phone = '';
  String address = '';
  String notes = '';
  String payment = 'cash';
  String tendered = '';
  bool saving = false;

  int get totalCents => lines.fold(0, (sum, line) => sum + line.subtotalCents);
  String get total => formatCents(totalCents);
  double get itemCount =>
      lines.fold(0.0, (sum, line) => sum + (double.tryParse(line.qty) ?? 0));
  bool get isEmpty => lines.isEmpty;
  double? get tenderedValue => double.tryParse(tendered.trim());
  bool get canSell =>
      lines.isNotEmpty && !saving && !_app.shiftClosed && _app.branchId != null;

  int get changeCents {
    final value = tenderedValue;
    if (value == null || !value.isFinite) return 0;
    final change = (value * 100).round() - totalCents;
    return change < 0 ? 0 : change;
  }

  String get orderSummary => switch (orderType) {
    'dine_in' => table.trim().isEmpty ? 'صالة' : 'صالة · طاولة $table',
    'delivery' => 'دليفري',
    _ => 'تيك أواي',
  };

  bool add(PosProduct product, {String quantity = '1'}) {
    if (!isValidQty(quantity)) {
      _app.tell(
        'الكمية يجب أن تكون بين 0.001 و 1000 وبثلاث خانات عشرية كحد أقصى.',
        isError: true,
      );
      return false;
    }
    final amount = parseQty(quantity);
    final index = lines.indexWhere(
      (line) => line.productId == product.id && line.price == product.price,
    );
    if (index >= 0) {
      final next = parseQty(lines[index].qty) + amount;
      if (next > 1000) {
        _app.tell('لا يمكن أن تتجاوز كمية الصنف 1000.', isError: true);
        return false;
      }
      lines[index].qty = formatQty(next);
    } else {
      lines.add(
        TicketLine(
          productId: product.id,
          name: product.name,
          price: product.price,
          qty: formatQty(amount),
        ),
      );
    }
    _changed();
    return true;
  }

  void increment(int index) {
    lines[index].qty = formatQty(
      (parseQty(lines[index].qty) + 1).clamp(1, 1000),
    );
    _changed();
  }

  void decrement(int index) {
    final next = parseQty(lines[index].qty) - 1;
    if (next <= 0) {
      lines.removeAt(index);
    } else {
      lines[index].qty = formatQty(next);
    }
    _changed();
  }

  void removeAt(int index) {
    lines.removeAt(index);
    _changed();
  }

  void setQty(int index, String value) {
    if (!isValidQty(value)) {
      _app.tell(
        'الكمية يجب أن تكون بين 0.001 و 1000 وبثلاث خانات عشرية كحد أقصى.',
        isError: true,
      );
      notifyListeners();
      return;
    }
    lines[index].qty = formatQty(parseQty(value));
    _changed();
  }

  void setNote(int index, String value) {
    lines[index].note = value.trim();
    _changed();
  }

  void setDetail(String key, String value) {
    switch (key) {
      case 'type':
        orderType = value;
      case 'table':
        table = value;
      case 'customer':
        customer = value;
      case 'phone':
        phone = value;
      case 'address':
        address = value;
      case 'notes':
        notes = value;
      case 'payment':
        payment = value;
      case 'tendered':
        tendered = value;
      default:
        return;
    }
    _changed();
  }

  void clear() {
    lines.clear();
    _changed();
  }

  void reset() {
    lines.clear();
    draftId = _uuid.v4();
    orderType = 'takeaway';
    table = '';
    customer = '';
    phone = '';
    address = '';
    notes = '';
    payment = 'cash';
    tendered = '';
    unawaited(persistDraft());
    notifyListeners();
  }

  void _changed() {
    _schedulePersist();
    notifyListeners();
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 250), persistDraft);
  }

  String get _draftKey => 'draft:${_app.user?.id ?? 0}:${_app.branchId ?? 0}';

  Future<void> persistDraft() async {
    _persistTimer?.cancel();
    await _app.db.saveDraft(_draftKey, {
      'clientId': draftId,
      'lines': lines.map((line) => line.toJson()).toList(),
      'fields': {
        'type': orderType,
        'table': table,
        'customer': customer,
        'phone': phone,
        'address': address,
        'notes': notes,
        'payment': payment,
        'tendered': tendered,
      },
    });
  }

  Future<void> loadDraft() async {
    final draft = await _app.db.readDraft(_draftKey);
    final fields = draft?['fields'] as Map<String, dynamic>? ?? {};
    lines
      ..clear()
      ..addAll(
        ((draft?['lines'] as List<dynamic>?) ?? []).map(
          (item) => TicketLine.fromJson(item as Map<String, dynamic>),
        ),
      );
    draftId = draft?['clientId'] as String? ?? _uuid.v4();
    orderType = fields['type'] as String? ?? 'takeaway';
    table = fields['table'] as String? ?? '';
    customer = fields['customer'] as String? ?? '';
    phone = fields['phone'] as String? ?? '';
    address = fields['address'] as String? ?? '';
    notes = fields['notes'] as String? ?? '';
    payment = fields['payment'] as String? ?? 'cash';
    tendered = fields['tendered'] as String? ?? '';
    notifyListeners();
  }

  /// Same acceptance rules as ``factory.views.pos_sync``, checked before saving.
  String? validate() {
    if (lines.isEmpty) return 'الطلب فارغ — اختر الأصناف من القائمة.';
    if (lines.length > 100) return 'الطلب يحتوي على عدد كبير جداً من الأصناف.';
    for (final line in lines) {
      if (!isValidQty(line.qty)) return 'راجع الأصناف والكميات.';
    }
    if (orderType == 'dine_in' && table.trim().isEmpty) {
      return 'أدخل رقم الطاولة.';
    }
    if (orderType == 'delivery' && phone.trim().isEmpty) {
      return 'أدخل هاتف التوصيل.';
    }
    if (orderType == 'delivery' && address.trim().isEmpty) {
      return 'أدخل عنوان التوصيل.';
    }
    if (payment == 'cash' && tendered.trim().isNotEmpty) {
      final value = tenderedValue;
      if (value == null || !value.isFinite) {
        return 'أدخل مبلغاً مدفوعاً صحيحاً.';
      }
      if ((value * 100).round() < totalCents) {
        return 'المبلغ المدفوع أقل من إجمالي الطلب.';
      }
    }
    return null;
  }

  Ticket buildTicket() {
    final user = _app.user!;
    final branch = _app.branch!;
    final value = tenderedValue;
    return Ticket(
      clientId: draftId,
      userId: user.id,
      branchId: branch.id,
      branchName: branch.name,
      orderType: orderType,
      payment: payment,
      placedAt: DateTime.now(),
      lines: lines.map((line) => line.copy()).toList(),
      table: orderType == 'dine_in' ? table.trim() : '',
      customer: orderType == 'delivery' ? customer.trim() : '',
      phone: orderType == 'delivery' ? phone.trim() : '',
      address: orderType == 'delivery' ? address.trim() : '',
      notes: notes.trim(),
      tendered: value == null ? null : formatCents((value * 100).round()),
    );
  }

  /// Saves locally first, then syncs and prints — the sale survives a dead network.
  Future<Ticket?> checkout(String paymentMethod) async {
    if (saving) return null;
    if (_app.shiftClosed) {
      _app.tell(
        'تم تقفيل هذه الوردية بالفعل. اختر فرعاً أو وردية مفتوحة للمتابعة.',
        isError: true,
      );
      return null;
    }
    if (_app.user == null || _app.branch == null) {
      _app.tell('لا يوجد فرع مصرح به لهذا المستخدم.', isError: true);
      return null;
    }
    payment = paymentMethod;
    final problem = validate();
    if (problem != null) {
      _app.tell(problem, isError: true);
      notifyListeners();
      return null;
    }
    saving = true;
    notifyListeners();
    try {
      final ticket = buildTicket();
      await _app.db.saveTicket(ticket);
      reset();
      await _app.refreshPending();

      // Payment should produce the receipt immediately. Do not make a cashier
      // wait for a slow or unavailable server before the print job starts.
      await _app.printer.printTicket(ticket, kitchen: false, force: true);
      await _app.printer.printTicket(ticket, kitchen: true);

      await _app.syncNow();
      final stored = await _app.db.ticketByClientId(ticket.clientId) ?? ticket;
      _app.tell(
        stored.synced
            ? 'تم حفظ البيع رقم ${stored.serverId} ومزامنته.'
            : 'تم حفظ الطلب على الجهاز. سيُزامَن تلقائياً عند عودة الاتصال.',
      );
      return stored;
    } catch (error) {
      _app.tell(
        'تعذر حفظ الطلب على الجهاز. راجع مساحة التخزين وقائمة الطلبات السابقة. $error',
        isError: true,
      );
      return null;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    super.dispose();
  }
}
