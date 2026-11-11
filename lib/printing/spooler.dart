import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

class PrintException implements Exception {
  PrintException(this.message);
  final String message;

  @override
  String toString() => message;
}

final class _DocInfo1 extends Struct {
  external Pointer<Utf16> pDocName;
  external Pointer<Utf16> pOutputFile;
  external Pointer<Utf16> pDatatype;
}

typedef _OpenPrinterC = Int32 Function(Pointer<Utf16>, Pointer<IntPtr>, Pointer<Void>);
typedef _OpenPrinterDart = int Function(Pointer<Utf16>, Pointer<IntPtr>, Pointer<Void>);
typedef _StartDocC = Uint32 Function(IntPtr, Uint32, Pointer<Void>);
typedef _StartDocDart = int Function(int, int, Pointer<Void>);
typedef _HandleOnlyC = Int32 Function(IntPtr);
typedef _HandleOnlyDart = int Function(int);
typedef _WritePrinterC = Int32 Function(IntPtr, Pointer<Void>, Uint32, Pointer<Uint32>);
typedef _WritePrinterDart = int Function(int, Pointer<Void>, int, Pointer<Uint32>);
typedef _ClosePrinterC = Int32 Function(IntPtr);
typedef _ClosePrinterDart = int Function(int);

/// Raw ESC/POS delivery through the Windows print spooler.
///
/// Writing datatype "RAW" bypasses the driver's rendering, so the printer gets
/// exactly the bytes we built — no dialog, no margins, no driver surprises.
class WindowsSpooler {
  WindowsSpooler() : _library = DynamicLibrary.open('winspool.drv') {
    _openPrinter = _library.lookupFunction<_OpenPrinterC, _OpenPrinterDart>('OpenPrinterW');
    _startDoc = _library.lookupFunction<_StartDocC, _StartDocDart>('StartDocPrinterW');
    _startPage = _library.lookupFunction<_HandleOnlyC, _HandleOnlyDart>('StartPagePrinter');
    _write = _library.lookupFunction<_WritePrinterC, _WritePrinterDart>('WritePrinter');
    _endPage = _library.lookupFunction<_HandleOnlyC, _HandleOnlyDart>('EndPagePrinter');
    _endDoc = _library.lookupFunction<_HandleOnlyC, _HandleOnlyDart>('EndDocPrinter');
    _close = _library.lookupFunction<_ClosePrinterC, _ClosePrinterDart>('ClosePrinter');
  }

  final DynamicLibrary _library;
  late final _OpenPrinterDart _openPrinter;
  late final _StartDocDart _startDoc;
  late final _HandleOnlyDart _startPage;
  late final _WritePrinterDart _write;
  late final _HandleOnlyDart _endPage;
  late final _HandleOnlyDart _endDoc;
  late final _ClosePrinterDart _close;

  static void ensureWindows() {
    if (!Platform.isWindows) {
      throw PrintException('الطباعة عبر USB متاحة على Windows فقط. استخدم الطابعة الشبكية أو PDF.');
    }
  }

  void send(String printerName, Uint8List bytes, {String docName = 'Al Rashedy POS'}) {
    ensureWindows();
    if (printerName.trim().isEmpty) throw PrintException('اختر اسم الطابعة أولاً.');

    using((arena) {
      final name = printerName.toNativeUtf16(allocator: arena);
      final handlePtr = arena<IntPtr>();
      if (_openPrinter(name, handlePtr, nullptr) == 0) {
        throw PrintException('تعذر فتح الطابعة "$printerName". تأكد من تشغيلها ومن الاسم الصحيح.');
      }
      final handle = handlePtr.value;
      try {
        final info = arena<_DocInfo1>();
        info.ref.pDocName = docName.toNativeUtf16(allocator: arena);
        info.ref.pOutputFile = nullptr;
        info.ref.pDatatype = 'RAW'.toNativeUtf16(allocator: arena);
        if (_startDoc(handle, 1, info.cast()) == 0) {
          throw PrintException('تعذر بدء مهمة الطباعة على "$printerName".');
        }
        try {
          if (_startPage(handle) == 0) throw PrintException('تعذر بدء صفحة الطباعة.');
          final buffer = arena<Uint8>(bytes.length);
          buffer.asTypedList(bytes.length).setAll(0, bytes);
          final written = arena<Uint32>();
          var offset = 0;
          while (offset < bytes.length) {
            final chunk = (bytes.length - offset) > 65536 ? 65536 : bytes.length - offset;
            if (_write(handle, (buffer + offset).cast(), chunk, written) == 0) {
              throw PrintException('انقطع إرسال البيانات إلى الطابعة. تحقق من الكابل أو منفذ USB.');
            }
            final count = written.value;
            if (count == 0) throw PrintException('لم تقبل الطابعة بيانات الإيصال.');
            offset += count;
          }
          _endPage(handle);
        } finally {
          _endDoc(handle);
        }
      } finally {
        _close(handle);
      }
    });
  }
}