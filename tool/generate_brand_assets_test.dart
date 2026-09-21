// Renders the Payflow app icon PNGs from the same painter the app uses.
//
//   flutter test tool/generate_brand_assets_test.dart
//   dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/core/theme/brand.dart';
import 'package:payflow/shared/widgets/brand_mark.dart';

Future<void> _render(
  String path, {
  required int size,
  Color? background,
  required Color stroke,
  required Color coin,
  required double scale,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = Size.square(size.toDouble());
  if (background != null) {
    canvas.drawRect(Offset.zero & s, Paint()..color = background);
  }
  BrandMarkPainter(strokeColor: stroke, coinColor: coin, scale: scale)
      .paint(canvas, s);
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('generate brand assets', (tester) async {
    await tester.runAsync(() async {
      // iOS / legacy Android: full-bleed jade square (OS applies the mask).
      await _render('assets/brand/app_icon.png',
          size: 1024,
          background: Brand.jade700,
          stroke: Brand.paper,
          coin: Brand.ember400,
          scale: 1.0);
      // Android adaptive foreground. flutter_launcher_icons adds a 16% inset,
      // which keeps the mark inside the 66% safe zone.
      await _render('assets/brand/app_icon_foreground.png',
          size: 1024,
          stroke: Brand.paper,
          coin: Brand.ember400,
          scale: 1.0);
      // Android 13 themed icon.
      await _render('assets/brand/app_icon_monochrome.png',
          size: 1024,
          stroke: Colors.white,
          coin: Colors.white,
          scale: 1.0);
      // Marketing mark on transparent background.
      await _render('assets/brand/mark.png',
          size: 512,
          stroke: Brand.jade700,
          coin: Brand.ember500,
          scale: 1.35);
    });
  });
}
