import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:media_lightbox/media_lightbox.dart';

import 'sample_images.dart';

/// A stand-in for a video player: an animated painting that plays only while
/// its page is the active one. The package has no video dependency, any
/// widget can be a page (video_player, chewie, a map, a chart ...).
class FakeVideoPage extends StatefulWidget {
  const FakeVideoPage({super.key, required this.isActive});

  final bool isActive;

  @override
  State<FakeVideoPage> createState() => _FakeVideoPageState();
}

class _FakeVideoPageState extends State<FakeVideoPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));
  bool _userPaused = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(FakeVideoPage old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.isActive && !_userPaused) {
      _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() {
        _userPaused = !_userPaused;
        _sync();
      }),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(painter: _WavePainter(_c.value)),
          ),
          Center(
            child: AnimatedOpacity(
              opacity: _userPaused || !widget.isActive ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: const CircleAvatar(
                radius: 32,
                backgroundColor: Colors.black54,
                child: Icon(Icons.play_arrow, color: Colors.white, size: 40),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1B1F3B), Color(0xFF3F2E6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
    for (var k = 0; k < 5; k++) {
      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width; x += 8) {
        final y = size.height * (0.5 + k * 0.08) +
            math.sin((x / size.width) * 6.28 * (1 + k * 0.4) + t * 6.28) * 28;
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
          path, Paint()..color = Color.lerp(const Color(0xFF7C5CFF), const Color(0xFFFF7A9A), k / 4)!.withValues(alpha: 0.35));
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.t != t;
}

class CustomPageDemo extends StatelessWidget {
  const CustomPageDemo({super.key, required this.photos});

  final List<SamplePhoto> photos;

  @override
  Widget build(BuildContext context) {
    final items = <LightboxItem>[
      LightboxItem.image(photos[0].image, caption: 'A normal image page', heroTag: 'mix-0'),
      // Not zoomable: the page keeps its own gestures (tap = play/pause), but
      // swiping between pages and swipe-down-to-dismiss still work.
      LightboxItem.custom(
        zoomable: false,
        size: const Size(16, 9),
        caption: 'A custom page (stand-in for a video player)',
        builder: (context, info) => FakeVideoPage(isActive: info.isActive),
      ),
      LightboxItem.image(photos[3].image, caption: 'Back to an image', heroTag: 'mix-2'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Mixed media')),
      body: Center(
        child: FilledButton.icon(
          icon: const Icon(Icons.collections),
          label: const Text('Open image + custom page + image'),
          onPressed: () => Lightbox.open(context, items: items),
        ),
      ),
    );
  }
}
