import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_lightbox/media_lightbox.dart';

/// Draws a [w] x [h] PNG (a gradient with a cross, so it is recognisable).
Future<Uint8List> makePng(int w, int h, Color a, Color b) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
  canvas.drawRect(
    rect,
    Paint()..shader = LinearGradient(colors: [a, b]).createShader(rect),
  );
  canvas.drawLine(
      rect.topLeft,
      rect.bottomRight,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 6);
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// Builds [count] 600x300 items and warms the image cache so they resolve
/// synchronously (and therefore have exact sizes on the first frame).
Future<List<LightboxItem>> makeItems(
  WidgetTester tester,
  int count, {
  bool hero = false,
  bool captions = true,
}) async {
  final items = <LightboxItem>[];
  await tester.runAsync(() async {
    for (var i = 0; i < count; i++) {
      final bytes = await makePng(
        600,
        300,
        Colors.primaries[i % Colors.primaries.length],
        Colors.primaries[(i + 5) % Colors.primaries.length],
      );
      final provider = MemoryImage(bytes);
      final completer = Completer<void>();
      final stream = provider.resolve(ImageConfiguration.empty);
      late ImageStreamListener l;
      l = ImageStreamListener((_, __) {
        completer.complete();
        stream.removeListener(l);
      });
      stream.addListener(l);
      await completer.future;
      items.add(LightboxItem.image(
        provider,
        heroTag: hero ? 'hero-$i' : null,
        caption: captions ? 'Caption $i' : null,
      ));
    }
  });
  return items;
}

Future<void> pumpApp(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester
      .pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: home));
  await tester.pump();
}

/// Pumps a gallery that fills the 800x600 test surface.
Future<LightboxController> pumpGallery(
  WidgetTester tester,
  List<LightboxItem> items, {
  LightboxOptions options = const LightboxOptions(),
  int initialIndex = 0,
}) async {
  final controller = LightboxController();
  addTearDown(controller.dispose);
  await pumpApp(
    tester,
    Scaffold(
      body: LightboxGallery(
        items: items,
        initialIndex: initialIndex,
        controller: controller,
        options: options,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// Drags with one pointer in small steps (so velocity stays low and the
/// gesture is a real drag, not a fling), then waits a beat before releasing.
Future<void> slowDrag(WidgetTester tester, Offset from, Offset delta,
    {int steps = 20}) async {
  final g = await tester.startGesture(from);
  for (var i = 0; i < steps; i++) {
    await g.moveBy(delta / steps.toDouble());
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(const Duration(milliseconds: 400));
  await g.up();
  await tester.pumpAndSettle();
}
