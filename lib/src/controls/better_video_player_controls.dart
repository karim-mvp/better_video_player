import 'dart:async';
import 'dart:math' as math;

import 'package:better_video_player/src/configuration/better_video_player_theme.dart';
import 'package:better_video_player/src/controls/progress/better_video_player_progress_bar.dart';
import 'package:better_video_player/src/controls/progress/better_video_player_progress_widget.dart';
import 'package:better_video_player/src/core/better_video_player_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const Duration _kAutoHideDelay = Duration(seconds: 3);
const Duration _kFadeDuration = Duration(milliseconds: 220);

// Buffering shorter than this never shows a spinner, so quick seeks and the
// first frames don't flash a loader at the user.
const Duration _kLoadingRevealDelay = Duration(milliseconds: 450);

const List<double> _kPlaybackSpeeds = [0.5, 1.0, 2.0];

class BetterVideoPlayerControls extends StatefulWidget {
  final bool isFullScreen;

  const BetterVideoPlayerControls({Key? key, required this.isFullScreen}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return BetterVideoPlayerControlsState();
  }
}

class BetterVideoPlayerControlsState extends State<BetterVideoPlayerControls>
    with HideStuff<BetterVideoPlayerControls> {
  bool absorbing = false;
  double _currentSpeed = 1.0;
  bool _speedMenuOpen = false;

  // True while the user drags the progress bar. Everything except the bar
  // fades out so the scrub bubble and thumb are the only focus.
  bool _scrubbing = false;

  _ControlsLayout _layout = const _ControlsLayout.regular();
  BetterVideoPlayerTheme _theme = const BetterVideoPlayerTheme();

  @override
  void initState() {
    super.initState();

    // 显示
    show(duration: _kAutoHideDelay);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BetterVideoPlayerController>();
    final videoValue = controller.value.videoPlayerController?.value;

    final isInitialized = videoValue?.isInitialized ?? false;
    final isPlaying = videoValue?.isPlaying ?? false;
    final hasError = videoValue?.hasError ?? false;

    _theme = controller.value.configuration.theme;

    if (isPlaying && isAlwaysShow() && !_speedMenuOpen) {
      // hide when video is playing
      scheduleMicrotask(() => show(duration: _kAutoHideDelay));
    } else if (isInitialized && !isPlaying && _isHide) {
      // show when video is not playing
      scheduleMicrotask(() => show());
    }

    // Media controls keep a left-to-right timeline in RTL locales too
    // (Material bidirectionality guideline), so Arabic users get the same
    // familiar scrubbing direction as every other video app.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _layout = _ControlsLayout.resolve(constraints.biggest, widget.isFullScreen);
            final controlsVisible = !_isHide;

            final Widget center = buildCenter(
              hasError: hasError,
              isInitialized: isInitialized,
              isPlaying: isPlaying,
              isBuffering: videoValue?.isBuffering ?? false,
            );
            final centerIsPersistent = center.key != const ValueKey('toggle');

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onSurfaceTap(isPlaying),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: controlsVisible && isInitialized ? 1.0 : 0.0,
                      duration: _kFadeDuration,
                      child: _buildScrim(),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: !controlsVisible && isInitialized && !hasError ? 1.0 : 0.0,
                        duration: _kFadeDuration,
                        child: _MiniProgressLine(theme: _theme),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    bottom: _layout.centerBottomInset,
                    child: AbsorbPointer(
                      absorbing: absorbing || _scrubbing || (_isHide && !centerIsPersistent),
                      child: AnimatedOpacity(
                        opacity: _scrubbing ? 0.0 : 1.0,
                        duration: _kFadeDuration,
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: _kFadeDuration,
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: center,
                          ),
                        ),
                      ),
                    ),
                  ),
                  AbsorbPointer(
                    absorbing: absorbing || _isHide,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: buildBottomBar(),
                        ),
                        ...buildCustomWidgets(_isHide),
                      ],
                    ),
                  ),
                  buildTopBar(_onReduceCollapse),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onSurfaceTap(bool isPlaying) {
    if (_isHide) {
      show(duration: _kAutoHideDelay);
    } else if (isPlaying && !_speedMenuOpen) {
      hide();
    }
  }

  // Picks the single widget shown in the middle of the player. Keys drive the
  // cross-fade between states.
  Widget buildCenter({
    required bool hasError,
    required bool isInitialized,
    required bool isPlaying,
    required bool isBuffering,
  }) {
    final controller = context.read<BetterVideoPlayerController>();

    if (hasError) {
      // 发生错误
      return KeyedSubtree(key: const ValueKey('error'), child: buildError(_onRestart));
    }

    if (!isInitialized || (isPlaying && isBuffering)) {
      // 加载中
      return KeyedSubtree(
        key: const ValueKey('loading'),
        child: _DelayedReveal(delay: _kLoadingRevealDelay, child: buildLoading()),
      );
    }

    if (controller.value.isVideoFinish && !controller.value.configuration.looping) {
      // 播放完成
      return KeyedSubtree(key: const ValueKey('replay'), child: buildReplay(_onPlayPause));
    }

    if (controller.value.wifiInterrupted) {
      // wifi中断
      return KeyedSubtree(key: const ValueKey('wifi'), child: buildWifiInterrupted(_onPlayPause));
    }

    // 播放 / 暂停
    return KeyedSubtree(
      key: const ValueKey('toggle'),
      child: AnimatedOpacity(
        opacity: _isHide ? 0.0 : 1.0,
        duration: _kFadeDuration,
        child: buildCenterPause(_onPlayPause),
      ),
    );
  }

  Widget buildTopBar(VoidCallback onTap) {
    if (!widget.isFullScreen) {
      return const SizedBox();
    }

    final visible = !_isHide;
    // Small visual circle, but the touch target stays a comfortable 44px.
    const double circleSize = 34;
    const double hitSize = 44;
    const double hitOverflow = (hitSize - circleSize) / 2;
    return Positioned(
      top: _layout.edgePadding - hitOverflow,
      left: _layout.edgePadding - hitOverflow,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: _kFadeDuration,
          child: _RoundIconButton(
            icon: Icons.close_rounded,
            size: circleSize,
            hitSize: hitSize,
            iconSize: 20,
            theme: _theme,
            filled: true,
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  Widget buildLoading() {
    final size = _layout.centerSize;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.22),
      decoration: BoxDecoration(
        color: _theme.surfaceColor,
        shape: BoxShape.circle,
      ),
      child: _SpinnerRing(
        color: _theme.accentColor,
        trackColor: _theme.trackColor,
        strokeWidth: math.max(2.5, size * 0.055),
      ),
    );
  }

  Widget buildBottomBar() {
    final controller = context.watch<BetterVideoPlayerController>();
    final videoValue = controller.value.videoPlayerController?.value;
    final isInitialized = videoValue?.isInitialized ?? false;
    final visible = !_isHide && isInitialized;
    final layout = _layout;
    // The progress track is inset by the thumb radius, so the bar gets less
    // outer padding than the row to keep both visually aligned.
    final outerPadding = math.max(0.0, layout.edgePadding - layout.progressInset);
    final rowPadding = layout.edgePadding - outerPadding;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: _kFadeDuration,
        curve: Curves.easeOut,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 0.15),
          duration: _kFadeDuration,
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: EdgeInsets.fromLTRB(outerPadding, 0, outerPadding, layout.bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedOpacity(
                  opacity: _scrubbing ? 0.0 : 1.0,
                  duration: _kFadeDuration,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: rowPadding),
                    child: Row(
                      children: [
                        Expanded(
                          child: layout.showTime
                              ? Align(alignment: Alignment.centerLeft, child: buildTimeLabel())
                              : const SizedBox(),
                        ),
                        if (layout.showSpeed) buildSpeedControl(),
                        if (controller.value.videoPlayerController != null) ...[
                          SizedBox(width: layout.gap),
                          buildExpand(widget.isFullScreen ? _onReduceCollapse : _onExpandCollapse),
                        ],
                      ],
                    ),
                  ),
                ),
                buildProgress(
                  () {
                    setState(() {
                      _scrubbing = true;
                    });
                    show();
                  },
                  () {
                    setState(() {
                      _scrubbing = false;
                    });
                    show(duration: _kAutoHideDelay);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTimeLabel() {
    final controller = context.watch<BetterVideoPlayerController>();
    final videoValue = controller.value.videoPlayerController?.value;
    final position = videoValue?.position ?? Duration.zero;
    final duration = videoValue?.duration ?? Duration.zero;

    final baseStyle = TextStyle(
      fontSize: _layout.fontSize,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.none,
      fontFeatures: const [FontFeature.tabularFigures()],
      shadows: const [Shadow(color: Color(0x66000000), blurRadius: 4)],
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: formatPlayerTime(position),
            style: baseStyle.copyWith(color: _theme.textColor),
          ),
          TextSpan(
            text: '  /  ${formatPlayerTime(duration)}',
            style: baseStyle.copyWith(
              color: _theme.textColor.withAlpha(0xB3),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
    );
  }

  Widget buildSpeedControl() {
    final videoController = context.read<BetterVideoPlayerController>().value.videoPlayerController;
    // Read from the player so inline and full screen always agree.
    final speed = videoController?.value.playbackSpeed ?? _currentSpeed;

    return Material(
      type: MaterialType.transparency,
      child: PopupMenuButton<double>(
        initialValue: speed,
        tooltip: 'Playback speed',
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.over,
        offset: const Offset(0, -8),
        elevation: 12,
        color: _theme.surfaceColor.withAlpha(0xF2),
        shadowColor: const Color(0x99000000),
        surfaceTintColor: const Color(0x00000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        constraints: const BoxConstraints(minWidth: 112),
        onOpened: () {
          _speedMenuOpen = true;
          show();
        },
        onCanceled: () {
          _speedMenuOpen = false;
          show(duration: _kAutoHideDelay);
        },
        onSelected: (double speed) {
          _speedMenuOpen = false;
          setState(() {
            _currentSpeed = speed;
          });
          final videoController = context.read<BetterVideoPlayerController>().value.videoPlayerController;
          videoController?.setPlaybackSpeed(speed);
          show(duration: _kAutoHideDelay);
        },
        itemBuilder: (BuildContext context) => _kPlaybackSpeeds.map((value) {
          final selected = value == speed;
          return PopupMenuItem<double>(
            value: value,
            height: 42,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: selected ? Icon(Icons.check_rounded, size: 18, color: _theme.accentColor) : null,
                ),
                const SizedBox(width: 6),
                Text(
                  _speedLabel(value),
                  style: TextStyle(
                    color: selected ? _theme.accentColor : _theme.textColor,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        child: Container(
          height: _layout.chipHeight,
          padding: EdgeInsets.symmetric(horizontal: _layout.chipHeight * 0.36),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _theme.surfaceColor,
            borderRadius: BorderRadius.circular(_layout.chipHeight / 2),
            border: Border.all(color: const Color(0x24FFFFFF)),
          ),
          child: Text(
            _speedLabel(speed),
            style: TextStyle(
              color: speed == 1.0 ? _theme.textColor : _theme.accentColor,
              fontSize: _layout.fontSize,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildError(VoidCallback onTap) {
    final size = _layout.centerSize;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline_rounded,
          color: _theme.errorColor,
          size: size * 0.5,
        ),
        SizedBox(height: size * 0.18),
        _Pressable(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _theme.surfaceColor,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x24FFFFFF)),
            ),
            child: Icon(
              Icons.refresh_rounded,
              color: _theme.iconColor,
              size: size * 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildExpand(VoidCallback onTap) {
    return _RoundIconButton(
      icon: widget.isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
      size: _layout.buttonSize,
      iconSize: _layout.iconSize + 2,
      theme: _theme,
      onTap: onTap,
    );
  }

  Widget buildPlayPause(VoidCallback onTap) {
    return buildCenterPause(onTap);
  }

  Widget buildWifiInterrupted(VoidCallback onTap) {
    final size = _layout.centerSize;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _CenterPlayButton(
          size: size,
          isPlaying: false,
          theme: _theme,
          onTap: onTap,
        ),
        Positioned(
          right: -size * 0.06,
          top: -size * 0.06,
          child: Container(
            width: size * 0.38,
            height: size * 0.38,
            decoration: BoxDecoration(
              color: _theme.surfaceColor.withAlpha(0xF2),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x24FFFFFF)),
            ),
            child: Icon(
              Icons.wifi_off_rounded,
              color: _theme.errorColor,
              size: size * 0.22,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildCenterPause(VoidCallback onTap) {
    final controller = context.watch<BetterVideoPlayerController>();
    return _CenterPlayButton(
      size: _layout.centerSize,
      isPlaying: controller.value.videoPlayerController?.value.isPlaying ?? false,
      theme: _theme,
      onTap: onTap,
    );
  }

  Widget buildReplay(VoidCallback onTap) {
    final size = _layout.centerSize;
    return _Pressable(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: _accentCircle(_theme),
        child: Icon(
          Icons.replay_rounded,
          color: _theme.iconColor,
          size: size * 0.52,
        ),
      ),
    );
  }

  Widget buildProgress(Function onDragStart, Function onDragEnd) {
    return BetterVideoPlayerProgressWidget(
      onDragStart: onDragStart,
      onDragEnd: onDragEnd,
      height: _layout.progressHeight,
      thumbRadius: _layout.thumbRadius,
    );
  }

  List<Widget> buildCustomWidgets(bool isHide) {
    return [];
  }

  Widget _buildScrim() {
    final scrim = _theme.scrimColor;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: scrim.withAlpha(0x1F)),
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            widthFactor: 1,
            heightFactor: 0.6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [scrim.withAlpha(0), scrim.withAlpha(0x52), scrim.withAlpha(0xB8)],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),
        if (widget.isFullScreen)
          Align(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              widthFactor: 1,
              heightFactor: 0.3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [scrim.withAlpha(0x8C), scrim.withAlpha(0)],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _speedLabel(double speed) {
    final text = speed == speed.roundToDouble() ? speed.toStringAsFixed(0) : speed.toString();
    return '${text}x';
  }

  void _onExpandCollapse() {
    hide();
    context.read<BetterVideoPlayerController>().enterFullScreen();
  }

  void _onReduceCollapse() {
    hide();
    context.read<BetterVideoPlayerController>().exitFullScreen();
  }

  void _onPlayPause() {
    final controller = context.read<BetterVideoPlayerController>();

    if (controller.value.videoPlayerController == null) {
      return;
    }

    if (controller.value.videoPlayerController?.value.isPlaying ?? false) {
      controller.value = controller.value.copyWith(isPauseFromUser: true);

      setState(() {
        absorbing = true;
      });
      Future.delayed(Duration.zero, () async {
        await controller.pause();
        await Future.delayed(Duration(milliseconds: 100));
        if (!mounted) return;
        setState(() {
          absorbing = false;
        });
      });
    } else {
      controller.value = controller.value.copyWith(isPauseFromUser: false);

      if (controller.value.videoPlayerController?.value.isInitialized ?? false) {
        setState(() {
          absorbing = true;
        });
        Future.delayed(Duration.zero, () async {
          if (controller.value.isVideoFinish) {
            controller.value = controller.value.copyWith(isVideoFinish: false); // ✅ Reset finish flag
            await controller.seekTo(const Duration());
          }
          await controller.play();
          await Future.delayed(Duration(milliseconds: 100));
          if (!mounted) return;
          setState(() {
            absorbing = false;
          });
        });
      }
    }
  }

  void _onRestart() {
    final controller = context.read<BetterVideoPlayerController>();
    controller.restart();
  }
}

mixin HideStuff<T extends StatefulWidget> on State<T> {
  bool _isHide = true;
  Timer? _hideTimer;

  void show({Duration? duration}) {
    _hideTimer?.cancel();
    if (!mounted) return;
    if (duration != null) {
      _hideTimer = Timer(duration, () {
        if (!mounted) return;
        setState(() {
          _isHide = true;
        });
      });
    }

    setState(() {
      _isHide = false;
    });
  }

  void hide() {
    _hideTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isHide = true;
    });
  }

  bool isAlwaysShow() {
    return !_isHide && !(_hideTimer?.isActive ?? false);
  }
}

// Sizes for the current player box. Small inline players (chat bubbles,
// grids) get a compact layout so the progress bar and buttons stay usable.
class _ControlsLayout {
  final double centerSize;
  final double buttonSize;
  final double iconSize;
  final double chipHeight;
  final double fontSize;
  final double edgePadding;
  final double bottomPadding;
  final double gap;
  final double progressHeight;
  final double thumbRadius;
  final bool showTime;
  final bool showSpeed;

  // On short players the center button is centered in the space above the
  // bottom bar instead of the whole box, so the two never overlap.
  final double centerBottomInset;

  const _ControlsLayout({
    required this.centerSize,
    required this.buttonSize,
    required this.iconSize,
    required this.chipHeight,
    required this.fontSize,
    required this.edgePadding,
    required this.bottomPadding,
    required this.gap,
    required this.progressHeight,
    required this.thumbRadius,
    required this.showTime,
    required this.showSpeed,
    this.centerBottomInset = 0,
  });

  const _ControlsLayout.regular()
      : centerSize = 60,
        buttonSize = 36,
        iconSize = 22,
        chipHeight = 26,
        fontSize = 12,
        edgePadding = 12,
        bottomPadding = 2,
        gap = 6,
        progressHeight = 26,
        thumbRadius = 6,
        showTime = true,
        showSpeed = true,
        centerBottomInset = 0;

  // Horizontal space the progress bar reserves around its track for the thumb,
  // used so the track lines up with the row above it.
  double get progressInset => thumbRadius * 1.35 + 2;

  double get bottomBarHeight => buttonSize + progressHeight + bottomPadding;

  _ControlsLayout _withCenterInset(double height) {
    final free = (height - centerSize) / 2;
    if (free >= bottomBarHeight + 4) {
      return this;
    }
    return _ControlsLayout(
      centerSize: centerSize,
      buttonSize: buttonSize,
      iconSize: iconSize,
      chipHeight: chipHeight,
      fontSize: fontSize,
      edgePadding: edgePadding,
      bottomPadding: bottomPadding,
      gap: gap,
      progressHeight: progressHeight,
      thumbRadius: thumbRadius,
      showTime: showTime,
      showSpeed: showSpeed,
      centerBottomInset: math.max(0.0, math.min(bottomBarHeight, height - centerSize)),
    );
  }

  factory _ControlsLayout.resolve(Size size, bool isFullScreen) {
    final width = size.width.isFinite ? size.width : 360.0;
    final height = size.height.isFinite ? size.height : 200.0;
    final shortest = math.min(width, height);

    if (isFullScreen) {
      return _ControlsLayout(
        centerSize: (shortest * 0.2).clamp(60.0, 84.0),
        buttonSize: 44,
        iconSize: 26,
        chipHeight: 30,
        fontSize: 13,
        edgePadding: 24,
        bottomPadding: 10,
        gap: 10,
        progressHeight: 30,
        thumbRadius: 7,
        showTime: true,
        showSpeed: true,
      )._withCenterInset(height);
    }

    final compact = width < 300;
    return _ControlsLayout(
      centerSize: (shortest * 0.22).clamp(40.0, 64.0),
      buttonSize: compact ? 30 : 36,
      iconSize: compact ? 20 : 22,
      chipHeight: compact ? 22 : 26,
      fontSize: compact ? 11 : 12,
      edgePadding: compact ? 8 : 12,
      bottomPadding: compact ? 0 : 2,
      gap: compact ? 4 : 6,
      progressHeight: compact ? 22 : 26,
      thumbRadius: compact ? 5 : 6,
      showTime: width >= 150,
      showSpeed: width >= 210,
    )._withCenterInset(height);
  }
}

BoxDecoration _accentCircle(BetterVideoPlayerTheme theme) {
  final gradient = theme.accentGradient;
  return BoxDecoration(
    shape: BoxShape.circle,
    color: gradient.length >= 2 ? null : theme.accentColor,
    gradient: gradient.length >= 2
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          )
        : null,
    boxShadow: [
      BoxShadow(
        color: theme.accentColor.withAlpha(0x66),
        blurRadius: 18,
        spreadRadius: 1,
      ),
    ],
  );
}

// Big center button. Brand gradient while paused (the call to action),
// quiet frosted surface while playing. The icon morphs play <-> pause.
class _CenterPlayButton extends StatefulWidget {
  final double size;
  final bool isPlaying;
  final BetterVideoPlayerTheme theme;
  final VoidCallback onTap;

  const _CenterPlayButton({
    Key? key,
    required this.size,
    required this.isPlaying,
    required this.theme,
    required this.onTap,
  }) : super(key: key);

  @override
  _CenterPlayButtonState createState() => _CenterPlayButtonState();
}

class _CenterPlayButtonState extends State<_CenterPlayButton> with SingleTickerProviderStateMixin {
  late final AnimationController _iconController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: widget.isPlaying ? 1.0 : 0.0,
  );

  @override
  void didUpdateWidget(covariant _CenterPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _iconController.forward();
      } else {
        _iconController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final size = widget.size;
    final decoration = widget.isPlaying
        ? BoxDecoration(
            shape: BoxShape.circle,
            color: theme.surfaceColor,
            border: Border.all(color: const Color(0x24FFFFFF)),
          )
        : _accentCircle(theme);

    return _Pressable(
      onTap: widget.onTap,
      semanticLabel: widget.isPlaying ? 'Pause' : 'Play',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: size,
        height: size,
        decoration: decoration,
        alignment: Alignment.center,
        child: AnimatedIcon(
          icon: AnimatedIcons.play_pause,
          progress: _iconController,
          color: theme.iconColor,
          size: size * 0.5,
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final BetterVideoPlayerTheme theme;
  final VoidCallback onTap;
  final bool filled;

  // Touch target, defaults to the visual size.
  final double? hitSize;

  const _RoundIconButton({
    Key? key,
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.theme,
    required this.onTap,
    this.filled = false,
    this.hitSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final target = hitSize ?? size;
    return _Pressable(
      onTap: onTap,
      child: SizedBox(
        width: target,
        height: target,
        child: Center(
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: filled
                ? BoxDecoration(
                    color: theme.surfaceColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x24FFFFFF)),
                  )
                : null,
            child: Icon(
              icon,
              color: theme.iconColor,
              size: iconSize,
              shadows: filled ? null : const [Shadow(color: Color(0x66000000), blurRadius: 6)],
            ),
          ),
        ),
      ),
    );
  }
}

// Tap target with a soft press-down scale, used instead of CupertinoButton so
// every control has the same feel.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final String? semanticLabel;

  const _Pressable({
    Key? key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
  }) : super(key: key);

  @override
  _PressableState createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() {
        _pressed = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _pressed ? 0.8 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// Fades its child in only after [delay], so short waits never show anything.
class _DelayedReveal extends StatefulWidget {
  final Duration delay;
  final Widget child;

  const _DelayedReveal({Key? key, required this.delay, required this.child}) : super(key: key);

  @override
  _DelayedRevealState createState() => _DelayedRevealState();
}

class _DelayedRevealState extends State<_DelayedReveal> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) {
        setState(() {
          _visible = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      child: widget.child,
    );
  }
}

// Brand-colored rotating arc used as the loading indicator.
class _SpinnerRing extends StatefulWidget {
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const _SpinnerRing({
    Key? key,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  }) : super(key: key);

  @override
  _SpinnerRingState createState() => _SpinnerRingState();
}

class _SpinnerRingState extends State<_SpinnerRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SpinnerRingPainter(
          color: widget.color,
          trackColor: widget.trackColor,
          strokeWidth: widget.strokeWidth,
        ),
      ),
    );
  }
}

class _SpinnerRingPainter extends CustomPainter {
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _SpinnerRingPainter({required this.color, required this.trackColor, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);

    canvas.drawCircle(
      rect.center,
      arcRect.width / 2,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    const sweep = math.pi * 1.5;
    canvas.drawArc(
      arcRect,
      0,
      sweep,
      false,
      Paint()
        ..shader = SweepGradient(
          colors: [color.withAlpha(0), color],
          stops: const [0.0, 0.75],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(_SpinnerRingPainter old) {
    return old.color != color || old.trackColor != trackColor || old.strokeWidth != strokeWidth;
  }
}

// Thin progress line at the very bottom while the controls are hidden.
class _MiniProgressLine extends StatelessWidget {
  final BetterVideoPlayerTheme theme;

  const _MiniProgressLine({Key? key, required this.theme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final value = context.watch<BetterVideoPlayerController>().videoPlayerValue;
    final durationMs = value?.duration.inMilliseconds ?? 0;
    final positionMs = value?.position.inMilliseconds ?? 0;
    final fraction = durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0;
    final gradient = theme.accentGradient;

    return SizedBox(
      height: 2.5,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: theme.trackColor),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: gradient.length >= 2 ? null : theme.accentColor,
                gradient: gradient.length >= 2 ? LinearGradient(colors: gradient) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
