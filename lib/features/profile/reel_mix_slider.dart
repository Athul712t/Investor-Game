import 'package:flutter/physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../reel/reel_sequencer.dart';

/// Reel mode: a 5-stop slider from games only (gamepad end) to learning only (mortarboard end).
/// Each new stop clicks, buzzes and saves at once.
class ReelMixSlider extends ConsumerStatefulWidget {
  const ReelMixSlider({super.key});

  @override
  ConsumerState<ReelMixSlider> createState() => _ReelMixSliderState();
}

class _ReelMixSliderState extends ConsumerState<ReelMixSlider> with SingleTickerProviderStateMixin {
  static const _last = 4;
  static const _thumbW = 34.0, _thumbH = 42.0;

  /// Colour of the track segment between stop i and i + 1: games yellow walking to knowledge blue.
  static const _segments = [AppColors.yellow, AppColors.green, AppColors.teal, AppColors.blue];

  late int _stop = ref.read(profileProvider).reelMix;
  late final _pos = AnimationController.unbounded(vsync: this, value: _stop.toDouble()); // in stops
  bool _dragging = false, _focused = false;

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  void _select(int stop) {
    stop = stop.clamp(0, _last);
    if (stop == _stop) return;
    setState(() => _stop = stop);
    Haptics.select();
    Sound.play(Sfx.tick);
    ref.read(profileProvider.notifier).saveReelMix(stop);
  }

  void _settle() {
    if (context.reduceMotion) {
      _pos.value = _stop.toDouble();
    } else {
      _pos.animateWith(SpringSimulation(AppMotion.spring, _pos.value, _stop.toDouble(), 0));
    }
  }

  void _go(int stop) {
    _select(stop);
    _settle();
  }

  double _stopAt(double x, double width) =>
      ((x - _thumbW / 2) / (width - _thumbW) * _last).clamp(0.0, _last.toDouble());

