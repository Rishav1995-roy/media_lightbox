import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// One generated picture with a title.
class SamplePhoto {
  const SamplePhoto(this.title, this.image, this.size);

  final String title;
  final ImageProvider image;
  final Size size;
}

/// Draws original landscape-style pictures at start-up, so the example needs
/// no image files and no network.
class SamplePhotos {
  const SamplePhotos._();

  static const _titles = [
    'Dawn ridge',
    'Dune light',
    'Quiet harbour',
    'Night garden',
    'Salt flats',
    'Pine valley',
    'Ember sky',
    'Glass lake',
    'Blue hour',
    'Low tide',
    'Meadow haze',
    'Last light',
  ];

  // width : height ratios, mixed so portrait/landscape/square all show up.
  static const _ratios = [1.5, 0.75, 1.0, 1.78, 1.33, 0.8, 1.5, 1.0, 1.78, 0.75, 1.33, 1.5];

  static const _palettes = [
    [Color(0xFFFFB27A), Color(0xFFE4577B), Color(0xFF3B2A6B)],
    [Color(0xFFFFE29A), Color(0xFFF08A4B), Color(0xFF6B3E2E)],
    [Color(0xFF9FD8F0), Color(0xFF4A8FD0), Color(0xFF1C3D6B)],
    [Color(0xFF5A4AA5), Color(0xFF2B2866), Color(0xFF0B1030)],
    [Color(0xFFEFF3F6), Color(0xFFB5C7D3), Color(0xFF5E7A8C)],
    [Color(0xFFBFE3B4), Color(0xFF5BA06A), Color(0xFF1F4A38)],
    [Color(0xFFFFD27F), Color(0xFFE5533D), Color(0xFF4A1A2C)],
    [Color(0xFFCDEBF2), Color(0xFF6FB6C9), Color(0xFF265A6B)],
    [Color(0xFF8FA6E8), Color(0xFF4C5BB5), Color(0xFF191E52)],
    [Color(0xFFFFD9C2), Color(0xFFD99A8B), Color(0xFF5C4452)],
    [Color(0xFFF4EBC1), Color(0xFFB9C77A), Color(0xFF4D6B3A)],
    [Color(0xFFFFC2A0), Color(0xFFC25B7C), Color(0xFF241A4A)],
  ];

  static Future<List<SamplePhoto>> load({int count = 12, int longSide = 1200}) async {
    final out = <SamplePhoto>[];
    for (var i = 0; i < count; i++) {
      final ratio = _ratios[i % _ratios.length];
      final w = ratio >= 1 ? longSide : (longSide * ratio).round();
      final h = ratio >= 1 ? (longSide / ratio).round() : longSide;
      final bytes = await _paint(i, w, h);
      out.add(SamplePhoto(
        _titles[i % _titles.length],
        MemoryImage(bytes),
        Size(w.toDouble(), h.toDouble()),
      ));
    }
    return out;
  }

  static Future<Uint8List> _paint(int seed, int w, int h) async {
    final p = _palettes[seed % _palettes.length];
    final rnd = math.Random(seed * 7919 + 3);
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    final size = Size(w.toDouble(), h.toDouble());
    final rect = Offset.zero & size;

    // Sky.
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p[2], p[1], p[0]],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    // Stars for the dark palettes.
    if (seed % _palettes.length == 3 || seed % _palettes.length == 8) {
      final star = Paint()..color = Colors.white.withValues(alpha: 0.8);
      for (var i = 0; i < 90; i++) {
        c.drawCircle(
          Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height * 0.5),
          0.8 + rnd.nextDouble() * 1.8,
          star,
        );
      }
    }
    // Sun / moon with a soft halo.
    final sun = Offset(size.width * (0.2 + rnd.nextDouble() * 0.6), size.height * (0.3 + rnd.nextDouble() * 0.15));
    final r = size.shortestSide * 0.09;
    c.drawCircle(
      sun,
      r * 3.2,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: sun, radius: r * 3.2)),
    );
    c.drawCircle(sun, r, Paint()..color = Colors.white.withValues(alpha: 0.95));

    // Layered ridges, far to near.
    for (var layer = 0; layer < 4; layer++) {
      final base = size.height * (0.52 + layer * 0.12);
      final amp = size.height * (0.10 - layer * 0.012);
      final f1 = 1.5 + rnd.nextDouble() * 2.2;
      final f2 = 4 + rnd.nextDouble() * 4;
      final ph = rnd.nextDouble() * 6.28;
      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width; x += 6) {
        final t = x / size.width;
        final y = base -
            amp * (0.6 * math.sin(t * f1 * 6.28 + ph) + 0.4 * math.sin(t * f2 * 6.28 + ph * 2)).abs();
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      final shade = Color.lerp(p[1], p[2], 0.25 + layer * 0.25)!;
      c.drawPath(path, Paint()..color = shade.withValues(alpha: 1));
    }
    // A fine detail grid so zooming has something to reveal.
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 60) {
      c.drawLine(Offset(x, size.height * 0.62), Offset(x, size.height), grid);
    }
    for (var y = size.height * 0.62; y < size.height; y += 60) {
      c.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final image = await recorder.endRecording().toImage(w, h);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}
