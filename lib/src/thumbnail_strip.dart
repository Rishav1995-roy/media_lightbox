import 'package:flutter/material.dart';

import 'lightbox_item.dart';
import 'lightbox_options.dart';

/// Horizontal strip of thumbnails that keeps the selected one centred.
class ThumbnailStrip extends StatefulWidget {
  const ThumbnailStrip({
    super.key,
    required this.items,
    required this.index,
    required this.options,
    required this.onSelect,
  });

  final List<LightboxItem> items;
  final int index;
  final LightboxOptions options;
  final ValueChanged<int> onSelect;

  @override
  State<ThumbnailStrip> createState() => _ThumbnailStripState();
}

class _ThumbnailStripState extends State<ThumbnailStrip> {
  final ScrollController _controller = ScrollController();

  double get _extent =>
      widget.options.theme.thumbnailSize +
      widget.options.theme.thumbnailSpacing;

  @override
  void didUpdateWidget(ThumbnailStrip old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _centre(animate: true);
  }

  void _centre({required bool animate}) {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    // The list is padded by half a viewport minus half an item on both sides,
    // so item i is centred at offset i * extent.
    final target = (widget.index * _extent).clamp(0.0, pos.maxScrollExtent);
    if (animate) {
      _controller.animateTo(target,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    } else {
      _controller.jumpTo(target);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.options.theme;
    return SizedBox(
      height: theme.thumbnailSize + 8,
      child: LayoutBuilder(builder: (context, c) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _controller.hasClients && _controller.offset == 0) {
            _centre(animate: false);
          }
        });
        return ListView.builder(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          itemExtent: _extent,
          padding: EdgeInsets.symmetric(
              horizontal: (c.maxWidth - _extent) / 2 < 0
                  ? 0
                  : (c.maxWidth - _extent) / 2),
          itemCount: widget.items.length,
          itemBuilder: (context, i) {
            final item = widget.items[i];
            final selected = i == widget.index;
            final child = widget.options.thumbnailBuilder
                    ?.call(context, item, i, selected) ??
                _defaultThumb(context, item, selected);
            return GestureDetector(
              onTap: () => widget.onSelect(i),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.only(right: theme.thumbnailSpacing),
                child: child,
              ),
            );
          },
        );
      }),
    );
  }

  Widget _defaultThumb(BuildContext context, LightboxItem item, bool selected) {
    final theme = widget.options.theme;
    final provider = item.thumbnail ?? item.image;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final radius = BorderRadius.circular(theme.thumbnailRadius);
    return Opacity(
      opacity: selected ? 1 : theme.inactiveThumbnailOpacity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: selected ? theme.activeThumbnailColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: provider == null
              ? ColoredBox(
                  color: Colors.white24,
                  child: Icon(Icons.play_arrow, color: theme.foregroundColor),
                )
              : Image(
                  image: ResizeImage.resizeIfNeeded(
                      (theme.thumbnailSize * dpr).round(), null, provider),
                  fit: BoxFit.cover,
                ),
        ),
      ),
    );
  }
}
