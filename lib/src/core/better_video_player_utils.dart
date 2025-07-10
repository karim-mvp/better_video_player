import 'package:video_player/video_player.dart';

class BetterVideoPlayerUtils {
  static String formatDuration(Duration position) {
    final ms = position.inMilliseconds;

    int seconds = ms ~/ 1000;
    final int hours = seconds ~/ 3600;
    seconds = seconds % 3600;
    final minutes = seconds ~/ 60;
    seconds = seconds % 60;

    final hoursString = hours >= 10
        ? '$hours'
        : hours == 0
            ? '00'
            : '0$hours';

    final minutesString = minutes >= 10
        ? '$minutes'
        : minutes == 0
            ? '00'
            : '0$minutes';

    final secondsString = seconds >= 10
        ? '$seconds'
        : seconds == 0
            ? '00'
            : '0$seconds';

    final formattedTime =
        '${hoursString == '00' ? '' : '$hoursString:'}$minutesString:$secondsString';

    return formattedTime;
  }

  static bool isVideoFinished(VideoPlayerValue? value) {
    // on iOS 12.4.1, video duration is 0 -> https://github.com/flutter/flutter/issues/87334
    if (value == null || value.duration <= Duration(milliseconds: 1)) {
      return false;
    }

    return value.position >= value.duration;
  }

  ///Latest value can be null
  // MODIFIED: This is the only function where changes are needed.
  static bool isLoading(VideoPlayerValue? value) {
    if (value == null) {
      return true; // Still loading if value is null (e.g., before controller is initialized)
    }

    if (!value.isInitialized) {
      return true; // Still loading if the video player itself is not initialized
    }

    // Key change: Only consider it "loading" (requiring the spinner) if it's buffering
    // AND the video is NOT currently playing.
    // If it's playing and buffering, it's considered background buffering and shouldn't show a prominent spinner.
    if (value.isBuffering && !value.isPlaying) {
      return true;
    }

    // If none of the above conditions are met, it's not in a "loading" state that warrants the spinner.
    return false;
  }

  static double? aspectRatio(VideoPlayerValue? value) {
    if (value == null || value.size.width == 0 || value.size.height == 0) {
      return null;
    }

    final double aspectRatio = value.size.width / value.size.height;

    if (aspectRatio <= 0) {
      return 1.0;
    }
    return aspectRatio;
  }
}
