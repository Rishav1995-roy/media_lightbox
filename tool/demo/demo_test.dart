// Renders doc/demo.gif frames and doc/screenshot_*.png deterministically,
// without a device. Run with:
//
//   fvm spawn 3.47.7 test tool/demo/demo_test.dart
//   ./tool/make_gif.sh
//
// It is NOT part of `flutter test` (it lives in tool/, not test/).
// The frames are real renderings of the real widgets; the "finger" dot is
// drawn by this script to show where the simulated touches land.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_lightbox/media_lightbox.dart';

import '../../example/lib/gallery_demo.dart';
import '../../example/lib/sample_images.dart';

const _size = Size(360, 720);
const _frameMs = 83; // ~12 fps

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('tool/fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

void main() {
  late Directory frames;
  late List<SamplePhoto> photos;
  final boundaryKey = GlobalKey();
  final finger = ValueNotifier<Offset?>(null);
  var n = 0;

  setUpAll(() async {
    await _loadFonts();
    frames = Directory('build/demo_frames')..createSync(recursive: true);
    for (final f in frames.listSync()) {
      if (f is File) f.deleteSync();
    }
  });

  Widget app(Widget home, {ThemeMode mode = ThemeMode.light}) => RepaintBoundary(
        key: boundaryKey,
        child: Stack(
          textDirection: TextDirection.ltr,
          children: [
            MaterialApp(
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              theme: ThemeData(
                  colorSchemeSeed: const Color(0xFF5B5BD6),
                  useMaterial3: true,
                  fontFamily: 'Roboto'),
              home: home,
            ),
            // The simulated finger.
            ValueListenableBuilder<Offset?>(
              valueListenable: finger,
              builder: (context, p, _) => p == null
                  ? const SizedBox.shrink()
                  : Positioned(
                      left: p.dx - 18,
                      top: p.dy - 18,
                      child: IgnorePointer(
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0x66FFFFFF),
                            border: Border.all(color: const Color(0xCCFFFFFF), width: 2),
                            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6)],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );

  Future<void> shot(WidgetTester tester, String path) async {
    await tester.runAsync(() async {
      final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File(path).writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  Future<void> frame(WidgetTester tester, {int count = 1}) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: _frameMs));
      await shot(tester, '${frames.path}/f${(n++).toString().padLeft(4, '0')}.png');
    }
  }

  Future<void> moveFinger(WidgetTester tester, Offset to, {int steps = 5}) async {
    final from = finger.value ?? to;
    for (var i = 1; i <= steps; i++) {
      finger.value = Offset.lerp(from, to, i / steps);
      await frame(tester);
    }
  }

  testWidgets('record demo', (tester) async {
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    photos = (await tester.runAsync(() => SamplePhotos.load(count: 9, longSide: 900)))!;
    final items = itemsFor(photos);

    late BuildContext ctx;
    await tester.pumpWidget(app(Scaffold(
      appBar: AppBar(title: const Text('Gallery')),
      body: Builder(builder: (context) {
        ctx = context;
        return PhotoGrid(
          photos: photos,
          onOpen: (i) => Lightbox.open(
            context,
            items: items,
            initialIndex: i,
            options: const LightboxOptions(showThumbnails: true),
          ),
        );
      }),
    )));
    // Warm the image cache so pictures show on the very first frame.
    await tester.runAsync(() async {
      for (final p in photos) {
        await precacheImage(p.image, ctx);
        await precacheImage(ResizeImage(p.image, width: 360), ctx);
      }
    });
    await tester.pump();

    // 1. Grid, finger goes to a thumbnail and taps it.
    await frame(tester, count: 3);
    final target = tester.getCenter(find.byType(Hero).at(4));
    await moveFinger(tester, target, steps: 6);
    final g = await tester.startGesture(target);
    await frame(tester);
    await g.up();
    finger.value = null;
    await frame(tester, count: 11); // Hero flight + fade in
    await tester.pumpAndSettle();
    await shot(tester, 'doc/screenshot_gallery.png');
    await frame(tester, count: 2);

    // 2. Double tap on the right part of the picture: zoom to that point.
    final tapAt = const Offset(250, 330);
    await moveFinger(tester, tapAt, steps: 4);
    await tester.tapAt(tapAt);
    await frame(tester);
    await tester.tapAt(tapAt);
    await frame(tester, count: 10);
    await shot(tester, 'doc/screenshot_zoomed.png');
    await frame(tester, count: 3);

    // 3. Pan the zoomed picture.
    final drag = await tester.startGesture(const Offset(260, 400));
    for (var i = 0; i < 6; i++) {
      await drag.moveBy(const Offset(-14, -8));
      finger.value = const Offset(260, 400) + Offset(-14.0 * (i + 1), -8.0 * (i + 1));
      await frame(tester);
    }
    await drag.up();
    finger.value = null;
    await frame(tester, count: 2);

    // 4. Double tap again: back to fit.
    await moveFinger(tester, const Offset(180, 360), steps: 3);
    await tester.tapAt(const Offset(180, 360));
    await frame(tester);
    await tester.tapAt(const Offset(180, 360));
    await frame(tester, count: 8);
    finger.value = null;
    await frame(tester, count: 2);

    // 5. Swipe to the next page.
    for (var page = 0; page < 1; page++) {
      final start = const Offset(300, 360);
      finger.value = start;
      await frame(tester);
      final s = await tester.startGesture(start);
      for (var i = 1; i <= 7; i++) {
        await s.moveBy(const Offset(-34, 0));
        finger.value = start + Offset(-34.0 * i, 0);
        await frame(tester);
      }
      await s.up();
      finger.value = null;
      await frame(tester, count: 8);
    }
    await frame(tester, count: 2);

    // 6. Swipe down to dismiss.
    final dStart = const Offset(180, 300);
    finger.value = dStart;
    await frame(tester);
    final d = await tester.startGesture(dStart);
    for (var i = 1; i <= 8; i++) {
      await d.moveBy(const Offset(4, 22));
      finger.value = dStart + Offset(4.0 * i, 22.0 * i);
      await frame(tester);
    }
    await d.up();
    finger.value = null;
    await frame(tester, count: 12); // pop + Hero back to the grid
    await tester.pumpAndSettle();
    await frame(tester, count: 5);
  });

  testWidgets('theme screenshot', (tester) async {
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    photos = (await tester.runAsync(() => SamplePhotos.load(count: 9, longSide: 900)))!;
    finger.value = null;
    late BuildContext ctx;
    await tester.pumpWidget(app(Scaffold(body: Builder(builder: (context) {
      ctx = context;
      return const SizedBox();
    }))));
    await tester.runAsync(() async {
      for (final p in photos) {
        await precacheImage(p.image, ctx);
      }
    });
    unawaitedOpen() => Lightbox.open(
          ctx,
          items: itemsFor(photos),
          initialIndex: 2,
          options: const LightboxOptions(
            showThumbnails: true,
            theme: LightboxTheme(
              backgroundColor: Color(0xFF2B2118),
              foregroundColor: Color(0xFFF5E6CF),
              scrimColor: Color(0xCC2B2118),
              activeThumbnailColor: Color(0xFFE0A458),
              thumbnailRadius: 14,
            ),
          ),
        );
    unawaitedOpen();
    await tester.pumpAndSettle();
    // Let the (async) thumbnail decodes finish before the shot.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();
    await shot(tester, 'doc/screenshot_theme.png');
  });
}
