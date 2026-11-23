import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content_repo.dart';
import '../../../core/profile.dart';
import '../../../core/theme.dart';
import '../../content/question_view.dart';
import '../reel_item.dart';
import 'reel_tag.dart';

/// A question as a full reel page. [QuestionView] owns feedback and its Continue button.
class QuestionCard extends ConsumerStatefulWidget {
  const QuestionCard({super.key, required this.item, required this.active, required this.onDone});
  final ReelQuestion item;

  /// True only while this card is the one on screen. When false the card ignores taps.
  final bool active;

  /// Called exactly once when the player may scroll on.
  final ReelDone onDone;

  @override
  ConsumerState<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends ConsumerState<QuestionCard> {
  bool _done = false;

  void _answered(bool correct) {
    if (_done) return;
    _done = true;
    ref.read(profileProvider.notifier)
      ..noteAnswer(widget.item.question, correct)
      ..reward(xp: correct ? 8 : 3, coins: correct ? 1 : 0);
    widget.onDone(correct: correct);
  }

  @override
  Widget build(BuildContext context) {
    final module = ref.watch(contentProvider).value?.moduleOf(widget.item.lessonId);
    final color = AppColors.named(module?.color);
    return Semantics(
      container: true,
      label: 'Question card',
      child: IgnorePointer(
        ignoring: !widget.active,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  ReelTag(module == null ? 'Question' : 'Question  ·  ${module.title}', color: color),
                  if (widget.item.retry) const ReelTag('Second look', color: AppColors.yellow),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              QuestionView(question: widget.item.question, onAnswered: _answered),
            ],
          ),
        ),
      ),
    );
  }
}
