import 'dart:typed_data';

import 'package:elrashedy_pos/core/api_client.dart';
import 'package:elrashedy_pos/core/settings.dart';
import 'package:elrashedy_pos/core/ticket.dart';
import 'package:elrashedy_pos/printing/printer_service.dart';
import 'package:elrashedy_pos/state/printer_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingPrinterService extends PrinterService {
  int ticketCalls = 0;
  int summaryCalls = 0;
  Uint8List? lastLogo;
  bool lastReprint = false;

  @override
  Future<void> printTicket(
    dynamic ticket,
    PrinterConfig config, {
    required bool kitchen,
    required String header,
    required String footer,
    Uint8List? logo,
    bool isReprint = false,
  }) async {
    ticketCalls++;
    lastLogo = logo;
    lastReprint = isReprint;
  }

  @override
  Future<void> printShiftSummary(
    ShiftSummary summary,
    PrinterConfig config, {
    required String header,
    required String footer,
    Uint8List? logo,
  }) async {
    summaryCalls++;
    lastLogo = logo;
  }
}

Ticket _ticket() => Ticket(
  clientId: 'test-ticket',
  userId: 1,
  branchId: 2,
  branchName: 'الفرع',
  orderType: 'takeaway',
  payment: 'visa',
  placedAt: DateTime(2026),
  lines: [TicketLine(productId: 3, name: 'صنف', price: '10.00', qty: '15')],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a forced customer receipt bypasses the auto-print preference',
    () async {
      final service = _RecordingPrinterService();
      final state = PrinterState(
        PrinterSettings(autoPrintCustomer: false),
        (_) async {},
        (_, _) {},
        service: service,
      );

      expect(await state.printTicket(_ticket(), kitchen: false), isFalse);
      expect(service.ticketCalls, 0);

      expect(
        await state.printTicket(_ticket(), kitchen: false, force: true),
        isTrue,
      );
      expect(service.ticketCalls, 1);
      expect(service.lastLogo, isNotNull);

      expect(
        await state.printTicket(
          _ticket(),
          kitchen: false,
          force: true,
          isReprint: true,
        ),
        isTrue,
      );
      expect(service.ticketCalls, 2);
      expect(service.lastReprint, isTrue);
      expect(service.lastLogo, isNull);
    },
  );

  test(
    'the consolidated shift summary always carries the receipt logo',
    () async {
      final service = _RecordingPrinterService();
      final state = PrinterState(
        PrinterSettings(),
        (_) async {},
        (_, _) {},
        service: service,
      );
      const summary = ShiftSummary(
        operationalDate: '2026-03-10',
        sales: '100.00',
        expenses: '10.00',
        advances: '20.00',
        suppliers: '30.00',
        closed: true,
        cashInId: 55,
      );

      expect(await state.printShiftSummary(summary), isTrue);
      expect(service.summaryCalls, 1);
      expect(service.lastLogo, isNotNull);
    },
  );
}
