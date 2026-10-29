import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'zoom_math.dart';

/// How the mouse wheel (and trackpad scroll events that arrive as wheel
/// events, for example a browser pinch) reacts over a [ZoomableView].
enum WheelZoomBehavior {
  /// Every wheel notch zooms around the cursor.
  always,

  /// Zoom only while Ctrl or Cmd is held; otherwise the event is left to
  /// ancestors (for example a scrolling page).
  withModifier,

  /// Wheel events are ignored.
  never,
}

/// Reads and drives a [ZoomableView] from the outside.
class ZoomableController extends ChangeNotifier {
  double _scale = 1;
  Offset _offset = Offset.zero;
  ZoomableViewState? _state;

  /// Current zoom factor relative to the fitted content (1 = fit).
  double get scale => _scale;

  /// Current translation in logical pixels, relative to the centred position.
  Offset get offset => _offset;

  /// Whether the content is zoomed in beyond the fit size.
  bool get isZoomed => _scale > 1.001;

  /// Animates back to the fit size (or jumps if [animate] is false).
  void reset({bool animate = true}) =>
      _state?.animateTo(1, Offset.zero, animate: animate);

  /// Zooms to [scale] around [focal] (viewport coordinates, default centre).
  void zoomTo(double scale, {Offset? focal, bool animate = true}) =>
      _state?.zoomToScale(scale, focal: focal, animate: animate);

  void _attach(ZoomableViewState state) {
    _state = state;
    _scale = 1;
    _offset = Offset.zero;
  }

  void _detach(ZoomableViewState state) {
    if (_state != state) return;
    _state = null;
    _scale = 1;
    _offset = Offset.zero;
  }

  void _update(double scale, Offset offset) {
    if (scale == _scale && offset == _offset) return;
    _scale = scale;
    _offset = offset;
    notifyListeners();
  }
}

/// A zoom and pan surface for any widget.
///
/// Unlike an `InteractiveViewer`-based viewer it uses raw pointer events, so it
/// never competes with an ancestor `PageView` in the gesture arena. Instead it
/// reports how much horizontal motion it could not use ([onOverscroll]) so the
/// parent can move the page by exactly that amount.
///
/// Supports pinch, double-tap to a configurable list of scales (zooming to the
/// tapped point), mouse wheel zoom around the cursor, trackpad pinch/pan,
/// mouse drag and fling.
class ZoomableView extends StatefulWidget {
  /// Creates a zoomable surface.
  const ZoomableView({
    super.key,
    required this.child,
    this.contentSize,
    this.controller,
    this.minScale = 1,
    this.maxScale = 4,
    this.doubleTapScales = const [1, 2.5],
    this.enableDoubleTap = true,
    this.zoomEnabled = true,
    this.elastic = true,
    this.wheelBehavior = WheelZoomBehavior.always,
    this.wheelSensitivity = 0.0015,
    this.dismissEnabled = false,
    this.onTap,
    this.onScaleChanged,
    this.onPinchChanged,
    this.onOverscroll,
    this.onOverscrollEnd,
    this.onDismissUpdate,
    this.onDismissEnd,
  })  : assert(minScale > 0),
        assert(maxScale >= minScale);

  /// The content. It is laid out at the size of the viewport; use
  /// [contentSize] to tell the layer the real (intrinsic) aspect ratio.
  final Widget child;

  /// Intrinsic size of what [child] shows. It is fitted with `BoxFit.contain`
  /// to compute pan limits. Null means the content fills the viewport.
  final Size? contentSize;

  /// Optional external controller.
  final ZoomableController? controller;

  /// Smallest allowed scale. Strict unless [elastic] is true.
  final double minScale;

  /// Largest allowed scale. Strict unless [elastic] is true.
  final double maxScale;

  /// Scales a double tap cycles through (each relative to the fit size).
  final List<double> doubleTapScales;

  /// Whether double tap / double click zooms.
  final bool enableDoubleTap;

  /// Master switch for pinch, double tap and wheel zoom.
  final bool zoomEnabled;

  /// Allow pinching slightly past the limits and spring back on release.
  final bool elastic;

  /// Wheel behaviour.
  final WheelZoomBehavior wheelBehavior;

  /// Scale change per scrolled pixel (factor is `exp(-dy * sensitivity)`).
  final double wheelSensitivity;

  /// Report vertical drags at fit size through [onDismissUpdate].
  final bool dismissEnabled;

  /// Called for a confirmed single tap (not part of a double tap).
  final VoidCallback? onTap;

  /// Called whenever the scale changes.
  final ValueChanged<double>? onScaleChanged;

  /// Called when a two-finger gesture starts (true) and ends (false).
  final ValueChanged<bool>? onPinchChanged;

