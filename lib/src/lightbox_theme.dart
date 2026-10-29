import 'package:flutter/material.dart';

/// Colours, sizes and text styles of the default gallery chrome.
@immutable
class LightboxTheme {
  /// Creates a theme. Every value has a dark-gallery default.
  const LightboxTheme({
    this.backgroundColor = Colors.black,
    this.foregroundColor = Colors.white,
    this.scrimColor = const Color(0xCC000000),
    this.counterStyle,
    this.captionStyle,
    this.thumbnailSize = 56,
    this.thumbnailSpacing = 8,
    this.thumbnailRadius = 8,
    this.activeThumbnailColor = Colors.white,
    this.inactiveThumbnailOpacity = 0.55,
    this.chromeDuration = const Duration(milliseconds: 200),
    this.closeIcon = Icons.close,
    this.chromePadding =
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  /// Backdrop colour; fades out while dragging to dismiss.
  final Color backgroundColor;

  /// Icon and text colour of the chrome.
  final Color foregroundColor;

  /// Colour at the outer edge of the top/bottom gradients behind the chrome.
  final Color scrimColor;

  /// Text style of the "1 / 5" counter.
  final TextStyle? counterStyle;

  /// Text style of the caption.
  final TextStyle? captionStyle;

  /// Edge length of a thumbnail in the strip.
  final double thumbnailSize;

  /// Gap between thumbnails.
  final double thumbnailSpacing;

  /// Corner radius of thumbnails.
  final double thumbnailRadius;

  /// Border colour of the selected thumbnail.
  final Color activeThumbnailColor;

  /// Opacity of unselected thumbnails.
  final double inactiveThumbnailOpacity;

  /// Fade duration of the chrome.
  final Duration chromeDuration;

  /// Icon of the default close button.
  final IconData closeIcon;

  /// Padding around the top bar and bottom area.
  final EdgeInsets chromePadding;

  /// Returns a copy with the given fields replaced.
  LightboxTheme copyWith({
    Color? backgroundColor,
    Color? foregroundColor,
    Color? scrimColor,
    TextStyle? counterStyle,
    TextStyle? captionStyle,
    double? thumbnailSize,
    double? thumbnailSpacing,
    double? thumbnailRadius,
    Color? activeThumbnailColor,
    double? inactiveThumbnailOpacity,
    Duration? chromeDuration,
    IconData? closeIcon,
    EdgeInsets? chromePadding,
  }) {
    return LightboxTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      scrimColor: scrimColor ?? this.scrimColor,
      counterStyle: counterStyle ?? this.counterStyle,
      captionStyle: captionStyle ?? this.captionStyle,
      thumbnailSize: thumbnailSize ?? this.thumbnailSize,
      thumbnailSpacing: thumbnailSpacing ?? this.thumbnailSpacing,
      thumbnailRadius: thumbnailRadius ?? this.thumbnailRadius,
      activeThumbnailColor: activeThumbnailColor ?? this.activeThumbnailColor,
      inactiveThumbnailOpacity:
          inactiveThumbnailOpacity ?? this.inactiveThumbnailOpacity,
      chromeDuration: chromeDuration ?? this.chromeDuration,
      closeIcon: closeIcon ?? this.closeIcon,
      chromePadding: chromePadding ?? this.chromePadding,
    );
  }
}
