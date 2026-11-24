import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'receipt.dart';

class ReceiptRaster {
  const ReceiptRaster({
    required this.widthDots,
    required this.height,
    required this.packed,
  });

  final int widthDots;
  final int height;

  /// 1-bit rows, MSB first, padded to whole bytes.
  final Uint8List packed;

  int get bytesPerRow => (widthDots + 7) ~/ 8;
}

class _Layout {
  _Layout(
    this.paragraphs,
    this.heights,
    this.dividers,
    this.gaps,
    this.images,
    this.imageWidths,
    this.totalHeight,
  );
  final List<ui.Paragraph> paragraphs;
  final List<double> heights;
  final List<bool> dividers;
  final List<double> gaps;
  final List<ui.Image?> images;
  final List<double> imageWidths;
  final double totalHeight;

  void dispose() {
    for (final paragraph in paragraphs) {
      paragraph.dispose();
    }
    for (final image in images) {
      image?.dispose();
    }
  }
}

Future<ui.Image> _decodeImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}

Future<_Layout> _layout(
  List<ReceiptElement> elements,
  double contentWidth,
  double scale,
) async {
  final paragraphs = <ui.Paragraph>[];
  final heights = <double>[];
  final dividers = <bool>[];
  final gaps = <double>[];
  final images = <ui.Image?>[];
  final imageWidths = <double>[];
  final availableDots = contentWidth / scale;

  for (final element in elements) {
    if (element.isImage) {
      final image = await _decodeImage(element.imageBytes!);
      final width = math.min(element.imageWidthDots.toDouble(), availableDots);
      paragraphs.add(ui.ParagraphBuilder(ui.ParagraphStyle()).build());
      heights.add(width * image.height / image.width * scale);
      dividers.add(false);
      gaps.add(0);
      images.add(image);
      imageWidths.add(width * scale);
      continue;
    }
    images.add(null);
    imageWidths.add(0);
    if (element.divider) {
      paragraphs.add(ui.ParagraphBuilder(ui.ParagraphStyle()).build());
      heights.add(14 * scale);
      dividers.add(true);
      gaps.add(0);
      continue;
    }
    if (element.isGap) {
      paragraphs.add(ui.ParagraphBuilder(ui.ParagraphStyle()).build());
      heights.add(element.dots * scale);
      dividers.add(false);
      gaps.add(element.dots * scale);
      continue;
    }
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textDirection: ui.TextDirection.rtl,
        textAlign: switch (element.align) {
          ReceiptAlign.right => ui.TextAlign.right,
          ReceiptAlign.center => ui.TextAlign.center,
          ReceiptAlign.left => ui.TextAlign.left,
        },
        maxLines: 6,
        ellipsis: '…',
      ),
    );
    builder.pushStyle(
      ui.TextStyle(
        fontFamily: 'Cairo',
        fontSize: element.size.dots * scale,
        height: 1.35,
        color: const ui.Color(0xFF000000),
        fontVariations: [ui.FontVariation('wght', element.bold ? 800 : 500)],
      ),
    );
    builder.addText(element.text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: contentWidth));
    paragraphs.add(paragraph);
    heights.add(paragraph.height);
    dividers.add(false);
    gaps.add(0);
  }

  final totalHeight =
      6 * scale +
      heights.fold<double>(0, (sum, height) => sum + height) +
      24 * scale;
  return _Layout(
    paragraphs,
    heights,
    dividers,
    gaps,
    images,
    imageWidths,
    totalHeight,
  );
}

