import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content_repo.dart';
import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'cards_data.dart';
import 'cards_logic.dart';

/// Ids that were unlocked the last time the album opened. Kept out of the profile on purpose.
const seenKey = 'cards_seen_v1';

const _tiers = ['common', 'rare', 'gold'];

Color tierColor(String tier) => switch (tier) {
  'gold' => AppColors.yellow,
  'rare' => AppColors.blue,
  _ => AppColors.green,
};

class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({super.key});

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  Set<String>? _fresh; // unlocked since the last visit; decided once per visit

  Set<String> _freshOnce(List<CardDef> cards, Profile p) {
    final now = unlockedIds(cards, p);
    final prefs = ref.read(prefsProvider);
    final seen = {...?prefs.getStringList(seenKey)};
    WidgetsBinding.instance.addPostFrameCallback((_) => prefs.setStringList(seenKey, now.toList()));
    return now.difference(seen);
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(cardsProvider).value;
    final contentState = ref.watch(contentProvider);
    final content = contentState.value;
    final profile = ref.watch(profileProvider);
    Widget body;
    if (contentState.hasError || (cards != null && cards.isEmpty)) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Text(
            'The album could not load right now. Try again later.',
            style: context.text.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (cards == null || content == null) {
      body = const Center(child: CircularProgressIndicator(color: AppColors.ink));
    } else {
      _fresh ??= _freshOnce(cards, profile);
      body = _Album(cards: cards, content: content, profile: profile, fresh: _fresh!);
    }
    return AppScaffold(
      appBar: AppBar(title: const Text('Album')),
      body: Padding(
        padding: const EdgeInsets.only(top: kToolbarHeight),
        child: body,
      ),
    );
  }
}

class _Album extends StatelessWidget {
  const _Album({required this.cards, required this.content, required this.profile, required this.fresh});
  final List<CardDef> cards;
  final Content content;
  final Profile profile;
  final Set<String> fresh;

  @override
  Widget build(BuildContext context) {
    final lessonOrder = {for (final (i, l) in content.lessons.indexed) l.id: i};
    int order(CardDef c) => lessonOrder[c.lesson] ?? 999;
    final sorted = [...cards]
      ..sort((a, b) {
        final byLesson = order(a).compareTo(order(b));
        return byLesson != 0 ? byLesson : _tiers.indexOf(a.tier).compareTo(_tiers.indexOf(b.tier));
      });
    final groups = <String, List<CardDef>>{};
    for (final c in sorted) {
      groups.putIfAbsent(content.moduleOf(c.lesson)?.title ?? 'More', () => []).add(c);
    }
    final got = unlockedIds(cards, profile).length;
    final scale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 480 ? 3 : 2;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpace.md),
              sliver: SliverToBoxAdapter(
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$got of ${cards.length} collected', style: context.text.titleLarge),
                      const SizedBox(height: AppSpace.sm),
                      FatProgress(value: cards.isEmpty ? 0 : got / cards.length, color: AppColors.yellow),
                    ],
                  ),
                ),
              ),
            ),
            for (final e in groups.entries) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.sm),
                sliver: SliverToBoxAdapter(child: Text(e.key, style: context.text.titleLarge)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: AppSpace.md,
                    crossAxisSpacing: AppSpace.md,
                    mainAxisExtent: 120 + 110 * scale,
                  ),
                  itemCount: e.value.length,
                  itemBuilder: (_, i) => _CardCell(card: e.value[i], profile: profile, content: content, fresh: fresh),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.lg)),
          ],
        );
      },
    );
  }
}

class _CardCell extends StatelessWidget {
  const _CardCell({required this.card, required this.profile, required this.content, required this.fresh});
  final CardDef card;
  final Profile profile;
  final Content content;
  final Set<String> fresh;

  @override
  Widget build(BuildContext context) {
    final unlocked = isUnlocked(card, profile);
    final hint = unlockHint(card, profile, content.lesson(card.lesson)?.title ?? card.lesson);
    final isNew = unlocked && fresh.contains(card.id);
    final face = _CardFace(card: card, unlocked: unlocked, hint: hint, isNew: isNew);
    return Pressable(
      label: unlocked ? '${card.title}, ${card.tier}, unlocked' : '${card.title}, ${card.tier}, locked, $hint',
      onTap: () => _openSheet(context, card, unlocked, hint, content.lesson(card.lesson)?.title, profile),
      builder: (_, down) => Padding(
        padding: EdgeInsets.only(top: down ? 3 : 0, bottom: down ? 0 : 3),
        child: isNew && !context.reduceMotion
            ? TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.7, end: 1),
                duration: const Duration(milliseconds: 650),
                curve: Curves.elasticOut,
                builder: (_, s, child) => Transform.scale(scale: s, child: child),
                child: face,
              )
            : face,
      ),
    );
  }
}

