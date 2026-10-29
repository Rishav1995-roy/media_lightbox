import 'package:flutter/material.dart';
import 'package:media_lightbox/media_lightbox.dart';

import 'gallery_demo.dart';
import 'sample_images.dart';

/// Every option of [LightboxOptions] you can try live.
class CustomizeDemoPage extends StatefulWidget {
  const CustomizeDemoPage({super.key, required this.photos});

  final List<SamplePhoto> photos;

  @override
  State<CustomizeDemoPage> createState() => _CustomizeDemoPageState();
}

class _CustomizeDemoPageState extends State<CustomizeDemoPage> {
  double _maxScale = 4;
  bool _elastic = true;
  bool _doubleTap = true;
  List<double> _steps = _stepOptions.values.first;
  WheelZoomBehavior _wheel = WheelZoomBehavior.always;
  bool _dismiss = true;
  bool _thumbs = true;
  bool _captions = true;
  bool _counter = true;
  bool _toggleChrome = true;
  double _gap = 12;
  int _themeIndex = 0;

  static const _stepOptions = <String, List<double>>{
    'Toggle 1x / 2.5x': [1.0, 2.5],
    'Three steps 1x / 2x / 4x': [1.0, 2.0, 4.0],
    'Always 3x': [1.0, 3.0],
  };

  static const _themes = <String, LightboxTheme>{
    'Dark': LightboxTheme(),
    'Sepia': LightboxTheme(
      backgroundColor: Color(0xFF2B2118),
      foregroundColor: Color(0xFFF5E6CF),
      scrimColor: Color(0xCC2B2118),
      activeThumbnailColor: Color(0xFFE0A458),
      thumbnailRadius: 14,
    ),
    'Midnight blue': LightboxTheme(
      backgroundColor: Color(0xFF0A1128),
      foregroundColor: Color(0xFFBFD4FF),
      scrimColor: Color(0xCC0A1128),
      activeThumbnailColor: Color(0xFF6C8CFF),
      thumbnailSize: 64,
      thumbnailRadius: 32,
    ),
  };

  LightboxOptions get _options => LightboxOptions(
        theme: _themes.values.elementAt(_themeIndex),
        maxScale: _maxScale,
        elasticZoom: _elastic,
        enableDoubleTap: _doubleTap,
        doubleTapScales: _steps,
        wheelZoom: _wheel,
        enableDismissGesture: _dismiss,
        showThumbnails: _thumbs,
        showCaptions: _captions,
        showCounter: _counter,
        toggleChromeOnTap: _toggleChrome,
        pageGap: _gap,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customize')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Theme', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [
              for (var i = 0; i < _themes.length; i++)
                ButtonSegment(value: i, label: Text(_themes.keys.elementAt(i))),
            ],
            selected: {_themeIndex},
            onSelectionChanged: (s) => setState(() => _themeIndex = s.first),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Max zoom: ${_maxScale.toStringAsFixed(1)}x'),
            subtitle: Slider(
              value: _maxScale,
              min: 1.5,
              max: 8,
              onChanged: (v) => setState(() => _maxScale = v),
            ),
          ),
          const Text('Double-tap steps'),
          DropdownButton<List<double>>(
            isExpanded: true,
            value: _steps,
            items: [
              for (final e in _stepOptions.entries)
                DropdownMenuItem(value: e.value, child: Text(e.key)),
            ],
            onChanged: (v) => setState(() => _steps = v ?? _steps),
          ),
          const SizedBox(height: 12),
          const Text('Mouse wheel'),
          DropdownButton<WheelZoomBehavior>(
            isExpanded: true,
            value: _wheel,
            items: const [
              DropdownMenuItem(value: WheelZoomBehavior.always, child: Text('Always zooms')),
              DropdownMenuItem(value: WheelZoomBehavior.withModifier, child: Text('Zooms with Ctrl / Cmd')),
              DropdownMenuItem(value: WheelZoomBehavior.never, child: Text('Ignored')),
            ],
            onChanged: (v) => setState(() => _wheel = v ?? _wheel),
          ),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Elastic pinch (springs back)'), value: _elastic, onChanged: (v) => setState(() => _elastic = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Double tap zoom'), value: _doubleTap, onChanged: (v) => setState(() => _doubleTap = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Swipe to dismiss'), value: _dismiss, onChanged: (v) => setState(() => _dismiss = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Thumbnail strip'), value: _thumbs, onChanged: (v) => setState(() => _thumbs = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Captions'), value: _captions, onChanged: (v) => setState(() => _captions = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Counter'), value: _counter, onChanged: (v) => setState(() => _counter = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Tap toggles overlay'), value: _toggleChrome, onChanged: (v) => setState(() => _toggleChrome = v)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Gap between pages: ${_gap.round()} px'),
            subtitle: Slider(value: _gap, min: 0, max: 40, onChanged: (v) => setState(() => _gap = v)),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_full),
            label: const Text('Open with these options'),
            onPressed: () => Lightbox.open(
              context,
              items: itemsFor(widget.photos),
              options: _options,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.brush),
            label: const Text('Open with a fully custom overlay'),
            onPressed: () => Lightbox.open(
              context,
              items: itemsFor(widget.photos),
              options: LightboxOptions(
                theme: _themes.values.elementAt(_themeIndex),
                overlayBuilder: (context, value, controller) => SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.chevron_left), onPressed: controller.previous),
                              Text('${value.index + 1}/${value.count}  ${value.zoomScale.toStringAsFixed(1)}x'),
                              IconButton(icon: const Icon(Icons.chevron_right), onPressed: controller.next),
                              IconButton(icon: const Icon(Icons.zoom_out_map), onPressed: controller.resetZoom),
                              IconButton(icon: const Icon(Icons.close), onPressed: controller.close),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
