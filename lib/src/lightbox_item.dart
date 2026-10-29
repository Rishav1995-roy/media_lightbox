import 'package:flutter/widgets.dart';

/// Information passed to a custom media page builder.
class LightboxPageInfo {
  /// Creates page info.
  const LightboxPageInfo({required this.index, required this.isActive});

  /// Index of the page in the gallery.
  final int index;

  /// True while this page is the one the user is looking at. Use it to start
  /// or pause playback in a custom (for example video) page.
  final bool isActive;
}

/// Builds the content of a custom page.
typedef LightboxPageContentBuilder = Widget Function(
    BuildContext context, LightboxPageInfo info);

/// One entry of a [LightboxGallery]: plain data, either an image or a custom
/// widget.
@immutable
class LightboxItem {
  /// An item that shows [image] (any [ImageProvider]: asset, file, memory,
  /// network, `CachedNetworkImageProvider`, ...).
  const LightboxItem.image(
    ImageProvider this.image, {
    this.heroTag,
    this.caption,
    this.thumbnail,
    this.size,
    this.semanticLabel,
    this.data,
  })  : builder = null,
        zoomable = true;

  /// An item whose content is built by [builder], for example a video player,
  /// a map or a drawing. The package has no dependency on any video package.
  ///
  /// Set [zoomable] to false for content that needs its own gestures (a video
  /// with controls): paging, tap and swipe-to-dismiss still work.
  const LightboxItem.custom({
    required LightboxPageContentBuilder this.builder,
    this.heroTag,
    this.caption,
    this.thumbnail,
    this.size,
    this.semanticLabel,
    this.zoomable = true,
    this.data,
  }) : image = null;

  /// The image, for image items.
  final ImageProvider? image;

  /// The builder, for custom items.
  final LightboxPageContentBuilder? builder;

  /// Hero tag. Give the thumbnail in your grid the same tag to get a Hero
  /// transition; null disables it for this item.
  final Object? heroTag;

  /// Caption shown by the default overlay.
  final String? caption;

  /// Image used in the thumbnail strip (and as the Hero placeholder while the
  /// full image loads). Falls back to [image].
  final ImageProvider? thumbnail;

  /// Intrinsic size hint. For custom items it defines the aspect ratio that
  /// is fitted into the screen; for images it is used until the image has
  /// loaded.
  final Size? size;

  /// Accessibility label.
  final String? semanticLabel;

  /// Whether pinch, double-tap and wheel zoom are enabled for this item.
  final bool zoomable;

  /// Anything you want to carry along (a model id, a URL, ...).
  final Object? data;
}

/// A read-only snapshot of the gallery state, handed to builders.
@immutable
class LightboxValue {
  /// Creates a snapshot.
  const LightboxValue({
    required this.index,
    required this.count,
    required this.item,
    required this.zoomScale,
    required this.chromeVisible,
    required this.dismissProgress,
  });

  /// Current page.
  final int index;

  /// Number of pages.
  final int count;

  /// Current item.
  final LightboxItem item;

  /// Zoom factor of the current page (1 = fit).
  final double zoomScale;

  /// Whether the overlay is shown.
  final bool chromeVisible;

  /// 0..1 progress of a swipe-to-dismiss drag in flight.
  final double dismissProgress;

  /// Whether the current page is zoomed in.
  bool get isZoomed => zoomScale > 1.001;
}
