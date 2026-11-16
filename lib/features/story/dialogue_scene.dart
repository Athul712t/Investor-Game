import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'story_data.dart';

/// Full-screen visual-novel scene. Tap finishes the typing, tap again advances.
/// Pops true when the last line is done or the player skips; false when closed.
class DialogueScene extends ConsumerStatefulWidget {
  const DialogueScene({super.key, required this.node, required this.chapter});
  final StoryNode node;
  final Chapter chapter;

  @override
  ConsumerState<DialogueScene> createState() => _DialogueSceneState();
}

class _DialogueSceneState extends ConsumerState<DialogueScene> with SingleTickerProviderStateMixin {
  late final _typing = AnimationController(vsync: this);
  int _i = 0;
  bool _started = false;

  List<DialogueLine> get _lines => widget.node.lines;
  String get _text => _lines[_i].text.replaceAll('{name}', ref.read(profileProvider).name);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _startLine();
    }
  }

  void _startLine() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _typing.value = 1;
    } else {
      _typing.duration = Duration(milliseconds: 24 * _text.characters.length);
      _typing.forward(from: 0);
    }
  }

  void _tap() {
    if (_typing.isAnimating) {
      _typing.value = 1;
    } else if (_i == _lines.length - 1) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _i++);
      _startLine();
    }
  }

  @override
  void dispose() {
    _typing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = _lines[_i];
    final sp = Speaker.of(line.speaker);
    final name = line.speaker == 'you' ? ref.watch(profileProvider).name : sp.name;
    final narrator = sp.name.isEmpty;
    final right = line.speaker == 'you';
    final c = widget.chapter.color;
    final text = _text;
    final calm = MediaQuery.disableAnimationsOf(context);

    final bubble = AnimatedBuilder(
      animation: _typing,
      builder: (context, _) {
        final chars = text.characters;
        final shown = (chars.length * _typing.value).round();
        final style = narrator
            ? context.text.bodyLarge!.copyWith(fontSize: 18, fontStyle: FontStyle.italic, color: AppColors.textDim)
            : context.text.bodyLarge!.copyWith(fontSize: 19, height: 1.45);
        // The hidden remainder keeps the bubble at full size, so it doesn't grow while typing.
        return Text.rich(
          TextSpan(
            style: style,
            children: [
              TextSpan(text: chars.take(shown).toString()),
              TextSpan(
                text: chars.skip(shown).toString(),
                style: const TextStyle(color: Colors.transparent),
              ),
            ],
          ),
          textAlign: narrator ? TextAlign.center : TextAlign.start,
          semanticsLabel: '${narrator ? '' : '$name: '}$text',
        );
      },
    );

    return Scaffold(
      body: Semantics(
        button: true,
        label: 'Tap to continue',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _tap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.lerp(c, AppColors.ink, 0.72)!, AppColors.ink, AppColors.ink],
                    stops: const [0, 0.6, 1],
                  ),
                ),
              ),
              Positioned.fill(child: CustomPaint(painter: _SkylinePainter(c))),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: AppSpace.maxWidth),
                    child: Column(
                      children: [
                        _topBar(context, c),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
                          child: AnimatedSwitcher(
                            duration: calm ? Duration.zero : AppMotion.base,
                            switchInCurve: AppMotion.curve,
                            transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(
                                position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(a),
                                child: child,
                              ),
                            ),
                            child: KeyedSubtree(
                              key: ValueKey(_i),
                              child: narrator ? _narration(bubble) : _speech(context, sp, name, right, bubble),
                            ),
                          ),
                        ),
                        _hint(context),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, Color c) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.xs, AppSpace.sm, 0),
    child: Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            Expanded(
              child: FatProgress(value: (_i + 1) / _lines.length, color: c, height: 8),
            ),
            const SizedBox(width: AppSpace.sm),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.fast_forward_rounded, size: 18),
              label: const Text('Skip'),
              style: TextButton.styleFrom(foregroundColor: AppColors.textDim, minimumSize: const Size(48, 48)),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Text(widget.node.title.toUpperCase(), style: context.text.labelSmall!.copyWith(letterSpacing: 2)),
      ],
    ),
  );

  Widget _narration(Widget bubble) => Container(
    padding: const EdgeInsets.all(AppSpace.lg),
    decoration: BoxDecoration(
      color: AppColors.ink.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(AppSpace.radius),
      border: Border.all(color: AppColors.line),
    ),
    child: bubble,
  );

  Widget _speech(BuildContext context, Speaker sp, String name, bool right, Widget bubble) {
    final avatar = _Bob(
      child: Badge3D(emoji: sp.emoji, color: sp.color, size: 96),
    );
    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: sp.color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: Color.lerp(sp.color, AppColors.ink, 0.5)!, offset: const Offset(0, 3))],
      ),
      child: Text(name, style: context.text.titleMedium!.copyWith(color: AppColors.ink)),
    );
    return Column(
      crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          textDirection: right ? TextDirection.rtl : TextDirection.ltr,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: avatar,
            ),
            const SizedBox(width: AppSpace.sm),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: tag,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 120),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: sp.color.withValues(alpha: 0.7), width: 2),
                boxShadow: [BoxShadow(color: Color.lerp(sp.color, AppColors.ink, 0.65)!, offset: const Offset(0, 6))],
              ),
              child: bubble,
            ),
            // Tail pointing up at the speaker.
            Positioned(
              top: -9,
              left: right ? null : 48,
              right: right ? 48 : null,
              child: Transform.rotate(
                angle: pi / 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(color: sp.color.withValues(alpha: 0.7), width: 2),
                      left: BorderSide(color: sp.color.withValues(alpha: 0.7), width: 2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _hint(BuildContext context) => SizedBox(
    height: 40,
    child: AnimatedBuilder(
      animation: _typing,
      builder: (context, _) => AnimatedOpacity(
        opacity: _typing.isAnimating ? 0 : 1,
        duration: AppMotion.fast,
        child: Text(
          _i == _lines.length - 1 ? 'Tap to finish  ✓' : 'Tap to continue  ▾',
          style: context.text.labelSmall!.copyWith(letterSpacing: 1),
        ),
      ),
    ),
  );
}

/// Gentle idle bob for the speaking character. Still when animations are off.
class _Bob extends StatefulWidget {
  const _Bob({required this.child});
  final Widget child;

  @override
  State<_Bob> createState() => _BobState();
}

class _BobState extends State<_Bob> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context) ? _c.stop() : _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) =>
        Transform.translate(offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)), child: child),
    child: widget.child,
  );
}

