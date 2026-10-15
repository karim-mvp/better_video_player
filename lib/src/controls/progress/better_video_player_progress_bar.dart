import 'dart:math' as math;

import 'package:better_video_player/src/controls/progress/better_video_player_progress_colors.dart';
import 'package:better_video_player/src/core/better_video_player_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

// Seekable progress bar.
//
// The whole widget height is the touch target, while only a thin track is
// painted, so it stays easy to grab even when the player is small. The thumb
// follows the finger immediately while dragging (seeks are async and lag
// behind), and a time bubble shows where the video will land.
class BetterVideoPlayerProgressBar extends StatefulWidget {
  BetterVideoPlayerProgressBar({
    this.colors,
    required this.onDragEnd,
    required this.onDragStart,
    this.onDragUpdate,
    this.height = 3,
    this.activeHeight = 5,
    this.thumbRadius = 6,
    this.showScrubLabel = true,
    Key? key,
  }) : super(key: key);

  // Falls back to the player theme when null.
  final BetterVideoPlayerProgressColors? colors;
  final Function onDragStart;
  final Function onDragEnd;
  final Function? onDragUpdate;

  // Track thickness at rest.
  final double height;

  // Track thickness while the user is scrubbing.
  final double activeHeight;

  // Thumb radius at rest, it grows while scrubbing.
  final double thumbRadius;

  // Floating time bubble above the thumb while scrubbing.
  final bool showScrubLabel;

  @override
  _VideoProgressBarState createState() {
    return _VideoProgressBarState();
  }
}

class _VideoProgressBarState extends State<BetterVideoPlayerProgressBar> {
  // Finger position while dragging, drives the UI instead of the real position.
  double? _dragFraction;

  // Last requested seek, held briefly so the thumb doesn't jump back while the
  // player is still seeking.
  double? _seekFraction;
  DateTime? _seekRequestedAt;

  static const Duration _seekHold = Duration(milliseconds: 900);
  static const double _activeThumbScale = 1.35;

  double get _inset => widget.thumbRadius * _activeThumbScale + 2;

  double _fractionAt(Offset localPosition, double width) {
    final trackWidth = width - _inset * 2;
    if (trackWidth <= 0) {
      return 0;
    }
    return ((localPosition.dx - _inset) / trackWidth).clamp(0.0, 1.0);
  }

  void _seekTo(double fraction) {
    _seekFraction = fraction;
    _seekRequestedAt = DateTime.now();
    context.read<BetterVideoPlayerController>().onProgressDragUpdate(fraction);
  }

