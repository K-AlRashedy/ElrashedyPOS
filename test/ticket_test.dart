import 'dart:convert';

import 'package:elrashedy_pos/core/ticket.dart';
import 'package:flutter_test/flutter_test.dart';

Ticket sampleTicket({String payment = 'cash', String? tendered, String orderType = 'takeaway'}) => Ticket(
      clientId: '3f2b8c1e-0000-4000-8000-000000000001',
      userId: 7,
      branchId: 3,
      branchName: 'الفرع الرئيسي',
      orderType: orderType,
      payment: payment,
      placedAt: DateTime.utc(2026, 3, 10, 14, 30),
      tendered: tendered,
      table: orderType == 'dine_in' ? '12' : '',
      lines: [
        TicketLine(productId: 11, name: 'شاورما', price: '45.50', qty: '2'),
        TicketLine(productId: 12, name: 'مياه', price: '5.00', qty: '1.5', note: 'باردة'),
      ],
    );

void main() {
  test('total is the sum of integer-cent line totals', () {
    final ticket = sampleTicket();
    expect(ticket.totalCents, 9100 + 750);
    expect(ticket.total, '98.50');
    expect(ticket.itemCount, 3.5);
  });

  test('tendered defaults to the total, like the browser terminal', () {
    expect(sampleTicket().tendered, '98.50');
    expect(sampleTicket().changeCents, 0);
  });

  test('cash change is computed from the tendered amount', () {
    final ticket = sampleTicket(tendered: '100.00');
    expect(ticket.changeCents, 150);
    expect(ticket.change, '1.50');
  });

  test('sync payload carries exactly the keys pos_sync reads', () {
    final payload = sampleTicket(orderType: 'dine_in').toSyncPayload();
    expect(payload.keys.toSet(), {
      'client_id', 'branch', 'order_type', 'payment', 'tendered', 'total',
      'placed_at', 'table', 'customer', 'phone', 'address', 'notes', 'lines',
    });
    expect(payload['branch'], 3);
    expect(payload['order_type'], 'dine_in');
    expect(payload['table'], '12');
    expect(payload['total'], '98.50');
    expect(payload['placed_at'], '2026-03-10T14:30:00.000Z');
    expect((payload['lines'] as List).first.keys.toSet(), {'id', 'qty', 'price', 'note'});
    expect((payload['lines'] as List).first['id'], 11);
  });

  test('local time is converted to UTC before it reaches the server', () {
    final ticket = Ticket(
      clientId: '3f2b8c1e-0000-4000-8000-000000000002',
      userId: 7,
      branchId: 3,
      branchName: 'فرع',
      orderType: 'takeaway',
      payment: 'cash',
      placedAt: DateTime(2026, 3, 10, 16, 30),
      lines: [TicketLine(productId: 1, name: 'صنف', price: '10.00', qty: '1')],
    );
    expect(ticket.toSyncPayload()['placed_at'], ticket.placedAt.toUtc().toIso8601String());
  });

  test('storage round trip preserves the outbox state', () {
    final ticket = sampleTicket(payment: 'visa')
      ..synced = true
      ..serverId = 4321
      ..attempts = 2;
    final restored = Ticket.fromStorageJson(jsonDecode(jsonEncode(ticket.toStorageJson())) as Map<String, dynamic>);
    expect(restored.clientId, ticket.clientId);
    expect(restored.userId, 7);
    expect(restored.branchName, 'الفرع الرئيسي');
    expect(restored.synced, isTrue);
    expect(restored.serverId, 4321);
    expect(restored.attempts, 2);
    expect(restored.total, '98.50');
    expect(restored.lines.last.note, 'باردة');
    expect(restored.toSyncPayload(), ticket.toSyncPayload());
  });

  test('a failed sync keeps its error message for the cashier', () {
    final ticket = sampleTicket()..error = 'سعر الصنف تغير. راجع المدير.';
    final restored = Ticket.fromStorageJson(jsonDecode(jsonEncode(ticket.toStorageJson())) as Map<String, dynamic>);
    expect(restored.synced, isFalse);
    expect(restored.error, 'سعر الصنف تغير. راجع المدير.');
  });
}