import 'package:flutter/foundation.dart';

import '../core/settings.dart';
import '../core/ticket.dart';
import '../printing/printer_service.dart';
import '../printing/spooler.dart';

/// Printer configuration plus every print job the terminal can start.
class PrinterState extends ChangeNotifier {
  PrinterState(
    this.settings,
    this._onSave,
    this._message, {
    PrinterService? service,
  }) : _service = service ?? PrinterService();

  PrinterSettings settings;
  final Future<void> Function(PrinterSettings) _onSave;
  final void Function(String message, bool isError) _message;
  final PrinterService _service;

  bool busy = false;
  String? error;

  Future<void> save(PrinterSettings next) async {
    settings = next;
    await _onSave(next);
    error = null;
    _message('تم حفظ إعدادات الطابعات.', false);
    notifyListeners();
  }

  Future<List<String>> listPrinters() => _service.listPrinters();

  /// Auto-print after checkout. Manual reprints pass [force].
  Future<bool> printTicket(Ticket ticket, {required bool kitchen, bool force = false}) {
    final config = kitchen ? settings.kitchen : settings.customer;
    final auto = kitchen ? settings.autoPrintKitchen : settings.autoPrintCustomer;
    if (!force && !auto) return Future.value(false);
    if (!config.enabled) {
      if (force) _message('الطابعة معطلة. فعّلها من شاشة الطابعات.', true);
      return Future.value(false);
    }
    return _run(() => _service.printTicket(
          ticket,
          config,
          kitchen: kitchen,
          header: settings.receiptHeader,
          footer: settings.receiptFooter,
        ));
  }

  Future<bool> testPrint(PrinterConfig config) => _run(() => _service.testPrint(config));

  Future<bool> openDrawer() {
    final config = settings.customer;
    if (!config.enabled || !config.isConfigured) {
      _message('أكمل إعدادات طابعة الإيصالات أولاً لفتح الدرج.', true);
      return Future.value(false);
    }
    return _run(() => _service.openDrawer(config));
  }

  Future<bool> _run(Future<void> Function() job) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await job();
      _message('تمت الطباعة.', false);
      return true;
    } on PrintException catch (failure) {
      error = failure.message;
      _message(failure.message, true);
      return false;
    } catch (failure) {
      error = 'تعذر الطباعة: $failure';
      _message(error!, true);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}