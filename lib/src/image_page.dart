import 'package:flutter/material.dart';

import 'lightbox_item.dart';
import 'lightbox_options.dart';

/// Content of one page: resolves the image size (for exact pan limits and a
/// distortion-free Hero) and draws the image or the custom builder output.
class LightboxContent extends StatefulWidget {
  const LightboxContent({
    super.key,
    required this.item,
    required this.info,
    required this.options,
    required this.onSize,
  });

  final LightboxItem item;
  final LightboxPageInfo info;
  final LightboxOptions options;

  /// Reports the intrinsic size once known.
  final ValueChanged<Size> onSize;

  @override
  State<LightboxContent> createState() => _LightboxContentState();
}

class _LightboxContentState extends State<LightboxContent> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _size;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(LightboxContent old) {
    super.didUpdateWidget(old);
    if (old.item.image != widget.item.image) _resolve();
  }

  void _resolve() {
    final provider = widget.item.image;
    if (provider == null) return;
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _unlisten();
    _error = null;
    _size = widget.item.size;
    _stream = stream;
    _listener = ImageStreamListener((info, sync) {
      final s = Size(info.image.width.toDouble(), info.image.height.toDouble());
      _size = s;
      widget.onSize(s);
      if (!sync && mounted) setState(() {});
    }, onError: (e, st) {
      _error = e;
      if (mounted) setState(() {});
    });
    stream.addListener(_listener!);
  }

  void _unlisten() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _unlisten();
    super.dispose();
  }

  Widget _hero(Widget child, ImageProvider? shuttle) {
    final tag = widget.item.heroTag;
    if (tag == null) return child;
    return Hero(
      tag: tag,
      flightShuttleBuilder: shuttle == null
          ? null
          : (context, animation, direction, from, to) =>
              Image(image: shuttle, fit: BoxFit.cover),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final builder = item.builder;
    if (builder != null) {
      final content = _hero(builder(context, widget.info), null);
      final size = item.size;
      if (size == null || size.isEmpty) return content;
      return Center(
        child: AspectRatio(
          aspectRatio: size.width / size.height,
          child: content,
        ),
      );
    }

    final provider = item.image!;
    if (_error != null) {
      return widget.options.errorBuilder?.call(context, _error!) ??
          Center(
            child: Icon(Icons.broken_image_outlined,
                color: widget.options.theme.foregroundColor, size: 48),
          );
    }
    final size = _size;
    if (size == null || size.isEmpty) {
      final loading = widget.options.loadingBuilder?.call(context) ??
          Center(
            child: CircularProgressIndicator(
                color: widget.options.theme.foregroundColor, strokeWidth: 2),
          );
      final thumb = item.thumbnail;
      if (item.heroTag != null && thumb != null) {
        return Stack(fit: StackFit.expand, children: [
          _hero(Image(image: thumb, fit: BoxFit.contain), thumb),
          loading,
        ]);
      }
      return loading;
    }
    return Center(
      child: AspectRatio(
        aspectRatio: size.width / size.height,
        child: _hero(
          Semantics(
            image: true,
            label: item.semanticLabel ?? item.caption,
            child: Image(
              image: provider,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
            ),
          ),
          provider,
        ),
      ),
    );
  }
}
