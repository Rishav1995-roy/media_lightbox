import 'package:flutter/material.dart';
import 'package:media_lightbox/media_lightbox.dart';

import 'sample_images.dart';

/// Builds the lightbox items for a list of photos. The Hero tag matches the
/// one used by [PhotoGrid], which is all a Hero transition needs.
List<LightboxItem> itemsFor(List<SamplePhoto> photos) => [
      for (var i = 0; i < photos.length; i++)
        LightboxItem.image(
          photos[i].image,
          heroTag: 'photo-$i',
          caption: '${photos[i].title} - synthetic image ${i + 1}',
          size: photos[i].size,
        ),
    ];

/// A grid of Hero thumbnails; tapping one opens the lightbox on it.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    super.key,
    required this.photos,
    required this.onOpen,
    this.padding = const EdgeInsets.all(8),
  });

  final List<SamplePhoto> photos;
  final ValueChanged<int> onOpen;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: photos.length,
      itemBuilder: (context, i) => GestureDetector(
        onTap: () => onOpen(i),
        child: Hero(
          tag: 'photo-$i',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image(
              image: ResizeImage(photos[i].image, width: 360),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

class GalleryDemoPage extends StatelessWidget {
  const GalleryDemoPage({super.key, required this.photos});

  final List<SamplePhoto> photos;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hero grid')),
      body: PhotoGrid(
        photos: photos,
        onOpen: (i) => Lightbox.open(
          context,
          items: itemsFor(photos),
          initialIndex: i,
          options: const LightboxOptions(showThumbnails: true),
        ),
      ),
    );
  }
}
