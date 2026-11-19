## 0.0.2

* Keeps the full pub.dev static analysis score on Flutter 3.50 and later, which deprecates `package:flutter/material.dart`. No API or behavior changes.

## 0.0.1

* Initial release.
* `Lightbox.open` / `LightboxGallery`: full-screen gallery with Hero, captions, thumbnail strip, counter and keyboard shortcuts.
* Pinch zoom, double-tap zoom to the tapped point with configurable steps, mouse-wheel zoom around the cursor, trackpad pinch/pan, mouse drag pan, fling.
* Zoom-aware paging: zoomed images pan first and hand over to the next page at their edge; pinch never pages.
* Strict or elastic min/max scale.
* Swipe-down-to-dismiss with fading backdrop and Hero return.
* `LightboxItem.custom` for any widget (video, maps) with `isActive`.
* `LightboxController`, `LightboxOptions`, `LightboxTheme`, `ZoomableView` and `ZoomableController`.
