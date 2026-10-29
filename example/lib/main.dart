import 'package:flutter/material.dart';

import 'custom_demo.dart';
import 'customize_demo.dart';
import 'gallery_demo.dart';
import 'sample_images.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'media_lightbox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF5B5BD6), useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF5B5BD6),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<List<SamplePhoto>> _photos = SamplePhotos.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SamplePhoto>>(
      future: _photos,
      builder: (context, snap) {
        final photos = snap.data;
        if (photos == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        Widget tile(String title, String sub, IconData icon, Widget page) => Card(
              child: ListTile(
                leading: Icon(icon),
                title: Text(title),
                subtitle: Text(sub),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
              ),
            );
        return Scaffold(
          appBar: AppBar(title: const Text('media_lightbox')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              tile('Hero grid', 'Tap a thumbnail: Hero open, pinch / double-tap / wheel zoom, swipe, swipe down to close', Icons.grid_view, GalleryDemoPage(photos: photos)),
              tile('Mixed media', 'Images plus a custom page (stand-in for video) in one gallery', Icons.movie_outlined, CustomPageDemo(photos: photos)),
              tile('Customize', 'Theme, zoom limits, double-tap steps, wheel behaviour, overlay builders', Icons.tune, CustomizeDemoPage(photos: photos)),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'All pictures are generated in code at start-up (no files, no network).\n\n'
                  'Desktop / web: scroll wheel zooms around the cursor, drag pans, arrow keys page, Esc closes, +/-/0 zoom.\n'
                  'Touch: pinch, double-tap, swipe left/right, swipe down to dismiss.',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
