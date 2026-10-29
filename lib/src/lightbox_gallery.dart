import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'image_page.dart';
import 'lightbox_controller.dart';
import 'lightbox_item.dart';
import 'lightbox_options.dart';
import 'thumbnail_strip.dart';
import 'zoom_math.dart';
import 'zoomable_view.dart';

/// A full-screen media gallery: zoom-aware paging, swipe-to-dismiss, Hero,
/// overlay, captions and thumbnails.
///
/// Normally opened with `Lightbox.open`; it can also be embedded anywhere
/// (give it a bounded size and set `LightboxOptions.onDismiss`).
class LightboxGallery extends StatefulWidget {
  /// Creates a gallery.
  const LightboxGallery({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.controller,
    this.options = const LightboxOptions(),
  });

  /// The pages.
  final List<LightboxItem> items;

  /// Page to start on.
  final int initialIndex;

  /// Optional controller to drive and observe the gallery.
  final LightboxController? controller;

  /// Everything configurable.
  final LightboxOptions options;

  @override
  State<LightboxGallery> createState() => _LightboxGalleryState();
}

class _LightboxGalleryState extends State<LightboxGallery>
    with SingleTickerProviderStateMixin
    implements LightboxControllerHost {
  late PageController _pages;
  late final AnimationController _backAnim;
  final ValueNotifier<Offset> _drag = ValueNotifier<Offset>(Offset.zero);
  final Map<int, ZoomableController> _zoom = <int, ZoomableController>{};
  late final FocusNode _focus = FocusNode(debugLabel: 'LightboxGallery');

  Offset _backFrom = Offset.zero;
  late int _index;
  double _zoomScale = 1;
  bool _chrome = true;
  Size _viewport = Size.zero;

  LightboxOptions get _o => widget.options;

  @override
  void initState() {
    super.initState();
    _backAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200))
      ..addListener(() {
        _drag.value = Offset.lerp(
            _backFrom, Offset.zero, Curves.easeOut.transform(_backAnim.value))!;
      });
    _index = _clampIndex(widget.initialIndex);
    _pages = PageController(initialPage: _index);
    widget.controller?.attach(this, index: _index, count: widget.items.length);
  }

  int _clampIndex(int i) =>
      widget.items.isEmpty ? 0 : i.clamp(0, widget.items.length - 1);

  @override
  void didUpdateWidget(LightboxGallery old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.detach(this);
      widget.controller
          ?.attach(this, index: _index, count: widget.items.length);
    }
    if (old.items.length != widget.items.length) {
      final i = _clampIndex(_index);
      if (i != _index) {
        _index = i;
        _pages.jumpToPage(i);
      }
      widget.controller?.sync(index: _index, count: widget.items.length);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach(this);
    _backAnim.dispose();
    _drag.dispose();
    _pages.dispose();
    _focus.dispose();
    for (final c in _zoom.values) {
      c.dispose();
    }
    super.dispose();
  }

  ZoomableController _zoomFor(int i) =>
      _zoom.putIfAbsent(i, ZoomableController.new);

  // ---------------------------------------------------------- host interface

  @override
  void jumpToPage(int index) => _pages.jumpToPage(_clampIndex(index));

  @override
  Future<void> animateToPage(int index, Duration duration, Curve curve) {
    final i = _clampIndex(index);
    if (!_pages.hasClients) return Future<void>.value();
    return _pages.animateToPage(i, duration: duration, curve: curve);
  }

  @override
  void resetZoom({bool animate = true}) =>
      _zoom[_index]?.reset(animate: animate);

  @override
  void zoomTo(double scale, {Offset? focal, bool animate = true}) =>
      _zoom[_index]?.zoomTo(scale, focal: focal, animate: animate);

  @override
  void setChromeVisible(bool visible) {
    if (visible == _chrome) return;
    setState(() => _chrome = visible);
    widget.controller?.sync(chromeVisible: visible);
  }

  @override
  void close() {
    final cb = _o.onDismiss;
    if (cb != null) {
      cb();
    } else {
      Navigator.of(context).maybePop(_index);
    }
  }

  // ------------------------------------------------------------- page events

  void _onPageChanged(int i) {
    setState(() {
      _index = i;
      _zoomScale = _zoom[i]?.scale ?? 1;
    });
    widget.controller?.sync(index: i, zoomScale: _zoomScale);
    _o.onPageChanged?.call(i);
  }

  void _onScale(int page, double s) {
    if (page != _index) return;
    setState(() => _zoomScale = s);
    widget.controller?.sync(zoomScale: s);
  }

  void _onOverscroll(double dx) {
    if (!_pages.hasClients) return;
    final pos = _pages.position;
    pos.jumpTo(
        (pos.pixels - dx).clamp(pos.minScrollExtent, pos.maxScrollExtent));
  }

  void _onOverscrollEnd(double vx) {
    if (!_pages.hasClients) return;
    final target = ZoomMath.settlePage(
      _pages.page ?? _index.toDouble(),
      vx,
      count: widget.items.length,
    );
    _pages.animateToPage(target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic);
  }

  void _onDismissUpdate(Offset total) {
    if (_backAnim.isAnimating) _backAnim.stop();
    _drag.value = total;
  }

  void _onDismissEnd(Offset velocity) {
    final close = ZoomMath.shouldDismiss(
      _drag.value,
      velocity,
      distance: _o.dismissDistance,
      minVelocity: _o.dismissVelocity,
    );
    if (close) {
      this.close();
    } else {
      _backFrom = _drag.value;
      _backAnim.forward(from: 0);
    }
  }

  void _onTap() {
    if (_o.toggleChromeOnTap) setChromeVisible(!_chrome);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (!_o.enableKeyboard || e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.pageDown) {
      animateToPage(
          _index + 1, const Duration(milliseconds: 260), Curves.easeOutCubic);
    } else if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.pageUp) {
      animateToPage(
          _index - 1, const Duration(milliseconds: 260), Curves.easeOutCubic);
    } else if (k == LogicalKeyboardKey.home) {
      animateToPage(0, const Duration(milliseconds: 260), Curves.easeOutCubic);
    } else if (k == LogicalKeyboardKey.end) {
      animateToPage(widget.items.length - 1, const Duration(milliseconds: 260),
          Curves.easeOutCubic);
    } else if (k == LogicalKeyboardKey.escape) {
      close();
    } else if (k == LogicalKeyboardKey.equal ||
        k == LogicalKeyboardKey.add ||
        k == LogicalKeyboardKey.numpadAdd) {
      zoomTo(_zoomScale * 1.5);
    } else if (k == LogicalKeyboardKey.minus ||
        k == LogicalKeyboardKey.numpadSubtract) {
      zoomTo(_zoomScale / 1.5);
    } else if (k == LogicalKeyboardKey.digit0 ||
        k == LogicalKeyboardKey.numpad0) {
      resetZoom();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ------------------------------------------------------------------- build

  LightboxValue _value(double progress) => LightboxValue(
        index: _index,
        count: widget.items.length,
        item: widget.items[_index],
        zoomScale: _zoomScale,
        chromeVisible: _chrome,
        dismissProgress: progress,
      );

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final theme = _o.theme;
    final routeAnim =
        ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;

    // The PageView never takes drags itself: horizontal drags are read by the
    // zoom layer of the page (which also owns pinch and pan), then forwarded
    // to the page controller. See ZoomableView.onOverscroll.
    final pageView = PageView.builder(
      controller: _pages,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.items.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, i) => Padding(
        padding: EdgeInsets.symmetric(horizontal: _o.pageGap / 2),
        child: _buildPage(context, i),
      ),
    );

    return Focus(
      focusNode: _focus,
      autofocus: _o.enableKeyboard,
      onKeyEvent: _onKey,
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(builder: (context, c) {
          _viewport = c.biggest;
          return AnimatedBuilder(
            animation: Listenable.merge([_drag, routeAnim]),
            builder: (context, _) {
              final progress = ZoomMath.dismissProgress(_drag.value, _viewport);
              final fade = routeAnim.value.clamp(0.0, 1.0) * (1 - progress);
              return Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: theme.backgroundColor
                        .withValues(alpha: theme.backgroundColor.a * fade),
                  ),
                  Transform.translate(
                    offset: _drag.value,
                    child: Transform.scale(
                      scale: 1 - progress * 0.18,
                      child: pageView,
                    ),
                  ),
                  Opacity(
                    opacity: (routeAnim.value.clamp(0.0, 1.0) * (1 - progress)),
                    child: AnimatedOpacity(
                      opacity: _chrome ? 1 : 0,
                      duration: theme.chromeDuration,
                      child: IgnorePointer(
                        ignoring: !_chrome,
                        child: _buildChrome(context, progress),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildPage(BuildContext context, int i) {
    final item = widget.items[i];
    return _PageHost(
      key: ValueKey<int>(i),
      item: item,
      index: i,
      active: i == _index,
      options: _o,
      controller: _zoomFor(i),
      onScale: (s) => _onScale(i, s),
      onOverscroll: _onOverscroll,
      onOverscrollEnd: _onOverscrollEnd,
      onDismissUpdate: _onDismissUpdate,
      onDismissEnd: _onDismissEnd,
      onTap: _onTap,
    );
  }

  Widget _buildChrome(BuildContext context, double progress) {
    final value = _value(progress);
    final custom = _o.overlayBuilder;
    if (custom != null) {
      return custom(context, value, widget.controller ?? _fallbackController());
    }
    final theme = _o.theme;
    final controller = widget.controller ?? _fallbackController();
    final top = _o.topBarBuilder?.call(context, value, controller) ??
        _defaultTopBar(context, value);
    Widget? caption;
    if (_o.showCaptions) {
      caption = _o.captionBuilder != null
          ? _o.captionBuilder!(context, value.item, value)
          : _defaultCaption(context, value.item);
    }
    return SafeArea(
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.scrimColor,
                  theme.scrimColor.withValues(alpha: 0)
                ],
              ),
            ),
            child: Padding(padding: theme.chromePadding, child: top),
          ),
          const Spacer(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  theme.scrimColor,
                  theme.scrimColor.withValues(alpha: 0)
                ],
              ),
            ),
            child: Padding(
              padding: theme.chromePadding.copyWith(top: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (caption != null) caption,
                  if (_o.showThumbnails && widget.items.length > 1) ...[
                    const SizedBox(height: 10),
                    ThumbnailStrip(
                      items: widget.items,
                      index: _index,
                      options: _o,
                      onSelect: (i) => animateToPage(
                          i,
                          const Duration(milliseconds: 280),
                          Curves.easeOutCubic),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LightboxController? _fallback;
  LightboxController _fallbackController() {
    // Builders always get a controller; when the app did not pass one, expose
    // a view onto this gallery.
    return _fallback ??= LightboxController(initialIndex: _index)
      ..attach(this, index: _index, count: widget.items.length);
  }

  Widget _defaultTopBar(BuildContext context, LightboxValue v) {
    final theme = _o.theme;
    final style = theme.counterStyle ??
        TextStyle(
            color: theme.foregroundColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()]);
    return Row(
      children: [
        if (_o.showCloseButton)
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: Icon(theme.closeIcon, color: theme.foregroundColor),
            onPressed: close,
          )
        else
          const SizedBox(height: 48),
        const Spacer(),
        if (_o.showCounter && v.count > 1)
          Text('${v.index + 1} / ${v.count}', style: style),
        const Spacer(),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget? _defaultCaption(BuildContext context, LightboxItem item) {
    final text = item.caption;
    if (text == null || text.isEmpty) return null;
    final theme = _o.theme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.captionStyle ??
              TextStyle(
                  color: theme.foregroundColor, fontSize: 15, height: 1.3),
        ),
      ),
    );
  }
}

/// One page: size tracking + zoom layer. Keeps the intrinsic size in state so
/// the zoom layer has exact pan limits.
class _PageHost extends StatefulWidget {
  const _PageHost({
    super.key,
    required this.item,
    required this.index,
    required this.active,
    required this.options,
    required this.controller,
    required this.onScale,
    required this.onOverscroll,
    required this.onOverscrollEnd,
    required this.onDismissUpdate,
    required this.onDismissEnd,
    required this.onTap,
  });

  final LightboxItem item;
  final int index;
  final bool active;
  final LightboxOptions options;
  final ZoomableController controller;
  final ValueChanged<double> onScale;
  final ValueChanged<double> onOverscroll;
  final ValueChanged<double> onOverscrollEnd;
  final ValueChanged<Offset> onDismissUpdate;
  final ValueChanged<Offset> onDismissEnd;
  final VoidCallback onTap;

  @override
  State<_PageHost> createState() => _PageHostState();
}

class _PageHostState extends State<_PageHost> {
  Size? _size;

  @override
  void initState() {
    super.initState();
    _size = widget.item.size;
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.options;
    final item = widget.item;
    final content = LightboxContent(
      item: item,
      info: LightboxPageInfo(index: widget.index, isActive: widget.active),
      options: o,
      onSize: (s) {
        if (_size == s) return;
        // Called from an image listener; defer so we never set state while
        // the framework is building.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _size = s);
        });
      },
    );
    // Images are laid out by AspectRatio inside the viewport, so the zoom layer
    // fits the same aspect ratio. Custom items fit [LightboxItem.size].
    final zoomable = ZoomableView(
      controller: widget.controller,
      contentSize: _size,
      minScale: o.minScale,
      maxScale: o.maxScale,
      doubleTapScales: o.doubleTapScales,
      enableDoubleTap: o.enableDoubleTap,
      zoomEnabled: item.zoomable,
      elastic: o.elasticZoom,
      wheelBehavior: o.wheelZoom,
      wheelSensitivity: o.wheelSensitivity,
      dismissEnabled: o.enableDismissGesture,
      onTap: widget.onTap,
      onScaleChanged: widget.onScale,
      onOverscroll: widget.onOverscroll,
      onOverscrollEnd: widget.onOverscrollEnd,
      onDismissUpdate: widget.onDismissUpdate,
      onDismissEnd: widget.onDismissEnd,
      child: content,
    );
    return o.pageBuilder?.call(context, item, widget.index, zoomable) ??
        zoomable;
  }
}
