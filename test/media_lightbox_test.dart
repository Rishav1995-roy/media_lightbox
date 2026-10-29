import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_lightbox/media_lightbox.dart';

import 'support/harness.dart';

void main() {
  testWidgets('shows caption and counter, tap toggles the overlay',
      (tester) async {
    final items = await makeItems(tester, 3);
    final c = await pumpGallery(tester, items);
    expect(find.text('Caption 0'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(c.chromeVisible, isTrue);
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.chromeVisible, isFalse);
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.chromeVisible, isTrue);
  });

  testWidgets('keyboard: arrows page, +/- zoom, 0 resets, Escape closes',
      (tester) async {
    final items = await makeItems(tester, 3);
    var closed = 0;
    final c = await pumpGallery(tester, items,
        options: LightboxOptions(onDismiss: () => closed++));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(c.index, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(c.index, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.pumpAndSettle();
    expect(c.zoomScale, closeTo(1.5, 1e-6));
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.pumpAndSettle();
    expect(c.zoomScale, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closed, 1);
  });

  testWidgets('controller: jump, next, previous, close, toggleChrome',
      (tester) async {
    final items = await makeItems(tester, 4);
    var closed = 0;
    final c = await pumpGallery(tester, items,
        options: LightboxOptions(onDismiss: () => closed++));
    c.jumpToPage(2);
    await tester.pumpAndSettle();
    expect(c.index, 2);
    unawaited(c.previous());
    await tester.pumpAndSettle();
    expect(c.index, 1);
    unawaited(c.next());
    await tester.pumpAndSettle();
    expect(c.index, 2);
    c.toggleChrome();
    await tester.pump();
    expect(c.chromeVisible, isFalse);
    c.close();
    expect(closed, 1);
  });

  testWidgets('onPageChanged and initialIndex', (tester) async {
    final items = await makeItems(tester, 3);
    final seen = <int>[];
    final c = await pumpGallery(tester, items,
        initialIndex: 2, options: LightboxOptions(onPageChanged: seen.add));
    expect(c.index, 2);
    unawaited(c.previous());
    await tester.pumpAndSettle();
    expect(seen, [1]);
  });

  testWidgets('thumbnail strip selects pages', (tester) async {
    final items = await makeItems(tester, 5);
    final c = await pumpGallery(tester, items,
        options: const LightboxOptions(showThumbnails: true));
    expect(find.byType(Image), findsWidgets);
    // Thumbnail 3 sits right of centre in the strip.
    final strip = find.byType(ListView);
    expect(strip, findsOneWidget);
    final box = tester.getRect(strip);
    await tester.tapAt(Offset(box.center.dx + 2 * 64, box.center.dy));
    await tester.pumpAndSettle();
    expect(c.index, 2);
  });

  testWidgets('overlayBuilder replaces the default chrome and sees the value',
      (tester) async {
    final items = await makeItems(tester, 3);
    await pumpGallery(
      tester,
      items,
      options: LightboxOptions(
        overlayBuilder: (context, v, controller) => Align(
          alignment: Alignment.bottomCenter,
          child: Text('custom ${v.index}/${v.count} z=${v.zoomScale}'),
        ),
      ),
    );
    expect(find.text('custom 0/3 z=1.0'), findsOneWidget);
    expect(find.text('1 / 3'), findsNothing);
  });

  testWidgets('captionBuilder and topBarBuilder are used', (tester) async {
    final items = await makeItems(tester, 2);
    await pumpGallery(
      tester,
      items,
      options: LightboxOptions(
        captionBuilder: (context, item, v) => Text('cap ${v.index}'),
        topBarBuilder: (context, v, c) => Text('top ${v.index}'),
      ),
    );
    expect(find.text('cap 0'), findsOneWidget);
    expect(find.text('top 0'), findsOneWidget);
  });

  testWidgets('pageBuilder can wrap each page', (tester) async {
    final items = await makeItems(tester, 2);
    await pumpGallery(
      tester,
      items,
      options: LightboxOptions(
        pageBuilder: (context, item, i, page) => Banner(
            message: 'p$i', location: BannerLocation.topEnd, child: page),
      ),
    );
    expect(find.byType(Banner), findsOneWidget);
  });

  testWidgets('custom item: builder gets isActive, non-zoomable ignores pinch',
      (tester) async {
    final active = <int, bool>{};
    final items = [
      LightboxItem.custom(
        zoomable: false,
        size: const Size(16, 9),
        builder: (context, info) {
          active[info.index] = info.isActive;
          return const ColoredBox(color: Colors.indigo);
        },
      ),
      LightboxItem.custom(
        builder: (context, info) {
          active[info.index] = info.isActive;
          return const ColoredBox(color: Colors.orange);
        },
      ),
    ];
    final c = await pumpGallery(tester, items);
    expect(active[0], isTrue);
    final a = await tester.startGesture(const Offset(380, 300), pointer: 1);
    final b = await tester.startGesture(const Offset(420, 300), pointer: 2);
    for (var i = 1; i <= 8; i++) {
      await a.moveBy(const Offset(-20, 0));
      await b.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(c.zoomScale, 1);
    unawaited(c.next());
    await tester.pumpAndSettle();
    expect(active[1], isTrue);
  });

  testWidgets('image error shows errorBuilder', (tester) async {
    final items = [
      LightboxItem.image(MemoryImage(Uint8List.fromList([1, 2, 3]))),
    ];
    await pumpGallery(
      tester,
      items,
      options: LightboxOptions(
          errorBuilder: (context, error) => const Text('broken')),
    );
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(find.text('broken'), findsOneWidget);
  });

  testWidgets('embedded gallery with no items renders nothing', (tester) async {
    await pumpApp(tester, const Scaffold(body: LightboxGallery(items: [])));
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('zoom state is not kept for a page the user left',
      (tester) async {
    final items = await makeItems(tester, 3);
    final c = await pumpGallery(tester, items);
    c.zoomTo(3, animate: false);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(c.index, 1);
    expect(c.zoomScale, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(c.zoomScale, 1);
  });
}
