import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// Implemented by the gallery state so a [LightboxController] can drive it.
/// Not for application code.
abstract class LightboxControllerHost {
  /// Jumps to [index].
  void jumpToPage(int index);

  /// Animates to [index].
  Future<void> animateToPage(int index, Duration duration, Curve curve);

  /// Resets the zoom of the current page.
  void resetZoom({bool animate = true});

  /// Zooms the current page.
  void zoomTo(double scale, {Offset? focal, bool animate = true});

  /// Shows or hides the overlay.
  void setChromeVisible(bool visible);

  /// Closes the gallery.
  void close();
}

/// Controls and observes a `LightboxGallery`. Notifies on page, zoom and
/// overlay changes.
class LightboxController extends ChangeNotifier {
  /// Creates a controller. [initialIndex] is used when the gallery is created
  /// without its own `initialIndex`.
  LightboxController({int initialIndex = 0}) : _index = initialIndex;

  LightboxControllerHost? _host;
  int _index;
  double _zoomScale = 1;
  bool _chromeVisible = true;
  int _count = 0;

  /// Current page index.
  int get index => _index;

  /// Number of pages (0 until attached).
  int get count => _count;

  /// Zoom factor of the current page.
  double get zoomScale => _zoomScale;

  /// Whether the current page is zoomed in.
  bool get isZoomed => _zoomScale > 1.001;

  /// Whether the overlay is shown.
  bool get chromeVisible => _chromeVisible;

  /// Whether a gallery is attached.
  bool get isAttached => _host != null;

  /// Jumps to a page without animation.
  void jumpToPage(int index) => _host?.jumpToPage(index);

  /// Animates to a page.
  Future<void> animateToPage(
    int index, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
  }) =>
      _host?.animateToPage(index, duration, curve) ?? Future<void>.value();

  /// Goes to the next page, if any.
  Future<void> next() => animateToPage(_index + 1);

  /// Goes to the previous page, if any.
  Future<void> previous() => animateToPage(_index - 1);

  /// Resets the zoom of the current page.
  void resetZoom({bool animate = true}) => _host?.resetZoom(animate: animate);

  /// Zooms the current page to [scale] around [focal] (default: centre).
  void zoomTo(double scale, {Offset? focal, bool animate = true}) =>
      _host?.zoomTo(scale, focal: focal, animate: animate);

  /// Shows or hides the overlay.
  void setChromeVisible(bool visible) => _host?.setChromeVisible(visible);

  /// Toggles the overlay.
  void toggleChrome() => setChromeVisible(!_chromeVisible);

  /// Closes the gallery (pops the route when opened with `Lightbox.open`).
  void close() => _host?.close();

  /// Called by the gallery. Not for application code.
  void attach(LightboxControllerHost host,
      {required int index, required int count}) {
    _host = host;
    _index = index;
    _count = count;
  }

  /// Called by the gallery. Not for application code.
  void detach(LightboxControllerHost host) {
    if (_host == host) _host = null;
  }

  /// Called by the gallery to publish its state. Not for application code.
  void sync({int? index, int? count, double? zoomScale, bool? chromeVisible}) {
    final changed = (index != null && index != _index) ||
        (count != null && count != _count) ||
        (zoomScale != null && zoomScale != _zoomScale) ||
        (chromeVisible != null && chromeVisible != _chromeVisible);
    _index = index ?? _index;
    _count = count ?? _count;
    _zoomScale = zoomScale ?? _zoomScale;
    _chromeVisible = chromeVisible ?? _chromeVisible;
    if (changed) notifyListeners();
  }
}
