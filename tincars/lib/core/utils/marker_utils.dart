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
    const size = 28.0; // Smaller and circular
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
          fontSize: 14,
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

  /// Crea un marcador circular a partir de una URL de imagen
  static Future<BitmapDescriptor> createAvatarFromUrl(String url) async {
    try {
      final Uint8List bytes = (await NetworkAssetBundle(
        Uri.parse(url),
      ).load(url)).buffer.asUint8List();
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 100,
        targetHeight: 100,
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ui.Image image = fi.image;

      const size = 45.0; // Smaller size as requested
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw shadow
      final paintShadow = Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(
        const Offset(size / 2, size / 2 + 2),
        size / 2 - 2,
        paintShadow,
      );

      // Draw background circle (White)
      final paintBg = Paint()..color = Colors.white;
      canvas.drawCircle(
        const Offset(size / 2, size / 2),
        size / 2 - 2,
        paintBg,
      );

      // Draw border (Black)
      final paintBorder = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(
        const Offset(size / 2, size / 2),
        size / 2 - 2,
        paintBorder,
      );

      // Clip image to circle
      final path = Path()..addOval(Rect.fromLTWH(4, 4, size - 8, size - 8));
      canvas.clipPath(path);

      // Draw image
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(4, 4, size - 8, size - 8),
        Paint(),
      );

      final picture = recorder.endRecording();
      final outputImage = await picture.toImage(size.toInt(), size.toInt());
      final data = await outputImage.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.bytes(data!.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error creating avatar marker: $e');
      return BitmapDescriptor.defaultMarker;
    }
  }

  /// Genera un marker A/B con etiqueta de tiempo y distancia
  static Future<BitmapDescriptor> createABMarkerWithMetrics({
    required String letter,
    required Color backgroundColor,
    required Color foregroundColor,
    required String timeText,
    required String distanceText,
  }) async {
    const double circleSize = 32.0;
    const double padding = 8.0;
    const double textPadding = 6.0;

    // Pre-calculate text sizes to determine canvas width
    final timePainter = TextPainter(
      text: TextSpan(
        text: timeText,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final distPainter = TextPainter(
      text: TextSpan(
        text: distanceText,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final tagWidth =
        (timePainter.width > distPainter.width
            ? timePainter.width
            : distPainter.width) +
        (textPadding * 2);
    final tagHeight =
        timePainter.height + distPainter.height + (textPadding * 2);

    final double canvasWidth = circleSize + padding + tagWidth;
    final double canvasHeight = circleSize > tagHeight
        ? circleSize
        : tagHeight + 8;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 1. Draw Tag Background (Rounded Rectangle with shadow)
    final tagRect = RRect.fromLTRBR(
      circleSize + padding,
      (canvasHeight - tagHeight) / 2,
      canvasWidth,
      ((canvasHeight - tagHeight) / 2) + tagHeight,
      const Radius.circular(8),
    );

    // Shadow
    canvas.drawRRect(
      tagRect.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Tag Fill
    canvas.drawRRect(tagRect, Paint()..color = Colors.white);

    // 2. Draw Tag Texts
    final textStartX = circleSize + padding + textPadding;
    final textStartY = (canvasHeight - tagHeight) / 2 + textPadding;

    timePainter.paint(canvas, Offset(textStartX, textStartY));
    distPainter.paint(
      canvas,
      Offset(textStartX, textStartY + timePainter.height),
    );

    // 3. Draw Main Circle
    final circleCenter = Offset(circleSize / 2, canvasHeight / 2);

    canvas.drawCircle(
      circleCenter,
      circleSize / 2,
      Paint()
        ..color = backgroundColor
        ..isAntiAlias = true,
    );
    canvas.drawCircle(
      circleCenter,
      (circleSize / 2) - 1.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..isAntiAlias = true,
    );

    final letterPainter = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    letterPainter.paint(
      canvas,
      Offset(
        circleCenter.dx - (letterPainter.width / 2),
        circleCenter.dy - (letterPainter.height / 2),
      ),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      canvasWidth.toInt(),
      canvasHeight.toInt(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  /// Carga la imagen del vehículo desde assets según el tipo
  static Future<BitmapDescriptor> createVehicleMarker({
    String? vehicleType,
  }) async {
    String assetPath = 'assets/vehiculos/auto.png';

    if (vehicleType != null) {
      final type = vehicleType.toLowerCase();
      if (type.contains('essentialxl')) {
        assetPath = 'assets/vehiculos/essentialxl.png';
      } else if (type.contains('essential')) {
        assetPath = 'assets/vehiculos/essentials.png';
      } else if (type.contains('executive')) {
        assetPath = 'assets/vehiculos/executive.png';
      } else if (type.contains('signature') || type.contains('signatuve')) {
        assetPath = 'assets/vehiculos/signatuve.png';
      }
    }

    try {
      final ByteData data = await rootBundle.load(assetPath);
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 50, // Slightly larger for better visibility
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ByteData? byteData = await fi.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    } catch (e) {
      // Fallback to generic auto if specific one fails
      final ByteData data = await rootBundle.load('assets/vehiculos/auto.png');
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 40,
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ByteData? byteData = await fi.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    }
  }

  /// Crea un marcador de flecha para la ubicación del conductor
  static Future<BitmapDescriptor> createDriverArrowMarker() async {
    const size = 45.0; // Smaller size as requested
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()
      ..color = Colors
          .black // Black arrow as requested
      ..style = ui.PaintingStyle.fill;

    // Sombra para que resalte
    final shadowPaint = ui.Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);

    final path = ui.Path();
    path.moveTo(size / 2, 4); // Punta
    path.lineTo(size * 0.85, size * 0.85);
    path.lineTo(size * 0.5, size * 0.7);
    path.lineTo(size * 0.15, size * 0.85);
    path.close();

    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);
    canvas.drawPath(path, paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  /// Crea un marcador circular pequeño que dice "PERSONA"
  static Future<BitmapDescriptor> createPersonMarker() async {
    const size = 38.0; // Smaller size as requested
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Sombra
    final shadowPaint = ui.Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3);
    canvas.drawCircle(
      const Offset(size / 2, size / 2 + 2),
      size / 2 - 4,
      shadowPaint,
    );

    // Círculo Blanco
    final paintBg = ui.Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 4, paintBg);

    // Borde Negro
    final paintBorder = ui.Paint()
      ..color = Colors.black
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 4,
      paintBorder,
    );

    // Icono de Persona (Emoji 👤)
    final textPainter = TextPainter(
      text: const TextSpan(text: '👤', style: TextStyle(fontSize: 22)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  /// Crea un marcador de "personita" mini para el pasajero (versión más grande)
  static Future<BitmapDescriptor> createMiniPersonMarker() async {
    const size = 85.0; // Aumentado de 50.0 a 85.0
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Sombra
    final shadowPaint = ui.Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
    canvas.drawCircle(
      const Offset(size / 2, size / 2 + 2),
      size / 2 - 8,
      shadowPaint,
    );

    // Círculo Blanco
    final paintBg = ui.Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 8, paintBg);

    // Borde Negro
    final paintBorder = ui.Paint()
      ..color = Colors.black
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 8,
      paintBorder,
    );

    // Icono de Persona (Emoji 👤)
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '👤',
        style: TextStyle(fontSize: 36), // Aumentado de 20 a 36
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }
}
