import 'dart:typed_data';

import 'package:elrashedy_pos/printing/escpos.dart';
import 'package:elrashedy_pos/printing/raster.dart';
import 'package:flutter_test/flutter_test.dart';

ReceiptRaster fakeRaster({required int height, int widthDots = 8}) => ReceiptRaster(
      widthDots: widthDots,
      height: height,
      packed: Uint8List(((widthDots + 7) ~/ 8) * height),
    );

void main() {
  test('init and cut use the standard ESC/POS sequences', () {
    final builder = EscPosBuilder()
      ..init()
      ..cut();
    expect(builder.toBytes(), [0x1B, 0x40, 0x1D, 0x56, 0x42, 0x00]);
  });

  test('raster emits GS v 0 with little-endian width and height', () {
    final builder = EscPosBuilder()..raster(fakeRaster(height: 3, widthDots: 576));
    final bytes = builder.toBytes();
    expect(bytes.sublist(0, 8), [0x1D, 0x76, 0x30, 0x00, 0x48, 0x00, 0x03, 0x00]);
    expect(bytes.length, 8 + 72 * 3);
  });

  test('tall receipts are split into 200-row chunks so printer buffers survive', () {
    final builder = EscPosBuilder()..raster(fakeRaster(height: 450));
    final bytes = builder.toBytes();
    final headers = <int>[];
    for (var index = 0; index + 8 <= bytes.length; index++) {
      if (bytes[index] == 0x1D && bytes[index + 1] == 0x76 && bytes[index + 2] == 0x30) {
        headers.add(bytes[index + 6] | (bytes[index + 7] << 8));
        index += 7 + (bytes[index + 4] | (bytes[index + 5] << 8)) * (bytes[index + 6] | (bytes[index + 7] << 8));
      }
    }
    expect(headers, [200, 200, 50]);
    expect(bytes.length, 3 * 8 + 450);
  });

  test('drawer kick is ESC p with the requested pulse times', () {
    final builder = EscPosBuilder()..kickDrawer();
    expect(builder.toBytes(), [0x1B, 0x70, 0x00, 25, 250]);
  });

  test('a full receipt feeds, optionally kicks the drawer, then cuts', () {
    final withDrawer = buildReceiptBytes(fakeRaster(height: 2), kickDrawer: true);
    expect(withDrawer.sublist(0, 2), [0x1B, 0x40]);
    expect(withDrawer.sublist(withDrawer.length - 9), [0x1B, 0x70, 0x00, 25, 250, 0x1D, 0x56, 0x42, 0x00]);

    final withoutDrawer = buildReceiptBytes(fakeRaster(height: 2), kickDrawer: false);
    expect(withoutDrawer.sublist(withoutDrawer.length - 7), [0x1B, 0x64, 0x03, 0x1D, 0x56, 0x42, 0x00]);
  });
}