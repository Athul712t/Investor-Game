import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content_repo.dart';
import '../../../core/profile.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../reel_item.dart';
import 'reel_tag.dart';

/// A quick read as a full reel page: big colour header, title, body and a Got it button.
class ReadCard extends ConsumerStatefulWidget {
  const ReadCard({super.key, required this.item, required this.active, required this.onDone});
  final ReelRead item;

  /// True only while this card is the one on screen. When false the card ignores taps.
  final bool active;

  /// Called exactly once when the player may scroll on.
  final ReelDone onDone;

  @override
  ConsumerState<ReadCard> createState() => _ReadCardState();
}

class _ReadCardState extends ConsumerState<ReadCard> {
  bool _done = false;

  void _gotIt() {
    if (_done) return;
    setState(() => _done = true);
    ref.read(profileProvider.notifier).reward(xp: 3);
    widget.onDone(correct: true);
  }

  @override
  Widget build(BuildContext context) {
    final module = ref.watch(contentProvider).value?.moduleOf(widget.item.lessonId);
    final color = AppColors.named(module?.color);
    final card = widget.item.card;
    final header = Container(
      height: 150,
      alignment: Alignment.center,
      decoration: pieceDecoration(fill: color),
      child: Text(card.emoji, style: const TextStyle(fontSize: 76), textScaler: TextScaler.noScaling),
    );
    return Semantics(
      container: true,
      label: 'Quick read: ${card.title}',
      child: IgnorePointer(
        ignoring: !widget.active,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ReelTag(module == null ? 'Quick read' : 'Quick read  ·  ${module.title}', color: color),
              ),
              const SizedBox(height: AppSpace.md),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PopIn(child: context.reduceMotion ? header : Tilt3D(child: header)),
                      const SizedBox(height: AppSpace.lg),
                      Text(card.title, style: context.text.headlineMedium),
                      const SizedBox(height: AppSpace.sm),
                      Text(card.body, style: context.text.bodyLarge!.copyWith(fontSize: 19, height: 1.4)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: ChunkyButton(
                  label: _done ? 'Nice' : 'Got it',
                  icon: _done ? Icons.check_rounded : null,
                  onPressed: _done ? null : _gotIt,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