  @override
  Widget build(BuildContext context) {
    // Another device (cloud restore) may change the setting under us.
    ref.listen(profileProvider.select((p) => p.reelMix), (_, s) {
      if (s != _stop) {
        setState(() => _stop = s);
        if (!_dragging) _settle();
      }
    });
    final label = ReelMix.labels[_stop];
    return Semantics(
      slider: true,
      label: 'Reel mode',
      value: label,
      hint: ReelMix.captions[_stop],
      increasedValue: _stop < _last ? ReelMix.labels[_stop + 1] : null,
      decreasedValue: _stop > 0 ? ReelMix.labels[_stop - 1] : null,
      onIncrease: _stop < _last ? () => _go(_stop + 1) : null,
      onDecrease: _stop > 0 ? () => _go(_stop - 1) : null,
      focusable: true,
      focused: _focused,
      excludeSemantics: true,
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        onKeyEvent: (_, e) {
          if (e is KeyUpEvent) return KeyEventResult.ignored;
          final k = e.logicalKey;
          if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.arrowUp) {
            _go(_stop + 1);
          } else if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowDown) {
            _go(_stop - 1);
          } else {
            return KeyEventResult.ignored;
          }
          return KeyEventResult.handled;
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpace.depth),
          padding: const EdgeInsets.fromLTRB(AppSpace.md, 12, AppSpace.md, 14),
          decoration: pieceDecoration(outline: _focused ? AppColors.blue : AppColors.ink),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.text.headlineSmall),
              const SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  const _EndIcon(_End.games),
                  const SizedBox(width: 6),
                  Expanded(child: _track()),
                  const SizedBox(width: 6),
                  const _EndIcon(_End.learning),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Text(ReelMix.captions[_stop], style: context.text.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _track() => LayoutBuilder(
    builder: (context, box) {
      final w = box.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _go(_stopAt(d.localPosition.dx, w).round()),
        onHorizontalDragStart: (d) {
          _pos.stop();
          setState(() => _dragging = true);
          _pos.value = _stopAt(d.localPosition.dx, w);
          _select(_pos.value.round());
        },
        onHorizontalDragUpdate: (d) {
          _pos.value = _stopAt(d.localPosition.dx, w);
          _select(_pos.value.round());
        },
        onHorizontalDragEnd: (_) {
          setState(() => _dragging = false);
          _settle();
        },
        onHorizontalDragCancel: () {
          setState(() => _dragging = false);
          _settle();
        },
        child: SizedBox(
          height: 56,
          child: AnimatedBuilder(
            animation: _pos,
            builder: (context, _) {
              final x = _pos.value.clamp(0.0, _last.toDouble()) / _last * (w - _thumbW);
              final thumbColor = _segments[(_stop - 1).clamp(0, _segments.length - 1)];
              final sink = _dragging ? 4.0 : 0.0;
              return Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _TrackPainter(_pos.value, _segments, _thumbW / 2))),
                  Positioned(
                    left: x,
                    top: (56 - _thumbH) / 2 - 2 + sink,
                    child: Container(
                      width: _thumbW,
                      height: _thumbH,
                      decoration: pieceDecoration(fill: thumbColor, radius: 12, depth: 4 - sink),
                      child: const _Grip(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

/// Three ink ridges so the thumb reads as something to grab.
class _Grip extends StatelessWidget {
  const _Grip();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < 3; i++)
        Container(
          width: 3,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(2)),
        ),
    ],
  );
}

/// The outlined track: solid segments filled up to [pos] (in stops), then a notch per stop.
class _TrackPainter extends CustomPainter {
  _TrackPainter(this.pos, this.segments, this.inset);
  final double pos, inset;
  final List<Color> segments;

  @override
  void paint(Canvas canvas, Size size) {
    const h = 18.0;
    final last = segments.length;
    final cy = size.height / 2 - 2;
    final bar = RRect.fromLTRBR(0, cy - h / 2, size.width, cy + h / 2, const Radius.circular(h / 2));
    final step = (size.width - 2 * inset) / last;
    double xOf(double s) => inset + s * step;

    canvas.drawRRect(bar.shift(const Offset(0, 3)), Paint()..color = AppColors.ink); // hard shadow
    canvas.drawRRect(bar, Paint()..color = AppColors.paperDeep);
    canvas.save();
    canvas.clipRRect(bar);
    final p = pos.clamp(0.0, last.toDouble());
    for (var i = 0; i < last && i < p; i++) {
      // The first segment also covers the rounded cap left of stop 0.
      final left = i == 0 ? 0.0 : xOf(i.toDouble());
      canvas.drawRect(
        Rect.fromLTRB(left, bar.top, xOf(p < i + 1 ? p : i + 1.0), bar.bottom),
        Paint()..color = segments[i],
      );
    }
    canvas.restore();
    canvas.drawRRect(
      bar,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppSpace.outline
        ..color = AppColors.ink,
    );
    for (var i = 0; i <= last; i++) {
      canvas.drawCircle(
        Offset(xOf(i.toDouble()), cy),
        3.5,
        Paint()..color = i <= p + 0.01 ? AppColors.card : AppColors.ink,
      );
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.pos != pos;
}

enum _End { games, learning }

/// Painted end pictograms: a gamepad for games, a mortarboard for learning.
class _EndIcon extends StatelessWidget {
  const _EndIcon(this.end);
  final _End end;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: const Size.square(40), painter: _EndPainter(end)),
  );
}

class _EndPainter extends CustomPainter {
  _EndPainter(this.end);
  final _End end;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 100; // drawn in a 100x100 box
    canvas.scale(k);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.6 / k
      ..color = AppColors.ink;
    void shape(Path p, Color fill) => canvas
      ..drawPath(p, Paint()..color = fill)
      ..drawPath(p, stroke);
    Path poly(List<double> xy) {
      final p = Path()..moveTo(xy[0], xy[1]);
      for (var i = 2; i < xy.length; i += 2) {
        p.lineTo(xy[i], xy[i + 1]);
      }
      return p..close();
    }

    switch (end) {
      case _End.games:
        // Body with two grips, a d-pad and two buttons.
        Path part(Rect r, double radius) => Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
        final body = Path.combine(
          PathOperation.union,
          part(const Rect.fromLTRB(8, 30, 92, 64), 17),
          Path.combine(
            PathOperation.union,
            part(Rect.fromCircle(center: const Offset(24, 66), radius: 15), 15),
            part(Rect.fromCircle(center: const Offset(76, 66), radius: 15), 15),
          ),
        );
        canvas.drawPath(body.shift(const Offset(0, 4)), Paint()..color = AppColors.ink);
        shape(body, AppColors.yellow);
        final ink = Paint()..color = AppColors.ink;
        canvas
          ..drawRRect(RRect.fromLTRBR(20, 45, 40, 53, const Radius.circular(2)), ink)
          ..drawRRect(RRect.fromLTRBR(26, 39, 34, 59, const Radius.circular(2)), ink);
        shape(Path()..addOval(Rect.fromCircle(center: const Offset(64, 52), radius: 6.5)), AppColors.red);
        shape(Path()..addOval(Rect.fromCircle(center: const Offset(77, 43), radius: 6.5)), AppColors.blue);
      case _End.learning:
        // Cap under a flat board, with a tassel hanging off the button.
        shape(poly([28, 50, 72, 50, 72, 74, 50, 82, 28, 74]), AppColors.blue);
        final board = poly([50, 16, 94, 36, 50, 56, 6, 36]);
        canvas.drawPath(board.shift(const Offset(0, 4)), Paint()..color = AppColors.ink);
        shape(board, AppColors.blue);
        final cord = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 4
          ..color = AppColors.ink;
        canvas.drawPath(
          Path()
            ..moveTo(50, 36)
            ..lineTo(84, 44)
            ..lineTo(84, 70),
          cord,
        );
        shape(poly([78, 68, 90, 68, 92, 84, 76, 84]), AppColors.yellow);
        shape(Path()..addOval(Rect.fromCircle(center: const Offset(50, 36), radius: 5)), AppColors.yellow);
    }
  }

  @override
  bool shouldRepaint(_EndPainter old) => old.end != end;
}
