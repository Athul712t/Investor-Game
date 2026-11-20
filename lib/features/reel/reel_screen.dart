import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/profile.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../home_hub/pictograms.dart';
import 'cards/game_card.dart';
import 'cards/question_card.dart';
import 'cards/read_card.dart';
import 'gated_physics.dart';
import 'reel_chrome.dart';
import 'reel_feed.dart';
import 'reel_item.dart';

/// The reel: a vertical pager of games, questions and reads. A card must be finished before the
/// player can move on, the next card stays hidden until reached, and there is no way back.
class ReelScreen extends ConsumerStatefulWidget {
  const ReelScreen({super.key});

  @override
  ConsumerState<ReelScreen> createState() => _ReelScreenState();
}

class _ReelScreenState extends ConsumerState<ReelScreen> {
  final _pages = PageController();
  ReelFeed? _feed;
  final _items = <ReelItem>[];
  int _current = 0;
  bool _done = false; // the current card called onDone
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual(reelFeedProvider, (_, next) {
      // Take the first feed only: it is stateful, and the reel keeps going with it.
      if (_feed != null || !next.hasValue) return;
      setState(() {
        _feed = next.requireValue;
        _items.add(_feed!.next());
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _onDone(int index, {required bool correct}) {
    if (index != _current || _done) return;
    final feed = _feed!, item = _items[index], profile = ref.read(profileProvider.notifier);
    if (item is ReelQuestion && !correct) feed.reportWrong(item);
    final streak = item is ReelQuestion && !correct ? 0 : _streak + 1;
    // Save before drawing the hidden next card, so leaving now replays it rather than skipping it.
    profile.saveReel(
      cursor: feed.cursor.toJson(),
      bestStreak: streak > ref.read(profileProvider).reelBestStreak ? streak : null,
    );
    setState(() {
      _streak = streak;
      _done = true;
      _items.add(feed.next());
    });
    Sound.play(Sfx.tick);
    Haptics.light();
  }

  void _next() {
    if (!_done || !_pages.hasClients) return;
    final pos = _pages.position;
    if (pos is ScrollPositionWithSingleContext) pos.goBallistic(GatedPagePhysics.flick + 1);
  }

  bool _onScrollEnd(ScrollEndNotification n) {
    if (n.depth != 0 || !_done) return false;
    final m = n.metrics;
    if (m.pixels > (_current + 0.5) * m.viewportDimension) {
      setState(() {
        _current++;
        _done = false;
      });
      // Settle exactly on the page edge once this scroll has fully ended.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pages.hasClients) _pages.jumpToPage(_current);
      });
      Sound.play(Sfx.swipe, volume: 0.5);
    }
    return false;
  }

  // Wheel and arrow keys: only "next", and only when allowed. Swallowed otherwise so nothing scrolls back.
  void _onPointerSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (_) {
      if (e.scrollDelta.dy > 0) _next();
    });
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown || e.logicalKey == LogicalKeyboardKey.pageDown) {
      _next();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp || e.logicalKey == LogicalKeyboardKey.pageUp) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _exit() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      context.go('/');
    }
  }

  Widget _page(BuildContext context, int index) {
    if (index > _current) return const HiddenCard();
    if (index < _current) return const SizedBox.shrink(); // never visible again
    final item = _items[index];
    void done({required bool correct}) => _onDone(index, correct: correct);
    final card = switch (item) {
      ReelGame() => GameCard(item: item, active: true, onDone: done),
      ReelQuestion() => QuestionCard(item: item, active: true, onDone: done),
      ReelRead() => ReadCard(item: item, active: true, onDone: done),
    };
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: KeyedSubtree(
        key: ValueKey(item.id),
        child: PopIn(child: card),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(reelFeedProvider);
    return AppScaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Column(
          children: [
            _TopBar(streak: _streak, onExit: _exit),
            Expanded(
              child: _feed != null
                  ? _pager(context)
                  : feed.hasError
                  ? _Problem(onRetry: () => ref.invalidate(reelFeedProvider), onExit: _exit)
                  : const _Loading(),
            ),
            if (_feed != null) SwipeCue(open: _done, onNext: _next),
          ],
        ),
      ),
    );
  }

  Widget _pager(BuildContext context) => NotificationListener<ScrollEndNotification>(
    onNotification: _onScrollEnd,
    child: PageView.builder(
      controller: _pages,
      scrollDirection: Axis.vertical,
      pageSnapping: false, // GatedPagePhysics snaps
      physics: GatedPagePhysics(page: _current, open: _done, reduceMotion: context.reduceMotion),
      scrollBehavior: ScrollConfiguration.of(context)
          .copyWith(scrollbars: false, overscroll: false, dragDevices: PointerDeviceKind.values.toSet()),
      itemCount: _items.length,
      itemBuilder: _page,
    ),
  );
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.streak, required this.onExit});
  final int streak;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.xs, AppSpace.md, AppSpace.xs),
      child: Row(
        children: [
          ExitButton(onTap: onExit),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  children: [
                    ReelPill(
                      semantic: 'Reel streak',
                      icon: const Pictogram(Pic.flame, size: 22, color: AppColors.orange),
                      value: streak,
                    ),
                    const SizedBox(width: AppSpace.sm),
                    ReelPill(semantic: 'Coins', icon: const Coin3D(size: 22), value: p.coins),
                    const SizedBox(width: AppSpace.sm),
                    ReelPill(
                      semantic: 'XP',
                      icon: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
                        child: const Icon(Icons.bolt_rounded, size: 16, color: AppColors.card),
                      ),
                      value: p.xp,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 4, color: AppColors.ink)),
        const SizedBox(height: AppSpace.md),
        Text('Shuffling your reel...', style: context.text.titleLarge),
      ],
    ),
  );
}

class _Problem extends StatelessWidget {
  const _Problem({required this.onRetry, required this.onExit});
  final VoidCallback onRetry, onExit;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Panel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('The reel is taking a break', textAlign: TextAlign.center, style: context.text.headlineSmall),
            const SizedBox(height: AppSpace.sm),
            Text(
              'We could not load your cards. Check your connection and try again.',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: AppSpace.md),
            ChunkyButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: onRetry),
            const SizedBox(height: AppSpace.sm),
            ChunkyButton(label: 'Back home', color: AppColors.card, onPressed: onExit),
          ],
        ),
      ),
    ),
  );
}
