import 'package:flutter/material.dart';

import 'lightbox_controller.dart';
import 'lightbox_gallery.dart';
import 'lightbox_item.dart';
import 'lightbox_options.dart';

/// Entry point: opens a [LightboxGallery] over the current screen.
class Lightbox {
  const Lightbox._();

  /// Builds the route used by [open]. Useful with a custom `Navigator` call.
  static Route<int> route({
    required List<LightboxItem> items,
    int initialIndex = 0,
    LightboxOptions options = const LightboxOptions(),
    LightboxController? controller,
    Duration transitionDuration = const Duration(milliseconds: 320),
  }) {
    return PageRouteBuilder<int>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: transitionDuration,
      reverseTransitionDuration: transitionDuration,
      pageBuilder: (context, animation, secondary) => LightboxGallery(
        items: items,
        initialIndex: initialIndex,
        controller: controller,
        options: options,
      ),
      // The gallery fades its own backdrop and overlay and lets Hero move the
      // image, so the page itself is not transformed.
      transitionsBuilder: (context, animation, secondary, child) => child,
    );
  }

  /// Opens the gallery at [initialIndex]. Completes with the index the user
  /// was on when it closed through the close button, Escape or a dismiss
  /// swipe (null for the system back button).
  static Future<int?> open(
    BuildContext context, {
    required List<LightboxItem> items,
    int initialIndex = 0,
    LightboxOptions options = const LightboxOptions(),
    LightboxController? controller,
    bool useRootNavigator = true,
    Duration transitionDuration = const Duration(milliseconds: 320),
  }) {
    return Navigator.of(context, rootNavigator: useRootNavigator).push(route(
      items: items,
      initialIndex: initialIndex,
      options: options,
      controller: controller,
      transitionDuration: transitionDuration,
    ));
  }
}
