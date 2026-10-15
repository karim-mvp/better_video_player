import 'package:better_video_player/src/configuration/better_video_player_configuration.dart';
import 'package:better_video_player/src/core/better_video_player_controller.dart';
import 'package:better_video_player/src/core/better_video_player_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

class BetterVideoPlayerWithControls extends StatefulWidget {
  final bool isFullScreen;
  final BetterVideoPlayerConfiguration configuration;

  const BetterVideoPlayerWithControls({Key? key, required this.isFullScreen, required this.configuration})
      : super(key: key);

  @override
  _BetterVideoPlayerWithControlsState createState() => _BetterVideoPlayerWithControlsState();
}

class _BetterVideoPlayerWithControlsState extends State<BetterVideoPlayerWithControls> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BetterVideoPlayerController>();

    final videoInitialized = controller.videoPlayerValue?.isInitialized ?? false;
    final videoAspectRatio = BetterVideoPlayerUtils.aspectRatio(controller.videoPlayerValue) ?? (16.0 / 9.0);

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Cross-fade from the placeholder to the first video frame instead of
          // popping it in.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            child: videoInitialized
                ? Center(
                    key: const ValueKey('video'),
                    child: ClipRRect(
                      child: AspectRatio(
                        aspectRatio: videoAspectRatio,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            widget.configuration.placeholder,
                            VideoPlayer(controller.value.videoPlayerController!),
                          ],
                        ),
                      ),
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey('placeholder'),
                    child: widget.configuration.placeholder,
                  ),
          ),
          if (widget.isFullScreen) widget.configuration.fullScreenControls else widget.configuration.controls,
        ],
      ),
    );
  }
}
