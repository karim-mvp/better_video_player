import 'package:flutter/widgets.dart';

// Visual style of the player controls. Defaults follow the Araby AI brand.
// Controls always sit on top of video, so they stay light-on-dark in both
// light and dark app themes (the same convention YouTube / Netflix use).
class BetterVideoPlayerTheme {
  // Main brand color: thumb, loading ring, selected speed.
  final Color accentColor;

  // Gradient painted on the played part of the progress bar.
  final List<Color> accentGradient;

  // Buffered part of the progress bar.
  final Color bufferedColor;

  // Unplayed part of the progress bar.
  final Color trackColor;

  // Icons drawn over the video.
  final Color iconColor;

  // Time labels and chips text.
  final Color textColor;

  // Frosted surfaces: center button, chips, speed menu.
  final Color surfaceColor;

  // Gradient scrim behind the bars, keeps controls readable on bright frames.
  final Color scrimColor;

  // Error state icon.
  final Color errorColor;

  const BetterVideoPlayerTheme({
    this.accentColor = const Color(0xFF0395FF),
    this.accentGradient = const [Color(0xFF1A82DB), Color(0xFF35BBE9)],
    this.bufferedColor = const Color(0x59FFFFFF),
    this.trackColor = const Color(0x2EFFFFFF),
    this.iconColor = const Color(0xFFFFFFFF),
    this.textColor = const Color(0xFFFFFFFF),
    this.surfaceColor = const Color(0x8C101114),
    this.scrimColor = const Color(0xFF000000),
    this.errorColor = const Color(0xFFF87171),
  });

  BetterVideoPlayerTheme copyWith({
    Color? accentColor,
    List<Color>? accentGradient,
    Color? bufferedColor,
    Color? trackColor,
    Color? iconColor,
    Color? textColor,
    Color? surfaceColor,
    Color? scrimColor,
    Color? errorColor,
  }) {
    return BetterVideoPlayerTheme(
      accentColor: accentColor ?? this.accentColor,
      accentGradient: accentGradient ?? this.accentGradient,
      bufferedColor: bufferedColor ?? this.bufferedColor,
      trackColor: trackColor ?? this.trackColor,
      iconColor: iconColor ?? this.iconColor,
      textColor: textColor ?? this.textColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      scrimColor: scrimColor ?? this.scrimColor,
      errorColor: errorColor ?? this.errorColor,
    );
  }
}
