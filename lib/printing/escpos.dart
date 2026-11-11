import 'dart:typed_data';

import 'raster.dart';

/// Minimal ESC/POS command builder for raster receipts.
class EscPosBuilder {
  final BytesBuilder _bytes = BytesBuilder(copy: false);

  static const int maxChunkRows = 200;

  void init() => _bytes.add(const [0x1B, 0x40]);

  void alignLeft() => _bytes.add(const [0x1B, 0x61, 0x00]);

  void alignCenter() => _bytes.add(const [0x1B, 0x61, 0x01]);

  /// GS v 0 — raster bit image, sent in row chunks so small printer buffers
  /// never overflow mid-receipt.
  void raster(ReceiptRaster image) {
    final bytesPerRow = image.bytesPerRow;
    for (var offset = 0; offset < image.height; offset += maxChunkRows) {
      final rows = (image.height - offset).clamp(0, maxChunkRows);
      _bytes.add([
        0x1D, 0x76, 0x30, 0x00,
        bytesPerRow & 0xFF, (bytesPerRow >> 8) & 0xFF,
        rows & 0xFF, (rows >> 8) & 0xFF,
      ]);
      _bytes.add(Uint8List.sublistView(image.packed, offset * bytesPerRow, (offset + rows) * bytesPerRow));
    }
  }

  void feed(int lines) => _bytes.add([0x1B, 0x64, lines & 0xFF]);

  void cut() => _bytes.add(const [0x1D, 0x56, 0x42, 0x00]);

  /// ESC p — cash drawer kick via the printer's DK port.
  void kickDrawer({int pin = 0, int onTime = 25, int offTime = 250}) =>
      _bytes.add([0x1B, 0x70, pin & 0x01, onTime & 0xFF, offTime & 0xFF]);

  Uint8List toBytes() => _bytes.toBytes();
}

Uint8List buildReceiptBytes(
  ReceiptRaster raster, {
  required bool kickDrawer,
  int feedLines = 3,
  bool cut = true,
}) {
  final builder = EscPosBuilder()
    ..init()
    ..raster(raster)
    ..feed(feedLines);
  if (kickDrawer) builder.kickDrawer();
  if (cut) builder.cut();
  return builder.toBytes();
}