import 'package:elrashedy_pos/core/ticket.dart';
import 'package:elrashedy_pos/printing/raster.dart';
import 'package:elrashedy_pos/printing/receipt.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo.ttf'));
    await loader.load();
  });

  test('an Arabic receipt renders to a 1-bit raster of the requested width', () async {
    final ticket = Ticket(
      clientId: '3f2b8c1e-0000-4000-8000-000000000001',
      userId: 7,
      branchId: 3,
      branchName: 'الفرع الرئيسي',
      orderType: 'takeaway',
      payment: 'cash',
      placedAt: DateTime(2026, 3, 10, 14, 30),
      lines: [TicketLine(productId: 11, name: 'شاورما فراخ', price: '45.50', qty: '2')],
    );
    final raster = await renderReceipt(
      buildCustomerReceipt(ticket, header: 'الرشيدي', footer: 'شكراً لزيارتكم'),
      widthDots: 576,
    );
    expect(raster.widthDots, 576);
    expect(raster.bytesPerRow, 72);
    expect(raster.packed.length, 72 * raster.height);
    expect(raster.height, greaterThan(100));

    var ink = 0;
    for (final byte in raster.packed) {
      ink += byte.bitCount();
    }
    expect(ink, greaterThan(500));
  });

  test('58mm paper produces a narrower raster than 80mm', () async {
    const elements = [ReceiptElement.text('الرشيدي', align: ReceiptAlign.center, size: ReceiptSize.huge)];
    final narrow = await renderReceipt(elements, widthDots: 384);
    final wide = await renderReceipt(elements, widthDots: 576);
    expect(narrow.bytesPerRow, 48);
    expect(wide.bytesPerRow, 72);
    expect(narrow.packed.length, lessThan(wide.packed.length));
  });

  test('the PDF fallback produces a real PNG', () async {
    final png = await renderReceiptPng(buildTestReceipt('XP-80C'), widthDots: 576);
    expect(png.length, greaterThan(1000));
    expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  });
}

extension on int {
  int bitCount() {
    var value = this;
    var count = 0;
    while (value != 0) {
      count += value & 1;
      value >>= 1;
    }
    return count;
  }
}