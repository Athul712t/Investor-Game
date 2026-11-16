import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/entities/question.dart';

/// Renders one question, shows feedback and the explanation, then reports the
/// result through [onAnswered] when the player taps Continue.
/// Placeholder: handles the quick types only.
class QuestionView extends StatefulWidget {
  QuestionView({required this.question, required this.onAnswered, this.compact = false})
    : super(key: ValueKey(question.id));
  final Question question;
  final ValueChanged<bool> onAnswered;
  final bool compact; // true inside the in-game boost sheet

  @override
  State<QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<QuestionView> {
  bool? _correct;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final p = q.payload;
    final (String prompt, List<String> options, int right) = switch (q.type) {
      QuestionType.trueFalse => (p['statement']! as String, ['True', 'False'], p['answer'] == true ? 0 : 1),
      QuestionType.mythFact => (p['statement']! as String, ['Myth', 'Fact'], p['answer'] == 'myth' ? 0 : 1),
      _ => (
        p['prompt']! as String,
        [for (final o in p['options']! as List) o is Map ? o['text'] as String : o as String],
        (p['correctIndex'] ?? 0) as int,
      ),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(prompt, style: context.text.titleLarge),
        const SizedBox(height: AppSpace.md),
        if (_correct == null)
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ChunkyButton(
                label: options[i],
                color: AppColors.surfaceHi,
                onPressed: () => setState(() => _correct = i == right),
              ),
            )
        else ...[
          Text(
            _correct! ? 'Correct!' : 'Not quite',
            style: context.text.titleLarge!.copyWith(color: _correct! ? AppColors.mint : AppColors.coral),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(q.explanation, style: context.text.bodyLarge),
          const SizedBox(height: AppSpace.md),
          ChunkyButton(label: 'Continue', onPressed: () => widget.onAnswered(_correct!)),
        ],
      ],
    );
  }
}
