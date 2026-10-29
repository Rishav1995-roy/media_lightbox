# media_lightbox

[![pub version](https://img.shields.io/pub/v/media_lightbox.svg)](https://pub.dev/packages/media_lightbox)
[![pub points](https://img.shields.io/pub/points/media_lightbox)](https://pub.dev/packages/media_lightbox/score)
[![likes](https://img.shields.io/pub/likes/media_lightbox)](https://pub.dev/packages/media_lightbox)
[![popularity](https://img.shields.io/pub/popularity/media_lightbox)](https://pub.dev/packages/media_lightbox/score)
[![CI](https://github.com/Rishav1995-roy/media_lightbox/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Rishav1995-roy/media_lightbox/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platforms-android%20%7C%20ios%20%7C%20web%20%7C%20macos%20%7C%20windows%20%7C%20linux-informational)

A full-screen image gallery for Flutter that gets the gestures right: pinch, double-tap to the tapped point, mouse-wheel and trackpad zoom, paging that never fights zoom, swipe-down to dismiss with a fading backdrop, and Hero from your thumbnails. Pure Dart, no dependencies, every platform.

<p align="center">
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/media_lightbox/main/doc/demo.gif" width="300" alt="Demo: hero open, double-tap zoom, pan, swipe to the next page, swipe down to dismiss">
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/media_lightbox/main/doc/screenshot_gallery.png" width="200" alt="Gallery with captions and thumbnails">
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/media_lightbox/main/doc/screenshot_zoomed.png" width="200" alt="Zoomed into the tapped point">
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/media_lightbox/main/doc/screenshot_theme.png" width="200" alt="Custom sepia theme">
</p>

> The demo frames are real renderings of the real widgets, produced by a headless Flutter test (`tool/demo/demo_test.dart`). The white dot is a finger indicator drawn by that script. All pictures are generated in code.

## Why this package

Showing a photo full screen sounds trivial and is full of gesture edge cases. These are the ones this package was built to solve, each with a test in `test/core_problems_test.dart`:

| Problem | How it is solved here |
|---|---|
| Mouse-wheel / trackpad zoom missing (`photo_view` [#481](https://github.com/bluefireteam/photo_view/issues/481)) | Wheel zooms around the cursor (`WheelZoomBehavior.always / withModifier / never`), trackpad pinch (pan/zoom events) zooms around the focal point, mouse drag pans. |
| Double tap does not zoom to the tapped position (`photo_view` [#425](https://github.com/bluefireteam/photo_view/issues/425)) | Double tap / double click zooms so the content under your finger stays under it. The steps are configurable (`doubleTapScales: [1, 2, 4]`). |
| Zoom gestures fight the `PageView` | The zoom layer reads pointers directly (no gesture arena) and forwards the horizontal motion it cannot use to the pager. A zoomed image pans first and hands over to the next page only at its edge; a pinch never pages; a second finger landing mid-swipe becomes a pinch. |
| Min/max scale not strict (`photo_view` [#85](https://github.com/bluefireteam/photo_view/issues/85)) | `elasticZoom: false` = hard limits at every moment, including wheel and trackpad. `true` = the pinch may overshoot a little and springs back. |
| Swipe-down-to-dismiss as a separate package | Built in: backdrop and overlay fade with the drag, distance and fling thresholds, springs back, Hero returns to the thumbnail. |

`photo_view` also tracks "use `InteractiveViewer`" ([#323](https://github.com/bluefireteam/photo_view/issues/323)); this package does not use `InteractiveViewer` either, because its pan/scale recognizer would compete with the pager. See "How it works".

### Honest comparison

| | `media_lightbox` | [`photo_view`](https://pub.dev/packages/photo_view) | [`extended_image`](https://pub.dev/packages/extended_image) |
|---|---|---|---|
| Maintained (as of 2026-10) | New (0.0.1) | Last release 2024-04, ~120 open issues | Yes, actively |
| Wheel / trackpad zoom | Yes | Open request (#481) | Yes |
| Double tap to tapped point | Yes, configurable steps | Open request (#425) | Yes (you write the animation callback) |
| Zoom-aware paging | Built in (hand-over at image edge) | Gallery widget; edge behaviour is a recurring question in its tracker | Yes (`ExtendedImageGesturePageView`) |
| Swipe down to dismiss | Built in | No | Via `ExtendedImageSlidePage` |
| Hero | Built in, aspect-correct shuttle | Yes | Yes |
| Arbitrary child (video, widgets) | `LightboxItem.custom` | `PhotoView.customChild` | Image-only |
| Own image widget / cache | No, any `ImageProvider` | No | Yes, a full image stack (cache, editor, crop) |
| Dependencies | None | None | Several |
| Maturity | Brand new, 0.0.1 | Years of production use | Years of production use |

**Use `extended_image` if** you want a maintained all-in-one image stack (its own network cache, cropping and editing, loading states) and are happy to adopt its image widget. **Use `photo_view`** if your app already works with it. **Use `media_lightbox`** if you want a small, dependency-free viewer with the gestures above working out of the box, and you bring your own images (including `cached_network_image` providers).

## Install

```sh
flutter pub add media_lightbox
```

## Quick start

```dart
import 'package:media_lightbox/media_lightbox.dart';

final items = [
  for (var i = 0; i < photos.length; i++)
    LightboxItem.image(
      NetworkImage(photos[i].url),         // any ImageProvider
      heroTag: 'photo-$i',                  // same tag on the thumbnail = Hero
      caption: photos[i].title,
    ),
];

// In a thumbnail:
GestureDetector(
  onTap: () => Lightbox.open(context, items: items, initialIndex: i),
  child: Hero(tag: 'photo-$i', child: Image.network(photos[i].url, fit: BoxFit.cover)),
);
```

`Lightbox.open` completes with the index the gallery was on when it was closed (via the close button, Escape or a swipe), or `null` for the system back button.

### Embedded

```dart
SizedBox(
  height: 400,
  child: LightboxGallery(
    items: items,
    options: LightboxOptions(onDismiss: () => setState(() => open = false)),
  ),
)
```

### Control it from outside

```dart
final controller = LightboxController();
Lightbox.open(context, items: items, controller: controller);

controller.next();
controller.jumpToPage(3);
controller.zoomTo(3);
controller.resetZoom();
controller.addListener(() => print('${controller.index} @ ${controller.zoomScale}x'));
```

## Custom media (video, maps, anything)

```dart
LightboxItem.custom(
  zoomable: false,            // the page keeps its own gestures (play/pause, scrubbing)
  size: const Size(16, 9),    // aspect ratio to fit
  caption: 'Clip',
  builder: (context, info) => MyVideoPlayer(play: info.isActive), // pause when off-screen
)
```

There is no video dependency; put `video_player`, `chewie`, a map or a chart in the builder. Paging, tap and swipe-down-to-dismiss keep working around it. A non-`zoomable` page is a good fit for anything with its own controls.

## Options

`LightboxOptions` (all optional):

| Option | Default | Description |
|---|---|---|
| `theme` | dark | `LightboxTheme`, see below |
| `minScale` / `maxScale` | 1 / 4 | Zoom limits relative to the fit size |
| `doubleTapScales` | `[1, 2.5]` | Scales a double tap cycles through |
| `enableDoubleTap` | true | Double tap / double click zoom |
| `elasticZoom` | true | Overshoot while pinching and spring back; false = strict limits |
| `wheelZoom` | `always` | `WheelZoomBehavior.always / withModifier / never` |
| `wheelSensitivity` | 0.0015 | Scale factor per scrolled pixel |
| `enableDismissGesture` | true | Drag down/up at fit size to close |
| `dismissDistance` / `dismissVelocity` | 110 px / 800 px/s | When releasing closes |
| `enableKeyboard` | true | Arrows, Page Up/Down, Home/End, Esc, `+` `-` `0` |
| `toggleChromeOnTap` | true | Single tap shows/hides the overlay |
| `showCounter` / `showCloseButton` / `showCaptions` / `showThumbnails` | true / true / true / false | Default overlay parts |
| `pageGap` | 12 | Space between pages while swiping |
| `onPageChanged` | | Page callback |
| `onDismiss` | `Navigator.maybePop` | Replace the close action (embedded use) |
| `overlayBuilder` | | Replace the whole overlay |
| `topBarBuilder` / `captionBuilder` / `thumbnailBuilder` | | Replace one part of the default overlay |
| `pageBuilder` | | Wrap or replace each page (`defaultPage` is passed in) |
| `loadingBuilder` / `errorBuilder` | spinner / icon | Image states |

`LightboxTheme`: `backgroundColor`, `foregroundColor`, `scrimColor`, `counterStyle`, `captionStyle`, `thumbnailSize`, `thumbnailSpacing`, `thumbnailRadius`, `activeThumbnailColor`, `inactiveThumbnailOpacity`, `chromeDuration`, `closeIcon`, `chromePadding`.

`LightboxItem.image(provider, {heroTag, caption, thumbnail, size, semanticLabel, data})` and `LightboxItem.custom({builder, zoomable, size, heroTag, caption, thumbnail, semanticLabel, data})`.

`LightboxController`: `index`, `count`, `zoomScale`, `isZoomed`, `chromeVisible`, `jumpToPage`, `animateToPage`, `next`, `previous`, `resetZoom`, `zoomTo`, `setChromeVisible`, `toggleChrome`, `close`.

### Theming example

```dart
Lightbox.open(
  context,
  items: items,
  options: const LightboxOptions(
    showThumbnails: true,
    maxScale: 6,
    doubleTapScales: [1, 2, 4],
    wheelZoom: WheelZoomBehavior.withModifier,
    theme: LightboxTheme(
      backgroundColor: Color(0xFF2B2118),
      foregroundColor: Color(0xFFF5E6CF),
      scrimColor: Color(0xCC2B2118),
      activeThumbnailColor: Color(0xFFE0A458),
      thumbnailRadius: 14,
    ),
  ),
);
```

### Fully custom overlay

```dart
LightboxOptions(
  overlayBuilder: (context, value, controller) => Align(
    alignment: Alignment.bottomCenter,
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(icon: const Icon(Icons.chevron_left), onPressed: controller.previous),
      Text('${value.index + 1}/${value.count}  ${value.zoomScale.toStringAsFixed(1)}x'),
      IconButton(icon: const Icon(Icons.chevron_right), onPressed: controller.next),
    ]),
  ),
)
```

### Zoom layer on its own

`ZoomableView` is the same gesture layer without the gallery: wrap any widget, get pinch, double tap, wheel zoom and pan, driven by an optional `ZoomableController`.

## How it works

The zoom layer listens to raw pointer events instead of competing in the gesture arena. A Flutter `Scrollable` (`PageView`) makes its subtree ignore new pointers as soon as a drag starts, so a second finger could never begin a pinch. Here the `PageView` never takes drags: the zoom layer decides what a single finger means (pan if zoomed, page if at fit size and the motion is horizontal, dismiss if vertical), forwards page motion to the `PageController`, and settles to the nearest page with fling velocity on release. Zoom is applied as `translate * scale` about the viewport centre; pan limits come from the image's real size once resolved, so there is never a gap or a dead zone.

## Platform support

| Android | iOS | Web | macOS | Windows | Linux |
|---|---|---|---|---|---|
| Yes | Yes | Yes | Yes | Yes | Yes |

Pure Dart and Flutter: no native code, no plugins, WASM-compatible. Mouse wheel and trackpad zoom, mouse drag and keyboard shortcuts matter on desktop and web; pinch, double-tap and swipes on touch devices. Trackpad two-finger horizontal scrolling does not page (use drag, arrows or the thumbnails).

## Coming from `photo_view`

| `photo_view` | `media_lightbox` |
|---|---|
| `PhotoView(imageProvider: p)` | `LightboxGallery(items: [LightboxItem.image(p)])` (embedded) or `Lightbox.open(...)` |
| `PhotoViewGallery.builder(...)` | `Lightbox.open(context, items: ..., initialIndex: ...)` |
| `PhotoViewHeroAttributes(tag: t)` | `LightboxItem.image(p, heroTag: t)` |
| `minScale` / `maxScale` | `LightboxOptions.minScale` / `maxScale` (`elasticZoom: false` for strict) |
| `customChild` | `LightboxItem.custom(builder: ...)` |
| `PhotoViewController` | `LightboxController` (`zoomTo`, `resetZoom`, `zoomScale`) |
| `loadingBuilder` / `errorBuilder` | `LightboxOptions.loadingBuilder` / `errorBuilder` |
| `scaleStateCycleStrategy` | `LightboxOptions.doubleTapScales` |
| `PhotoView` as a standalone zoomable widget | `ZoomableView` |
| `onTapUp` etc. | single tap toggles the overlay (`toggleChromeOnTap`); use `pageBuilder` to add your own handlers |

Not carried over: rotation gestures and `basePosition` style options.

## FAQ

**Does it work with `cached_network_image`?** Yes. Pass `CachedNetworkImageProvider(url)` as the `ImageProvider`.

**Why does a thumbnail-to-full image Hero not stretch?** The Hero's shuttle is built with `BoxFit.cover` and the destination is sized to the image's real aspect ratio, so the picture is cropped smoothly instead of distorted. Pass `size` on the item if the image is slow to load so the layout is right on the first frame.

**Can I loop pages?** Not in 0.0.1.

**Can I show video?** Yes through `LightboxItem.custom`; the package deliberately has no video dependency.

**Why is horizontal paging not a normal `PageView` swipe?** See "How it works". It is the reason pinch and swipe do not conflict. Semantics scroll actions of the `PageView` are therefore not exposed; the close button, keyboard shortcuts, `controller.next()` and the thumbnail strip are.

**Does it work in a `ListView` / with ancestor scrollables?** The gallery is meant to be full screen or in a bounded box. Wheel events are consumed only when `wheelZoom` allows zooming.

## Known limits (0.0.1)

- No rotation gesture, no looping, vertical or RTL-aware paging.
- Hero while zoomed in flies from the zoomed rectangle.
- Verified by widget tests and a headless demo render; mouse-wheel and trackpad behaviour is exercised with synthetic pointer events, not a physical device. Try the example on desktop/web to see it with your own hardware.

## Contributing

Issues and pull requests are welcome at <https://github.com/Rishav1995-roy/media_lightbox>. Run `flutter analyze` and `flutter test` before opening a PR. A change in gesture behaviour should come with a test in `test/core_problems_test.dart`.

## License

MIT, see [LICENSE](LICENSE).
