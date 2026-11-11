import 'dart:convert';

import 'package:elrashedy_pos/core/models.dart';
import 'package:elrashedy_pos/core/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bootstrap parses the payload the desktop API returns', () {
    final data = Bootstrap.fromJson({
      'user': {
        'id': 7,
        'username': 'cashier',
        'display_name': 'أحمد',
        'is_superuser': false,
        'employee_id': 12,
        'branch_name': 'الفرع الرئيسي',
        'permissions': {'confirm_selling_order': true, 'add_any_selling_order': false},
      },
      'branches': [
        {'id': 3, 'name': 'الفرع الرئيسي'},
      ],
      'products': [
        {'id': 11, 'name': 'شاورما', 'price': '45.50', 'category_id': 'section-2', 'category': 'سندوتشات'},
      ],
      'expense_accounts': {
        'main': [
          {'id': 1, 'name': 'مصروفات تشغيل'},
        ],
        'sub': [
          {'id': 2, 'name': 'كهرباء', 'parent_id': 1},
        ],
      },
      'employees': [
        {'id': 12, 'name': 'أحمد', 'branch_id': 3},
      ],
      'suppliers': [
        {'id': 5, 'name': 'مورد الخضار'},
      ],
      'shifts': [
        {'value': 'day', 'label': 'صباحية'},
        {'value': 'night', 'label': 'مسائية'},
        {'value': 'container', 'label': 'كونتنر'},
      ],
      'order_types': [
        {'value': 'dine_in', 'label': 'صالة'},
      ],
      'payment_methods': [
        {'value': 'cash', 'label': 'نقدي'},
      ],
      'operational_date': '2026-03-10',
    });

    expect(data.user.displayName, 'أحمد');
    expect(data.user.permissions['confirm_selling_order'], isTrue);
    expect(data.branches.single.id, 3);
    expect(data.products.single.categoryIds, ['section-2']);
    expect(data.products.single.isMenuSection, isTrue);
    expect(data.subAccounts.single.parentId, 1);
    expect(data.shifts.map((shift) => shift.value), ['day', 'night', 'container']);
    expect(data.operationalDate, '2026-03-10');
  });

  test('a product without categories still lands in a fallback bucket', () {
    final product = PosProduct.fromJson({'id': 1, 'name': 'صنف', 'price': '10.00'});
    expect(product.categories.single.name, 'أصناف أخرى');
    expect(product.isMenuSection, isFalse);
  });

  test('printer settings survive a storage round trip', () {
    final settings = AppSettings(
      serverUrl: 'https://app.herokuapp.com',
      deviceName: 'كاشير 1',
      printers: PrinterSettings(
        customer: PrinterConfig(
          transport: PrinterTransport.network,
          host: '192.168.1.50',
          port: 9100,
          width: PaperWidth.mm80,
          kickDrawer: true,
        ),
        kitchen: PrinterConfig(
          transport: PrinterTransport.usb,
          printerName: 'XP-80C',
          width: PaperWidth.mm58,
        ),
        autoPrintKitchen: true,
        receiptHeader: 'الرشيدي',
        receiptFooter: 'شكراً',
      ),
    );
    final restored = AppSettings.fromJson(jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>);
    expect(restored.serverUrl, 'https://app.herokuapp.com');
    expect(restored.deviceName, 'كاشير 1');
    expect(restored.printers.customer.host, '192.168.1.50');
    expect(restored.printers.customer.kickDrawer, isTrue);
    expect(restored.printers.customer.width.dots, 576);
    expect(restored.printers.kitchen.transport, PrinterTransport.usb);
    expect(restored.printers.kitchen.printerName, 'XP-80C');
    expect(restored.printers.kitchen.width.dots, 384);
    expect(restored.printers.autoPrintKitchen, isTrue);
    expect(restored.printers.autoPrintCustomer, isTrue);
    expect(restored.printers.receiptFooter, 'شكراً');
  });

  test('an unconfigured printer is reported as incomplete', () {
    expect(PrinterConfig().isConfigured, isFalse);
    expect(PrinterConfig(host: '192.168.1.50').isConfigured, isTrue);
    expect(PrinterConfig(transport: PrinterTransport.usb).isConfigured, isFalse);
    expect(PrinterConfig(transport: PrinterTransport.usb, printerName: 'XP-80C').describe, 'XP-80C');
  });

  test('the kitchen printer starts disabled so nothing prints by accident', () {
    final settings = PrinterSettings();
    expect(settings.customer.enabled, isTrue);
    expect(settings.kitchen.enabled, isFalse);
    expect(settings.autoPrintCustomer, isTrue);
    expect(settings.autoPrintKitchen, isFalse);
  });
}