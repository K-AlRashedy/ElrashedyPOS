import 'dart:convert';

import 'package:elrashedy_pos/core/api_client.dart';
import 'package:elrashedy_pos/core/ticket.dart';
import 'package:elrashedy_pos/printing/receipt.dart';
import 'package:flutter_test/flutter_test.dart';

Ticket ticket({
  bool synced = false,
  String payment = 'cash',
  String orderType = 'delivery',
}) => Ticket(
  clientId: '3f2b8c1e-9a4b-4c5d-8e9f-000000000001',
  userId: 7,
  branchId: 3,
  branchName: 'الفرع الرئيسي',
  orderType: orderType,
  payment: payment,
  placedAt: DateTime(2026, 3, 10, 14, 30),
  customer: 'أحمد',
  phone: '01000000000',
  address: 'شارع الجمهورية',
  tendered: '100.00',
  synced: synced,
  serverId: synced ? 4321 : null,
  lines: [
    TicketLine(
      productId: 11,
      name: 'شاورما',
      price: '45.50',
      qty: '2',
      note: 'بدون بصل',
    ),
    TicketLine(productId: 12, name: 'مياه', price: '5.00', qty: '1'),
  ],
);

String joined(List<ReceiptElement> elements) =>
    elements.map((element) => element.text).join('\n');

void main() {
  test('the customer receipt carries branding, totals and the sale number', () {
    final text = joined(
      buildCustomerReceipt(
        ticket(synced: true),
        header: 'الرشيدي',
        footer: 'شكراً لزيارتكم',
      ),
    );
    expect(text, contains('الرشيدي'));
    expect(text, contains('الفرع الرئيسي'));
    expect(text, contains('دليفري'));
    expect(text, contains('أحمد'));
    expect(text, contains('01000000000'));
    expect(text, contains('شارع الجمهورية'));
    expect(text, contains('2 × شاورما'));
    expect(text, contains('الإجمالي: 96.00 ج.م'));
    expect(text, contains('الدفع: نقدي'));
    expect(text, contains('المدفوع: 100.00 ج.م'));
    expect(text, contains('المتبقي للعميل: 4.00 ج.م'));
    expect(text, contains('رقم البيع: 4321'));
    expect(text, contains('شكراً لزيارتكم'));
    expect(text, contains('ملاحظة: بدون بصل'));
  });

  test('original receipts carry the logo while reprints omit branding', () {
    final logo = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2nWQAAAAASUVORK5CYII=',
    );
    final original = buildCustomerReceipt(
      ticket(),
      header: 'الرشيدي',
      footer: '',
      logo: logo,
    );
    final reprint = buildCustomerReceipt(
      ticket(),
      header: 'الرشيدي',
      footer: '',
      logo: logo,
      isReprint: true,
    );

    expect(original.any((element) => element.isImage), isTrue);
    expect(reprint.any((element) => element.isImage), isFalse);
    expect(joined(reprint), contains('إعادة طباعة'));
    expect(joined(reprint), isNot(contains('الرشيدي')));
  });

  test('the shift summary groups items and includes every payment method', () {
    const summary = ShiftSummary(
      operationalDate: '2026-03-10',
      sales: '100.00',
      expenses: '10.00',
      advances: '20.00',
      suppliers: '30.00',
      closed: true,
      cashInId: 55,
      branchName: 'الفرع الرئيسي',
      cashierName: 'أحمد',
      shiftLabel: 'صباحية',
      orderCount: 2,
      realAmount: '100.00',
      cashSales: '100.00',
      netCash: '40.00',
      categories: [
        ShiftCategorySummary(
          id: 'section-1',
          name: 'سندوتشات',
          total: '100.00',
          items: [
            ShiftItemSummary(
              id: '11',
              name: 'شاورما',
              quantity: '2',
              amount: '100.00',
            ),
          ],
        ),
      ],
      payments: [
        ShiftPaymentSummary(value: 'cash', label: 'نقدي', amount: '100.00'),
        ShiftPaymentSummary(value: 'visa', label: 'Visa', amount: '0.00'),
      ],
    );
    final text = joined(
      buildShiftSummaryReceipt(summary, header: 'الرشيدي', footer: ''),
    );

    expect(text, contains('ملخص مبيعات الوردية'));
    expect(text, contains('الكاشير: أحمد'));
    expect(text, contains('عدد الطلبات: 2'));
    expect(text, contains('سندوتشات'));
    expect(text, contains('شاورما × 2 = 100.00 ج.م'));
    expect(text, contains('نقدي: 100.00 ج.م'));
    expect(text, contains('Visa: 0.00 ج.م'));
    expect(text, contains('صافي الكاش المسلّم للخزنة: 40.00 ج.م'));
    expect(text, contains('إجمالي الوردية: 100.00 ج.م'));
  });

  test('an unsynced ticket is clearly marked as local only', () {
    final text = joined(
      buildCustomerReceipt(ticket(), header: 'الرشيدي', footer: ''),
    );
    expect(text, contains('محفوظ محلياً — لم تتم المزامنة'));
    expect(text, isNot(contains('رقم البيع')));
  });

  test('non-cash payments hide the tendered and change lines', () {
    final text = joined(
      buildCustomerReceipt(
        ticket(payment: 'visa'),
        header: 'الرشيدي',
        footer: '',
      ),
    );
    expect(text, contains('الدفع: Visa'));
    expect(text, isNot(contains('المدفوع')));
    expect(text, isNot(contains('المتبقي للعميل')));
  });

  test('the kitchen ticket shows items and notes but no money', () {
    final text = joined(buildKitchenReceipt(ticket(orderType: 'dine_in')));
    expect(text, contains('طلب المطبخ'));
    expect(text, contains('2 × شاورما'));
    expect(text, contains('** بدون بصل'));
    expect(text, isNot(contains('ج.م')));
    expect(text, isNot(contains('الإجمالي')));
  });

  test('ticket id and time are shortened for the receipt header', () {
    expect(shortTicketId('3f2b8c1e-9a4b-4c5d-8e9f-000000000001'), '3F2B8C1E');
    expect(formatTicketTime(DateTime(2026, 3, 10, 14, 5)), '2026/03/10 14:05');
  });

  test('the test receipt exercises Arabic shaping and both digit sets', () {
    final text = joined(buildTestReceipt('192.168.1.50:9100'));
    expect(text, contains('طباعة تجريبية'));
    expect(text, contains('192.168.1.50:9100'));
    expect(text, contains('١٢٣ 123'));
  });
}
