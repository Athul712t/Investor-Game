import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content_repo.dart';
import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../content/question_view.dart';

/// One question a day, the same for everyone on that date.
class DailyCard extends ConsumerWidget {
  const DailyCard({super.key});
  static const xp = 15, coins = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dayKey(DateTime.now());
    final done = ref.watch(profileProvider.select((p) => p.dailyDoneDay)) == today;
    final question = ref.watch(contentProvider).value?.randomQuick(Random(today.hashCode));
    if (question == null) return const SizedBox.shrink();
    return Panel(
      accent: done ? null : AppColors.red,
      child: Row(
        children: [
          Badge3D(emoji: done ? '✅' : '🎯', color: done ? AppColors.green : AppColors.red),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily question', style: context.text.titleLarge),
                Text(
                  done ? 'Done for today. Come back tomorrow!' : 'One answer a day. +$xp XP, +$coins coins',
                  style: context.text.bodyMedium,
                ),
              ],
            ),
          ),
          if (!done)
            ChunkyButton(
              label: 'Go',
              expand: false,
              color: AppColors.red,
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppColors.card,
                showDragHandle: true,
                builder: (sheet) => SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpace.lg,
                      0,
                      AppSpace.lg,
                      AppSpace.lg + MediaQuery.viewInsetsOf(sheet).bottom,
                    ),
                    child: QuestionView(
                      question: question,
                      compact: true,
                      onAnswered: (correct) {
                        final n = ref.read(profileProvider.notifier)..markDailyDone();
                        // Wrong answers still earn a little: showing up is the habit.
                        n.reward(xp: correct ? xp : 5, coins: correct ? coins : 0);
                        Navigator.pop(sheet);
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