/// City at dusk: stars, a big moon, two layers of buildings with lit windows.
class _SkylinePainter extends CustomPainter {
  _SkylinePainter(this.tint);
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(7);
    final w = size.width, h = size.height;
    final star = Paint()..color = AppColors.text.withValues(alpha: 0.5);
    for (var i = 0; i < 40; i++) {
      canvas.drawCircle(Offset(rng.nextDouble() * w, rng.nextDouble() * h * 0.4), rng.nextDouble() * 1.4 + 0.4, star);
    }
    final moon = Offset(w * 0.78, h * 0.16);
    canvas.drawCircle(moon, 80, Paint()..color = AppColors.amber.withValues(alpha: 0.05));
    canvas.drawCircle(moon, 52, Paint()..color = AppColors.amber.withValues(alpha: 0.07));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: moon, radius: 30)),
        Path()..addOval(Rect.fromCircle(center: moon + const Offset(12, -8), radius: 26)),
      ),
      Paint()..color = AppColors.amber.withValues(alpha: 0.9),
    );

    final base = h * 0.6;
    void layer(Color color, double minH, double maxH, double windowAlpha) {
      final paint = Paint()..color = color;
      final win = Paint()..color = AppColors.amber.withValues(alpha: windowAlpha);
      var x = -10.0;
      while (x < w) {
        final bw = 34 + rng.nextDouble() * 46;
        final bh = minH + rng.nextDouble() * (maxH - minH);
        final r = Rect.fromLTWH(x, base - bh, bw, h - base + bh);
        canvas.drawRRect(
          RRect.fromRectAndCorners(r, topLeft: const Radius.circular(4), topRight: const Radius.circular(4)),
          paint,
        );
        for (var wy = r.top + 12; wy < base + 40; wy += 18) {
          for (var wx = r.left + 8; wx < r.right - 10; wx += 14) {
            if (rng.nextDouble() < 0.35) canvas.drawRect(Rect.fromLTWH(wx, wy, 6, 8), win);
          }
        }
        x += bw + 4;
      }
    }

    layer(Color.lerp(Color.lerp(tint, AppColors.ink, 0.78)!, AppColors.surfaceHi, 0.35)!, 70, 210, 0.22);
    layer(AppColors.surface, 30, 110, 0.5);
    // Fade the street into the page so the dialogue sits on a calm surface.
    canvas.drawRect(
      Rect.fromLTWH(0, base - 20, w, h - base + 20),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.ink.withValues(alpha: 0), AppColors.ink],
          stops: const [0, 0.35],
        ).createShader(Rect.fromLTWH(0, base - 20, w, h - base + 20)),
    );
  }

  @override
  bool shouldRepaint(_SkylinePainter old) => old.tint != tint;
}
