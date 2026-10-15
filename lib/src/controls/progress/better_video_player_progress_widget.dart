import 'package:better_video_player/src/controls/progress/better_video_player_progress_bar.dart';
import 'package:flutter/material.dart';

// 播放控制器的播放进度控件
// Full-width progress bar. Time labels live in the controls row above it, so
// the bar always gets the whole player width, no matter how narrow it is.
class BetterVideoPlayerProgressWidget extends StatefulWidget {
  /// 拖动开始
  final Function onDragStart;

  /// 拖动结束
  final Function onDragEnd;

  // Touch target height, the painted track is much thinner.
  final double height;

  final double thumbRadius;

  const BetterVideoPlayerProgressWidget({
    Key? key,
    required this.onDragStart,
    required this.onDragEnd,
    this.height = 26,
    this.thumbRadius = 6,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return BetterVideoPlayerProgressWidgetState();
  }
}

class BetterVideoPlayerProgressWidgetState extends State<BetterVideoPlayerProgressWidget> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: buildProgressBar(),
    );
  }

  Widget buildProgressBar() {
    return BetterVideoPlayerProgressBar(
      onDragStart: widget.onDragStart,
      onDragEnd: widget.onDragEnd,
      thumbRadius: widget.thumbRadius,
    );
  }
}