  /// Horizontal drag the content could not absorb (an edge was reached).
  /// Positive = finger moving right.
  final ValueChanged<double>? onOverscroll;

  /// Called when a drag that produced [onOverscroll] ends, with the finger's
  /// horizontal velocity in px/s.
  final ValueChanged<double>? onOverscrollEnd;

  /// Total drag since the start of a swipe-to-dismiss gesture.
  final ValueChanged<Offset>? onDismissUpdate;

  /// Swipe-to-dismiss gesture ended with this velocity (px/s).
  final ValueChanged<Offset>? onDismissEnd;

  @override
  State<ZoomableView> createState() => ZoomableViewState();
}

/// State of [ZoomableView]. Public only so [ZoomableController] can drive it.
class ZoomableViewState extends State<ZoomableView>
    with SingleTickerProviderStateMixin {
  static const double _eps = 0.001;
  static const Duration _doubleTapTimeout = Duration(milliseconds: 280);

  late final AnimationController _anim;

  double _scale = 1;
  Offset _offset = Offset.zero;
  Size _viewport = Size.zero;

  final Map<int, Offset> _pointers = <int, Offset>{};
  final Set<int> _ignored = <int>{};
  VelocityTracker _tracker = VelocityTracker.withKind(PointerDeviceKind.touch);
  Offset _downPos = Offset.zero;
  bool _moved = false;
  bool _pinching = false;
  bool _pinchedThisGesture = false;
  bool? _dismissMode;
  double _handoff = 0;
  double _lastDist = 1;
  Offset _lastFocal = Offset.zero;

  Timer? _pendingTap;
  Offset _lastTapPos = Offset.zero;

  double _pzLastScale = 1;
  Offset _pzLastPan = Offset.zero;

  double _tweenFromScale = 1;
  double _tweenToScale = 1;
  Offset _tweenFromOffset = Offset.zero;
  Offset _tweenToOffset = Offset.zero;
  Curve _tweenCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 240))
      ..addListener(_onAnimTick);
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(ZoomableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.controller != widget.controller) {
      old.controller?._detach(this);
      widget.controller?._attach(this);
      widget.controller?._update(_scale, _offset);
    }
    if (old.contentSize != widget.contentSize ||
        old.minScale != widget.minScale ||
        old.maxScale != widget.maxScale) {
      final s = _scale.clamp(widget.minScale, widget.maxScale).toDouble();
      _set(s, _clamp(_offset, s));
    }
  }

  @override
  void dispose() {
    _pendingTap?.cancel();
    _anim.dispose();
    widget.controller?._detach(this);
    super.dispose();
  }

  // ---------------------------------------------------------------- helpers

  Size get _fitted =>
      ZoomMath.fitContain(widget.contentSize ?? _viewport, _viewport);

  Offset _clamp(Offset o, double s) =>
      ZoomMath.clampOffset(o, s, _fitted, _viewport);

  void _set(double s, Offset o) {
    if (s == _scale && o == _offset) return;
    final scaleChanged = (s - _scale).abs() > 1e-9;
    setState(() {
      _scale = s;
      _offset = o;
    });
    widget.controller?._update(s, o);
    if (scaleChanged) widget.onScaleChanged?.call(s);
  }

  void _stopAnim() {
    if (_anim.isAnimating) _anim.stop();
  }

  void _onAnimTick() {
    final t = _tweenCurve.transform(_anim.value);
    _set(
      _tweenFromScale + (_tweenToScale - _tweenFromScale) * t,
      Offset.lerp(_tweenFromOffset, _tweenToOffset, t)!,
    );
  }

  /// Animates (or jumps) to a scale and translation.
  void animateTo(
    double scale,
    Offset offset, {
    bool animate = true,
    Duration? duration,
    Curve curve = Curves.easeOutCubic,
  }) {
    _stopAnim();
    final target = _clamp(offset, scale);
    if (!animate || _viewport.isEmpty) {
      _set(scale, target);
      return;
    }
    _tweenFromScale = _scale;
    _tweenToScale = scale;
    _tweenFromOffset = _offset;
    _tweenToOffset = target;
    _tweenCurve = curve;
    _anim.duration = duration ?? const Duration(milliseconds: 240);
    _anim.forward(from: 0);
  }

  /// Zooms to an absolute [scale] around [focal].
  void zoomToScale(double scale, {Offset? focal, bool animate = true}) {
    final s = scale.clamp(widget.minScale, widget.maxScale).toDouble();
    final f = focal ?? _viewport.center(Offset.zero);
    final o = ZoomMath.zoomAround(
      offset: _offset,
      oldScale: _scale,
      newScale: s,
      focal: f,
      viewport: _viewport,
    );
    animateTo(s, o, animate: animate);
  }

  void _zoomBy(double factor, Offset focal, {required bool elastic}) {
    final s = ZoomMath.limitScale(
      _scale * factor,
      widget.minScale,
      widget.maxScale,
      elastic: elastic,
    );
    final o = ZoomMath.zoomAround(
      offset: _offset,
      oldScale: _scale,
      newScale: s,
      focal: focal,
      viewport: _viewport,
    );
    _set(s, _clamp(o, s));
  }

  void _settleScale() {
    final s = _scale.clamp(widget.minScale, widget.maxScale).toDouble();
    if ((s - _scale).abs() > 1e-6) {
      final o = ZoomMath.zoomAround(
        offset: _offset,
        oldScale: _scale,
        newScale: s,
        focal: _viewport.center(Offset.zero),
        viewport: _viewport,
      );
      animateTo(s, o);
    }
  }

  // ---------------------------------------------------------------- pointers

  void _down(PointerDownEvent e) {
    if (e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryButton) {
      _ignored.add(e.pointer);
      return;
    }
    _stopAnim();
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1) {
      _tracker = VelocityTracker.withKind(e.kind)
        ..addPosition(e.timeStamp, e.localPosition);
      _downPos = e.localPosition;
      _moved = false;
      _pinchedThisGesture = false;
      _dismissMode = null;
      _handoff = 0;
    } else if (_pointers.length == 2 && widget.zoomEnabled) {
      _beginPinch();
    }
  }

  void _beginPinch() {
    if (_dismissMode == true) {
      widget.onDismissEnd?.call(Offset.zero);
    }
    _dismissMode = false;
    if (_handoff != 0) {
      widget.onOverscrollEnd?.call(0);
      _handoff = 0;
    }
    _pinching = true;
    _pinchedThisGesture = true;
    _moved = true;
    _pendingTap?.cancel();
    _pendingTap = null;
    final pts = _pointers.values.take(2).toList();
    _lastDist = math.max(1.0, (pts[0] - pts[1]).distance);
    _lastFocal = (pts[0] + pts[1]) / 2;
    widget.onPinchChanged?.call(true);
  }

  void _move(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1) {
      _tracker.addPosition(e.timeStamp, e.localPosition);
    }

    if (_pinching && _pointers.length >= 2) {
      final pts = _pointers.values.take(2).toList();
      final dist = math.max(1.0, (pts[0] - pts[1]).distance);
      final focal = (pts[0] + pts[1]) / 2;
      _zoomBy(dist / _lastDist, focal, elastic: widget.elastic);
      final panned = _clamp(_offset + (focal - _lastFocal), _scale);
      _set(_scale, panned);
      _lastDist = dist;
      _lastFocal = focal;
      return;
    }
    if (_pointers.length != 1 || _pinchedThisGesture) return;

    final pos = e.localPosition;
    if (!_moved && (pos - _downPos).distance > kTouchSlop) _moved = true;

    if (widget.zoomEnabled && _scale > 1 + _eps) {
      _panWithHandoff(e.localDelta);
      return;
    }
    // At fit size a single finger either dismisses (vertical) or pages
    // (horizontal). Both are handled here, not by a Scrollable, because a
    // Scrollable makes its subtree ignore pointers once a drag begins and a
    // second finger could then never start a pinch.
    if (_dismissMode == null && (pos - _downPos).distance > 10) {
      final d = pos - _downPos;
      final vertical = widget.dismissEnabled && d.dy.abs() > d.dx.abs() * 1.2;
      _dismissMode = vertical;
      if (!vertical && widget.onOverscroll != null) {
        _handoff += d.dx;
        widget.onOverscroll!(d.dx);
      }
      return;
    }
    if (_dismissMode == true) {
      widget.onDismissUpdate?.call(pos - _downPos);
    } else if (_dismissMode == false && widget.onOverscroll != null) {
      _handoff += e.localDelta.dx;
      widget.onOverscroll!(e.localDelta.dx);
    }
  }

  void _panWithHandoff(Offset delta) {
    var dx = delta.dx;
    // Dragging back first undoes any page displacement already handed off.
    if (_handoff != 0 && dx != 0 && dx.sign == -_handoff.sign) {
      final back = dx.abs() < _handoff.abs() ? dx : -_handoff;
      _handoff += back;
      widget.onOverscroll?.call(back);
      dx -= back;
    }
    final r = ZoomMath.panBy(
      offset: _offset,
      delta: Offset(dx, delta.dy),
      scale: _scale,
      fitted: _fitted,
      viewport: _viewport,
    );
    _set(_scale, r.offset);
    if (r.excessX != 0 && widget.onOverscroll != null) {
      _handoff += r.excessX;
      widget.onOverscroll!(r.excessX);
    }
  }

  void _up(PointerEvent e, {required bool cancelled}) {
    if (_ignored.remove(e.pointer)) return;
    if (!_pointers.containsKey(e.pointer)) return;
    if (_pointers.length == 1) {
      _tracker.addPosition(e.timeStamp, e.localPosition);
    }
    final wasPinching = _pinching;
    _pointers.remove(e.pointer);
    if (wasPinching && _pointers.length < 2) {
      _pinching = false;
      widget.onPinchChanged?.call(false);
      _settleScale();
    }
    if (_pointers.isNotEmpty) return;

    final velocity = _tracker.getVelocity().pixelsPerSecond;
    if (_handoff != 0) {
      widget.onOverscrollEnd?.call(cancelled ? 0 : velocity.dx);
      _handoff = 0;
    } else if (_dismissMode == true) {
      widget.onDismissEnd?.call(cancelled ? Offset.zero : velocity);
    } else if (!_pinchedThisGesture &&
        _moved &&
        _scale > 1 + _eps &&
        !cancelled) {
      _fling(velocity);
    } else if (!_moved && !_pinchedThisGesture && !cancelled) {
      _tap(e.localPosition);
    }
    _dismissMode = null;
  }

  void _fling(Offset velocity) {
    if (velocity.distance < 150) return;
    final target = _clamp(_offset + velocity * 0.22, _scale);
    animateTo(_scale, target,
        duration: const Duration(milliseconds: 420), curve: Curves.decelerate);
  }

  void _tap(Offset p) {
    if (widget.zoomEnabled && widget.enableDoubleTap) {
      if (_pendingTap != null && (p - _lastTapPos).distance < 100) {
        _pendingTap!.cancel();
        _pendingTap = null;
        _doubleTap(p);
        return;
      }
      _lastTapPos = p;
      _pendingTap = Timer(_doubleTapTimeout, () {
        _pendingTap = null;
        widget.onTap?.call();
      });
    } else {
      widget.onTap?.call();
    }
  }

  void _doubleTap(Offset p) {
    final steps = widget.doubleTapScales.isEmpty
        ? const [1.0, 2.5]
        : widget.doubleTapScales;
    final next = ZoomMath.nextStep(_scale, steps)
        .clamp(widget.minScale, widget.maxScale)
        .toDouble();
    final o = ZoomMath.zoomAround(
      offset: _offset,
      oldScale: _scale,
      newScale: next,
      focal: p,
      viewport: _viewport,
    );
    animateTo(next, o);
  }

  // ------------------------------------------------------- wheel / trackpad

  void _signal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || !widget.zoomEnabled) return;
    switch (widget.wheelBehavior) {
      case WheelZoomBehavior.never:
        return;
      case WheelZoomBehavior.withModifier:
        final kb = HardwareKeyboard.instance;
        if (!(kb.isControlPressed || kb.isMetaPressed)) return;
      case WheelZoomBehavior.always:
        break;
    }
    GestureBinding.instance.pointerSignalResolver.register(e, (event) {
      final ev = event as PointerScrollEvent;
      _stopAnim();
      _zoomBy(
        ZoomMath.wheelFactor(ev.scrollDelta.dy, widget.wheelSensitivity),
        ev.localPosition,
        elastic: false,
      );
    });
  }

  void _pzStart(PointerPanZoomStartEvent e) {
    _stopAnim();
    _pzLastScale = 1;
    _pzLastPan = Offset.zero;
  }

  void _pzUpdate(PointerPanZoomUpdateEvent e) {
    if (!widget.zoomEnabled) return;
    final factor = e.scale / _pzLastScale;
    if (factor != 1) _zoomBy(factor, e.localPosition, elastic: widget.elastic);
    final pan = e.pan - _pzLastPan;
    if (_scale > 1 + _eps && pan != Offset.zero) {
      _set(_scale, _clamp(_offset + pan, _scale));
    }
    _pzLastScale = e.scale;
    _pzLastPan = e.pan;
  }

  void _pzEnd(PointerPanZoomEndEvent e) => _settleScale();

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _viewport = constraints.biggest;
      final shown = _clamp(_offset, _scale);
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: (e) => _up(e, cancelled: false),
        onPointerCancel: (e) => _up(e, cancelled: true),
        onPointerSignal: _signal,
        onPointerPanZoomStart: _pzStart,
        onPointerPanZoomUpdate: _pzUpdate,
        onPointerPanZoomEnd: _pzEnd,
        child: ClipRect(
          child: MouseRegion(
            cursor:
                _scale > 1 + _eps ? SystemMouseCursors.grab : MouseCursor.defer,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4(_scale, 0, 0, 0, 0, _scale, 0, 0, 0, 0, 1, 0,
                  shown.dx, shown.dy, 0, 1),
              child: SizedBox.fromSize(size: _viewport, child: widget.child),
            ),
          ),
        ),
      );
    });
  }
}
