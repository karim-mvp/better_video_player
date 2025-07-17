import 'package:better_video_player/better_video_player.dart';
import 'package:better_video_player_example/constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PortraitPlayerPage extends StatefulWidget {
  @override
  _PortraitPlayerPageState createState() => _PortraitPlayerPageState();
}

class _PortraitPlayerPageState extends State<PortraitPlayerPage> {
  late BetterVideoPlayerController controller;

  @override
  void initState() {
    super.initState();

    controller = BetterVideoPlayerController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Portrait player"),
      ),
      body: BetterVideoPlayer(
        controller: controller,
        configuration: BetterVideoPlayerConfiguration(
          placeholder: Image.network(
            kPortraitVideoThumbnail,
            fit: BoxFit.contain,
          ),
          controls: const _CustomVideoPlayerControls(),
        ),
        dataSource: BetterVideoPlayerDataSource(
          BetterVideoPlayerDataSourceType.network,
          kPortraitVideoUrl,
        ),
      ),
    );
  }
}

class _CustomVideoPlayerControls extends StatefulWidget {
  const _CustomVideoPlayerControls({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _CustomVideoPlayerControlsState();
  }
}

class _CustomVideoPlayerControlsState
    extends State<_CustomVideoPlayerControls> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BetterVideoPlayerController>();

    return InkWell(
      onTap: _onPlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // If there's an error, display the error message.
          if (controller.value.videoPlayerController?.value.hasError ?? false)
            buildError()
          // If the video is loading AND it's not currently playing (to avoid showing loader mid-play), display the loading indicator.
          else if (controller.value.isLoading &&
              !(controller.value.videoPlayerController?.value.isPlaying ??
                  true))
            Center(child: buildLoading())
          // If the video has finished and is not set to loop, display the replay icon.
          else if (controller.value.isVideoFinish &&
              !controller.value.configuration.looping)
            Center(child: buildReplay())
          // If the video is not playing (paused or not started), display the play icon and progress bar.
          else if (!(controller.value.videoPlayerController?.value.isPlaying ??
              false))
            Stack(children: [
              Center(child: buildPlayPause()),
              Align(alignment: Alignment.bottomCenter, child: buildProgress()),
            ])
          // Otherwise (video is playing), show nothing as controls should auto-hide.
          else
            const SizedBox(),
        ],
      ),
    );
  }

  // Widget to display the CircularProgressIndicator during loading.
  Widget buildLoading() {
    return const CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
    );
  }

  // Widget to display an error message.
  Widget buildError() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.warning,
            color: Colors.yellowAccent,
            size: 42,
          ),
          Text(
            "无法播放视频", // "Unable to play video"
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  // Widget to display the play/pause icon.
  Widget buildPlayPause() {
    return const Icon(
      Icons.play_arrow,
      color: Colors.white,
      size: 60,
    );
  }

  // Widget to display the replay icon when the video finishes.
  Widget buildReplay() {
    return const Icon(
      Icons.cached_rounded,
      color: Colors.white,
      size: 60,
    );
  }

  // Widget for the video progress bar.
  Widget buildProgress() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.black,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      constraints: const BoxConstraints.expand(height: 44),
      child: BetterVideoPlayerProgressWidget(
        onDragStart: () => null, // Placeholder, can be implemented if needed
        onDragEnd: () => null, // Placeholder, can be implemented if needed
      ),
    );
  }

  // Handles play/pause and replay logic.
  void _onPlayPause() {
    final controller = context.read<BetterVideoPlayerController>();

    if (controller.value.videoPlayerController?.value.isPlaying ?? false) {
      // If currently playing, pause the video.
      controller.pause();
    } else {
      // If not playing and initialized:
      if (controller.value.videoPlayerController?.value.isInitialized ??
          false) {
        if (controller.value.isVideoFinish) {
          // If the video has finished, reset the finish flag and seek to the beginning.
          // This is the crucial fix! ✅
          controller.value = controller.value.copyWith(isVideoFinish: false);
          controller.seekTo(const Duration());
        }
        // Play the video.
        controller.play();
      }
    }
  }
}

// import 'package:better_video_player/better_video_player.dart';
// import 'package:better_video_player_example/constants.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// class PortraitPlayerPage extends StatefulWidget {
//   @override
//   _PortraitPlayerPageState createState() => _PortraitPlayerPageState();
// }

// class _PortraitPlayerPageState extends State<PortraitPlayerPage> {
//   late BetterVideoPlayerController controller;

//   @override
//   void initState() {
//     super.initState();

//     controller = BetterVideoPlayerController();
//   }

//   @override
//   void dispose() {
//     controller.dispose();

//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Portrait player"),
//       ),
//       body: BetterVideoPlayer(
//         controller: controller,
//         configuration: BetterVideoPlayerConfiguration(
//           placeholder: Image.network(
//             kPortraitVideoThumbnail,
//             fit: BoxFit.contain,
//           ),
//           controls: const _CustomVideoPlayerControls(),
//         ),
//         dataSource: BetterVideoPlayerDataSource(
//           BetterVideoPlayerDataSourceType.network,
//           kPortraitVideoUrl,
//         ),
//       ),
//     );
//   }
// }

// class _CustomVideoPlayerControls extends StatefulWidget {
//   const _CustomVideoPlayerControls({Key? key}) : super(key: key);

//   @override
//   State<StatefulWidget> createState() {
//     return _CustomVideoPlayerControlsState();
//   }
// }

// class _CustomVideoPlayerControlsState extends State<_CustomVideoPlayerControls> {
//   @override
//   Widget build(BuildContext context) {
//     final controller = context.watch<BetterVideoPlayerController>();

//     return InkWell(
//       onTap: _onPlayPause,
//       child: Stack(
//         fit: StackFit.expand,
//         children: [
//           if (controller.value.videoPlayerController?.value.hasError ?? false)
//             buildError()
//           else if (controller.value.isLoading)
//             Center(child: buildLoading())
//           else if (!(controller.value.videoPlayerController?.value.isPlaying ?? false))
//             Stack(children: [
//               Center(child: buildPlayPause()),
//               Align(alignment: Alignment.bottomCenter, child: buildProgress()),
//             ])
//           else
//             SizedBox(),
//         ],
//       ),
//     );
//   }

//   Widget buildLoading() {
//     return CircularProgressIndicator(
//       valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
//     );
//   }

//   Widget buildError() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.warning,
//             color: Colors.yellowAccent,
//             size: 42,
//           ),
//           Text(
//             "无法播放视频",
//             style: TextStyle(color: Colors.white),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget buildPlayPause() {
//     return const Icon(
//       Icons.play_arrow,
//       color: Colors.white,
//       size: 60,
//     );
//   }

//   Widget buildProgress() {
//     return Container(
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [
//             Colors.transparent,
//             Colors.black,
//           ],
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//         ),
//       ),
//       constraints: BoxConstraints.expand(height: 44),
//       child: BetterVideoPlayerProgressWidget(
//         onDragStart: () => null,
//         onDragEnd: () => null,
//       ),
//     );
//   }

//   void _onPlayPause() {
//     final controller = context.read<BetterVideoPlayerController>();

//     setState(() {
//       if (controller.value.videoPlayerController?.value.isPlaying ?? false) {
//         controller.pause();
//       } else {
//         if (controller.value.videoPlayerController?.value.isInitialized ?? false) {
//           if (controller.value.isVideoFinish) {
//             controller.seekTo(const Duration());
//           }
//           controller.play();
//         }
//       }
//     });
//   }
// }
