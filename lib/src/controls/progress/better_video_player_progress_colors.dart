import 'package:better_video_player/src/configuration/better_video_player_theme.dart';
import 'package:flutter/rendering.dart';

class BetterVideoPlayerProgressColors {
  BetterVideoPlayerProgressColors({
    Color playedColor = const Color(0xFF0395FF),
    Color bufferedColor = const Color(0x59FFFFFF),
    Color handleColor = const Color(0xFFFFFFFF),
    Color backgroundColor = const Color(0x2EFFFFFF),
    this.playedGradient,
  })  : playedPaint = Paint()..color = playedColor,
        bufferedPaint = Paint()..color = bufferedColor,
        handlePaint = Paint()..color = handleColor,
        backgroundPaint = Paint()..color = backgroundColor;

  factory BetterVideoPlayerProgressColors.fromTheme(BetterVideoPlayerTheme theme) {
    return BetterVideoPlayerProgressColors(
      playedColor: theme.accentColor,
      bufferedColor: theme.bufferedColor,
      handleColor: theme.iconColor,
      backgroundColor: theme.trackColor,
      playedGradient: theme.accentGradient,
    );
  }

  final Paint playedPaint;
  final Paint bufferedPaint;
  final Paint handlePaint;
  final Paint backgroundPaint;

  // When set (2+ colors), the played part is painted with this gradient
  // instead of the flat playedPaint color.
  final List<Color>? playedGradient;
}
