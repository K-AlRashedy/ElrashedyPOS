import 'money.dart';

class TicketLine {
  TicketLine({
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
    this.note = '',
  });

  final int productId;
  final String name;
  final String price;
  String qty;
  String note;

  int get subtotalCents => lineTotalCents(price, qty);

  Map<String, dynamic> toJson() => {
        'id': productId,
        'name': name,
        'price': price,
        'qty': qty,
        'note': note,
      };

  factory TicketLine.fromJson(Map<String, dynamic> json) => TicketLine(
        productId: (json['id'] as num).toInt(),
        name: json['name'] as String,
        price: json['price'].toString(),
        qty: json['qty'].toString(),
        note: json['note'] as String? ?? '',
      );

  TicketLine copy() => TicketLine(productId: productId, name: name, price: price, qty: qty, note: note);
}

class Ticket {
  Ticket({
    required this.clientId,
    required this.userId,
    required this.branchId,
    required this.branchName,
    required this.orderType,
    required this.payment,
    required this.placedAt,
    required this.lines,
    this.table = '',
    this.customer = '',
    this.phone = '',
    this.address = '',
    this.notes = '',
    String? tendered,
    this.synced = false,
    this.serverId,
    this.error,
    this.attempts = 0,
  }) : tendered = tendered ?? formatCents(lines.fold(0, (sum, line) => sum + line.subtotalCents));

  final String clientId;
  final int userId;
  final int branchId;
  final String branchName;
  final String orderType;
  final String payment;
  final DateTime placedAt;
  final List<TicketLine> lines;
  final String table;
  final String customer;
  final String phone;
  final String address;
  final String notes;
  final String tendered;
  bool synced;
  int? serverId;
  String? error;
  int attempts;

  int get totalCents => lines.fold(0, (sum, line) => sum + line.subtotalCents);
  String get total => formatCents(totalCents);
  int get changeCents => toCents(tendered) - totalCents;
  String get change => formatCents(changeCents < 0 ? 0 : changeCents);
  double get itemCount => lines.fold(0.0, (sum, line) => sum + (double.tryParse(line.qty) ?? 0));

  /// Payload accepted by ``factory.views.pos_sync`` — identical to the browser's.
  Map<String, dynamic> toSyncPayload() => {
        'client_id': clientId,
        'branch': branchId,
        'order_type': orderType,
        'payment': payment,
        'tendered': tendered,
        'total': total,
        'placed_at': placedAt.toUtc().toIso8601String(),
        'table': table,
        'customer': customer,
        'phone': phone,
        'address': address,
        'notes': notes,
        'lines': lines
            .map((line) => {'id': line.productId, 'qty': line.qty, 'price': line.price, 'note': line.note})
            .toList(),
      };

  Map<String, dynamic> toStorageJson() => {
        ...toSyncPayload(),
        // The sync payload omits names; the local copy needs them for receipts.
        'lines': lines.map((line) => line.toJson()).toList(),
        'user': userId,
        'branchName': branchName,
        'synced': synced,
        'serverId': serverId,
        'error': error,
        'attempts': attempts,
      };

  factory Ticket.fromStorageJson(Map<String, dynamic> json) => Ticket(
        clientId: json['client_id'] as String,
        userId: (json['user'] as num).toInt(),
        branchId: (json['branch'] as num).toInt(),
        branchName: json['branchName'] as String? ?? '',
        orderType: json['order_type'] as String,
        payment: json['payment'] as String,
        placedAt: DateTime.parse(json['placed_at'] as String),
        lines: (json['lines'] as List<dynamic>)
            .map((item) => TicketLine.fromJson(item as Map<String, dynamic>))
            .toList(),
        table: json['table'] as String? ?? '',
        customer: json['customer'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        address: json['address'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        tendered: json['tendered']?.toString(),
        synced: json['synced'] == true,
        serverId: json['serverId'] == null ? null : (json['serverId'] as num).toInt(),
        error: json['error'] as String?,
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      );
}