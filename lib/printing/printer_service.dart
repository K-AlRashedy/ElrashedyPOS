import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/settings.dart';
import 'escpos.dart';
import 'raster.dart';
import 'receipt.dart';
import 'spooler.dart';

class PrinterService {
  PrinterService([this._spooler]);

  WindowsSpooler? _spooler;

  Future<List<String>> listPrinters() async {
    try {
      final printers = await Printing.listPrinters();
      return printers.map((printer) => printer.name).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> printElements(
    List<ReceiptElement> elements,
    PrinterConfig config, {
    String docName = 'إيصال الرشيدي',
  }) async {
    if (!config.enabled) return;
    if (!config.isConfigured) {
      throw PrintException('إعدادات الطابعة غير مكتملة. افتح شاشة الطابعات وأكمل البيانات.');
    }
    switch (config.transport) {
      case PrinterTransport.network:
        final raster = await renderReceipt(elements, widthDots: config.width.dots);
        await _sendNetwork(config, buildReceiptBytes(raster, kickDrawer: config.kickDrawer));
      case PrinterTransport.usb:
        final raster = await renderReceipt(elements, widthDots: config.width.dots);
        _spooler ??= WindowsSpooler();
        _spooler!.send(config.printerName, buildReceiptBytes(raster, kickDrawer: config.kickDrawer), docName: docName);
      case PrinterTransport.pdf:
        await _sendPdf(elements, config, docName: docName);
    }
  }

  Future<void> printTicket(
    dynamic ticket,
    PrinterConfig config, {
    required bool kitchen,
    required String header,
    required String footer,
  }) async {
    final elements = kitchen
        ? buildKitchenReceipt(ticket)
        : buildCustomerReceipt(ticket, header: header, footer: footer);
    await printElements(elements, config, docName: kitchen ? 'شيك المطبخ' : 'إيصال العميل');
  }

  Future<void> testPrint(PrinterConfig config) =>
      printElements(buildTestReceipt(config.describe), config, docName: 'طباعة تجريبية');

  Future<void> openDrawer(PrinterConfig config) async {
    final builder = EscPosBuilder()
      ..init()
      ..kickDrawer();
    final bytes = builder.toBytes();
    switch (config.transport) {
      case PrinterTransport.network:
        await _sendNetwork(config, bytes);
      case PrinterTransport.usb:
        _spooler ??= WindowsSpooler();
        _spooler!.send(config.printerName, bytes, docName: 'فتح الدرج');
      case PrinterTransport.pdf:
        throw PrintException('فتح الدرج غير متاح عبر PDF. استخدم طابعة إيصالات شبكية أو USB.');
    }
  }

  Future<void> _sendNetwork(PrinterConfig config, Uint8List bytes) async {
    Socket? socket;
    try {
      socket = await Socket.connect(config.host.trim(), config.port, timeout: const Duration(seconds: 6));
      socket.add(bytes);
      await socket.flush().timeout(const Duration(seconds: 10));
      await socket.close().timeout(const Duration(seconds: 5));
    } on SocketException catch (error) {
      throw PrintException('تعذر الوصول إلى الطابعة الشبكية ${config.host}:${config.port}. ${error.osError?.message ?? ''}');
    } on TimeoutException {
      throw PrintException('انتهت مهلة الاتصال بالطابعة ${config.host}:${config.port}.');
    } finally {
      socket?.destroy();
    }
  }

  Future<void> _sendPdf(List<ReceiptElement> elements, PrinterConfig config, {required String docName}) async {
    final png = await renderReceiptPng(elements, widthDots: config.width.dots);
    final document = pw.Document();
    final image = pw.MemoryImage(png);
    final receiptWidth = config.width == PaperWidth.mm80 ? 80 * PdfPageFormat.mm : 58 * PdfPageFormat.mm;
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(12 * PdfPageFormat.mm),
        build: (context) => pw.Align(
          alignment: pw.Alignment.topCenter,
          child: pw.Image(image, width: receiptWidth, fit: pw.BoxFit.contain),
        ),
      ),
    );
    final bytes = await document.save();
    final installed = await Printing.listPrinters();
    Printer? target;
    for (final printer in installed) {
      if (printer.name == config.printerName) target = printer;
    }
    target ??= Printer(url: config.printerName, name: config.printerName);
    final ok = await Printing.directPrintPdf(
      printer: target,
      onLayout: (format) async => bytes,
      name: docName,
    );
    if (!ok) throw PrintException('تعذر إرسال الإيصال إلى الطابعة "${config.printerName}".');
  }
}