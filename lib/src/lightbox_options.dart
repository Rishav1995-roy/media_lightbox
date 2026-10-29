import 'package:flutter/widgets.dart';

import 'lightbox_controller.dart';
import 'lightbox_item.dart';
import 'lightbox_theme.dart';
import 'zoomable_view.dart';

/// Builds a full replacement of the overlay (top bar, caption, thumbnails).
typedef LightboxOverlayBuilder = Widget Function(
    BuildContext context, LightboxValue value, LightboxController controller);

/// Builds the caption area of the default overlay.
typedef LightboxCaptionBuilder = Widget? Function(
    BuildContext context, LightboxItem item, LightboxValue value);

/// Builds one thumbnail of the strip.
typedef LightboxThumbnailBuilder = Widget Function(
    BuildContext context, LightboxItem item, int index, bool selected);

/// Wraps or replaces the content of a page. [defaultPage] is what the package
/// would show (zoom layer included).
typedef LightboxPageBuilder = Widget Function(
    BuildContext context, LightboxItem item, int index, Widget defaultPage);

/// Builds the error state of an image page.
typedef LightboxErrorBuilder = Widget Function(
    BuildContext context, Object error);

/// Everything configurable about a gallery besides its items.
@immutable
class LightboxOptions {
  /// Creates options. All fields have sensible defaults.
  const LightboxOptions({
    this.theme = const LightboxTheme(),
    this.minScale = 1,
    this.maxScale = 4,
    this.doubleTapScales = const [1, 2.5],
    this.enableDoubleTap = true,
    this.elasticZoom = true,
    this.wheelZoom = WheelZoomBehavior.always,
    this.wheelSensitivity = 0.0015,
    this.enableDismissGesture = true,
    this.dismissDistance = 110,
    this.dismissVelocity = 800,
    this.enableKeyboard = true,
    this.toggleChromeOnTap = true,
    this.showCounter = true,
    this.showCloseButton = true,
    this.showCaptions = true,
    this.showThumbnails = false,
    this.pageGap = 12,
    this.onPageChanged,
    this.onDismiss,
    this.overlayBuilder,
    this.topBarBuilder,
    this.captionBuilder,
    this.thumbnailBuilder,
    this.pageBuilder,
    this.loadingBuilder,
    this.errorBuilder,
  })  : assert(minScale > 0),
        assert(maxScale >= minScale);

  /// Look of the default chrome.
  final LightboxTheme theme;

  /// Smallest zoom (1 = fit to screen).
  final double minScale;

  /// Largest zoom, relative to the fit size.
  final double maxScale;

  /// Scales a double tap cycles through, zooming to the tapped point.
  final List<double> doubleTapScales;

  /// Whether double tap / double click zooms.
  final bool enableDoubleTap;

  /// Lets a pinch overshoot the limits and spring back. With false the limits
  /// are strict at every moment.
  final bool elasticZoom;

  /// Mouse-wheel behaviour.
  final WheelZoomBehavior wheelZoom;

  /// Scale change per scrolled pixel for wheel zoom.
  final double wheelSensitivity;

  /// Drag down (or up) at fit size to close.
  final bool enableDismissGesture;

  /// Drag distance (logical px) after which releasing closes.
  final double dismissDistance;

  /// Fling velocity (px/s) that closes regardless of distance.
  final double dismissVelocity;

  /// Arrow keys, Escape, +, -, 0, Home and End.
  final bool enableKeyboard;

  /// A single tap shows/hides the overlay.
  final bool toggleChromeOnTap;

  /// Show the "1 / N" counter in the default top bar.
  final bool showCounter;

  /// Show the close button in the default top bar.
  final bool showCloseButton;

  /// Show captions in the default overlay.
  final bool showCaptions;

  /// Show the thumbnail strip in the default overlay.
  final bool showThumbnails;

  /// Gap between pages while swiping.
  final double pageGap;

  /// Called when the page changes.
  final ValueChanged<int>? onPageChanged;

  /// Replaces the default close action (`Navigator.maybePop`). Use it when the
  /// gallery is embedded rather than opened with `Lightbox.open`.
  final VoidCallback? onDismiss;

  /// Replaces the whole default overlay.
  final LightboxOverlayBuilder? overlayBuilder;

  /// Replaces the default top bar (close button + counter).
  final LightboxOverlayBuilder? topBarBuilder;

  /// Replaces the default caption.
  final LightboxCaptionBuilder? captionBuilder;

  /// Replaces the default thumbnail.
  final LightboxThumbnailBuilder? thumbnailBuilder;

  /// Wraps or replaces each page.
  final LightboxPageBuilder? pageBuilder;

  /// Shown while an image loads.
  final WidgetBuilder? loadingBuilder;

  /// Shown when an image fails to load.
  final LightboxErrorBuilder? errorBuilder;
}
