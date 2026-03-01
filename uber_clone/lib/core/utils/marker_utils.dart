import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerUtils {
  /// Genera un bitmap de marker circular solo con letra (A o B)
  static Future<BitmapDescriptor> createABMarker({
    required String letter,
    required Color backgroundColor,
    required Color foregroundColor,
    required String
    label, // Mantener parámetro para no romper código existente, aunque no se dibuje
  }) async {
    const size = 36.0; // Aún más pequeño y circular
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Dibujar círculo de fondo
    final bgPaint = Paint()
      ..color = backgroundColor
      ..isAntiAlias = true;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, bgPaint);

    // Borde blanco interior ligero para que resalte
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..isAntiAlias = true;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      (size / 2) - 1,
      borderPaint,
    );

    // Dibujar la letra (A or B) en el centro
    final letterPainter = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    letterPainter.layout();
    letterPainter.paint(
      canvas,
      Offset(
        (size - letterPainter.width) / 2,
        (size - letterPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  /// Carga la imagen del vehículo desde assets y la redimensiona
  static Future<BitmapDescriptor> createVehicleMarker() async {
    final ByteData data = await rootBundle.load('assets/vehiculos/auto.png');
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 50, // Tamaño pequeño para el mapa
    );
    final ui.FrameInfo fi = await codec.getNextFrame();
    final ByteData? byteData = await fi.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }
}
