import 'dart:ui' as ui;
import 'dart:typed_data' as typed_data;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';

class EmojiMarkerGenerator {
  static Future<BitmapDescriptor> createEmojiMarker(String emoji) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double logicalSize = 40.0;
    const double pixelRatio = 3.0;
    const double size = logicalSize * pixelRatio;

    canvas.scale(pixelRatio, pixelRatio);

    // Draw background circle
    final Paint paint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(logicalSize / 2, logicalSize / 2), logicalSize / 2, paint);

    // Draw border
    final Paint borderPaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(const Offset(logicalSize / 2, logicalSize / 2), logicalSize / 2, borderPaint);

    // Draw Emoji Text
    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: emoji,
      style: const TextStyle(fontSize: logicalSize * 0.6),
    );
    textPainter.layout();

    // Center text
    textPainter.paint(
      canvas,
      Offset((logicalSize - textPainter.width) / 2, (logicalSize - textPainter.height) / 2),
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );

    final typed_data.ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final typed_data.Uint8List uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.bytes(uint8List, imagePixelRatio: pixelRatio);
  }
}
