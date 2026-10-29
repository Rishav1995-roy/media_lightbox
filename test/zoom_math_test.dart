import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_lightbox/media_lightbox.dart';

void main() {
  const viewport = Size(800, 600);

  test('fitContain letterboxes a wide image', () {
    expect(ZoomMath.fitContain(const Size(600, 300), viewport),
        const Size(800, 400));
    expect(ZoomMath.fitContain(Size.zero, viewport), viewport);
  });

  test('clampOffset leaves no gaps and centres content smaller than viewport',
      () {
    const fitted = Size(800, 400);
    // At 1x the image is shorter than the viewport: no vertical pan at all.
    expect(ZoomMath.clampOffset(const Offset(50, 80), 1, fitted, viewport),
        Offset.zero);
    // At 2x: 800 px of slack horizontally (400 each side), 100 vertically.
    expect(ZoomMath.clampOffset(const Offset(999, -999), 2, fitted, viewport),
        const Offset(400, -100));
  });

  test('zoomAround keeps the content point under the focal point fixed', () {
    const focal = Offset(600, 200);
    final before = ZoomMath.contentPointAt(focal, Offset.zero, 1, viewport);
    final o = ZoomMath.zoomAround(
      offset: Offset.zero,
      oldScale: 1,
      newScale: 3,
      focal: focal,
      viewport: viewport,
    );
    final after = ZoomMath.contentPointAt(focal, o, 3, viewport);
    expect((after - before).distance, lessThan(1e-9));
  });

  test('nextStep cycles through the configured steps', () {
    const steps = [1.0, 2.0, 4.0];
    expect(ZoomMath.nextStep(1, steps), 2);
    expect(ZoomMath.nextStep(2, steps), 4);
    expect(ZoomMath.nextStep(4, steps), 1);
    expect(ZoomMath.nextStep(3, steps), 4);
    expect(ZoomMath.nextStep(5, steps), 1);
  });

  test('limitScale is strict or elastic', () {
    expect(ZoomMath.limitScale(9, 1, 4, elastic: false), 4);
    expect(ZoomMath.limitScale(0.2, 1, 4, elastic: false), 1);
    expect(ZoomMath.limitScale(9, 1, 4, elastic: true), 5);
    expect(ZoomMath.limitScale(0.2, 1, 4, elastic: true), 0.8);
  });

  test('panBy reports the horizontal excess handed to the pager', () {
    const fitted = Size(800, 400);
    final r = ZoomMath.panBy(
      offset: const Offset(-350, 0),
      delta: const Offset(-100, 10),
      scale: 2,
      fitted: fitted,
      viewport: viewport,
    );
    expect(r.offset.dx, -400);
    expect(r.excessX, -50);
  });

  test('wheelFactor zooms in on scroll up and out on scroll down', () {
    expect(ZoomMath.wheelFactor(-100, 0.0015), greaterThan(1));
    expect(ZoomMath.wheelFactor(100, 0.0015), lessThan(1));
    expect(ZoomMath.wheelFactor(0, 0.0015), 1);
  });

  test('dismiss rules', () {
    expect(ZoomMath.dismissProgress(const Offset(0, 240), viewport), 1);
    expect(ZoomMath.dismissProgress(Offset.zero, viewport), 0);
    expect(
        ZoomMath.shouldDismiss(const Offset(0, 150), Offset.zero,
            distance: 110, minVelocity: 800),
        isTrue);
    expect(
        ZoomMath.shouldDismiss(const Offset(0, 30), const Offset(0, 1500),
            distance: 110, minVelocity: 800),
        isTrue);
    // A fling back towards the start does not dismiss.
    expect(
        ZoomMath.shouldDismiss(const Offset(0, 30), const Offset(0, -1500),
            distance: 110, minVelocity: 800),
        isFalse);
    expect(
        ZoomMath.shouldDismiss(const Offset(0, 30), const Offset(0, 100),
            distance: 110, minVelocity: 800),
        isFalse);
  });

  test('settlePage follows velocity, otherwise rounds', () {
    expect(ZoomMath.settlePage(0.3, 0, count: 3), 0);
    expect(ZoomMath.settlePage(0.6, 0, count: 3), 1);
    expect(ZoomMath.settlePage(0.2, -900, count: 3), 1);
    expect(ZoomMath.settlePage(0.8, 900, count: 3), 0);
    expect(ZoomMath.settlePage(2.4, -900, count: 3), 2);
  });
}
