// One group per competitor problem (photo_view issues), see README "Why".
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_lightbox/media_lightbox.dart';

import 'support/harness.dart';

const viewport = Size(800, 600);

Future<ZoomableController> pumpZoomable(
  WidgetTester tester, {
  WheelZoomBehavior wheel = WheelZoomBehavior.always,
  List<double> steps = const [1, 2.5],
  bool elastic = true,
  double maxScale = 4,
  VoidCallback? onTap,
}) async {
  final c = ZoomableController();
  addTearDown(c.dispose);
  await pumpApp(
    tester,
    Scaffold(
      body: ZoomableView(
        controller: c,
        wheelBehavior: wheel,
        doubleTapScales: steps,
        elastic: elastic,
        maxScale: maxScale,
        onTap: onTap,
        child: const ColoredBox(color: Colors.teal),
      ),
    ),
  );
  return c;
}

void main() {
  // photo_view #481: no mouse-wheel / trackpad zoom.
  group('Problem 1: mouse-wheel and trackpad zoom around the cursor', () {
    testWidgets('wheel zoom keeps the point under the cursor fixed',
        (tester) async {
      final c = await pumpZoomable(tester);
      const cursor = Offset(620, 180);
      final before = ZoomMath.contentPointAt(cursor, Offset.zero, 1, viewport);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(cursor));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -300)));
      await tester.pump();
      expect(c.scale, greaterThan(1.3));
      final after =
          ZoomMath.contentPointAt(cursor, c.offset, c.scale, viewport);
      expect((after - before).distance, lessThan(0.01));

      // Scrolling the other way zooms back out, never below 1.
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 5000)));
      await tester.pump();
      expect(c.scale, 1);
    });

    testWidgets('wheel zoom never passes maxScale', (tester) async {
      final c = await pumpZoomable(tester, maxScale: 3);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(const Offset(400, 300)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -9000)));
      await tester.pump();
      expect(c.scale, 3);
    });

    testWidgets('withModifier only zooms while Ctrl is held', (tester) async {
      final c =
          await pumpZoomable(tester, wheel: WheelZoomBehavior.withModifier);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(const Offset(400, 300)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -300)));
      await tester.pump();
      expect(c.scale, 1);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -300)));
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(c.scale, greaterThan(1.3));
    });

    testWidgets('never ignores the wheel', (tester) async {
      final c = await pumpZoomable(tester, wheel: WheelZoomBehavior.never);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(const Offset(400, 300)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -300)));
      await tester.pump();
      expect(c.scale, 1);
    });

    testWidgets('trackpad pinch (pan/zoom events) zooms about the focal point',
        (tester) async {
      final c = await pumpZoomable(tester);
      const focal = Offset(600, 200);
      final trackpad = TestPointer(2, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(trackpad.panZoomStart(focal));
      await tester
          .sendEventToBinding(trackpad.panZoomUpdate(focal, scale: 2.0));
      await tester.pump();
      expect(c.scale, closeTo(2.0, 1e-9));
      final p = ZoomMath.contentPointAt(focal, c.offset, c.scale, viewport);
      final q = ZoomMath.contentPointAt(focal, Offset.zero, 1, viewport);
      expect((p - q).distance, lessThan(0.01));
      await tester.sendEventToBinding(trackpad.panZoomEnd());
      await tester.pump();
    });

    testWidgets('mouse drag pans a zoomed image', (tester) async {
      final c = await pumpZoomable(tester);
      c.zoomTo(3, animate: false);
      await tester.pump();
      final g = await tester.startGesture(const Offset(400, 300),
          kind: PointerDeviceKind.mouse);
      await g.moveBy(const Offset(-120, 40));
      await g.up();
      await tester.pump();
      expect(c.offset.dx, closeTo(-120, 1e-6));
      expect(c.offset.dy, closeTo(40, 1e-6));
    });
  });

  // photo_view #425: double tap does not zoom to the tapped position.
  group('Problem 2: double-tap zooms to the tapped point with set steps', () {
    testWidgets('double tap keeps the tapped content point under the finger',
        (tester) async {
      final c = await pumpZoomable(tester);
      const tap = Offset(600, 200);
      final before = ZoomMath.contentPointAt(tap, Offset.zero, 1, viewport);
      await tester.tapAt(tap);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(tap);
      await tester.pumpAndSettle();
      expect(c.scale, 2.5);
      final after = ZoomMath.contentPointAt(tap, c.offset, c.scale, viewport);
      expect((after - before).distance, lessThan(0.01));
      // The offset is not the centre: it really zoomed towards the tap.
      expect(c.offset.dx, lessThan(-100));
    });

    testWidgets('steps are configurable and cycle back to the first',
        (tester) async {
      final c = await pumpZoomable(tester, steps: const [1, 2, 4]);
      Future<void> doubleTap() async {
        await tester.tapAt(const Offset(400, 300));
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tapAt(const Offset(400, 300));
        await tester.pumpAndSettle();
      }

      await doubleTap();
      expect(c.scale, 2);
      await doubleTap();
      expect(c.scale, 4);
      await doubleTap();
      expect(c.scale, 1);
    });

    testWidgets(
        'a single tap fires onTap after the double-tap window and does '
        'not zoom', (tester) async {
      var taps = 0;
      final c = await pumpZoomable(tester, onTap: () => taps++);
      await tester.tapAt(const Offset(400, 300));
      expect(taps, 0);
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 1);
      expect(c.scale, 1);
    });

    testWidgets('a double tap fires no onTap', (tester) async {
      var taps = 0;
      await pumpZoomable(tester, onTap: () => taps++);
      await tester.tapAt(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();
      expect(taps, 0);
    });
  });

  // photo_view: gestures conflict with PageView (zoomed images swipe away).
  group('Problem 3: paging does not fight zoom gestures', () {
    testWidgets('at fit size a horizontal swipe changes the page',
        (tester) async {
      final items = await makeItems(tester, 3);
      final c = await pumpGallery(tester, items);
      await slowDrag(tester, const Offset(600, 300), const Offset(-500, 0));
      expect(c.index, 1);
    });

    testWidgets('when zoomed, a drag pans the image and does not page',
        (tester) async {
      final items = await makeItems(tester, 3);
      final c = await pumpGallery(tester, items);
      c.zoomTo(2, animate: false);
      await tester.pump();
      expect(c.isZoomed, isTrue);
      await slowDrag(tester, const Offset(500, 300), const Offset(-150, 0));
      expect(c.index, 0, reason: 'still inside the zoomed image');
      expect(c.zoomScale, 2);
    });

    testWidgets('dragging past the zoomed image edge hands over to the pager',
        (tester) async {
      final items = await makeItems(tester, 3);
      final c = await pumpGallery(tester, items);
      c.zoomTo(2, animate: false);
      await tester.pump();
      // 600x300 fitted to 800x400, x-slack at 2x is 400 px; drag 900 px.
      await slowDrag(tester, const Offset(700, 300), const Offset(-900, 0),
          steps: 30);
      expect(c.index, 1, reason: '500 px beyond the edge reaches page 2');
      expect(c.zoomScale, 1, reason: 'the new page starts at fit size');
    });

    testWidgets('a short overscroll snaps back instead of paging',
        (tester) async {
      final items = await makeItems(tester, 3);
      final c = await pumpGallery(tester, items);
      c.zoomTo(2, animate: false);
      await tester.pump();
      await slowDrag(tester, const Offset(700, 300), const Offset(-480, 0),
          steps: 24);
      expect(c.index, 0);
    });

    testWidgets('a pinch that moves horizontally at fit size does not page',
        (tester) async {
      final items = await makeItems(tester, 3);
      final c = await pumpGallery(tester, items);
      final a = await tester.startGesture(const Offset(300, 300), pointer: 1);
      final b = await tester.startGesture(const Offset(500, 300), pointer: 2);
      for (var i = 1; i <= 10; i++) {
        await a.moveTo(Offset(300 - i * 20.0, 300));
        await b.moveTo(Offset(500 + i * 20.0, 300));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(c.zoomScale, greaterThan(2.5));
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(c.index, 0);
      expect(c.zoomScale, greaterThan(2.5));
    });

    testWidgets(
        'a second finger landing after the first started paging turns it into '
        'a pinch and the page snaps back', (tester) async {
      final items = await makeItems(tester, 3);
      final c = await pumpGallery(tester, items);
      final a = await tester.startGesture(const Offset(380, 300), pointer: 1);
      for (var i = 1; i <= 4; i++) {
        await a.moveBy(const Offset(-15, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // First finger has dragged the page ~60 px; now a second finger lands.
      final b = await tester.startGesture(const Offset(420, 300), pointer: 2);
      for (var i = 1; i <= 10; i++) {
        await a.moveBy(const Offset(-20, 0));
        await b.moveBy(const Offset(20, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(c.zoomScale, greaterThan(1.5));
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(c.index, 0);
    });

    testWidgets('a mouse drag at fit size pages as well', (tester) async {
      final items = await makeItems(tester, 3);
      final c = await pumpGallery(tester, items);
      final g = await tester.startGesture(const Offset(600, 300),
          kind: PointerDeviceKind.mouse);
      for (var i = 0; i < 20; i++) {
        await g.moveBy(const Offset(-25, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await g.up();
      await tester.pumpAndSettle();
      expect(c.index, 1);
    });

    testWidgets('a quick flick pages even for a short distance',
        (tester) async {
      final items = await makeItems(tester, 3);
      final c = await pumpGallery(tester, items);
      await tester.fling(find.byType(PageView), const Offset(-120, 0), 1500);
      await tester.pumpAndSettle();
      expect(c.index, 1);
    });
  });

  // photo_view #85: min/max scale not strictly honoured.
  group('Problem 4: strict or elastic min/max scale', () {
    Future<void> pinchOut(WidgetTester tester,
        {required void Function() mid}) async {
      final a = await tester.startGesture(const Offset(380, 300), pointer: 1);
      final b = await tester.startGesture(const Offset(420, 300), pointer: 2);
      for (var i = 1; i <= 12; i++) {
        await a.moveTo(Offset(380 - i * 25.0, 300));
        await b.moveTo(Offset(420 + i * 25.0, 300));
        await tester.pump(const Duration(milliseconds: 16));
      }
      mid();
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
    }

    testWidgets('elastic: may overshoot while pinching, springs back to max',
        (tester) async {
      final c = await pumpZoomable(tester, maxScale: 3);
      await pinchOut(tester, mid: () {
        expect(c.scale, greaterThan(3));
        expect(c.scale, lessThanOrEqualTo(3.75 + 1e-9));
      });
      expect(c.scale, closeTo(3, 1e-3));
    });

    testWidgets('strict: never passes max at any moment', (tester) async {
      final c = await pumpZoomable(tester, elastic: false, maxScale: 3);
      var peak = 0.0;
      c.addListener(() => peak = peak < c.scale ? c.scale : peak);
      await pinchOut(tester, mid: () => expect(c.scale, 3));
      expect(peak, lessThanOrEqualTo(3));
    });
  });

  group('Problem 5: swipe down to dismiss with Hero', () {
    Widget launcher(List<LightboxItem> items) => Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: GestureDetector(
                onTap: () => Lightbox.open(context,
                    items: items,
                    options: const LightboxOptions(showThumbnails: true)),
                child: Hero(
                  tag: 'hero-0',
                  child: Container(
                      key: const Key('thumb'),
                      width: 80,
                      height: 80,
                      color: Colors.red),
                ),
              ),
            ),
          ),
        );

    testWidgets('open with Hero, drag past the threshold closes',
        (tester) async {
      final items = await makeItems(tester, 3, hero: true);
      await pumpApp(tester, launcher(items));
      await tester.tap(find.byKey(const Key('thumb')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Mid-transition: a Hero flight is in progress.
      expect(find.byType(LightboxGallery), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is Hero && w.tag == 'hero-0'),
          findsWidgets);

      await slowDrag(tester, const Offset(400, 200), const Offset(0, 220));
      expect(find.byType(LightboxGallery), findsNothing);
    });

    testWidgets('a short drag springs back and keeps the gallery open',
        (tester) async {
      final items = await makeItems(tester, 3, hero: true);
      await pumpApp(tester, launcher(items));
      await tester.tap(find.byKey(const Key('thumb')));
      await tester.pumpAndSettle();
      await slowDrag(tester, const Offset(400, 200), const Offset(0, 50));
      expect(find.byType(LightboxGallery), findsOneWidget);
    });

    testWidgets('a quick downward fling closes', (tester) async {
      final items = await makeItems(tester, 3, hero: true);
      await pumpApp(tester, launcher(items));
      await tester.tap(find.byKey(const Key('thumb')));
      await tester.pumpAndSettle();
      await tester.fling(find.byType(PageView), const Offset(0, 90), 2500);
      await tester.pumpAndSettle();
      expect(find.byType(LightboxGallery), findsNothing);
    });

    testWidgets('Lightbox.open completes with the last index', (tester) async {
      final items = await makeItems(tester, 3);
      int? result;
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await Lightbox.open(context, items: items),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(result, 1);
    });

    testWidgets('dragging zoomed content does not dismiss', (tester) async {
      final items = await makeItems(tester, 2);
      var closed = 0;
      final c = await pumpGallery(tester, items,
          options: LightboxOptions(onDismiss: () => closed++));
      c.zoomTo(2, animate: false);
      await tester.pump();
      await slowDrag(tester, const Offset(400, 200), const Offset(0, 250));
      expect(closed, 0);
      expect(c.zoomScale, 2);

      // Back at fit size the same drag does close.
      c.resetZoom(animate: false);
      await tester.pump();
      await slowDrag(tester, const Offset(400, 200), const Offset(0, 250));
      expect(closed, 1);
    });
  });
}