void _openSheet(BuildContext context, CardDef card, bool unlocked, String hint, String? lesson, Profile profile) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpace.radius)),
      side: BorderSide(color: AppColors.ink, width: AppSpace.outline),
    ),
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SizedBox(
              width: 240,
              height: 320,
              child: unlocked
                  ? Tilt3D(
                      child: _CardFace(card: card, unlocked: true, hint: hint, big: true),
                    )
                  : _CardFace(card: card, unlocked: false, hint: hint, big: true),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          if (lesson != null) Text('From the lesson $lesson', textAlign: TextAlign.center, style: ctx.text.bodyMedium),
          if (!unlocked) ...[
            const SizedBox(height: AppSpace.sm),
            FatProgress(value: unlockProgress(card, profile), color: tierColor(card.tier)),
          ],
          const SizedBox(height: AppSpace.md),
          ChunkyButton(label: unlocked ? 'Nice' : 'Got it', onPressed: () => Navigator.of(ctx).pop()),
        ],
      ),
    ),
  );
}

/// One collectible. Unlocked: solid tier colour with a header band. Locked: flat paper piece with a padlock.
class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.card,
    required this.unlocked,
    required this.hint,
    this.isNew = false,
    this.big = false,
  });
  final CardDef card;
  final bool unlocked, isNew, big;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final k = big ? 1.4 : 1.0;
    final color = tierColor(card.tier);
    final gold = card.tier == 'gold';
    final fill = unlocked ? color : AppColors.paperDeep;
    final fg = unlocked ? AppColors.on(fill) : AppColors.inkDim;
    final tag = card.tier.toUpperCase();
    final text = context.text;

    final tagPill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.card : AppColors.track,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Text(tag, style: text.labelSmall!.copyWith(color: AppColors.ink)),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppSpace.radius),
        border: Border.all(color: AppColors.ink, width: gold && unlocked ? 4 : AppSpace.outline),
        boxShadow: [BoxShadow(color: AppColors.ink, offset: Offset(0, unlocked ? 5 : 3))],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 64 * k,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: unlocked ? AppColors.tint(color, 0.55) : AppColors.track,
                  border: const Border(bottom: BorderSide(color: AppColors.ink, width: 2)),
                ),
                child: ExcludeSemantics(
                  child: unlocked
                      ? Text(card.emoji, style: TextStyle(fontSize: 36 * k))
                      : CustomPaint(size: Size.square(38 * k), painter: const _LockPainter()),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleLarge!.copyWith(color: unlocked ? fg : AppColors.ink, fontSize: 18 * k),
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: Text(
                          unlocked ? card.blurb : hint,
                          maxLines: big ? 8 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall!.copyWith(
                            color: fg,
                            fontSize: 12 * k,
                            height: 1.25,
                            fontWeight: unlocked ? FontWeight.w700 : FontWeight.w800,
                          ),
                        ),
                      ),
                      tagPill,
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (unlocked && gold)
            Positioned(
              top: 4,
              right: 4,
              child: ExcludeSemantics(
                child: CustomPaint(size: Size.square(24 * k), painter: const _BurstPainter()),
              ),
            ),
          if (isNew)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
                child: Text('New', style: text.labelSmall!.copyWith(color: AppColors.card)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small padlock on a flat grey disc, standing in for the hidden card art.
class _LockPainter extends CustomPainter {
  const _LockPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 40;
    canvas.scale(k);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.ink;
    final shackle = Path()
      ..moveTo(12, 18)
      ..lineTo(12, 12)
      ..arcToPoint(const Offset(28, 12), radius: const Radius.circular(8))
      ..lineTo(28, 18);
    canvas.drawPath(shackle, ink);
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(7, 18, 26, 18), const Radius.circular(5));
    canvas.drawRRect(body, Paint()..color = AppColors.inkDim);
    canvas.drawRRect(body, ink);
    canvas.drawCircle(const Offset(20, 26), 2.6, Paint()..color = AppColors.paperDeep);
    canvas.drawLine(const Offset(20, 27), const Offset(20, 31), ink..strokeWidth = 2.6);
  }

  @override
  bool shouldRepaint(_LockPainter old) => false;
}

/// Eight-point star burst for gold cards.
class _BurstPainter extends CustomPainter {
  const _BurstPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 1.5;
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final a = i * pi / 8 - pi / 2;
      final rr = i.isEven ? r : r * 0.55;
      final p = c + Offset(cos(a), sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = AppColors.card);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.ink,
    );
  }

  @override
  bool shouldRepaint(_BurstPainter old) => false;
}