Future<ui.Image> _renderImage(
  List<ReceiptElement> elements, {
  required int widthDots,
  required int marginDots,
  required double scale,
}) async {
  final width = widthDots * scale;
  final layout = await _layout(
    elements,
    (widthDots - marginDots * 2) * scale,
    scale,
  );
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width, layout.totalHeight),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );

  var y = 6 * scale;
  for (var index = 0; index < layout.paragraphs.length; index++) {
    final image = layout.images[index];
    if (image != null) {
      final imageWidth = layout.imageWidths[index];
      final imageHeight = layout.heights[index];
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTWH((width - imageWidth) / 2, y, imageWidth, imageHeight),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
    } else if (layout.dividers[index]) {
      canvas.drawLine(
        ui.Offset(marginDots * scale, y + 7 * scale),
        ui.Offset(width - marginDots * scale, y + 7 * scale),
        ui.Paint()
          ..color = const ui.Color(0xFF000000)
          ..strokeWidth = 2 * scale,
      );
    } else if (layout.gaps[index] == 0) {
      canvas.drawParagraph(
        layout.paragraphs[index],
        ui.Offset(marginDots * scale, y),
      );
    }
    y += layout.heights[index];
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(width.ceil(), layout.totalHeight.ceil());
  picture.dispose();
  layout.dispose();
  return image;
}

/// Renders a receipt with Flutter's text engine, then thresholds it to 1-bit.
///
/// Going through the real text engine is what makes Arabic shaping and RTL
/// correct on thermal printers that have no Arabic code page.
Future<ReceiptRaster> renderReceipt(
  List<ReceiptElement> elements, {
  required int widthDots,
  int marginDots = 8,
  int blackThreshold = 170,
}) async {
  final image = await _renderImage(
    elements,
    widthDots: widthDots,
    marginDots: marginDots,
    scale: 1,
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final height = image.height;
  final stride = image.width;
  image.dispose();
  if (byteData == null) {
    throw StateError('تعذر تحويل الإيصال إلى صورة للطباعة.');
  }

  final bytesPerRow = (widthDots + 7) ~/ 8;
  final packed = Uint8List(bytesPerRow * height);
  final pixels = byteData.buffer.asUint8List();
  for (var row = 0; row < height; row++) {
    for (var column = 0; column < widthDots && column < stride; column++) {
      final offset = (row * stride + column) * 4;
      final luminance =
          0.299 * pixels[offset] +
          0.587 * pixels[offset + 1] +
          0.114 * pixels[offset + 2];
      if (luminance < blackThreshold) {
        packed[row * bytesPerRow + (column >> 3)] |= 0x80 >> (column & 7);
      }
    }
  }
  return ReceiptRaster(widthDots: widthDots, height: height, packed: packed);
}

/// Smooth PNG of the same receipt, used by the PDF/A4 fallback path.
Future<Uint8List> renderReceiptPng(
  List<ReceiptElement> elements, {
  required int widthDots,
  int marginDots = 8,
  double scale = 2,
}) async {
  final image = await _renderImage(
    elements,
    widthDots: widthDots,
    marginDots: marginDots,
    scale: scale,
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) throw StateError('تعذر إنشاء صورة الإيصال.');
  return data.buffer.asUint8List();
}

Future<List<Uint8List>> renderReceiptPngPages(
  List<ReceiptElement> elements, {
  required int widthDots,
  required int maxHeightDots,
  int marginDots = 8,
  double scale = 2,
}) async {
  final contentWidth = (widthDots - marginDots * 2) * scale;
  final measured = await _layout(elements, contentWidth, scale);
  final heights = List<double>.of(measured.heights);
  measured.dispose();

  final pageHeight = maxHeightDots * scale;
  final pagePadding = 30 * scale;
  final pages = <List<ReceiptElement>>[];
  var page = <ReceiptElement>[];
  var usedHeight = pagePadding;

  for (var index = 0; index < elements.length; index++) {
    final height = heights[index];
    if (page.isNotEmpty && usedHeight + height > pageHeight) {
      pages.add(page);
      page = [];
      usedHeight = pagePadding;
    }
    page.add(elements[index]);
    usedHeight += height;
  }
  if (page.isNotEmpty || pages.isEmpty) pages.add(page);

  final result = <Uint8List>[];
  for (final pageElements in pages) {
    final image = await _renderImage(
      pageElements,
      widthDots: widthDots,
      marginDots: marginDots,
      scale: scale,
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('تعذر إنشاء صفحة الإيصال.');
    result.add(data.buffer.asUint8List());
  }
  return result;
}
