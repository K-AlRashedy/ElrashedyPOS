import 'package:elrashedy_pos/core/settings.dart';
import 'package:elrashedy_pos/core/ticket.dart';
import 'package:elrashedy_pos/printing/printer_service.dart';
import 'package:elrashedy_pos/state/printer_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingPrinterService extends PrinterService {
  int ticketCalls = 0;

  @override
  Future<void> printTicket(
    dynamic ticket,
    PrinterConfig config, {
    required bool kitchen,
    required String header,
    required String footer,
  }) async {
    ticketCalls++;
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
    },
  );
}
