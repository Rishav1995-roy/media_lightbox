import 'dart:math' as math;
import 'package:flutter/painting.dart';

/// Pure geometry used by the zoom layer. No widgets, easy to unit test.
///
/// Model: the content is laid out centred in the viewport at "fit" size and
/// drawn with `translate(offset) * scale` about the viewport centre, so a
/// viewport point `p` shows the content point `(p - c - t) / s`.
class ZoomMath {
  const ZoomMath._();

  /// Size of [content] after being fitted inside [viewport] with
  /// [BoxFit.contain]. An empty [content] fills the viewport.
  static Size fitContain(Size content, Size viewport) {
    if (content.isEmpty || viewport.isEmpty) return viewport;
    return applyBoxFit(BoxFit.contain, content, viewport).destination;
  }

  /// Largest allowed translation magnitude per axis at [scale].
  static Offset maxOffset(double scale, Size fitted, Size viewport) {
    return Offset(
      math.max(0, (fitted.width * scale - viewport.width) / 2),
      math.max(0, (fitted.height * scale - viewport.height) / 2),
    );
  }

  /// Clamps [offset] so the content never leaves a gap inside the viewport.
  static Offset clampOffset(
      Offset offset, double scale, Size fitted, Size viewport) {
    final m = maxOffset(scale, fitted, viewport);
    return Offset(
      offset.dx.clamp(-m.dx, m.dx).toDouble(),
      offset.dy.clamp(-m.dy, m.dy).toDouble(),
    );
  }

  /// New translation after changing the scale from [oldScale] to [newScale]
  /// while keeping the content point under [focal] (viewport coordinates)
  /// fixed. Not clamped.
  static Offset zoomAround({
    required Offset offset,
    required double oldScale,
    required double newScale,
    required Offset focal,
    required Size viewport,
  }) {
    final c = viewport.center(Offset.zero);
    final f = focal - c;
    return f - (f - offset) * (newScale / oldScale);
  }

  /// Content point (relative to the content centre, unscaled) shown at
  /// viewport point [p].
  static Offset contentPointAt(
      Offset p, Offset offset, double scale, Size viewport) {
    return (p - viewport.center(Offset.zero) - offset) / scale;
  }

  /// Next double-tap scale: the first step larger than [current], or the first
  /// step again once the last one is reached.
  static double nextStep(double current, List<double> steps) {
    assert(steps.isNotEmpty);
    for (final s in steps) {
      if (s > current + 0.01) return s;
    }
    return steps.first;
  }

  /// Applies a pan of [delta] and reports how much horizontal motion could not
  /// be used because an edge was reached (`excessX`, same sign as the refused
  /// part of [delta]).
  static ({Offset offset, double excessX}) panBy({
    required Offset offset,
    required Offset delta,
    required double scale,
    required Size fitted,
    required Size viewport,
  }) {
    final raw = offset + delta;
    final clamped = clampOffset(raw, scale, fitted, viewport);
    return (offset: clamped, excessX: raw.dx - clamped.dx);
  }

  /// Scale limits during a gesture. With [elastic] the user may pull a little
  /// past the limits (the caller springs back on release); otherwise the
  /// limits are strict.
  static double limitScale(
    double scale,
    double min,
    double max, {
    required bool elastic,
  }) {
    if (!elastic) return scale.clamp(min, max).toDouble();
    return scale.clamp(min * 0.8, max * 1.25).toDouble();
  }

  /// Scale factor for a mouse-wheel / scroll delta (pixels, positive = down).
  static double wheelFactor(double scrollDy, double sensitivity) =>
      math.exp(-scrollDy * sensitivity);

  /// 0..1 progress of a swipe-to-dismiss drag.
  static double dismissProgress(Offset drag, Size viewport) {
    if (viewport.isEmpty) return 0;
    return (drag.dy.abs() / (viewport.height * 0.4)).clamp(0.0, 1.0);
  }

  /// Whether a drag ending with [velocity] (px/s) should close the gallery.
  static bool shouldDismiss(
    Offset drag,
    Offset velocity, {
    required double distance,
    required double minVelocity,
  }) {
    if (drag.dy.abs() >= distance) return true;
    return velocity.dy.abs() >= minVelocity && velocity.dy.sign == drag.dy.sign;
  }

  /// Page to settle on after a horizontal hand-off ends. [page] is the
  /// fractional page position, [velocityX] the finger velocity (px/s, positive
  /// = moving right, i.e. towards the previous page).
  static int settlePage(
    double page,
    double velocityX, {
    required int count,
    double minVelocity = 300,
  }) {
    final int target;
    if (velocityX.abs() >= minVelocity) {
      target = velocityX > 0 ? page.floor() : page.ceil();
    } else {
      target = page.round();
    }
    return target.clamp(0, count - 1);
  }
}