  double _displayFraction(double actual) {
    if (_dragFraction != null) {
      return _dragFraction!;
    }
    final seekFraction = _seekFraction;
    final requestedAt = _seekRequestedAt;
    if (seekFraction != null && requestedAt != null) {
      final settled = (actual - seekFraction).abs() < 0.01;
      final expired = DateTime.now().difference(requestedAt) > _seekHold;
      if (!settled && !expired) {
        return seekFraction;
      }
      _seekFraction = null;
      _seekRequestedAt = null;
    }
    return actual;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BetterVideoPlayerController>();
    final videoPlayerValue = controller.value.videoPlayerController?.value;
    final theme = controller.value.configuration.theme;
    final colors = widget.colors ?? BetterVideoPlayerProgressColors.fromTheme(theme);

    final isInitialized = videoPlayerValue?.isInitialized ?? false;
    final duration = videoPlayerValue?.duration ?? Duration.zero;
    final position = videoPlayerValue?.position ?? Duration.zero;
    final actual = isInitialized && duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final fraction = _displayFraction(actual);
    final isDragging = _dragFraction != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (DragStartDetails details) {
            context.read<BetterVideoPlayerController>().onProgressDragStart();
            setState(() {
              _dragFraction = _fractionAt(details.localPosition, width);
            });

            widget.onDragStart();
          },
          onHorizontalDragUpdate: (DragUpdateDetails details) {
            final next = _fractionAt(details.localPosition, width);
            setState(() {
              _dragFraction = next;
            });
            _seekTo(next);

            if (widget.onDragUpdate != null) {
              widget.onDragUpdate!();
            }
          },
          onHorizontalDragEnd: (DragEndDetails details) {
            final last = _dragFraction;
            setState(() {
              _dragFraction = null;
              if (last != null) {
                _seekFraction = last;
                _seekRequestedAt = DateTime.now();
              }
            });
            context.read<BetterVideoPlayerController>().onProgressDragEnd();

            widget.onDragEnd();
          },
          onHorizontalDragCancel: () {
            if (_dragFraction != null) {
              setState(() {
                _dragFraction = null;
              });
            }
          },
          onTapDown: (TapDownDetails details) {
            _seekTo(_fractionAt(details.localPosition, width));
            setState(() {});
          },
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: isDragging ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            builder: (context, activeT, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ProgressBarPainter(
                        value: videoPlayerValue,
                        colors: colors,
                        fraction: fraction,
                        barHeight: widget.height + (widget.activeHeight - widget.height) * activeT,
                        thumbRadius: widget.thumbRadius * (1 + (_activeThumbScale - 1) * activeT),
                        haloOpacity: activeT,
                        haloColor: theme.accentColor,
                        inset: _inset,
                      ),
                    ),
                  ),
                  if (widget.showScrubLabel && activeT > 0.01)
                    _buildScrubLabel(
                      width: width,
                      height: constraints.maxHeight,
                      fraction: fraction,
                      duration: duration,
                      opacity: activeT,
                      textColor: theme.textColor,
                      surfaceColor: theme.surfaceColor,
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildScrubLabel({
    required double width,
    required double height,
    required double fraction,
    required Duration duration,
    required double opacity,
    required Color textColor,
    required Color surfaceColor,
  }) {
    const labelWidth = 64.0;
    final trackWidth = math.max(0.0, width - _inset * 2);
    final center = _inset + trackWidth * fraction;
    final double left = (center - labelWidth / 2).clamp(0.0, math.max(0.0, width - labelWidth)).toDouble();

    return Positioned(
      left: left,
      bottom: height / 2 + widget.thumbRadius * _activeThumbScale + 8,
      width: labelWidth,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: surfaceColor.withAlpha(0xE6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x1FFFFFFF)),
              ),
              child: Text(
                formatPlayerTime(duration * fraction),
                maxLines: 1,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// m:ss, or h:mm:ss for long videos.
String formatPlayerTime(Duration duration) {
  final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
  }
  return '$minutes:$ss';
}

class _ProgressBarPainter extends CustomPainter {
  _ProgressBarPainter({
    required this.value,
    required this.colors,
    required this.fraction,
    required this.barHeight,
    required this.thumbRadius,
    required this.haloOpacity,
    required this.haloColor,
    required this.inset,
  });

  final VideoPlayerValue? value;
  final BetterVideoPlayerProgressColors colors;
  final double fraction;
  final double barHeight;
  final double thumbRadius;
  final double haloOpacity;
  final Color haloColor;
  final double inset;

  @override
  bool shouldRepaint(_ProgressBarPainter old) {
    return old.value != value ||
        old.fraction != fraction ||
        old.barHeight != barHeight ||
        old.thumbRadius != thumbRadius ||
        old.haloOpacity != haloOpacity ||
        old.colors != colors;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final left = inset;
    final right = size.width - inset;
    if (right <= left) {
      return;
    }
    final trackWidth = right - left;
    final centerY = size.height / 2;
    final radius = Radius.circular(barHeight / 2);

    RRect segment(double from, double to) {
      return RRect.fromLTRBR(from, centerY - barHeight / 2, to, centerY + barHeight / 2, radius);
    }

    canvas.drawRRect(segment(left, right), colors.backgroundPaint);

    final value = this.value;
    if (value == null || !value.isInitialized) {
      return;
    }

    final duration = value.duration;
    if (duration.inMilliseconds > 0) {
      for (final DurationRange range in value.buffered) {
        final start = left + range.startFraction(duration).clamp(0.0, 1.0) * trackWidth;
        final end = left + range.endFraction(duration).clamp(0.0, 1.0) * trackWidth;
        if (end > start) {
          canvas.drawRRect(segment(start, end), colors.bufferedPaint);
        }
      }
    }

    final playedEnd = left + fraction.clamp(0.0, 1.0) * trackWidth;
    if (playedEnd > left) {
      final gradient = colors.playedGradient;
      Paint playedPaint = colors.playedPaint;
      if (gradient != null && gradient.length >= 2) {
        // Shader spans the full track so colors don't stretch as playback advances.
        playedPaint = Paint()
          ..shader = LinearGradient(colors: gradient).createShader(
            Rect.fromLTRB(left, centerY - barHeight / 2, right, centerY + barHeight / 2),
          );
      }
      canvas.drawRRect(segment(left, math.max(playedEnd, left + barHeight)), playedPaint);
    }

    final thumbCenter = Offset(playedEnd, centerY);

    if (haloOpacity > 0) {
      canvas.drawCircle(
        thumbCenter,
        thumbRadius * 2.1,
        Paint()..color = haloColor.withAlpha((0x47 * haloOpacity).round()),
      );
    }

    canvas.drawCircle(
      thumbCenter.translate(0, 1),
      thumbRadius + 0.5,
      Paint()
        ..color = const Color(0x52000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(thumbCenter, thumbRadius, colors.handlePaint);
  }
}
